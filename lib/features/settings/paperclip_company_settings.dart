/// Paperclip connection settings — base URL + agent API key.
/// Paperclip is a standalone REST service on the VPS (port 3100). See
/// `docs/PocketClaw-Paperclip-Architecture-v2.0.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/gateway/paperclip_rest.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import 'paperclip_onboarding_wizard.dart';

class PaperclipCompanySettings extends ConsumerStatefulWidget {
  const PaperclipCompanySettings({super.key});

  @override
  ConsumerState<PaperclipCompanySettings> createState() =>
      _PaperclipCompanySettingsState();
}

class _PaperclipCompanySettingsState
    extends ConsumerState<PaperclipCompanySettings> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _baseUrl = TextEditingController(
      text: prefs.getString('paperclip_base_url') ?? '',
    );
    _apiKey = TextEditingController(
      text: prefs.getString('paperclip_api_key') ?? '',
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
    await prefs.setString('paperclip_base_url', url);
    await prefs.setString('paperclip_api_key', key);

    ref.read(paperclipBaseUrlProvider.notifier).state = url;
    ref.read(paperclipApiKeyProvider.notifier).state = key;

    // Re-run the AsyncNotifier build against the new values.
    ref.read(paperclipProvider.notifier).refresh();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paperclip settings saved')),
      );
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final url = _baseUrl.text.trim();
    final key = _apiKey.text.trim();
    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _testing = false;
        _testResult = 'Fill in both fields first.';
        _testOk = false;
      });
      return;
    }
    final probe = PaperclipRestClient(baseUrl: url, apiKey: key);
    try {
      final ok = await probe.isReachable();
      setState(() {
        _testing = false;
        _testOk = ok;
        _testResult = ok ? 'Reachable' : 'Unreachable or HTTP error';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = '$e';
      });
    } finally {
      probe.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paperclipProvider);
    final connectedLabel = async.when(
      loading: () => 'Connecting…',
      error: (e, _) => friendlyPaperclipError(e),
      data: (s) => s.configured ? 'Connected' : 'Not connected',
    );
    final connectedOk = async.valueOrNull?.configured == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Paperclip Company')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(
              connectedOk ? Icons.check_circle : Icons.cloud_off,
              color: connectedOk ? Colors.greenAccent : Colors.white54,
            ),
            title: Text(connectedLabel),
            subtitle: const Text(
              'Paperclip runs as its own service (port 3100) separate from '
              'OpenClaw. Auth is a long-lived agent API key.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            color: PocketClawTheme.surfaceContainerLow,
            child: ListTile(
              leading: Icon(Icons.outbox_outlined,
                  color: PocketClawTheme.electricTeal),
              title: const Text('Onboard with invite'),
              subtitle: const Text(
                'Paste an invite token from the Paperclip dashboard — the '
                'app handles the claim flow automatically.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PaperclipOnboardingWizard(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Or paste an existing API key manually below.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Paperclip base URL',
              hintText: 'http://100.x.x.x:3100',
              border: OutlineInputBorder(),
              helperText:
                  'Dashboard URL — /api suffix added automatically if missing',
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Agent API key',
              hintText: 'Generated in Paperclip dashboard → Agent → API Keys',
              border: OutlineInputBorder(),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_testOk ? Colors.green : Colors.red).withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    _testOk ? Icons.check_circle : Icons.error_outline,
                    size: 16,
                    color: _testOk ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: _testOk ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 16),
                  label: const Text('Test connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'First-time setup:\n'
              '1. SSH the VPS and run: npx paperclipai onboard --yes --bind tailnet\n'
              '2. Visit http://<your-vps-ip>:3100 in a browser, create a company\n'
              '3. Connect OpenClaw via the invite-prompt flow\n'
              '4. Create an agent called "Pocket Claw Mobile" and copy its API key',
              style: TextStyle(fontSize: 11, color: Colors.white60, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
