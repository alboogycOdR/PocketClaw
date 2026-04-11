/// Paperclip Company URLs and tokens (spec §6.4, §6.7).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';

class PaperclipCompanySettings extends ConsumerStatefulWidget {
  const PaperclipCompanySettings({super.key});

  @override
  ConsumerState<PaperclipCompanySettings> createState() =>
      _PaperclipCompanySettingsState();
}

class _PaperclipCompanySettingsState
    extends ConsumerState<PaperclipCompanySettings> {
  late final TextEditingController _rest;
  late final TextEditingController _ws;
  late final TextEditingController _token;
  late final TextEditingController _company;
  late final TextEditingController _mission;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _rest = TextEditingController(
      text: prefs.getString('paperclip_rest_url') ?? '',
    );
    _ws = TextEditingController(
      text: prefs.getString('paperclip_ws_url') ?? '',
    );
    _token = TextEditingController(
      text: prefs.getString('paperclip_token') ?? '',
    );
    _company = TextEditingController();
    _mission = TextEditingController();
    final pc = ref.read(paperclipProvider);
    _company.text = pc.overview?.name ?? '';
    _mission.text = pc.overview?.description ?? '';
  }

  @override
  void dispose() {
    _rest.dispose();
    _ws.dispose();
    _token.dispose();
    _company.dispose();
    _mission.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('paperclip_rest_url', _rest.text.trim());
    await prefs.setString('paperclip_ws_url', _ws.text.trim());
    await prefs.setString('paperclip_token', _token.text.trim());

    ref.read(paperclipRestUrlProvider.notifier).state = _rest.text.trim();
    ref.read(paperclipWsUrlProvider.notifier).state = _ws.text.trim();
    ref.read(paperclipTokenProvider.notifier).state = _token.text.trim();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paperclip settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = ref.watch(paperclipProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paperclip Company')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(
              pc.isConnected ? Icons.check_circle : Icons.cloud_off,
              color: pc.isConnected ? Colors.greenAccent : Colors.white54,
            ),
            title: Text(pc.isConnected ? 'Connected' : 'Not connected'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'Company name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mission,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Mission',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'URLs (Tailscale only in production — no public ports).',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rest,
            decoration: const InputDecoration(
              labelText: 'Paperclip REST base URL',
              hintText: 'http://100.x.x.x:3100',
              border: OutlineInputBorder(),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ws,
            decoration: const InputDecoration(
              labelText: 'Paperclip WebSocket URL',
              hintText: 'ws://100.x.x.x:3100/ws',
              border: OutlineInputBorder(),
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Bearer token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('Save & reconnect'),
          ),
        ],
      ),
    );
  }
}
