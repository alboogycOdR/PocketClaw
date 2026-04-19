/// Persistent Ed25519 device identity for OpenClaw gateway pairing.
///
/// Mirrors the behavior of the OpenClaw client's `loadOrCreateDeviceIdentity`
/// and crypto primitives (`buildDeviceAuthPayloadV3`, `signDevicePayload`,
/// `deriveDeviceIdFromPublicKey`, `publicKeyRawBase64UrlFromPem`).
///
/// Wire-format contract (all must match the JS implementation exactly):
///   - deviceId      = lowercase-hex SHA-256 of the raw 32-byte Ed25519 pubkey (64 chars).
///   - publicKey     = raw 32 bytes, base64url-encoded, no padding (43 chars).
///   - signature     = raw 64-byte Ed25519 signature, base64url, no padding (86 chars).
///   - signed bytes  = UTF-8 of the `|`-joined v3 payload (see buildSignaturePayloadV3).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdentity {
  final String deviceId;
  final Uint8List publicKeyRaw;
  final Uint8List privateKeySeed;

  const DeviceIdentity({
    required this.deviceId,
    required this.publicKeyRaw,
    required this.privateKeySeed,
  });

  String get publicKeyBase64Url => _b64UrlNoPad(publicKeyRaw);

  SimpleKeyPairData asKeyPair() => SimpleKeyPairData(
        privateKeySeed,
        publicKey:
            SimplePublicKey(publicKeyRaw, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );

  static const _storageKey = 'openclaw_device_identity_v1';
  static const _storage = FlutterSecureStorage();

  /// Load from secure storage, generate+persist on first run.
  static Future<DeviceIdentity> loadOrCreate() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) {
      try {
        final m = jsonDecode(existing) as Map<String, dynamic>;
        final pub = base64Decode(m['publicKey'] as String);
        final priv = base64Decode(m['privateKeySeed'] as String);
        final id = m['deviceId'] as String;
        // Re-derive and self-heal if pubkey/id disagree.
        final derived = await _deviceIdFromPublicKeyRaw(pub);
        if (derived != id) {
          final fixed = DeviceIdentity(
            deviceId: derived,
            publicKeyRaw: pub,
            privateKeySeed: priv,
          );
          await _persist(fixed);
          return fixed;
        }
        return DeviceIdentity(
          deviceId: id,
          publicKeyRaw: pub,
          privateKeySeed: priv,
        );
      } catch (_) {
        // Fallthrough to generate a fresh identity.
      }
    }

    final algo = Ed25519();
    final kp = await algo.newKeyPair();
    final kpData = await kp.extract();
    final pubKey = await kp.extractPublicKey();
    final pubBytes = Uint8List.fromList(pubKey.bytes);
    final privBytes = Uint8List.fromList(kpData.bytes);
    final id = await _deviceIdFromPublicKeyRaw(pubBytes);
    final identity = DeviceIdentity(
      deviceId: id,
      publicKeyRaw: pubBytes,
      privateKeySeed: privBytes,
    );
    await _persist(identity);
    return identity;
  }

  static Future<void> _persist(DeviceIdentity d) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'version': 1,
        'deviceId': d.deviceId,
        'publicKey': base64Encode(d.publicKeyRaw),
        'privateKeySeed': base64Encode(d.privateKeySeed),
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  static Future<String> _deviceIdFromPublicKeyRaw(Uint8List raw) async {
    final digest = await Sha256().hash(raw);
    return _toLowerHex(Uint8List.fromList(digest.bytes));
  }
}

/// Build the v3 signature payload EXACTLY as `buildDeviceAuthPayloadV3` does
/// on the OpenClaw side: `v3|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce|platform|deviceFamily`.
///
/// `scopes` is comma-joined (no spaces). `token` defaults to "". `platform`
/// and `deviceFamily` are ASCII-lowercased and trimmed.
String buildSignaturePayloadV3({
  required String deviceId,
  required String clientId,
  required String clientMode,
  required String role,
  required List<String> scopes,
  required int signedAtMs,
  required String? token,
  required String nonce,
  required String? platform,
  required String? deviceFamily,
}) {
  return [
    'v3',
    deviceId,
    clientId,
    clientMode,
    role,
    scopes.join(','),
    '$signedAtMs',
    token ?? '',
    nonce,
    _normalizeDeviceMetadataForAuth(platform),
    _normalizeDeviceMetadataForAuth(deviceFamily),
  ].join('|');
}

/// Mirror of server-side `normalizeDeviceMetadataForAuth`: trim, then ASCII
/// lowercase (only A–Z → a–z). Dart's `String.toLowerCase()` is Unicode-aware
/// and would diverge on non-ASCII input, so we do it by code unit.
String _normalizeDeviceMetadataForAuth(String? value) {
  if (value == null) return '';
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final units = trimmed.codeUnits;
  final out = List<int>.filled(units.length, 0);
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    out[i] = (c >= 0x41 && c <= 0x5A) ? c + 32 : c;
  }
  return String.fromCharCodes(out);
}

/// Ed25519-sign UTF-8 bytes of `payload`, return base64url (no padding).
Future<String> signPayloadEd25519(
  String payload,
  DeviceIdentity identity,
) async {
  final algo = Ed25519();
  final sig = await algo.sign(
    utf8.encode(payload),
    keyPair: identity.asKeyPair(),
  );
  return _b64UrlNoPad(Uint8List.fromList(sig.bytes));
}

String _b64UrlNoPad(Uint8List bytes) {
  return base64UrlEncode(bytes).replaceAll(RegExp(r'=+$'), '');
}

String _toLowerHex(Uint8List bytes) {
  const hex = '0123456789abcdef';
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(hex[(b >> 4) & 0xF]);
    out.write(hex[b & 0xF]);
  }
  return out.toString();
}
