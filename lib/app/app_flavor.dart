/// Compile-time app flavor selection.
library;

enum AppFlavor { clawCommander, hermesCommander }

const _flavorName = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'clawCommander',
);

const AppFlavor kAppFlavor = _flavorName == 'hermesCommander'
    ? AppFlavor.hermesCommander
    : AppFlavor.clawCommander;

const bool kHermesOnlyMode = kAppFlavor == AppFlavor.hermesCommander;

String get appFlavorName => switch (kAppFlavor) {
  AppFlavor.clawCommander => 'ClawCommander',
  AppFlavor.hermesCommander => 'Hermes Commander',
};

bool get isHermesOnlyMode => kHermesOnlyMode;
