library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../app/hermes_commander_theme.dart';
import '../../data/providers/integration_providers.dart';

class OpenNotebookSettings extends ConsumerStatefulWidget {
  const OpenNotebookSettings({super.key});

  @override
  ConsumerState<OpenNotebookSettings> createState() =>
      _OpenNotebookSettingsState();
}

class _OpenNotebookSettingsState
    extends ConsumerState<OpenNotebookSettings> {
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool? _testOk;
  int? _notebookCount;

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
    final url = prefs.getString('opennotebook_base_url') ?? '';
    if (mounted) setState(() => _urlController.text = url);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'opennotebook_base_url',
      _urlController.text.trim(),
    );
    ref.read(openNotebookBaseUrlProvider.notifier).state =
        _urlController.text.trim();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Open-Notebook URL saved')));
    }
  }

  Future<void> _test() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _testing = true;
      _testResult = null;
      _testOk = null;
      _notebookCount = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$url/api/notebooks'))
          .timeout(const Duration(seconds: 8));
      final ok = res.statusCode == 200;
      int? count;
      if (ok) {
        try {
          final body = jsonDecode(res.body);
          if (body is List) {
            count = body.length;
          } else if (body is Map<String, dynamic>) {
            final items =
                body['items'] as List? ??
                body['notebooks'] as List? ??
                const [];
            count = items.length;
          }
        } catch (_) {}
      }
      setState(() {
        _testing = false;
        _testOk = ok;
        _testResult = ok
            ? 'Connected successfully'
            : 'Server returned ${res.statusCode}';
        _notebookCount = count;
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open-Notebook')),
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
              hintText: 'http://100.x.x.x:5055',
              prefixIcon: Icon(Icons.menu_book_outlined),
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
                subtitle: _notebookCount != null
                    ? Text('$_notebookCount notebook${_notebookCount == 1 ? '' : 's'} found')
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Open-Notebook',
                    style: TextStyle(
                      fontFamily: 'GeistSans',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Open-source notebook server (Python + FastAPI + SurrealDB). Runs via Docker Compose on your VPS at port 5055. Access via Tailscale private network.',
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
