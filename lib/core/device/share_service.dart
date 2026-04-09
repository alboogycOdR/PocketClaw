/// Wraps share_plus for sharing / drafting messages
library;

import 'package:share_plus/share_plus.dart';

import '../local_agent/tool_executor.dart';

class ShareService {
  /// Drafts and presents a share sheet for the given [body].
  ///
  /// [channel] hints at the target (e.g. "whatsapp", "email", "sms", "generic").
  /// The OS share sheet ultimately decides the target app.
  Future<ToolResult> draft({
    required String body,
    String? recipient,
    String? subject,
    String channel = 'generic',
  }) async {
    try {
      final text = _buildShareText(
        body: body,
        recipient: recipient,
        subject: subject,
        channel: channel,
      );

      final result = await Share.share(text);

      if (result.status == ShareResultStatus.dismissed) {
        return ToolResult.ok(
          'Share sheet dismissed by user.',
          data: {'status': 'dismissed'},
        );
      }

      return ToolResult.ok(
        'Message shared successfully via ${result.raw}.',
        data: {
          'status': 'shared',
          'channel': channel,
          'bodyLength': body.length,
        },
      );
    } catch (e) {
      return ToolResult.error('Share failed: $e');
    }
  }

  String _buildShareText({
    required String body,
    String? recipient,
    String? subject,
    required String channel,
  }) {
    final buffer = StringBuffer();

    if (recipient != null && channel == 'email') {
      buffer.writeln('To: $recipient');
    }
    if (subject != null && channel == 'email') {
      buffer.writeln('Subject: $subject');
      buffer.writeln();
    }

    buffer.write(body);
    return buffer.toString();
  }
}
