library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/intelligence_providers.dart';

class OsirisSettings extends ConsumerStatefulWidget {
  const OsirisSettings({super.key});

  @override
  ConsumerState<OsirisSettings> createState() => _OsirisSettingsState();
}

class _OsirisSettingsState extends ConsumerState<OsirisSettings> {
  late final TextEditingController _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(
      text: ref.read(sharedPrefsProvider).getString('osiris_base_url') ?? '',
    );
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    final url = _baseUrl.text.trim();
    await prefs.setString('osiris_base_url', url);
    ref.read(osirisBaseUrlProvider.notifier).state = url;
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Osiris settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    final reachable = ref.watch(osirisReachableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Osiris Intelligence')),
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
                  const Row(
                    children: [
                      Icon(Icons.public_outlined, color: HCTheme.gold),
                      SizedBox(width: 8),
                      Text(
                        'Osiris',
                        style: TextStyle(
                          fontFamily: 'GeistSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reachable.when(
                      data: (ok) => ok
                          ? 'Connected and responding.'
                          : 'Offline or not configured.',
                      loading: () => 'Checking connection...',
                      error: (_, __) => 'Connection test failed.',
                    ),
                    style: const TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 13,
                      color: HCTheme.textSecondary,
                    ),
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
              hintText: 'https://your-osiris-host:3001',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: HCTheme.gold,
              foregroundColor: HCTheme.bgBase,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
