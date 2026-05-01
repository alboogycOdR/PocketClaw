/// Remote APK delivery: upload the latest release APK to Gofile.io and
/// post the download link to a Telegram chat via a bot.
///
/// Configuration is read from a `.env` file at the project root (gitignored):
///
///   TELEGRAM_BOT_TOKEN=1234567890:AAAA...
///   TELEGRAM_CHAT_ID=123456789
///
/// Usage: `dart scripts/release_remote.dart`
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _apkPath = 'build/app/outputs/flutter-apk/app-release.apk';

Future<void> main(List<String> args) async {
  final apk = File(_apkPath);
  if (!apk.existsSync()) {
    stderr.writeln('APK not found at $_apkPath');
    stderr.writeln('Run: flutter build apk --release --target-platform android-arm64');
    exit(1);
  }

  final env = _loadEnv();
  final token = env['TELEGRAM_BOT_TOKEN'];
  final chatId = env['TELEGRAM_CHAT_ID'];

  if (token == null || token.isEmpty) {
    stderr.writeln('TELEGRAM_BOT_TOKEN not set in .env');
    stderr.writeln(_setupInstructions);
    exit(1);
  }
  if (chatId == null || chatId.isEmpty) {
    stderr.writeln('TELEGRAM_CHAT_ID not set in .env');
    stderr.writeln(_setupInstructions);
    exit(1);
  }

  final sizeMb = (apk.lengthSync() / 1024 / 1024).toStringAsFixed(1);
  final commitHash = await _currentCommitHash();
  final commitMsg = await _currentCommitMessage();

  stdout.writeln('');
  stdout.writeln('Uploading ${apk.path} ($sizeMb MB) to Gofile.io...');

  final uploadResult = await _uploadToGofile(apk);
  if (uploadResult == null) {
    stderr.writeln('Upload failed.');
    exit(1);
  }

  stdout.writeln('Upload complete.');
  stdout.writeln('  Download page: ${uploadResult.downloadPage}');
  stdout.writeln('');
  stdout.writeln('Sending Telegram notification...');

  final message = _buildMessage(
    downloadPage: uploadResult.downloadPage,
    sizeMb: sizeMb,
    commitHash: commitHash,
    commitMsg: commitMsg,
  );

  final sent = await _sendTelegram(
    token: token,
    chatId: chatId,
    text: message,
  );

  if (sent) {
    stdout.writeln('\u2713 Telegram message sent.');
    stdout.writeln('');
    stdout.writeln('Check your Telegram. Link expires in ~10 days.');
  } else {
    stderr.writeln('Telegram send failed.');
    stdout.writeln('Download URL (save this): ${uploadResult.downloadPage}');
    exit(1);
  }
}

// ── Gofile.io upload ─────────────────────────────────────────────────────

class _GofileResult {
  final String downloadPage;
  _GofileResult(this.downloadPage);
}

Future<_GofileResult?> _uploadToGofile(File apk) async {
  try {
    // Step 1: get a server
    final serversResp = await http
        .get(Uri.parse('https://api.gofile.io/servers'))
        .timeout(const Duration(seconds: 30));

    if (serversResp.statusCode != 200) {
      stderr.writeln('Gofile getServers failed: HTTP ${serversResp.statusCode}');
      return null;
    }

    final serversJson = jsonDecode(serversResp.body) as Map<String, dynamic>;
    if (serversJson['status'] != 'ok') {
      stderr.writeln('Gofile getServers status: ${serversJson['status']}');
      return null;
    }

    final servers = (serversJson['data']['servers'] as List<dynamic>);
    if (servers.isEmpty) {
      stderr.writeln('Gofile returned no servers');
      return null;
    }
    final server = servers[0]['name'] as String;
    stdout.writeln('Using Gofile server: $server');

    // Step 2: upload (streamed multipart)
    final uploadUri =
        Uri.parse('https://$server.gofile.io/contents/uploadfile');
    final request = http.MultipartRequest('POST', uploadUri);
    request.files.add(
      await http.MultipartFile.fromPath('file', apk.path),
    );

    stdout.writeln('Uploading... (this may take a few minutes on mobile data)');
    final streamed =
        await request.send().timeout(const Duration(minutes: 20));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      stderr.writeln('Gofile upload HTTP ${streamed.statusCode}: $body');
      return null;
    }

    final uploadJson = jsonDecode(body) as Map<String, dynamic>;
    if (uploadJson['status'] != 'ok') {
      stderr.writeln('Gofile upload status: ${uploadJson['status']}');
      stderr.writeln('Body: $body');
      return null;
    }

    final data = uploadJson['data'] as Map<String, dynamic>;
    final downloadPage = data['downloadPage'] as String;
    return _GofileResult(downloadPage);
  } catch (e) {
    stderr.writeln('Gofile upload exception: $e');
    return null;
  }
}

// ── Telegram send ────────────────────────────────────────────────────────

Future<bool> _sendTelegram({
  required String token,
  required String chatId,
  required String text,
}) async {
  try {
    // Plain text — no parse_mode. Telegram's legacy Markdown does not
    // support backslash escapes (only MarkdownV2 does), and any unmatched
    // `_` / `*` / backtick / bracket in commit messages breaks parsing.
    // URLs are still auto-linked by Telegram in plain text, so the
    // recipient experience is identical for the download-link case.
    final resp = await http.post(
      Uri.parse('https://api.telegram.org/bot$token/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chat_id': chatId,
        'text': text,
        'disable_web_page_preview': false,
      }),
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      stderr.writeln('Telegram HTTP ${resp.statusCode}: ${resp.body}');
      return false;
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['ok'] == true;
  } catch (e) {
    stderr.writeln('Telegram exception: $e');
    return false;
  }
}

String _buildMessage({
  required String downloadPage,
  required String sizeMb,
  required String? commitHash,
  required String? commitMsg,
}) {
  final buf = StringBuffer();
  buf.writeln('\u{1F980} Pocket Claw build ready');
  buf.writeln();
  if (commitMsg != null && commitMsg.isNotEmpty) {
    buf.writeln(commitMsg);
    buf.writeln();
  }
  buf.writeln('Size: $sizeMb MB');
  if (commitHash != null) buf.writeln('Commit: $commitHash');
  buf.writeln();
  buf.writeln(downloadPage);
  buf.writeln();
  buf.writeln('Link expires in approx 10 days.');
  return buf.toString();
}

// ── Helpers ──────────────────────────────────────────────────────────────

Map<String, String> _loadEnv() {
  final result = <String, String>{};
  final envFile = File('.env');
  if (!envFile.existsSync()) return result;

  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq == -1) continue;
    final key = trimmed.substring(0, eq).trim();
    var value = trimmed.substring(eq + 1).trim();
    // Strip surrounding quotes if present
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}

Future<String?> _currentCommitHash() async {
  try {
    final result = await Process.run('git', ['rev-parse', '--short', 'HEAD']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return null;
}

Future<String?> _currentCommitMessage() async {
  try {
    final result = await Process.run('git', ['log', '-1', '--pretty=%s']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return null;
}

const _setupInstructions = '''
To set up Telegram notifications:

1. Create a bot: message @BotFather on Telegram, /newbot, follow prompts.
   Save the token it gives you.

2. Get your chat ID: message @userinfobot on Telegram, it replies with
   your numeric chat ID.

3. Create a `.env` file in the project root (gitignored):

     TELEGRAM_BOT_TOKEN=1234567890:AAAA...your-token...
     TELEGRAM_CHAT_ID=123456789

4. Send a first message to your bot so it can DM you back.

Then run this script again.
''';
