library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../app/hermes_commander_theme.dart';
import '../../data/providers/integration_providers.dart';

class AgentMemorySettings extends ConsumerStatefulWidget {
  const AgentMemorySettings({super.key});

  @override
  ConsumerState<AgentMemorySettings> createState() =>
      _AgentMemorySettingsState();
}

class _AgentMemorySettingsState extends ConsumerState<AgentMemorySettings> {
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool? _testOk;
  int? _memoryCount;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadPrefs();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('agentmemory_base_url') ?? '';
    if (mounted) setState(() => _urlController.text = url);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agentmemory_base_url', _urlController.text.trim());
    ref.read(agentMemoryBaseUrlProvider.notifier).state =
        _urlController.text.trim();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AgentMemory URL saved')));
    }
  }

  Future<void> _test() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _testing = true;
      _testResult = null;
      _testOk = null;
      _memoryCount = null;
    });
    try {
      final healthRes = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 6));
      final statsRes = await http
          .get(Uri.parse('$url/api/stats'))
          .timeout(const Duration(seconds: 6));
      final ok = healthRes.statusCode == 200;
      int? count;
      try {
        final body = jsonDecode(statsRes.body);
        if (body is Map<String, dynamic>) {
          count = (body['totalMemories'] ?? body['memoryCount']) as int?;
        }
      } catch (_) {}
      setState(() {
        _testing = false;
        _testOk = ok;
        _testResult = ok
            ? 'Connected successfully'
            : 'Server returned ${healthRes.statusCode}';
        _memoryCount = count;
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = e.toString();
      });
    }
  }

  Future<void> _clearMemories() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all memories?'),
        content: const Text(
          'This will delete all memories on the AgentMemory server. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: HCTheme.statusRed),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    try {
      await http
          .delete(Uri.parse('$url/api/memories'))
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memories cleared')),
        );
        setState(() => _memoryCount = 0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AgentMemory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Server URL',
            style: TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 13,
              color: HCTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'http://100.x.x.x:3111',
              prefixIcon: Icon(Icons.psychology_alt_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: HCTheme.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test Connection'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  _testOk == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: _testOk == true
                      ? HCTheme.statusGreen
                      : HCTheme.statusRed,
                ),
                title: Text(_testResult!),
                subtitle: _memoryCount != null
                    ? Text('$_memoryCount memories stored')
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.delete_outline,
              color: HCTheme.statusRed,
            ),
            title: const Text('Clear all memories'),
            subtitle: const Text(
              'Permanently delete all memories from the AgentMemory server',
              style: TextStyle(color: HCTheme.textSecondary),
            ),
            onTap: _clearMemories,
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AgentMemory',
                    style: TextStyle(
                      fontFamily: 'GeistSans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Open-source semantic memory server. Runs alongside Hermes on your VPS at port 3111. Access via Tailscale private network.',
                    style: TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 12,
                      color: HCTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
