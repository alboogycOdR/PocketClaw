/// Privacy warning banner — shown above the chat input when the user is
/// in Cloud or OpenClaw mode AND the draft text contains privacy-sensitive
/// keywords. One tap switches to Local. User is never blocked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/chat/chat_mode.dart';
import '../../data/providers/chat_mode_providers.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/providers/core_providers.dart';

/// Keywords that trigger the "sounds sensitive" warning.
const List<String> _privacyKeywords = [
  'password',
  'secret',
  'private',
  'confidential',
  'ssn',
  'social security',
  'bank account',
  'credit card',
  'medical',
  'diagnosis',
  'salary',
  'nda',
  'classified',
  'pin code',
  'passport',
];

/// Returns true if [text] contains any privacy-sensitive keyword.
bool containsPrivacyKeyword(String text) {
  final lower = text.toLowerCase();
  return _privacyKeywords.any(lower.contains);
}

class PrivacyWarningBanner extends ConsumerWidget {
  final String draftText;

  const PrivacyWarningBanner({super.key, required this.draftText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(chatModeProvider);

    // Privacy banner is for non-local modes (OpenClaw / Hermes) where
    // the message leaves the device. Local stays silent.
    if (mode == ChatMode.local) return const SizedBox.shrink();
    if (!containsPrivacyKeyword(draftText)) return const SizedBox.shrink();

    final localAvailability = ref.watch(modeAvailabilityProvider(ChatMode.local));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PocketClawTheme.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PocketClawTheme.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              size: 18, color: PocketClawTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This looks sensitive. Current mode sends to '
              '${mode == ChatMode.hermes ? "your Hermes server" : "the OpenClaw gateway"}.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: PocketClawTheme.warning,
              ),
            ),
          ),
          if (localAvailability.isAvailable) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _switchToLocal(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PocketClawTheme.electricTeal.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: PocketClawTheme.electricTeal.withAlpha(120)),
                ),
                child: Text(
                  'Switch to Local',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.electricTeal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _switchToLocal(BuildContext context, WidgetRef ref) async {
    final prefs = ref.read(sharedPrefsProvider);
    final sessionManager = ref.read(sessionManagerProvider);
    final messages = ref.read(messagesProvider.notifier);

    await prefs.setString('chat_mode', ChatMode.local.name);
    ref.read(chatModeProvider.notifier).state = ChatMode.local;
    sessionManager.setMode(ChatMode.local.name);

    final savedKey = prefs.getString(ChatMode.local.storageKey);
    if (savedKey != null) {
      try {
        await sessionManager.loadSession(savedKey);
        final loaded = await sessionManager.recentHistory(200);
        messages.clear();
        for (final m in loaded) {
          messages.add(m);
        }
      } catch (_) {
        await sessionManager.startNewSession(mode: ChatMode.local.name);
        messages.clear();
      }
    } else {
      await sessionManager.startNewSession(mode: ChatMode.local.name);
      messages.clear();
    }
    await prefs.setString(
        ChatMode.local.storageKey, sessionManager.currentSessionKey);
  }
}
