/// Full-screen in-app SSH terminal. Power User Feature Pack §1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xterm/xterm.dart';

import '../../data/providers/ssh_providers.dart';
import 'terminal_session.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  Future<void> _autoConnect() async {
    final host = ref.read(sshHostProvider);
    final port = ref.read(sshPortProvider);
    final username = ref.read(sshUsernameProvider);
    final password = await readSshPassword();

    if (host.isEmpty || username.isEmpty) return;

    setState(() => _connecting = true);
    final session = ref.read(terminalSessionProvider);
    await session.connect(
      host: host,
      port: port,
      username: username,
      password: password,
    );
    if (mounted) setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(terminalSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (session.status) {
                  TerminalStatus.connected => const Color(0xFF3FB950),
                  TerminalStatus.connecting => Colors.amber,
                  TerminalStatus.error => Colors.red,
                  TerminalStatus.disconnected => Colors.white24,
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.status == TerminalStatus.connected
                  ? '${ref.read(sshUsernameProvider)}@${ref.read(sshHostProvider)}'
                  : session.status.name,
              style: GoogleFonts.jetBrainsMono(fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Reconnect',
            onPressed: _connecting
                ? null
                : () {
                    session.disconnect();
                    _autoConnect();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Disconnect',
            onPressed: () => setState(() => session.disconnect()),
          ),
        ],
      ),
      body: Stack(
        children: [
          TerminalView(
            session.terminal,
            theme: const TerminalTheme(
              cursor: Color(0xFFC9A227),
              selection: Color(0x40C9A227),
              foreground: Color(0xFFE6EDF3),
              background: Color(0xFF0C0C0C),
              black: Color(0xFF000000),
              red: Color(0xFFF85149),
              green: Color(0xFF3FB950),
              yellow: Color(0xFFFFA657),
              blue: Color(0xFF58A6FF),
              magenta: Color(0xFFBC8CFF),
              cyan: Color(0xFF39C5CF),
              white: Color(0xFFB1BAC4),
              brightBlack: Color(0xFF6E7681),
              brightRed: Color(0xFFFF7B72),
              brightGreen: Color(0xFF56D364),
              brightYellow: Color(0xFFE3B341),
              brightBlue: Color(0xFF79C0FF),
              brightMagenta: Color(0xFFD2A8FF),
              brightCyan: Color(0xFF56D4DD),
              brightWhite: Color(0xFFFFFFFF),
              searchHitBackground: Color(0xFF264F78),
              searchHitBackgroundCurrent: Color(0xFFFFFF00),
              searchHitForeground: Color(0xFFFFFFFF),
            ),
            textStyle: const TerminalStyle(
              fontSize: 13,
              fontFamily: 'JetBrainsMono',
            ),
            padding: const EdgeInsets.all(8),
            autofocus: true,
          ),
          if (_connecting)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 12),
                  Text(
                    'Connecting…',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
