/// Shared SSH transport for Hermes management + OpenClaw diagnostics.
/// One persistent connection per app session; reconnects on demand.
///
/// Usage:
///   final out = await ssh.exec('sqlite3 -readonly -json ~/.hermes/state.db "SELECT …"');
///   final txt = await ssh.readFile('~/.hermes/memories/MEMORY.md');
///   await ssh.writeFile('~/.hermes/cron/jobs.json', updatedJson);
///
/// SPEC-MultiTransport-v1.0.md §5.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

abstract class SshAuth {
  const SshAuth();
}

class SshPasswordAuth extends SshAuth {
  final String password;
  const SshPasswordAuth(this.password);
}

class SshKeyAuth extends SshAuth {
  final SSHKeyPair keyPair;
  const SshKeyAuth(this.keyPair);
}

class HermesSshClient {
  final String host;
  final int port;
  final String username;
  final SshAuth auth;
  final Duration connectTimeout;

  SSHClient? _client;
  bool _connecting = false;

  HermesSshClient({
    required this.host,
    required this.port,
    required this.username,
    required this.auth,
    this.connectTimeout = const Duration(seconds: 10),
  });

  bool get isConnected => _client != null && !(_client!.isClosed);

  // ── Connection ────────────────────────────────────────────────────────

  Future<bool> isReachable() async {
    try {
      await _ensureConnected();
      return isConnected;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureConnected() async {
    if (isConnected) return;
    if (_connecting) {
      // Spin-wait up to ~5 s for a concurrent connect to finish.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (isConnected) return;
      }
      throw const SshTimeoutException();
    }

    _connecting = true;
    try {
      final socket = await SSHSocket.connect(host, port, timeout: connectTimeout);
      final a = auth;
      _client = SSHClient(
        socket,
        username: username,
        identities: a is SshKeyAuth ? [a.keyPair] : const [],
        onPasswordRequest: a is SshPasswordAuth ? () => a.password : null,
      );
      await _client!.authenticated;
    } catch (e) {
      _client?.close();
      _client = null;
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  // ── Remote exec ───────────────────────────────────────────────────────

  /// Run a command on the remote host and return the combined stdout.
  /// Non-zero exit codes throw [SshCommandException] when stdout is empty;
  /// commands that print useful output despite a non-zero exit (e.g. tools
  /// that emit warnings) still return their stdout.
  Future<String> exec(String command) async {
    await _ensureConnected();
    final session = await _client!.execute(command);
    final stdoutF = session.stdout.cast<List<int>>().transform(utf8.decoder).join();
    final stderrF = session.stderr.cast<List<int>>().transform(utf8.decoder).join();
    final out = await stdoutF;
    final err = await stderrF;
    final code = session.exitCode ?? 0;
    if (code != 0 && out.isEmpty) {
      throw SshCommandException(command: command, exitCode: code, stderr: err);
    }
    return out;
  }

  /// Stream stdout lines from a long-running remote command (e.g. `tail -f`).
  /// Each yielded element is one newline-delimited line from stdout.
  Stream<String> execStream(String command) async* {
    await _ensureConnected();
    final session = await _client!.execute(command);
    yield* session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  /// Open a bidirectional remote process. Caller writes UTF-8 lines to
  /// [SshProcess.stdin] and reads them from [SshProcess.stdout]. Used by
  /// the ACP client to talk JSON-RPC stdio with a `hermes acp` subprocess.
  /// SPEC-ACPWireProtocol §Transport Rules.
  Future<SshProcess> executeInteractive(String command) async {
    await _ensureConnected();
    final session = await _client!.execute(command);
    return SshProcess._(session);
  }

  // ── SFTP ──────────────────────────────────────────────────────────────

  Future<String> readFile(String remotePath) async {
    final bytes = await readBytes(remotePath);
    return utf8.decode(bytes);
  }

  Future<Uint8List> readBytes(String remotePath) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    final file = await sftp.open(_resolveTilde(remotePath));
    try {
      return await file.readBytes();
    } finally {
      await file.close();
    }
  }

  Future<void> writeFile(String remotePath, String content) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    final file = await sftp.open(
      _resolveTilde(remotePath),
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(Uint8List.fromList(utf8.encode(content)));
    } finally {
      await file.close();
    }
  }

  Future<List<String>> listDirectory(String remotePath) async {
    await _ensureConnected();
    final sftp = await _client!.sftp();
    // sftp.readdir streams chunks; flatten to a single list of names.
    final out = <String>[];
    final stream = sftp.readdir(_resolveTilde(remotePath));
    await for (final chunk in stream) {
      for (final entry in chunk) {
        if (entry.filename != '.' && entry.filename != '..') {
          out.add(entry.filename);
        }
      }
    }
    return out;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  void disconnect() {
    _client?.close();
    _client = null;
  }

  /// Some SFTP servers don't expand `~/`. Many do (OpenSSH does). When they
  /// don't, swap the leading `~/` for `/home/<username>/` since we know the
  /// connecting user.
  String _resolveTilde(String path) {
    if (!path.startsWith('~/')) return path;
    return '/home/$username/${path.substring(2)}';
  }
}

/// Bidirectional view onto a remote SSH-exec'd process — caller can
/// write UTF-8 strings to [stdin] and listen to [stdout] / [stderr] as
/// line streams. Closing [stdin] tells the remote side EOF; calling
/// [close] tears down the SSH session.
class SshProcess {
  final SSHSession _session;
  SshProcess._(this._session);

  Stream<String> get stdout => _session.stdout
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  Stream<String> get stderr => _session.stderr
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  /// Send a UTF-8 line. Newline is appended only if the caller didn't
  /// already include one — keeps the JSON-RPC framing rule (one object
  /// per `\n`-terminated line) simple to follow.
  void writeLine(String line) {
    final framed = line.endsWith('\n') ? line : '$line\n';
    _session.write(Uint8List.fromList(utf8.encode(framed)));
  }

  /// Tell the remote side stdin is finished.
  Future<void> closeStdin() async {
    await _session.stdin.close();
  }

  Future<int?> get exitCode async => _session.exitCode;

  void close() => _session.close();
}

class SshCommandException implements Exception {
  final String command;
  final int exitCode;
  final String stderr;
  const SshCommandException({
    required this.command,
    required this.exitCode,
    required this.stderr,
  });
  @override
  String toString() =>
      'SshCommandException: `$command` exited $exitCode: $stderr';
}

class SshTimeoutException implements Exception {
  const SshTimeoutException();
  @override
  String toString() => 'SshTimeoutException: connect timed out';
}
