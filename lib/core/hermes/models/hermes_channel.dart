/// Model for one Hermes inbound channel (Telegram / Discord / Slack /
/// WhatsApp). Settings live in `~/.hermes/config.yaml`; bot tokens
/// live in `~/.hermes/.env` and are NEVER displayed — we only surface
/// a presence boolean so the user knows whether the channel is
/// runnable.
library;

enum HermesChannelKind { telegram, discord, slack, whatsapp }

extension HermesChannelKindLabel on HermesChannelKind {
  String get displayName => switch (this) {
        HermesChannelKind.telegram => 'Telegram',
        HermesChannelKind.discord => 'Discord',
        HermesChannelKind.slack => 'Slack',
        HermesChannelKind.whatsapp => 'WhatsApp',
      };

  /// The top-level YAML key for this channel in `config.yaml`.
  String get yamlKey => name;

  /// The .env variable name we expect the bot token / API key under.
  /// Verified by reading the live VPS layout — Hermes uses
  /// `<UPPERCASE>_BOT_TOKEN` for chat platforms and a different
  /// convention for WhatsApp Cloud API.
  String get envTokenKey => switch (this) {
        HermesChannelKind.telegram => 'TELEGRAM_BOT_TOKEN',
        HermesChannelKind.discord => 'DISCORD_BOT_TOKEN',
        HermesChannelKind.slack => 'SLACK_BOT_TOKEN',
        HermesChannelKind.whatsapp => 'WHATSAPP_ACCESS_TOKEN',
      };
}

/// Field-type tag used by the UI to render the right widget for a
/// given setting key. Inferred from the value at read time so the
/// model doesn't need to know about each channel's schema.
enum HermesChannelFieldType { bool_, csv, text, map }

class HermesChannelConfig {
  final HermesChannelKind kind;

  /// Raw settings deserialised from YAML. Map order is preserved as
  /// it was read so the UI can render fields in a stable order
  /// matching the file. Values are bool / String / Map<String, dynamic>.
  final Map<String, dynamic> settings;

  /// True when a corresponding bot token exists in `~/.hermes/.env`.
  /// Used purely for the "🔑 Token present" badge — never expose the
  /// token itself.
  final bool tokenPresent;

  const HermesChannelConfig({
    required this.kind,
    required this.settings,
    required this.tokenPresent,
  });

  HermesChannelConfig copyWith({Map<String, dynamic>? settings}) =>
      HermesChannelConfig(
        kind: kind,
        settings: settings ?? this.settings,
        tokenPresent: tokenPresent,
      );

  bool get isConfigured =>
      settings.values.any((v) => v != null && v != '' && v != false &&
          !(v is Map && v.isEmpty));

  /// Best-effort type inference for the UI editor.
  static HermesChannelFieldType inferType(dynamic value) {
    if (value is bool) return HermesChannelFieldType.bool_;
    if (value is Map) return HermesChannelFieldType.map;
    final s = value is String ? value : '';
    if (s.contains(',')) return HermesChannelFieldType.csv;
    return HermesChannelFieldType.text;
  }
}

class HermesChannelsBundle {
  final List<HermesChannelConfig> channels;
  const HermesChannelsBundle({required this.channels});

  HermesChannelConfig? byKind(HermesChannelKind k) =>
      channels.cast<HermesChannelConfig?>().firstWhere(
            (c) => c?.kind == k,
            orElse: () => null,
          );
}
