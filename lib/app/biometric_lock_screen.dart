/// Full-screen biometric lock gate shown when biometric lock is enabled.
library;

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'theme.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const BiometricLockScreen({super.key, required this.onUnlocked});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Attempt authentication immediately on mount
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Pocket Claw',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        widget.onUnlocked();
      } else {
        if (mounted) {
          setState(() => _error = 'Authentication failed. Tap to retry.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Biometric error. Tap to retry.');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PocketClawTheme.surfaceDim,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: PocketClawTheme.electricTeal.withAlpha(180),
            ),
            const SizedBox(height: 24),
            Text(
              'Pocket Claw is Locked',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Authenticate to continue',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (_authenticating)
              CircularProgressIndicator(
                color: PocketClawTheme.electricTeal,
              )
            else ...[
              IconButton(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                iconSize: 56,
                color: PocketClawTheme.electricTeal,
                tooltip: 'Unlock',
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to unlock',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: PocketClawTheme.lobsterRed,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
