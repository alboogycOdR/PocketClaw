/// Messaging channel models — mirrors the ClawX desktop client's
/// `src/types/channel.ts` so types stay aligned with the same OpenClaw
/// backend.
library;

/// The 15 messaging channel types OpenClaw supports.
enum ChannelType {
  whatsapp,
  wechat,
  dingtalk,
  telegram,
  discord,
  signal,
  feishu,
  wecom,
  imessage,
  matrix,
  line,
  msteams,
  googlechat,
  mattermost,
  qqbot;

  static ChannelType? tryParse(String? raw) {
    if (raw == null) return null;
    final norm = raw.toLowerCase().trim();
    for (final t in ChannelType.values) {
      if (t.name == norm) return t;
    }
    return null;
  }

  String get displayName => switch (this) {
        ChannelType.whatsapp => 'WhatsApp',
        ChannelType.wechat => 'WeChat',
        ChannelType.dingtalk => 'DingTalk',
        ChannelType.telegram => 'Telegram',
        ChannelType.discord => 'Discord',
        ChannelType.signal => 'Signal',
        ChannelType.feishu => 'Feishu',
        ChannelType.wecom => 'WeCom',
        ChannelType.imessage => 'iMessage',
        ChannelType.matrix => 'Matrix',
        ChannelType.line => 'LINE',
        ChannelType.msteams => 'Microsoft Teams',
        ChannelType.googlechat => 'Google Chat',
        ChannelType.mattermost => 'Mattermost',
        ChannelType.qqbot => 'QQ Bot',
      };

  String get emoji => switch (this) {
        ChannelType.whatsapp => '🟢',
        ChannelType.wechat => '💬',
        ChannelType.dingtalk => '🔔',
        ChannelType.telegram => '✈️',
        ChannelType.discord => '🎮',
        ChannelType.signal => '🔒',
        ChannelType.feishu => '🦅',
        ChannelType.wecom => '🏢',
        ChannelType.imessage => '💙',
        ChannelType.matrix => '🟦',
        ChannelType.line => '💚',
        ChannelType.msteams => '🟣',
        ChannelType.googlechat => '🟧',
        ChannelType.mattermost => '🔷',
        ChannelType.qqbot => '🐧',
      };

  ChannelConnectionType get connection => switch (this) {
        ChannelType.whatsapp => ChannelConnectionType.qr,
        ChannelType.wechat => ChannelConnectionType.qr,
        ChannelType.imessage => ChannelConnectionType.qr,
        ChannelType.telegram => ChannelConnectionType.token,
        ChannelType.qqbot => ChannelConnectionType.token,
        ChannelType.line => ChannelConnectionType.token,
        ChannelType.discord => ChannelConnectionType.oauth,
        ChannelType.msteams => ChannelConnectionType.oauth,
        ChannelType.googlechat => ChannelConnectionType.oauth,
        ChannelType.feishu => ChannelConnectionType.oauth,
        ChannelType.wecom => ChannelConnectionType.oauth,
        ChannelType.dingtalk => ChannelConnectionType.oauth,
        ChannelType.matrix => ChannelConnectionType.token,
        ChannelType.mattermost => ChannelConnectionType.token,
        ChannelType.signal => ChannelConnectionType.qr,
      };
}

enum ChannelConnectionType { token, qr, oauth, webhook }

enum ChannelStatus { connected, disconnected, connecting, degraded, error }

ChannelStatus _parseStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'connected':
      return ChannelStatus.connected;
    case 'connecting':
      return ChannelStatus.connecting;
    case 'degraded':
      return ChannelStatus.degraded;
    case 'error':
      return ChannelStatus.error;
    default:
      return ChannelStatus.disconnected;
  }
}

/// One configured account on a channel (e.g. one WhatsApp number, one
/// Telegram bot token). A single channel type can have multiple accounts.
class ChannelAccount {
  final String accountId;
  final String name;
  final ChannelStatus status;
  final bool configured;
  final bool isDefault;
  final String? statusReason;
  final String? lastError;
  final String? agentId;
  final Map<String, dynamic> raw;

  const ChannelAccount({
    required this.accountId,
    required this.name,
    required this.status,
    this.configured = false,
    this.isDefault = false,
    this.statusReason,
    this.lastError,
    this.agentId,
    this.raw = const {},
  });

  factory ChannelAccount.fromJson(Map<String, dynamic> json) => ChannelAccount(
        accountId: json['accountId'] as String? ??
            json['account_id'] as String? ??
            json['id'] as String? ??
            '',
        name: json['name'] as String? ?? '(unnamed)',
        status: _parseStatus(json['status'] as String?),
        configured: json['configured'] == true,
        isDefault: json['isDefault'] == true || json['is_default'] == true,
        statusReason: json['statusReason'] as String?,
        lastError: json['lastError'] as String?,
        agentId: json['agentId'] as String?,
        raw: json,
      );
}

/// A channel type entry in the live status response — bundles the channel
/// type with its accounts and the rolled-up status.
class ChannelGroup {
  final ChannelType type;
  final ChannelStatus status;
  final List<ChannelAccount> accounts;
  final String? statusReason;
  final String? defaultAccountId;
  final Map<String, dynamic> raw;

  const ChannelGroup({
    required this.type,
    required this.status,
    this.accounts = const [],
    this.statusReason,
    this.defaultAccountId,
    this.raw = const {},
  });

  bool get isConfigured =>
      accounts.any((a) => a.configured) ||
      status == ChannelStatus.connected ||
      status == ChannelStatus.connecting ||
      status == ChannelStatus.degraded;

  factory ChannelGroup.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['channelType'] ?? json['type'] ?? json['id'])
        as String?;
    final type = ChannelType.tryParse(typeRaw);
    final accountsRaw = (json['accounts'] as List?) ?? const [];
    return ChannelGroup(
      type: type ?? ChannelType.telegram, // safe fallback for filtering
      status: _parseStatus(json['status'] as String?),
      accounts: [
        for (final a in accountsRaw)
          if (a is Map<String, dynamic>) ChannelAccount.fromJson(a),
      ],
      statusReason: json['statusReason'] as String?,
      defaultAccountId: json['defaultAccountId'] as String?,
      raw: json,
    );
  }
}
