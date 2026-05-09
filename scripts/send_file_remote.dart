/// Generic remote delivery: upload an arbitrary file to Gofile.io and
/// post the link to Telegram. Also attaches the file directly to
/// Telegram if it is small enough (Telegram bot file limit is 50 MB).
///
/// Usage:
///   dart scripts/send_file_remote.dart <path-to-file>
///
/// Reads TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from .env at the repo
/// root, same as scripts/release_remote.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _telegramFileLimitBytes = 50 * 1024 * 1024;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart scripts/send_file_remote.dart <file>');
    exit(2);
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exit(1);
  }

  final env = _loadEnv();
  final token = env['TELEGRAM_BOT_TOKEN'];
  final chatId = env['TELEGRAM_CHAT_ID'];
  if (token == null || token.isEmpty || chatId == null || chatId.isEmpty) {
    stderr.writeln('TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID missing in .env');
    exit(1);
  }

  final sizeBytes = file.lengthSync();
  final sizeMb = (sizeBytes / 1024 / 1024).toStringAsFixed(2);
  final fileName = file.uri.pathSegments.last;
  stdout.writeln('Sending $fileName ($sizeMb MB)...');

  // Step 1: Gofile upload — the durable link.
  final gofile = await _uploadToGofile(file);
  if (gofile == null) {
    stderr.writeln('Gofile upload failed.');
    exit(1);
  }
  stdout.writeln('Gofile: ${gofile.downloadPage}');

  // Step 2: Telegram — attach the file directly when within the 50 MB
  // bot limit so the recipient can read it inline; fall back to a link
  // message otherwise.
  final caption = _buildCaption(
    fileName: fileName,
    sizeMb: sizeMb,
    gofileUrl: gofile.downloadPage,
  );

  bool sent;
  if (sizeBytes <= _telegramFileLimitBytes) {
    sent = await _sendTelegramDocument(
      token: token,
      chatId: chatId,
      file: file,
      caption: caption,
    );
  } else {
    stdout.writeln(
        'File over 50 MB — sending Telegram text with link only.');
    sent = await _sendTelegramText(
      token: token,
      chatId: chatId,
      text: caption,
    );
  }

  if (!sent) {
    stderr.writeln('Telegram send failed.');
    stdout.writeln('Gofile link (save this): ${gofile.downloadPage}');
    exit(1);
  }
  stdout.writeln('✓ Telegram delivered.');
}

class _GofileResult {
  final String downloadPage;
  _GofileResult(this.downloadPage);
}

Future<_GofileResult?> _uploadToGofile(File file) async {
  try {
    final serversResp = await http
        .get(Uri.parse('https://api.gofile.io/servers'))
        .timeout(const Duration(seconds: 30));
    if (serversResp.statusCode != 200) {
      stderr.writeln('Gofile getServers HTTP ${serversResp.statusCode}');
      return null;
    }
    final serversJson = jsonDecode(serversResp.body) as Map<String, dynamic>;
    if (serversJson['status'] != 'ok') return null;
    final servers = serversJson['data']['servers'] as List<dynamic>;
    if (servers.isEmpty) return null;
    final server = servers[0]['name'] as String;

    final uri = Uri.parse('https://$server.gofile.io/contents/uploadfile');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send().timeout(const Duration(minutes: 20));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      stderr.writeln('Gofile upload HTTP ${streamed.statusCode}: $body');
      return null;
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['status'] != 'ok') return null;
    final data = json['data'] as Map<String, dynamic>;
    return _GofileResult(data['downloadPage'] as String);
  } catch (e) {
    stderr.writeln('Gofile exception: $e');
    return null;
  }
}

Future<bool> _sendTelegramDocument({
  required String token,
  required String chatId,
  required File file,
  required String caption,
}) async {
  try {
    final uri =
        Uri.parse('https://api.telegram.org/bot$token/sendDocument');
    final req = http.MultipartRequest('POST', uri)
      ..fields['chat_id'] = chatId
      ..fields['caption'] = caption
      ..files.add(await http.MultipartFile.fromPath('document', file.path));
    final streamed = await req.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      stderr.writeln('Telegram sendDocument HTTP ${streamed.statusCode}: $body');
      return false;
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['ok'] == true;
  } catch (e) {
    stderr.writeln('Telegram document exception: $e');
    return false;
  }
}

Future<bool> _sendTelegramText({
  required String token,
  required String chatId,
  required String text,
}) async {
  try {
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
    stderr.writeln('Telegram text exception: $e');
    return false;
  }
}

String _buildCaption({
  required String fileName,
  required String sizeMb,
  required String gofileUrl,
}) {
  return [
    fileName,
    'Size: $sizeMb MB',
    '',
    gofileUrl,
    'Link expires in approx 10 days.',
  ].join('\n');
}

Map<String, String> _loadEnv() {
  final result = <String, String>{};
  final f = File('.env');
  if (!f.existsSync()) return result;
  for (final line in f.readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final eq = t.indexOf('=');
    if (eq == -1) continue;
    final key = t.substring(0, eq).trim();
    var value = t.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}
