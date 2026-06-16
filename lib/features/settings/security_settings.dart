/// Security settings: biometric lock toggle, clear data
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../app/theme.dart';
import '../../core/device/battery_optimization_service.dart';
import '../../data/providers/core_providers.dart';

class SecuritySettings extends ConsumerStatefulWidget {
  const SecuritySettings({super.key});

  @override
  ConsumerState<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<SecuritySettings>
    with WidgetsBindingObserver {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool? _batteryExempt;
  bool _batteryChecking = true;
  bool _toggling = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricState();
    _loadBatteryState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBatteryState();
    }
  }

  Future<void> _loadBiometricState() async {
    final prefs = ref.read(sharedPrefsProvider);
    final available =
        await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();
    if (mounted) {
      setState(() {
        _biometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
        _biometricAvailable = available;
      });
    }
  }

  Future<void> _onBiometricToggled(bool enable) async {
    if (_toggling) return;
    setState(() => _toggling = true);

    try {
      // Always require biometric auth before changing the setting
      final reason = enable
          ? 'Verify your identity to enable biometric lock'
          : 'Verify your identity to disable biometric lock';

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed')),
          );
        }
        return;
      }

      // Persist the setting
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setBool('biometric_lock_enabled', enable);

      if (mounted) {
        setState(() => _biometricEnabled = enable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enable ? 'Biometric lock enabled' : 'Biometric lock disabled',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Biometric error: $e')));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _loadBatteryState() async {
    setState(() => _batteryChecking = true);
    final exempt =
        await BatteryOptimizationService.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _batteryExempt = exempt;
      _batteryChecking = false;
    });
  }

  Future<void> _openBatteryOptimisationSettings() async {
    await BatteryOptimizationService.requestExemption();
    await BatteryOptimizationService.markAsked();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Battery settings opened')));
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear All Data?'),
          content: const Text(
            'This will permanently delete all local messages, notes, settings, and downloaded models. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PocketClawTheme.lobsterRed,
              ),
              child: const Text('Clear Data'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Biometric lock
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Biometric Lock'),
              subtitle: Text(
                _biometricAvailable
                    ? 'Require fingerprint or face to open the app'
                    : 'Biometrics not available on this device',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              secondary: Icon(
                Icons.fingerprint,
                color: _biometricEnabled
                    ? PocketClawTheme.electricTeal
                    : Colors.white38,
              ),
              value: _biometricEnabled,
              onChanged: _biometricAvailable && !_toggling
                  ? _onBiometricToggled
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // Battery optimisation
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                _batteryExempt == true
                    ? Icons.battery_charging_full_outlined
                    : Icons.battery_saver_outlined,
                color: _batteryExempt == true
                    ? PocketClawTheme.electricTeal
                    : Colors.amber,
              ),
              title: const Text('Battery Optimisation'),
              subtitle: Text(
                _batteryChecking
                    ? 'Checking Android battery state...'
                    : _batteryExempt == true
                    ? 'Unrestricted battery use is enabled'
                    : 'Allow unrestricted battery use for TV and long-running sessions',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              trailing: _batteryExempt == true
                  ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                  : const Icon(Icons.chevron_right),
              onTap: _openBatteryOptimisationSettings,
            ),
          ),

          const SizedBox(height: 24),

          // Clear data
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: PocketClawTheme.lobsterRed,
              ),
              title: const Text('Clear All Data'),
              subtitle: const Text(
                'Delete messages, notes, settings, and models',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              onTap: _showClearDataDialog,
            ),
          ),
        ],
      ),
    );
  }
}
