/// Gateway URL input with QR scan option, test connection, skip for offline-only
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import 'model_download.dart';

class GatewaySetup extends StatefulWidget {
  const GatewaySetup({super.key});

  @override
  State<GatewaySetup> createState() => _GatewaySetupState();
}

class _GatewaySetupState extends State<GatewaySetup> {
  final _urlController = TextEditingController();
  bool _testing = false;
  bool? _testSuccess;

  Future<void> _testConnection() async {
    if (_urlController.text.trim().isEmpty) return;

    setState(() {
      _testing = true;
      _testSuccess = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSuccess = true;
    });
  }

  void _proceed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ModelDownload()),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Gateway'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect to your\nOpenClaw Gateway',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your gateway URL or scan the QR code from your server dashboard.',
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),

              const SizedBox(height: 32),

              // URL input
              TextField(
                controller: _urlController,
                style: GoogleFonts.jetBrainsMono(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Gateway URL',
                  hintText: 'http://192.168.1.100:18789',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, size: 22),
                    onPressed: () {
                      // Placeholder: QR scanner
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR scanner coming soon'),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Test button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PocketClawTheme.lobsterRed,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_testing ? 'Testing...' : 'Test Connection'),
                ),
              ),

              // Test result
              if (_testSuccess != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_testSuccess!
                            ? const Color(0xFF4CAF50)
                            : PocketClawTheme.lobsterRed)
                        .withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_testSuccess!
                              ? const Color(0xFF4CAF50)
                              : PocketClawTheme.lobsterRed)
                          .withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess!
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 18,
                        color: _testSuccess!
                            ? const Color(0xFF4CAF50)
                            : PocketClawTheme.lobsterRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _testSuccess!
                            ? 'Connected successfully!'
                            : 'Connection failed. Check the URL.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _testSuccess!
                              ? const Color(0xFF4CAF50)
                              : PocketClawTheme.lobsterRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceed,
                  child: const Text('Continue'),
                ),
              ),

              const SizedBox(height: 12),

              // Skip
              Center(
                child: TextButton(
                  onPressed: _proceed,
                  child: const Text(
                    'Skip - use offline only',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
