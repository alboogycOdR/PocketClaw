/// Gateway URL and auth configuration form
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/gateway/gateway_client.dart';
import '../../data/models/gateway_event.dart';
import '../../data/providers/core_providers.dart';

class GatewayConfig extends ConsumerStatefulWidget {
  const GatewayConfig({super.key});

  @override
  ConsumerState<GatewayConfig> createState() => _GatewayConfigState();
}

class _GatewayConfigState extends ConsumerState<GatewayConfig> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final url = ref.read(gatewayUrlProvider);
    final token = ref.read(gatewayTokenProvider);
    _urlController = TextEditingController(text: url);
    _tokenController = TextEditingController(text: token);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _testResult = 'Please enter a gateway URL';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    ref.read(gatewayStateProvider.notifier).state = GatewayState.connecting;

    GatewayClient? client;
    try {
      client = GatewayClient(gatewayUrl: url, authToken: token);
      await client.connect();

      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'Connection successful!';
        _testSuccess = true;
      });
      ref.read(gatewayStateProvider.notifier).state = GatewayState.connected;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'Connection failed: $e';
        _testSuccess = false;
      });
      ref.read(gatewayStateProvider.notifier).state = GatewayState.error;
    } finally {
      client?.dispose();
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    // Persist to SharedPreferences
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('gateway_url', url);
    await prefs.setString('gateway_token', token);

    // Update reactive providers so the rest of the app picks up the change
    ref.read(gatewayUrlProvider.notifier).state = url;
    ref.read(gatewayTokenProvider.notifier).state = token;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration saved')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gateway Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Gateway URL',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            style: GoogleFonts.jetBrainsMono(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'http://your-server:18789',
              prefixIcon: Icon(Icons.link, size: 20),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Auth Token',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenController,
            obscureText: false,
            style: GoogleFonts.jetBrainsMono(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Optional authentication token',
              prefixIcon: Icon(Icons.key, size: 20),
            ),
          ),

          const SizedBox(height: 24),

          // Test connection button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),
          ),

          // Test result
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testSuccess
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935))
                    .withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_testSuccess
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935))
                      .withAlpha(60),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle : Icons.error_outline,
                    size: 18,
                    color: _testSuccess
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE53935),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: _testSuccess
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Save button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _save,
              child: const Text('Save Configuration'),
            ),
          ),
        ],
      ),
    );
  }
}
