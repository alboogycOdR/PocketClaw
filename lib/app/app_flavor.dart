/// Compile-time app flavor selection.
library;

enum AppFlavor { clawCommander, hermesCommander }

const _rawFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'hermesCommander',
);

const AppFlavor kAppFlavor = _rawFlavor == 'clawCommander'
    ? AppFlavor.clawCommander
    : AppFlavor.hermesCommander;

const bool kHermesOnlyMode = kAppFlavor == AppFlavor.hermesCommander;

extension AppFlavorConfig on AppFlavor {
  bool get isHermesOnly => this == AppFlavor.hermesCommander;

  String get appName => switch (this) {
    AppFlavor.clawCommander => 'ClawCommander',
    AppFlavor.hermesCommander => 'HermesCommander',
  };

  String get shortName => switch (this) {
    AppFlavor.clawCommander => 'Claw',
    AppFlavor.hermesCommander => 'Hermes',
  };

  String get packageId => switch (this) {
    AppFlavor.clawCommander => 'com.carmen.clawcommander',
    AppFlavor.hermesCommander => 'com.nuburo.hermescommander',
  };
}

String get appFlavorName => kAppFlavor.appName;

bool get isHermesOnlyMode => kHermesOnlyMode;
