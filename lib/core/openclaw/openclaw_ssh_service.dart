/// OpenClaw diagnostics over SSH — log tail (`journalctl`),
/// `openclaw doctor`, gateway restart, and device list / approve /
/// revoke. Reuses the SSH transport from Sprint 3.
/// SPEC-OpenClaw-Improvements §6 + devices fallback (the WS
/// `devices.*` namespace doesn't exist on the user's gateway version).
library;

import 'dart:convert';

import '../../data/models/openclaw_device.dart';
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

  // ── Devices fallback (SSH CLI when WS RPC is absent) ──────────────────
  //
  // The user's gateway build doesn't expose `devices.list / approve /
  // revoke` over WebSocket — the request silently drops. The CLI
  // (`openclaw devices ...`) reads `~/.openclaw/devices.json` directly
  // and works fine. These wrappers run the CLI over SSH and parse the
  // output so the in-app Devices screen has feature parity with the
  // SSH terminal.

  Future<List<OpenClawDevice>> listDevices() async {
    // The CLI requires the `list` subcommand — running `openclaw
    // devices` alone prints the help screen (verified 2026-05-09).
    // Try `list --json` first, then plain `list` (ASCII table) if
    // --json isn't supported.
    String rawJson = '';
    try {
      rawJson =
          await _ssh.exec('$_pathPrefix openclaw devices list --json 2>&1');
      final parsedJson = _parseDevicesJson(rawJson);
      if (parsedJson.isNotEmpty) return parsedJson;
    } on SshCommandException {
      // --json flag rejected; fall through to ASCII.
    }

    final out = await _ssh.exec('$_pathPrefix openclaw devices list 2>&1');
    final parsed = _parseDevicesAscii(out);
    if (parsed.isNotEmpty) return parsed;

    // Both forms parsed empty. If either output had content, the
    // parser is the issue — surface the raw text so the caller can
    // render it for debugging instead of pretending the gateway has
    // no devices.
    final raw = out.isNotEmpty ? out : rawJson;
    if (raw.trim().isNotEmpty) {
      throw OpenClawDevicesParseException(raw);
    }
    return const [];
  }

  Future<void> approveDevice(String deviceId) async {
    await _ssh.exec('$_pathPrefix openclaw devices approve $deviceId 2>&1');
  }

  Future<void> revokeDevice(String deviceId) async {
    await _ssh.exec('$_pathPrefix openclaw devices revoke $deviceId 2>&1');
  }

  // ── Output parsers ────────────────────────────────────────────────────

  static List<OpenClawDevice> _parseDevicesJson(String raw) {
    try {
      final json = jsonDecode(raw.trim());
      // Expected shapes: `{devices:[...]}` or a raw array.
      final list = json is Map ? json['devices'] : json;
      if (list is! List) return const [];
      return [
        for (final d in list)
          if (d is Map<String, dynamic>) OpenClawDevice.fromJson(d),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Parse the ASCII table output of `openclaw devices list`. Strict
  /// version — only accepts rows whose first non-whitespace token is a
  /// UUID (`8-4-4-4-12` hex), a 64-char hex (deviceId), or a 32-char hex
  /// fingerprint. Everything else (column headers, separators, name-only
  /// rows, blank cells, "Pocket Claw"/"ClawCommander" labels without a
  /// paired hex) is dropped. Approve/Revoke can only operate on a real
  /// ID anyway.
  ///
  /// Pending section emits `id = requestId`, status = pending.
  /// Paired section emits `id = deviceId`, status = paired.
  static List<OpenClawDevice> _parseDevicesAscii(String raw) {
    final out = <OpenClawDevice>[];
    final lines = raw.split('\n');
    var section = ''; // 'pending' | 'paired' | 'revoked'

    final headerRe =
        RegExp(r'^(Pending|Paired|Revoked)\s*\(\d+\)', caseSensitive: false);
    // UUID, 64-char hex (device id sha-256), or 32-char hex.
    final idRe = RegExp(
      r'\b('
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      r'|[0-9a-f]{64}'
      r'|[0-9a-f]{32}'
      r')\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final hdr = headerRe.firstMatch(trimmed);
      if (hdr != null) {
        section = hdr.group(1)!.toLowerCase();
        continue;
      }
      if (section.isEmpty) continue;

      // Find an ID-shaped token anywhere in the line. Anything without
      // one is column header / separator / name-only / noise — skip.
      final m = idRe.firstMatch(trimmed);
      if (m == null) continue;
      final id = m.group(1)!;

      // Try to extract a friendly display name from the row by looking
      // for "ClawCommander", "Pocket Claw" (legacy), or any non-id
      // leading text. Best-effort.
      String? name;
      final nameMatch = RegExp(
              r'(ClawCommander|Pocket Claw|[A-Za-z][A-Za-z0-9 _-]{1,30})')
          .firstMatch(trimmed.replaceAll(id, ''));
      if (nameMatch != null) name = nameMatch.group(0)!.trim();

      out.add(OpenClawDevice(
        id: id,
        name: name,
        status: section,
      ));
    }
    return out;
  }
}

/// Thrown when both `openclaw devices --json` and the ASCII parser
/// produce zero rows but the CLI returned non-empty text. Carries the
/// raw output so the UI can render it for debugging.
class OpenClawDevicesParseException implements Exception {
  final String rawOutput;
  const OpenClawDevicesParseException(this.rawOutput);

  @override
  String toString() {
    final preview = rawOutput.length > 600
        ? '${rawOutput.substring(0, 600)}\n…(truncated)'
        : rawOutput;
    return 'CLI output not understood. Raw response:\n\n$preview';
  }
}
