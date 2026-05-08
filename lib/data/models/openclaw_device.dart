/// OpenClaw paired/pending device — one row from the `devices.list` RPC.
library;

class OpenClawDevice {
  final String id;
  final String? name;
  final String status; // 'paired' | 'pending' | 'revoked'
  final String? publicKey; // Ed25519 public key (base64 or hex per gateway)
  final DateTime? pairedAt;
  final DateTime? lastSeenAt;
  final bool isCurrentDevice;

  const OpenClawDevice({
    required this.id,
    this.name,
    this.status = 'unknown',
    this.publicKey,
    this.pairedAt,
    this.lastSeenAt,
    this.isCurrentDevice = false,
  });

  bool get isPending => status == 'pending';
  bool get isPaired => status == 'paired';
  bool get isRevoked => status == 'revoked';

  OpenClawDevice copyWith({bool? isCurrentDevice}) => OpenClawDevice(
        id: id,
        name: name,
        status: status,
        publicKey: publicKey,
        pairedAt: pairedAt,
        lastSeenAt: lastSeenAt,
        isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
      );

  factory OpenClawDevice.fromJson(Map<String, dynamic> json) => OpenClawDevice(
        id: json['id'] as String? ?? '',
        name: json['name'] as String?,
        status: json['status'] as String? ?? 'unknown',
        publicKey: json['publicKey'] as String?,
        pairedAt: _parseDate(json['pairedAt']),
        lastSeenAt: _parseDate(json['lastSeenAt']),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}
