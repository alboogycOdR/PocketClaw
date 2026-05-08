/// Hermes Agent settings — base URL, API key, and connection test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/hermes_client.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/hermes_providers.dart';

class HermesSettings extends ConsumerStatefulWidget {
  const HermesSettings({super.key});

  @override
  ConsumerState<HermesSettings> createState() => _HermesSettingsState();
}

class _HermesSettingsState extends ConsumerState<HermesSettings> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  bool _testing = false;
  bool? _testOk;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _baseUrl = TextEditingController(
      text: prefs.getString('hermes_base_url') ?? '',
    );
    _apiKey = TextEditingController(
      text: prefs.getString('hermes_api_key') ?? '',
    );
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    final url = _baseUrl.text.trim();
    final key = _apiKey.text.trim();
    await prefs.setString('hermes_base_url', url);
    await prefs.setString('hermes_api_key', key);
    ref.read(hermesBaseUrlProvider.notifier).state = url;
    ref.read(hermesApiKeyProvider.notifier).state = key;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hermes settings saved')),
      );
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testOk = null;
      _testMessage = null;
    });
    final client = HermesClient(
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
    );
    try {
      final ok = await client.isReachable();
      final model = ok ? await client.getModelId() : null;
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = ok;
        _testMessage = ok
            ? 'Connected · model: ${model ?? 'hermes-agent'}'
            : 'Unreachable — check URL, Tailscale, and API key';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = '$e';
      });
    } finally {
      client.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hermes Agent',
          style: GoogleFonts.jetBrainsMono(fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology_outlined,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hermes Agent v0.12',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Self-improving agent by Nous Research running on your '
                    'VPS. Carries its full toolset — terminal, web, memory, '
                    'skills, delegation — and replies via OpenAI-compatible '
                    'streaming.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://100.78.70.2:8642',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'hermes-pocket-claw-...',
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? 'Testing…' : 'Test Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
              foregroundColor: Colors.white,
            ),
          ),

          if (_testMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testOk == true ? Colors.teal : Colors.red)
                    .withAlpha(38),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testOk == true
                      ? Colors.tealAccent
                      : Colors.redAccent,
                ),
              ),
              child: Text(
                _testMessage!,
                style: TextStyle(
                  color: _testOk == true
                      ? Colors.tealAccent
                      : Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
