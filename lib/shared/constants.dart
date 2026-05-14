/// ClawCommander constants
library;

class AppConstants {
  AppConstants._();

  static const String appName = 'ClawCommander';
  static const String appVersion = '2.8.0';
  static const String orgName = 'Nuburo.DIGITAL (PTY) LTD';

  // Default Gateway
  static const int defaultGatewayPort = 18789;
  static const String defaultSessionKey = 'pocket-claw-main';

  // Smart Router thresholds
  static const int simpleTaskMinKeywords = 2;
  static const Duration routerTimeout = Duration(milliseconds: 50);

  // Performance budgets
  static const Duration localFirstToken = Duration(seconds: 3);
  static const Duration serverFirstToken = Duration(seconds: 2);
  static const Duration ragSearchTimeout = Duration(milliseconds: 100);

  // Mission Control refresh intervals
  static const Duration healthRefreshInterval = Duration(seconds: 30);
  static const Duration usageRefreshInterval = Duration(minutes: 5);

  // Local LLM
  static const int minRamForGemma = 6000;
  static const int minRamForQwen = 4000;

  // Memory
  static const int maxRagResults = 5;
  static const int maxConversationHistory = 10;
}
