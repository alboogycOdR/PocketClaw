/// OpenClaw diagnostics over SSH — log tail (`journalctl`),
/// `openclaw doctor`, and gateway restart. Reuses the SSH transport
/// from Sprint 3. SPEC-OpenClaw-Improvements §6.
library;

import '../ssh/hermes_ssh_client.dart';

class OpenClawSshService {
  final HermesSshClient _ssh;

  OpenClawSshService({required HermesSshClient ssh}) : _ssh = ssh;

  /// Tail the systemd journal for the openclaw-gateway service.
  /// `--no-pager` and `--output=short` keep the output a flat plain text
  /// stream that's easy to render line-by-line. `2>&1` folds stderr into
  /// stdout so transient warnings don't trip the SSH error path.
  Future<List<String>> getLogs({int lines = 100}) async {
    try {
      final out = await _ssh.exec(
        'journalctl -u openclaw-gateway -n $lines --no-pager --output=short 2>&1',
      );
      return out
          .split('\n')
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Live-follow the journal. Caller cancels the subscription to stop.
  Stream<String> followLogs() => _ssh.execStream(
        'journalctl -u openclaw-gateway -f --no-pager --output=short',
      );

  /// Run `openclaw doctor` and return its raw output.
  /// Folded stderr ensures non-zero diagnostic exit codes still surface
  /// useful output rather than throwing out of the SSH client.
  Future<String> runDoctor() async {
    try {
      return await _ssh.exec('openclaw doctor 2>&1');
    } catch (e) {
      return 'doctor failed: $e';
    }
  }

  /// Restart the openclaw-gateway systemd service. Caller is expected to
  /// surface a destructive-action confirm dialog before invoking this —
  /// it kills any in-flight WebSocket sessions.
  Future<void> restartGateway() async {
    await _ssh.exec('sudo systemctl restart openclaw-gateway');
    // Give the service a moment to come back up before the WebSocket
    // client retries — this just keeps the UX sane, the actual reconnect
    // is driven by GatewayClient's exponential-backoff loop.
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}
