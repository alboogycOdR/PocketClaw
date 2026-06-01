/// Remote file delivery: upload a file to Gofile.io and post the
/// public link to a Telegram chat via a bot.
///
/// Configuration is read from a `.env` file at the project root
/// (gitignored):
///
///   TELEGRAM_BOT_TOKEN=1234567890:AAAA...
///   TELEGRAM_CHAT_ID=123456789
///
/// Usage:
///   dart scripts/release_remote.dart [path-to-file]
///
/// If no path is passed, defaults to the Flutter release APK path.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _defaultFilePath = 'build/app/outputs/flutter-apk/app-release.apk';

Future<void> main(List<String> args) async {
  final filePath = args.isNotEmpty ? args.first : _defaultFilePath;
  final file = File(filePath);

  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    if (args.isEmpty) {
      stderr.writeln(
        'Run: flutter build apk --release --target-platform android-arm64 '
        '--dart-define=APP_FLAVOR=hermesCommander',
      );
    }
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

  final fileName = file.uri.pathSegments.isEmpty
      ? file.path
      : file.uri.pathSegments.last;
  final sizeMb = (file.lengthSync() / 1024 / 1024).toStringAsFixed(1);
  final commitHash = await _safeGit(['rev-parse', '--short', 'HEAD']);
  final commitMsg = await _safeGit(['log', '-1', '--pretty=%s']);

  stdout.writeln('');
  stdout.writeln('Uploading ${file.path} ($sizeMb MB) to Gofile...');

  final uploadResult = await _uploadToGofile(file);
  if (uploadResult == null) {
    stderr.writeln('Upload failed.');
    exit(1);
  }

  stdout.writeln('Upload complete.');
  stdout.writeln('  Download page: ${uploadResult.downloadPage}');
  stdout.writeln('');
  stdout.writeln('Sending Telegram notification...');

  final message = _buildMessage(
    fileName: fileName,
    downloadPage: uploadResult.downloadPage,
    sizeMb: sizeMb,
    commitHash: commitHash,
    commitMsg: commitMsg,
  );

  final sent = await _sendTelegram(token: token, chatId: chatId, text: message);

  if (!sent) {
    stderr.writeln('Telegram send failed.');
    stdout.writeln('Download URL (save this): ${uploadResult.downloadPage}');
    exit(1);
  }

  stdout.writeln('Sent: ${uploadResult.downloadPage}');
  stdout.writeln('Check Telegram. Link expires in ~10 days.');
}

class _GofileResult {
  final String downloadPage;

  const _GofileResult(this.downloadPage);
}

Future<_GofileResult?> _uploadToGofile(File file) async {
  try {
    final serversResp = await http
        .get(Uri.parse('https://api.gofile.io/servers'))
        .timeout(const Duration(seconds: 30));

    if (serversResp.statusCode != 200) {
      stderr.writeln(
        'Gofile getServers failed: HTTP ${serversResp.statusCode}',
      );
      return null;
    }

    final serversJson = jsonDecode(serversResp.body) as Map<String, dynamic>;
    if (serversJson['status'] != 'ok') {
      stderr.writeln('Gofile getServers status: ${serversJson['status']}');
      return null;
    }

    final servers =
        (serversJson['data']['servers'] as List<dynamic>? ?? const []);
    if (servers.isEmpty) {
      stderr.writeln('Gofile returned no servers.');
      return null;
    }
    final server = (servers.first as Map<String, dynamic>)['name'] as String?;
    if (server == null || server.isEmpty) {
      stderr.writeln('Gofile returned an invalid server name.');
      return null;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://$server.gofile.io/contents/uploadfile'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(minutes: 20));
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

    final data = uploadJson['data'] as Map<String, dynamic>? ?? const {};
    final downloadPage = data['downloadPage'] as String?;
    if (downloadPage == null || downloadPage.isEmpty) {
      stderr.writeln('Gofile upload succeeded but returned no downloadPage.');
      return null;
    }

    return _GofileResult(downloadPage);
  } catch (e) {
    stderr.writeln('Gofile upload exception: $e');
    return null;
  }
}

Future<bool> _sendTelegram({
  required String token,
  required String chatId,
  required String text,
}) async {
  try {
    final resp = await http
        .post(
          Uri.parse('https://api.telegram.org/bot$token/sendMessage'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': chatId,
            'text': text,
            'disable_web_page_preview': false,
          }),
        )
        .timeout(const Duration(seconds: 30));

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
  required String fileName,
  required String downloadPage,
  required String sizeMb,
  required String? commitHash,
  required String? commitMsg,
}) {
  return [
    'Build ready: $fileName',
    if (commitMsg != null && commitMsg.isNotEmpty) '',
    if (commitMsg != null && commitMsg.isNotEmpty) commitMsg,
    '',
    'Size: $sizeMb MB',
    if (commitHash != null && commitHash.isNotEmpty) 'Commit: $commitHash',
    '',
    downloadPage,
    '',
    'Link expires in ~10 days.',
  ].join('\n');
}

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
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}

Future<String?> _safeGit(List<String> args) async {
  try {
    final result = await Process.run('git', args);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return null;
}

const _setupInstructions = '''
To set up Telegram notifications:

1. Create a bot: message @BotFather on Telegram, run /newbot, and save the token.
2. Get your chat ID: message @userinfobot and copy the numeric ID it returns.
3. Send your bot one message first. Until you initiate the chat, the bot cannot DM you.
4. Create a .env file in the project root (gitignored):

     TELEGRAM_BOT_TOKEN=1234567890:AAAA...your-token...
     TELEGRAM_CHAT_ID=123456789

Then run this script again.
''';
