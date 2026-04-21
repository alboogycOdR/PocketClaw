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
///
/// Persistence strategy (dual-store — 2026-04-21):
///   - Primary   : `flutter_secure_storage` (Android Keystore-backed EncryptedSharedPreferences).
///   - Secondary : plain `SharedPreferences` under a dedicated key.
///   The secondary copy is a pragmatic durability fallback — on some OEM
///   Android builds (Huawei/MediaTek) Keystore entries get wiped after
///   reinstall or OTA, which caused the client to generate a fresh keypair
///   and require a new pairing approval each time. The prefs copy is
///   plaintext-readable by any app that can access the app's data dir (on
///   rooted devices, that's any app; on stock devices, only the OS + our
///   code). Acceptable trade-off for a Tailscale-only admin-approval
///   topology; revisit for public release.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  final String deviceId;
  final Uint8List publicKeyRaw;
  final Uint8List privateKeySeed;
  final DateTime? createdAt;

  const DeviceIdentity({
    required this.deviceId,
    required this.publicKeyRaw,
    required this.privateKeySeed,
    this.createdAt,
  });

  String get publicKeyBase64Url => _b64UrlNoPad(publicKeyRaw);

  SimpleKeyPairData asKeyPair() => SimpleKeyPairData(
        privateKeySeed,
        publicKey:
            SimplePublicKey(publicKeyRaw, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );

  static const _storageKey = 'openclaw_device_identity_v1';
  static const _prefsBackupKey = 'openclaw_device_identity_backup_v1';
  static const _storage = FlutterSecureStorage();

  /// Load from persistent storage (dual-store — secure first, prefs fallback).
  /// Generates + persists a new identity only if BOTH stores are empty or
  /// corrupted.
  static Future<DeviceIdentity> loadOrCreate() async {
    // 1. Try secure storage first.
    final secureJson = await _safeSecureRead();
    final fromSecure = _decodeIdentity(secureJson);

    // 2. Fall back to SharedPreferences if secure is missing / corrupted.
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString(_prefsBackupKey);
    final fromPrefs = _decodeIdentity(prefsJson);

    // 3. If either store has a valid identity, use it — preferring secure.
    //    Also self-heal: if one store has data but the other doesn't,
    //    write the missing side so both stores match.
    final chosen = fromSecure ?? fromPrefs;
    if (chosen != null) {
      if (fromSecure == null) {
        // Secure lost its entry (Keystore wiped?) — repopulate from prefs.
        await _writeSecure(chosen);
      }
      if (fromPrefs == null) {
        // Prefs backup missing — populate from secure.
        await _writePrefs(prefs, chosen);
      }
      return chosen;
    }

    // 4. Both stores empty → generate a fresh keypair.
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
      createdAt: DateTime.now(),
    );
    await _writeSecure(identity);
    await _writePrefs(prefs, identity);
    return identity;
  }

  /// Read the current identity without creating a fresh one. Returns null if
  /// neither store holds a valid identity — useful for a Settings display.
  static Future<DeviceIdentity?> current() async {
    final secureJson = await _safeSecureRead();
    final fromSecure = _decodeIdentity(secureJson);
    if (fromSecure != null) return fromSecure;
    final prefs = await SharedPreferences.getInstance();
    return _decodeIdentity(prefs.getString(_prefsBackupKey));
  }

  /// Wipe both stores. Next call to `loadOrCreate()` generates a fresh
  /// keypair — which the user must then have re-approved on the gateway.
  static Future<void> reset() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {/* already gone or inaccessible */}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsBackupKey);
  }

  static Future<String?> _safeSecureRead() async {
    try {
      return await _storage.read(key: _storageKey);
    } catch (_) {
      // Keystore wiped / inaccessible — return null and let the caller
      // fall through to the prefs backup.
      return null;
    }
  }

  static DeviceIdentity? _decodeIdentity(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final pub = base64Decode(m['publicKey'] as String);
      final priv = base64Decode(m['privateKeySeed'] as String);
      final id = m['deviceId'] as String;
      final createdAtMs = m['createdAtMs'];
      return DeviceIdentity(
        deviceId: id,
        publicKeyRaw: pub,
        privateKeySeed: priv,
        createdAt: createdAtMs is int
            ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toJson(DeviceIdentity d) => {
        'version': 1,
        'deviceId': d.deviceId,
        'publicKey': base64Encode(d.publicKeyRaw),
        'privateKeySeed': base64Encode(d.privateKeySeed),
        'createdAtMs':
            (d.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      };

  static Future<void> _writeSecure(DeviceIdentity d) async {
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(_toJson(d)));
    } catch (_) {
      // Keystore may reject writes on some devices — fail soft; the prefs
      // backup still gets written by the caller.
    }
  }

  static Future<void> _writePrefs(
    SharedPreferences prefs,
    DeviceIdentity d,
  ) async {
    await prefs.setString(_prefsBackupKey, jsonEncode(_toJson(d)));
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
