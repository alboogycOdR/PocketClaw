/// Server SSH settings — host, port, username, auth method, password,
/// and a Test Connection button. Sprint 3 §4.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/ssh/hermes_ssh_client.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/ssh_providers.dart';

class SshSettings extends ConsumerStatefulWidget {
  const SshSettings({super.key});

  @override
  ConsumerState<SshSettings> createState() => _SshSettingsState();
}

class _SshSettingsState extends ConsumerState<SshSettings> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _password;
  String _authMethod = 'password';
  bool _testing = false;
  bool? _testOk;
  String? _testMessage;
  bool _passwordLoaded = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _host = TextEditingController(text: prefs.getString('ssh_host') ?? '');
    _port = TextEditingController(
      text: (prefs.getInt('ssh_port') ?? 22).toString(),
    );
    _user = TextEditingController(text: prefs.getString('ssh_username') ?? '');
    _authMethod = prefs.getString('ssh_auth_method') ?? 'password';
    _password = TextEditingController();
    // Hydrate password from secure storage asynchronously.
    readSshPassword().then((pw) {
      if (!mounted) return;
      setState(() {
        _password.text = pw ?? '';
        _passwordLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    final port = int.tryParse(_port.text.trim()) ?? 22;
    await prefs.setString('ssh_host', _host.text.trim());
    await prefs.setInt('ssh_port', port);
    await prefs.setString('ssh_username', _user.text.trim());
    await prefs.setString('ssh_auth_method', _authMethod);

    if (_authMethod == 'password') {
      final pw = _password.text;
      if (pw.isEmpty) {
        await clearSshPassword();
      } else {
        await writeSshPassword(pw);
      }
    }

    // Push prefs back into reactive providers.
    ref.read(sshHostProvider.notifier).state = _host.text.trim();
    ref.read(sshPortProvider.notifier).state = port;
    ref.read(sshUsernameProvider.notifier).state = _user.text.trim();
    ref.read(sshAuthMethodProvider.notifier).state = _authMethod;
    // Bump the revision so sshClientProvider re-reads the password.
    ref.read(sshSettingsRevProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('SSH settings saved')));
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testOk = null;
      _testMessage = null;
    });
    final port = int.tryParse(_port.text.trim()) ?? 22;
    final client = HermesSshClient(
      host: _host.text.trim(),
      port: port,
      username: _user.text.trim(),
      auth: SshPasswordAuth(_password.text),
    );
    try {
      final ok = await client.isReachable();
      String? whoami;
      if (ok) {
        try {
          whoami = (await client.exec('whoami')).trim();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = ok;
        _testMessage = ok
            ? 'Connected as ${whoami ?? _user.text.trim()}@${_host.text.trim()}'
            : 'Could not authenticate — check host, user, and password';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = '$e';
      });
    } finally {
      client.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Server SSH',
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
                      Icon(Icons.terminal, color: PocketClawTheme.electricTeal),
                      const SizedBox(width: 8),
                      Text(
                        'SSH transport',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Used for Hermes management (sessions, memory, cron, '
                    'skills, logs) and server-side diagnostics. Phone must '
                    'be on Tailscale.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'Host',
              hintText: 'your-vps-host',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '22',
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'operator',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _authMethod,
            decoration: const InputDecoration(
              labelText: 'Auth method',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            items: const [
              DropdownMenuItem(value: 'password', child: Text('Password')),
              DropdownMenuItem(
                value: 'key',
                enabled: false,
                child: Text('Key (coming soon)'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _authMethod = v);
            },
          ),
          const SizedBox(height: 12),
          if (_authMethod == 'password')
            TextField(
              controller: _password,
              obscureText: true,
              enabled: _passwordLoaded,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _passwordLoaded
                    ? 'Stored in encrypted secure storage'
                    : 'Loading…',
                prefixIcon: const Icon(Icons.password),
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
            label: Text(_testing ? 'Testing…' : 'Test SSH Connection'),
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
                color: (_testOk == true ? Colors.teal : Colors.red).withAlpha(
                  38,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _testOk == true ? Colors.tealAccent : Colors.redAccent,
                ),
              ),
              child: Text(
                _testMessage!,
                style: TextStyle(
                  color: _testOk == true ? Colors.tealAccent : Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
