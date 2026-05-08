/// OpenClaw diagnostics over SSH — log tail (`journalctl`),
/// `openclaw doctor`, and gateway restart. Reuses the SSH transport
/// from Sprint 3. SPEC-OpenClaw-Improvements §6.
library;

import '../ssh/hermes_ssh_client.dart';

class OpenClawSshService {
  final HermesSshClient _ssh;

  OpenClawSshService({required HermesSshClient ssh}) : _ssh = ssh;

  /// Augment $PATH with the common locations npm-installed binaries land
  /// in. Non-interactive non-login SSH sessions don't source `.bashrc`,
  /// so `openclaw` (typically at `~/.npm-global/bin/openclaw`) isn't
  /// found by name. Prefixing PATH per-command is faster and more
  /// portable than `bash -lic`.
  static const _pathPrefix =
      r'PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:$PATH"';

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
      return await _ssh.exec('$_pathPrefix openclaw doctor 2>&1');
    } on SshCommandException catch (e) {
      if (e.exitCode == 127) {
        return 'openclaw CLI not found on the gateway host.\n'
            'Expected at ~/.npm-global/bin/openclaw — verify the install '
            'with `which openclaw` after `ssh clawusr@<host>`.';
      }
      return 'doctor failed (exit ${e.exitCode}):\n${e.stderr}';
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
