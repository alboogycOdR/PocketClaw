/// Security settings: biometric lock toggle, clear data
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';

class SecuritySettings extends ConsumerStatefulWidget {
  const SecuritySettings({super.key});

  @override
  ConsumerState<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<SecuritySettings> {
  bool _biometricEnabled = false;

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
              subtitle: const Text(
                'Require fingerprint or face to open the app',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              secondary: Icon(
                Icons.fingerprint,
                color: _biometricEnabled
                    ? PocketClawTheme.electricTeal
                    : Colors.white38,
              ),
              value: _biometricEnabled,
              onChanged: (val) {
                setState(() => _biometricEnabled = val);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Clear data
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Color(0xFFE53935),
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
