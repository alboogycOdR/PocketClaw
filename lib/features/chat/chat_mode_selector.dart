/// Chat Mode Selector — segmented control showing Local / OpenClaw / Hermes.
/// Tapping switches the active mode and loads that mode's session.
/// Unavailable modes are visually dim and show a helper message on tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/chat/chat_mode.dart';
import '../../data/providers/chat_mode_providers.dart';
import '../../data/providers/chat_providers.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/server_providers.dart';

class ChatModeSelector extends ConsumerWidget {
  const ChatModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(chatModeProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: PocketClawTheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(
              color: PocketClawTheme.colorScheme.outline.withAlpha(80)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: ChatMode.values
                .map((m) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: m == ChatMode.values.last ? 0 : 6,
                        ),
                        child: _ModeButton(
                          mode: m,
                          isActive: mode == m,
                          onTap: () => _onModeTap(context, ref, m),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          _ActiveModeSubtitle(mode: mode),
        ],
      ),
    );
  }

  Future<void> _onModeTap(
    BuildContext context,
    WidgetRef ref,
    ChatMode mode,
  ) async {
    final availability = ref.read(modeAvailabilityProvider(mode));
    if (!availability.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(availability.reasonUnavailable ??
              '${mode.displayName} mode unavailable.'),
          duration: const Duration(seconds: 4),
        ),
      );
      // Still allow switching — user can configure from there
    }

    // Save current mode's session and switch
    final currentMode = ref.read(chatModeProvider);
    if (currentMode == mode) return;

    final sessionManager = ref.read(sessionManagerProvider);

    // Flush buffered messages to disk under the OLD mode tag BEFORE we
    // switch. If we set the new mode first, the buffer gets persisted
    // with the wrong tag and shows up in the new mode's history list.
    // (ADR-001 §3.2 — mode tag bug.)
    await sessionManager.flushCurrentSession();

    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('chat_mode', mode.name);
    ref.read(chatModeProvider.notifier).state = mode;

    // Keep activeServer in lockstep with chat mode — Phase 2 makes the
    // server the top-level scope, so changing chat mode also changes
    // which agent's Mission Control / Memory / Skills the user sees.
    final correspondingServer = switch (mode) {
      ChatMode.openclaw => ActiveServer.openclaw,
      ChatMode.hermes => ActiveServer.hermes,
      ChatMode.local => ActiveServer.local,
    };
    await setActiveServer(ref, correspondingServer);

    sessionManager.setMode(mode.name);

    // Load the new mode's last session (or start fresh)
    final savedKey = prefs.getString(mode.storageKey);
    final messages = ref.read(messagesProvider.notifier);

    if (savedKey != null) {
      try {
        await sessionManager.loadSession(savedKey);
        final loaded = await sessionManager.recentHistory(200);
        messages.clear();
        for (final m in loaded) {
          messages.add(m);
        }
      } catch (_) {
        // Corrupt or missing session — start fresh
        await sessionManager.startNewSession(mode: mode.name);
        messages.clear();
      }
    } else {
      await sessionManager.startNewSession(mode: mode.name);
      messages.clear();
    }

    // Remember this as the current session for the new mode
    await prefs.setString(mode.storageKey, sessionManager.currentSessionKey);
  }
}

class _ModeButton extends ConsumerWidget {
  final ChatMode mode;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeButton({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(modeAvailabilityProvider(mode));
    final color = mode.color;
    final bg = isActive ? color.withAlpha(30) : PocketClawTheme.surface;
    final borderColor = isActive ? color : color.withAlpha(60);
    final textColor = availability.isAvailable
        ? (isActive ? color : Colors.white70)
        : Colors.white24;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(mode.icon, size: 14, color: textColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    mode.displayName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!availability.isAvailable) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.lock_outline, size: 10, color: Colors.white24),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveModeSubtitle extends ConsumerWidget {
  final ChatMode mode;
  const _ActiveModeSubtitle({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(modeAvailabilityProvider(mode));
    final text = availability.isAvailable
        ? (availability.subtitle ?? mode.tagline)
        : (availability.reasonUnavailable ?? 'Unavailable');

    return Row(
      children: [
        Icon(
          availability.isAvailable ? Icons.check_circle : Icons.warning_amber,
          size: 12,
          color: availability.isAvailable
              ? PocketClawTheme.success
              : PocketClawTheme.warning,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: Colors.white54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
