/// Commercial edition onboarding — gateway + company setup (spec §6.8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers/core_providers.dart';

class CommercialWizardScreen extends ConsumerStatefulWidget {
  const CommercialWizardScreen({super.key});

  @override
  ConsumerState<CommercialWizardScreen> createState() =>
      _CommercialWizardScreenState();
}

class _CommercialWizardScreenState
    extends ConsumerState<CommercialWizardScreen> {
  final _page = PageController();
  int _index = 0;

  late final TextEditingController _gatewayUrl;
  late final TextEditingController _gatewayToken;
  late final TextEditingController _paperclipRest;
  late final TextEditingController _paperclipWs;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _gatewayUrl = TextEditingController(
      text: prefs.getString('gateway_url') ?? '',
    );
    _gatewayToken = TextEditingController(
      text: prefs.getString('gateway_token') ?? '',
    );
    _paperclipRest = TextEditingController(
      text: prefs.getString('paperclip_rest_url') ?? '',
    );
    _paperclipWs = TextEditingController(
      text: prefs.getString('paperclip_ws_url') ?? '',
    );
  }

  @override
  void dispose() {
    _page.dispose();
    _gatewayUrl.dispose();
    _gatewayToken.dispose();
    _paperclipRest.dispose();
    _paperclipWs.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('gateway_url', _gatewayUrl.text.trim());
    await prefs.setString('gateway_token', _gatewayToken.text.trim());
    await prefs.setString('paperclip_rest_url', _paperclipRest.text.trim());
    await prefs.setString('paperclip_ws_url', _paperclipWs.text.trim());
    await prefs.setBool('commercial_onboarding_complete', true);

    ref.read(gatewayUrlProvider.notifier).state = _gatewayUrl.text.trim();
    ref.read(gatewayTokenProvider.notifier).state = _gatewayToken.text.trim();
    ref.read(paperclipRestUrlProvider.notifier).state = _paperclipRest.text.trim();
    ref.read(paperclipWsUrlProvider.notifier).state = _paperclipWs.text.trim();

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your AI Company')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_index + 1) / 4),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _pageWelcome(),
                _pageGateway(),
                _pagePaperclip(),
                _pageDone(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: () async {
                      await _page.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                      if (mounted) setState(() => _index--);
                    },
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () async {
                    if (_index < 3) {
                      await _page.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                      if (mounted) setState(() => _index++);
                    } else {
                      await _finish();
                    }
                  },
                  child: Text(_index < 3 ? 'Next' : 'Finish'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageWelcome() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Pocket Claw',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Connect your OpenClaw gateway and Paperclip company over your '
            'Tailscale network. No public ports are required.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withAlpha(191),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageGateway() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'OpenClaw gateway',
          style: GoogleFonts.jetBrainsMono(fontSize: 18),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gatewayUrl,
          decoration: const InputDecoration(
            labelText: 'WebSocket URL',
            hintText: 'ws://100.x.x.x:18789/ws',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gatewayToken,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Bearer token',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _pagePaperclip() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Paperclip',
          style: GoogleFonts.jetBrainsMono(fontSize: 18),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _paperclipRest,
          decoration: const InputDecoration(
            labelText: 'REST base URL',
            hintText: 'http://100.x.x.x:3100',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _paperclipWs,
          decoration: const InputDecoration(
            labelText: 'WebSocket URL',
            hintText: 'ws://100.x.x.x:3100/ws',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _pageDone() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are ready',
            style: GoogleFonts.jetBrainsMono(fontSize: 20),
          ),
          const SizedBox(height: 12),
          Text(
            'Use Settings → Paperclip Company to refine tokens, and '
            'Company → Security to watch governance.',
            style: TextStyle(
              color: Colors.white.withAlpha(179),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
