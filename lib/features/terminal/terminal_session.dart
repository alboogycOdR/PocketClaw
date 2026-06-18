/// Interactive SSH shell session powering the in-app terminal.
///
/// Spawns its own [SSHClient] instead of reusing [sshClientProvider]'s
/// pooled connection so that interactive PTY traffic doesn't fight
/// exec-based usage in monitor / Hermes management screens.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

enum TerminalStatus { disconnected, connecting, connected, error }

class TerminalSession {
  late final Terminal terminal;
  TerminalStatus status = TerminalStatus.disconnected;
  String? errorMessage;

  SSHClient? _client;
  SSHSession? _session;
  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;

  TerminalSession() {
    terminal = Terminal(
      maxLines: 5000,
      onOutput: _onTerminalOutput,
      onResize: _onTerminalResize,
    );
  }

  void _onTerminalOutput(String data) {
    final s = _session;
    if (s == null) return;
    s.stdin.add(Uint8List.fromList(utf8.encode(data)));
  }

  void _onTerminalResize(int w, int h, int pw, int ph) {
    _session?.resizeTerminal(w, h, pw, ph);
  }

  Future<void> connect({
    required String host,
    required int port,
    required String username,
    required String? password,
  }) async {
    status = TerminalStatus.connecting;
    errorMessage = null;

    try {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );

      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password ?? '',
      );

      _session = await _client!.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );

      _stdoutSub = _session!.stdout.listen((data) {
        terminal.write(utf8.decode(data, allowMalformed: true));
      });

      _stderrSub = _session!.stderr.listen((data) {
        terminal.write(utf8.decode(data, allowMalformed: true));
      });

      status = TerminalStatus.connected;

      _session!.done.then((_) {
        terminal.write('\r\n[Connection closed]\r\n');
        status = TerminalStatus.disconnected;
      });
    } catch (e) {
      status = TerminalStatus.error;
      errorMessage = e.toString();
      terminal.write('\r\n[Connection failed: $e]\r\n');
    }
  }

  void disconnect() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    try {
      _session?.close();
    } catch (_) {}
    try {
      _client?.close();
    } catch (_) {}
    _session = null;
    _client = null;
    if (status != TerminalStatus.error) {
      status = TerminalStatus.disconnected;
    }
  }

  void dispose() {
    disconnect();
  }
}

final terminalSessionProvider = Provider.autoDispose<TerminalSession>((ref) {
  final session = TerminalSession();
  ref.onDispose(session.dispose);
  return session;
});
