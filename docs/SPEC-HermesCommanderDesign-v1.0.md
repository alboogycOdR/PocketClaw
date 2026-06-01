# Hermes Commander — UI Design System
## Hermes WebUI Visual Parity Specification v1.0

**Date:** 2026-05-14  
**Author:** CARMEN PTY LTD  
**Reference:** nesquena/hermes-webui screenshots + live README  
**Status:** Implementation-ready  
**Estimated effort:** 5–6 days (design system + all screens)  

---

## Design Philosophy

The Hermes WebUI has a specific, disciplined aesthetic: **dark intelligence terminal**.  
Not generic "dark mode AI app". The exact qualities to replicate:

- Near-black backgrounds with layered depth (not flat black, not dark grey — layered navy)
- Gold/amber as the **only** accent colour — used sparingly and meaningfully
- Monospace typeface for anything agent-related (filenames, paths, session IDs, code)
- Sans-serif for UI chrome and prose
- Status communicated through coloured dots, not icons
- Surfaces have barely-visible borders, not shadows
- No gradients except the Hermes logo glow
- Composer footer is the identity anchor — profile · workspace · model always visible

---

## 1. Colour System

```dart
// lib/app/hermes_commander_theme.dart
library;

import 'package:flutter/material.dart';

/// HermesCommander colour system — extracted from nesquena/hermes-webui
/// screenshots to pixel accuracy.
class HCTheme {

  // ── Base surfaces ──────────────────────────────────────────────────────────

  /// Page/scaffold background — near-black navy
  static const bgBase     = Color(0xFF0D1117);

  /// Sidebar / panel background — one step lighter
  static const bgPanel    = Color(0xFF161B22);

  /// Card / elevated surface — two steps lighter
  static const bgSurface  = Color(0xFF1C2128);

  /// Active item / hover state
  static const bgActive   = Color(0xFF21262D);

  /// Input field background
  static const bgInput    = Color(0xFF0D1117);

  // ── Borders ────────────────────────────────────────────────────────────────

  /// Default border — barely visible
  static const border     = Color(0xFF30363D);

  /// Subtle section dividers
  static const borderMuted = Color(0xFF21262D);

  // ── Text ──────────────────────────────────────────────────────────────────

  static const textPrimary   = Color(0xFFE6EDF3);  // near white
  static const textSecondary = Color(0xFF8B949E);  // muted grey
  static const textMuted     = Color(0xFF484F58);  // very muted
  static const textLink      = Color(0xFF58A6FF);  // blue for links

  // ── Accent — Gold/Amber (Hermes brand) ────────────────────────────────────

  static const gold       = Color(0xFFC9A227);   // primary brand gold
  static const goldLight  = Color(0xFFD4A017);   // slightly brighter gold
  static const goldMuted  = Color(0xFF8B6914);   // muted gold for backgrounds
  static const goldBg     = Color(0xFF1A1509);   // gold tint background

  // ── Status colours ────────────────────────────────────────────────────────

  static const statusGreen  = Color(0xFF3FB950);  // active / online
  static const statusAmber  = Color(0xFFF0883E);  // processing / running
  static const statusBlue   = Color(0xFF58A6FF);  // info / queued
  static const statusRed    = Color(0xFFF85149);  // error / failed
  static const statusMuted  = Color(0xFF6E7681);  // idle / offline

  // ── Pinned star gold ──────────────────────────────────────────────────────

  static const starGold   = Color(0xFFD29922);

  // ── Approval card colours ─────────────────────────────────────────────────

  static const approvalBg     = Color(0xFF161B22);
  static const approvalBorder = Color(0xFF3FB950);
  static const denyBg         = Color(0xFF1C1010);
  static const denyBorder     = Color(0xFFF85149);

  // ── ThemeData ─────────────────────────────────────────────────────────────

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgBase,
    colorScheme: const ColorScheme.dark(
      surface:          bgPanel,
      surfaceContainerHighest: bgSurface,
      primary:          gold,
      secondary:        goldLight,
      onPrimary:        Color(0xFF0D1117),
      onSurface:        textPrimary,
      outline:          border,
      error:            statusRed,
    ),
    fontFamily: 'GeistSans',          // primary UI font — see §2
    textTheme: _textTheme,
    cardTheme: CardTheme(
      color: bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: border),
      ),
    ),
    dividerColor: border,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgPanel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 18),
      actionsIconTheme: IconThemeData(color: textSecondary, size: 18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgPanel,
      indicatorColor: bgActive,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      )),
      iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: textSecondary, size: 20)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: bgBase,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: border),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: border),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: gold, width: 1),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      hintStyle: TextStyle(color: textMuted, fontSize: 14),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );

  static const _textTheme = TextTheme(
    titleLarge:  TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: textPrimary),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary),
    titleSmall:  TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: textSecondary),
    bodyLarge:   TextStyle(fontSize: 14, color: textPrimary, height: 1.6),
    bodyMedium:  TextStyle(fontSize: 13, color: textPrimary, height: 1.5),
    bodySmall:   TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
    labelLarge:  TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: textPrimary),
    labelSmall:  TextStyle(fontWeight: FontWeight.w500, fontSize: 10, color: textSecondary),
  );
}
```

---

## 2. Typography

Two typefaces — same as the WebUI:

```yaml
# pubspec.yaml — add under flutter: fonts:
flutter:
  fonts:
    - family: GeistSans
      fonts:
        - asset: assets/fonts/Geist-Regular.ttf    weight: 400
        - asset: assets/fonts/Geist-Medium.ttf     weight: 500
        - asset: assets/fonts/Geist-SemiBold.ttf   weight: 600
    - family: GeistMono
      fonts:
        - asset: assets/fonts/GeistMono-Regular.ttf  weight: 400
        - asset: assets/fonts/GeistMono-Medium.ttf   weight: 500
```

**Download from:** https://github.com/vercel/geist-font/releases  
Free, open source (OFL license). The WebUI uses Geist for UI and GeistMono for code, paths, session IDs.

**Typography rules:**
- All agent responses → `GeistSans` 14px, line-height 1.6
- Code blocks, file paths, session IDs → `GeistMono` 12px  
- Composer input → `GeistSans` 15px
- Section labels (TODAY, PINNED) → `GeistSans` 11px, ALL CAPS, `textMuted`
- Composer footer chips → `GeistSans` 11–12px

---

## 3. Hermes Logo + Avatar System

### Hermes Avatar (agent messages)
The exact avatar from the WebUI — dark circle with gold caduceus:

```dart
// lib/shared/widgets/hermes_avatar.dart
library;

import 'package:flutter/material.dart';
import '../../app/hermes_commander_theme.dart';

class HermesAvatar extends StatelessWidget {
  final double size;
  const HermesAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1509),
        border: Border.all(color: HCTheme.goldMuted, width: 1),
        boxShadow: [
          BoxShadow(
            color: HCTheme.gold.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/images/hermes_caduceus.png',
          width: size * 0.55,
          height: size * 0.55,
          color: HCTheme.gold,
        ),
      ),
    );
  }
}

/// User avatar — solid coloured circle with initial
class UserAvatar extends StatelessWidget {
  final String initial;
  final double size;
  const UserAvatar({super.key, required this.initial, this.size = 32});

  @override
  Widget build(BuildContext context) {
    // Deterministic colour from initial
    final colors = [
      const Color(0xFF388BFD), // blue
      const Color(0xFF3FB950), // green
      const Color(0xFFF0883E), // amber
      const Color(0xFF9E6ADE), // purple
    ];
    final color = colors[initial.codeUnitAt(0) % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'GeistSans',
            fontWeight: FontWeight.w600,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}
```

### Large Hermes Logo (empty state)
```dart
// In the empty state screen — matches the WebUI centered logo
Container(
  width: 80,
  height: 80,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: const Color(0xFF1A1509),
    border: Border.all(color: HCTheme.goldMuted, width: 1.5),
    boxShadow: [
      BoxShadow(
        color: HCTheme.gold.withOpacity(0.2),
        blurRadius: 24,
        spreadRadius: 4,
      ),
    ],
  ),
  child: Center(
    child: Image.asset(
      'assets/images/hermes_caduceus.png',
      width: 40, height: 40,
      color: HCTheme.gold,
    ),
  ),
),
```

---

## 4. Bottom Navigation

Mobile adaptation of the WebUI's left icon rail.

```dart
// lib/app/hermes_commander_nav.dart

// Five destinations matching the scoped feature set:
NavigationBar(
  backgroundColor: HCTheme.bgPanel,
  indicatorColor: HCTheme.bgActive,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  // Top border only:
  child: DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: HCTheme.border, width: 0.5),
      ),
      color: HCTheme.bgPanel,
    ),
    child: NavigationBar(
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          selectedIcon: const Icon(Icons.chat_bubble, size: 20),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: const Icon(Icons.tune_outlined, size: 20),
          selectedIcon: const Icon(Icons.tune, size: 20),
          label: 'Control',
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_tree_outlined, size: 20),
          selectedIcon: const Icon(Icons.account_tree, size: 20),
          label: 'Swarm',
        ),
        NavigationDestination(
          icon: const Icon(Icons.radar_outlined, size: 20),
          selectedIcon: const Icon(Icons.radar, size: 20),
          label: 'Intel',
        ),
        NavigationDestination(
          icon: const Icon(Icons.headphones_outlined, size: 20),
          selectedIcon: const Icon(Icons.headphones, size: 20),
          label: 'Ambient',
        ),
      ],
    ),
  ),
),
```

**Icon colour rules:**
- Active: `HCTheme.gold`
- Inactive: `HCTheme.textSecondary`
- No labels on active state (icon only) — matches WebUI icon rail
- NavBar background has a top border `HCTheme.border` — no shadow

---

## 5. Session List (Sidebar → Chat Drawer)

The WebUI's left session panel becomes a **slide-in drawer** from the left in Hermes Commander, triggered by swiping right or tapping the hamburger in the AppBar.

### Section Headers
```dart
// PINNED / TODAY / YESTERDAY / EARLIER
Padding(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
  child: Text(
    sectionLabel,  // 'PINNED', 'TODAY', etc.
    style: const TextStyle(
      fontFamily: 'GeistSans',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: HCTheme.textMuted,
      letterSpacing: 0.8,
    ),
  ),
),
```

### Session Item
```dart
// Exact match to WebUI session row
class _SessionTile extends StatelessWidget {
  final HermesSession session;
  final bool isActive;
  final bool isPinned;
  final bool isLive;  // has status dot (active session)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? HCTheme.bgActive : Colors.transparent,
          border: isActive
              ? const Border(
                  left: BorderSide(color: HCTheme.gold, width: 2))
              : null,
        ),
        child: Row(
          children: [
            // Pinned star
            if (isPinned)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.star, size: 12, color: HCTheme.starGold),
              ),

            // Session title
            Expanded(
              child: Text(
                session.displayTitle,
                style: TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                  color: isActive ? HCTheme.textPrimary : HCTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status dot (live sessions only)
            if (isLive)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(left: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: HCTheme.statusAmber,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### Drawer Footer — Model + Workspace Chips
Matches the WebUI's bottom-left model selector and workspace indicator:

```dart
// Bottom of session drawer
Container(
  padding: const EdgeInsets.all(12),
  decoration: const BoxDecoration(
    border: Border(top: BorderSide(color: HCTheme.border)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // MODEL label
      const Text('MODEL',
          style: TextStyle(fontSize: 10, color: HCTheme.textMuted,
              letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),

      // Model selector dropdown
      _ModelDropdown(),

      const SizedBox(height: 8),

      // Workspace path
      Row(children: [
        const Icon(Icons.folder_outlined, size: 14, color: HCTheme.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            workspacePath,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 10,
              color: HCTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),

      const SizedBox(height: 12),

      // Transcript / JSON / Import row
      Row(children: [
        _DrawerAction(label: '↓ Transcript', onTap: _exportTranscript),
        const SizedBox(width: 8),
        _DrawerAction(label: '{} JSON', onTap: _exportJson),
        const SizedBox(width: 8),
        _DrawerAction(label: '↑ Import', onTap: _importSession),
      ]),
    ],
  ),
),
```

---

## 6. Chat Screen

### AppBar — Session Header

```dart
AppBar(
  backgroundColor: HCTheme.bgPanel,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.menu, size: 18, color: HCTheme.textSecondary),
    onPressed: _openDrawer,
  ),
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        session.displayTitle,
        style: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: HCTheme.textPrimary,
        ),
      ),
      if (session.messageCount > 0)
        Text(
          '${session.messageCount} messages',
          style: const TextStyle(
            fontSize: 11,
            color: HCTheme.textSecondary,
          ),
        ),
    ],
  ),
  actions: [
    // Profile chip — matches WebUI top-right
    _ProfileChip(),
    const SizedBox(width: 4),

    // Model chip
    _ModelChip(),
    const SizedBox(width: 4),

    // Clear button
    IconButton(
      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
      color: HCTheme.textSecondary,
      tooltip: 'Clear',
      onPressed: _confirmClear,
    ),
    const SizedBox(width: 8),
  ],
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(0.5),
    child: Container(height: 0.5, color: HCTheme.border),
  ),
),
```

### Empty State
Exact replica of the WebUI empty state from Screenshot 2:

```dart
// lib/features/chat/hermes_empty_state.dart
class HermesEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gold logo with glow
            const HermesLargeLogo(),
            const SizedBox(height: 24),

            // "What can I help with?"
            const Text(
              'What can I help with?',
              style: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: HCTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Ask anything, run commands, explore files,\nor manage your scheduled tasks.',
              style: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 14,
                color: HCTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Suggestion chips
            _SuggestionChip(
              icon: Icons.folder_outlined,
              label: 'What files are in this workspace?',
              onTap: () => _sendSuggestion(context,
                  'What files are in this workspace?'),
            ),
            const SizedBox(height: 8),
            _SuggestionChip(
              icon: Icons.calendar_today_outlined,
              label: "What's on my schedule today?",
              onTap: () => _sendSuggestion(context,
                  "What's on my schedule today?"),
            ),
            const SizedBox(height: 8),
            _SuggestionChip(
              icon: Icons.memory_outlined,
              label: 'What do you remember about me?',
              onTap: () => _sendSuggestion(context,
                  'What do you remember about me?'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HCTheme.border),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: HCTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 13,
              color: HCTheme.textSecondary,
            ),
          ),
        ]),
      ),
    );
  }
}
```

### Message Bubbles

The WebUI does NOT use chat bubbles. Messages are full-width with avatar + left-aligned content — like a terminal or a document, not WhatsApp. Replicate this exactly.

```dart
// lib/features/chat/hermes_message_row.dart
class HermesMessageRow extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar column — fixed width
          SizedBox(
            width: 36,
            child: showAvatar
                ? (isUser
                    ? const UserAvatar(initial: 'Y', size: 28)
                    : const HermesAvatar(size: 28))
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),

          // Content — full remaining width
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role label (shown once per block, not per message)
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          isUser ? 'You' : 'Hermes',
                          style: const TextStyle(
                            fontFamily: 'GeistSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HCTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(message.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: HCTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Message content
                _MessageContent(message: message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final ChatMessage message;
  const _MessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: message.content,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 14,
          color: HCTheme.textPrimary,
          height: 1.6,
        ),
        code: const TextStyle(
          fontFamily: 'GeistMono',
          fontSize: 12,
          color: Color(0xFFE6EDF3),
          backgroundColor: Color(0xFF161B22),
        ),
        codeblockDecoration: BoxDecoration(
          color: HCTheme.bgPanel,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: HCTheme.border),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        blockquoteDecoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: HCTheme.border, width: 3),
          ),
        ),
        a: const TextStyle(color: HCTheme.textLink),
        h1: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HCTheme.textPrimary,
        ),
        h2: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: HCTheme.textPrimary,
        ),
        listBullet: const TextStyle(color: HCTheme.textSecondary),
      ),
      selectable: true,
    );
  }
}
```

---

## 7. Context Ring (Token Usage Indicator)

The circular token fill indicator that lives in the composer footer — one of the WebUI's most distinctive UI elements.

```dart
// lib/shared/widgets/context_ring.dart
library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/hermes_commander_theme.dart';

/// Circular token usage indicator matching the WebUI composer footer ring.
/// Shows fill 0.0–1.0 with colour-coded severity.
class ContextRing extends StatelessWidget {
  final double fill;         // 0.0 to 1.0
  final int tokenCount;
  final double estimatedCost; // USD
  final double size;

  const ContextRing({
    super.key,
    required this.fill,
    required this.tokenCount,
    this.estimatedCost = 0,
    this.size = 32,
  });

  Color get _ringColor {
    if (fill >= 0.9) return HCTheme.statusRed;
    if (fill >= 0.75) return const Color(0xFFF0883E);  // amber
    if (fill >= 0.5) return const Color(0xFFD29922);   // yellow
    return HCTheme.statusGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(fill: fill, color: _ringColor),
          child: Center(
            child: Text(
              _compact(tokenCount),
              style: TextStyle(
                fontFamily: 'GeistMono',
                fontSize: size * 0.28,
                fontWeight: FontWeight.w500,
                color: _ringColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _tooltip {
    final pct = (fill * 100).toStringAsFixed(0);
    final cost = estimatedCost > 0
        ? '  ·  ~\$${estimatedCost.toStringAsFixed(4)}'
        : '';
    return '$tokenCount tokens ($pct% of context)$cost';
  }

  String _compact(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return '$n';
  }
}

class _RingPainter extends CustomPainter {
  final double fill;
  final Color color;
  const _RingPainter({required this.fill, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final strokeWidth = 2.5;

    // Background track
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = HCTheme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Fill arc
    if (fill > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,                      // start at top
        2 * pi * fill.clamp(0, 1),   // sweep
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fill != fill || old.color != color;
}
```

---

## 8. Composer

The composer is the most important component. The WebUI's composer has:
- Borderless large input
- Left: attachment + mic icons
- Footer row: profile chip · workspace chip · model chip · context ring
- Right: send button (gold arrow up on dark circle)

```dart
// lib/features/chat/hermes_composer.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/hermes_commander_theme.dart';
import '../../shared/widgets/context_ring.dart';
import 'hermes_voice_button.dart';

class HermesComposer extends ConsumerStatefulWidget {
  final void Function(String text) onSend;
  final int tokenCount;
  final double contextFill;
  final bool isProcessing;
  final VoidCallback? onStop;

  const HermesComposer({
    super.key,
    required this.onSend,
    this.tokenCount = 0,
    this.contextFill = 0,
    this.isProcessing = false,
    this.onStop,
  });

  @override
  ConsumerState<HermesComposer> createState() => _HermesComposerState();
}

class _HermesComposerState extends ConsumerState<HermesComposer> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _hasText = false);
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HCTheme.bgPanel,
        border: Border(top: BorderSide(color: HCTheme.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Text input area ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [

                  // Attachment button
                  IconButton(
                    icon: const Icon(Icons.attach_file, size: 18),
                    color: HCTheme.textMuted,
                    onPressed: _attachFile,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    tooltip: 'Attach file',
                  ),

                  // Voice button
                  const HermesVoiceButton(),

                  // Text field — expand freely
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: 14,
                        color: HCTheme.textPrimary,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Message Hermes...',
                        hintStyle: TextStyle(
                          fontFamily: 'GeistSans',
                          fontSize: 14,
                          color: HCTheme.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        filled: false,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),

                  // Send / Stop button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: widget.isProcessing
                        ? _StopButton(onTap: widget.onStop ?? () {})
                        : _SendButton(
                            enabled: _hasText,
                            onTap: _send,
                          ),
                  ),
                ],
              ),
            ),

            // ── Footer chips row ───────────────────────────────────────
            _ComposerFooter(
              tokenCount: widget.tokenCount,
              contextFill: widget.contextFill,
            ),
          ],
        ),
      ),
    );
  }

  void _attachFile() {/* file picker */}
}

// ── Send button — gold arrow on dark circle ───────────────────────────────────

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? HCTheme.gold : HCTheme.bgActive,
        ),
        child: Icon(
          Icons.arrow_upward,
          size: 16,
          color: enabled ? HCTheme.bgBase : HCTheme.textMuted,
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HCTheme.bgActive,
          border: Border.all(color: HCTheme.border),
        ),
        child: const Icon(Icons.stop, size: 14, color: HCTheme.textSecondary),
      ),
    );
  }
}

// ── Composer footer row ───────────────────────────────────────────────────────
// Matches WebUI: profile · workspace · model · context ring

class _ComposerFooter extends ConsumerWidget {
  final int tokenCount;
  final double contextFill;
  const _ComposerFooter({required this.tokenCount, required this.contextFill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read active profile, workspace, model from providers
    final profile   = 'default';            // ref.watch(activeProfileProvider)
    final workspace = 'Home';               // ref.watch(activeWorkspaceProvider)
    final model     = 'Claude Sonnet 4.6'; // ref.watch(activeModelProvider)

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          // Profile chip
          _FooterChip(
            icon: Icons.person_outline,
            label: profile,
            onTap: _openProfilePicker,
          ),
          const SizedBox(width: 6),

          // Workspace chip
          _FooterChip(
            icon: Icons.folder_outlined,
            label: workspace,
            onTap: _openWorkspacePicker,
          ),
          const SizedBox(width: 6),

          // Model chip
          _FooterChip(
            icon: Icons.auto_awesome_outlined,
            label: _shortModel(model),
            onTap: _openModelPicker,
          ),

          const Spacer(),

          // Context ring
          if (tokenCount > 0)
            ContextRing(
              fill: contextFill,
              tokenCount: tokenCount,
              size: 28,
            ),
        ],
      ),
    );
  }

  String _shortModel(String m) {
    // "Claude Sonnet 4.6" → "Sonnet 4.6"
    return m.replaceFirst('Claude ', '').replaceFirst('GPT-', '');
  }

  void _openProfilePicker() {}
  void _openWorkspacePicker() {}
  void _openModelPicker() {}
}

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HCTheme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: HCTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 11,
              color: HCTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.keyboard_arrow_down,
              size: 12, color: HCTheme.textMuted),
        ]),
      ),
    );
  }
}
```

---

## 9. Update Banner

Exact match to the WebUI amber update notification:

```dart
// lib/shared/widgets/update_banner.dart

class HermesUpdateBanner extends StatelessWidget {
  final String webUiVersion;
  final String agentVersion;
  final VoidCallback onUpdateNow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HCTheme.goldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.goldMuted),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_upward, size: 14, color: HCTheme.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebUI: $webUiVersion updates · Agent: $agentVersion update available',
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 12,
                    color: HCTheme.gold,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  GestureDetector(
                    onTap: () {/* open WebUI changelog */},
                    child: const Text('What\'s new: WebUI',
                        style: TextStyle(
                            fontSize: 11,
                            color: HCTheme.textLink,
                            decoration: TextDecoration.underline)),
                  ),
                  const Text(' · ',
                      style: TextStyle(fontSize: 11, color: HCTheme.textMuted)),
                  GestureDetector(
                    onTap: () {/* open Agent changelog */},
                    child: const Text('Agent',
                        style: TextStyle(
                            fontSize: 11,
                            color: HCTheme.textLink,
                            decoration: TextDecoration.underline)),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BannerButton(label: 'Later', onTap: onDismiss, outlined: true),
          const SizedBox(width: 6),
          _BannerButton(label: 'Update Now', onTap: onUpdateNow),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  const _BannerButton({required this.label, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : HCTheme.gold,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: HCTheme.gold),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeistSans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: outlined ? HCTheme.gold : HCTheme.bgBase,
          ),
        ),
      ),
    );
  }
}
```

---

## 10. Slash Command Autocomplete

Matching the WebUI's `/` dropdown — key panel from the WebUI:

```dart
// lib/features/chat/slash_command_overlay.dart

class SlashCommandOverlay extends StatelessWidget {
  final String query;
  final List<CommandEntry> commands;
  final int selectedIndex;
  final void Function(CommandEntry) onSelect;

  @override
  Widget build(BuildContext context) {
    if (commands.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: HCTheme.bgPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: commands.length,
        shrinkWrap: true,
        itemBuilder: (_, i) {
          final cmd = commands[i];
          final isSelected = i == selectedIndex;
          return Container(
            color: isSelected ? HCTheme.bgActive : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: HCTheme.bgSurface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: HCTheme.border),
                ),
                child: Center(
                  child: Text(
                    cmd.trigger.substring(0, 2),
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 10,
                      color: HCTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cmd.trigger,
                        style: const TextStyle(
                            fontFamily: 'GeistMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: HCTheme.textPrimary)),
                    Text(cmd.description,
                        style: const TextStyle(
                            fontSize: 11,
                            color: HCTheme.textSecondary)),
                  ],
                ),
              ),
              if (isSelected)
                const Text('↵',
                    style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontSize: 11,
                        color: HCTheme.textMuted)),
            ]),
          );
        },
      ),
    );
  }
}
```

---

## 11. Files Changed / New Files

### New files
```
lib/app/hermes_commander_theme.dart    ← Complete HCTheme colour system
lib/shared/widgets/hermes_avatar.dart  ← HermesAvatar + UserAvatar
lib/shared/widgets/context_ring.dart   ← Circular token usage ring
lib/shared/widgets/update_banner.dart  ← Amber update notification
lib/features/chat/hermes_empty_state.dart ← WebUI empty state replica
lib/features/chat/hermes_message_row.dart ← Full-width message layout
lib/features/chat/hermes_composer.dart    ← Footer chips + context ring
lib/features/chat/slash_command_overlay.dart ← /command autocomplete
assets/fonts/Geist-*.ttf              ← Geist Sans + Mono
assets/images/hermes_caduceus.png     ← Gold caduceus SVG rendered as PNG
```

### Changed files
| File | Change |
|---|---|
| `lib/app/theme.dart` | Replace `PocketClawTheme` with `HCTheme` as the active theme |
| `lib/features/chat/chat_screen.dart` | Swap `ChatBubble` → `HermesMessageRow`, add `HermesEmptyState`, new AppBar |
| `lib/features/chat/chat_bubble.dart` | Kept for ClawCommander branch; not used in HC |
| `pubspec.yaml` | Add Geist font family |

---

## 12. Implementation Order

| Step | Task | Time |
|---|---|---|
| 1 | Download Geist fonts, add to pubspec + assets | 20 min |
| 2 | Create `hermes_commander_theme.dart` | 1 hour |
| 3 | Create `hermes_avatar.dart` + caduceus asset | 45 min |
| 4 | Replace AppBar in chat screen | 30 min |
| 5 | Build `HermesEmptyState` | 45 min |
| 6 | Build `HermesMessageRow` — full-width no-bubble layout | 1.5 hours |
| 7 | Build `HermesComposer` with footer chips | 2 hours |
| 8 | Build `ContextRing` | 45 min |
| 9 | Update composer to show context ring | 30 min |
| 10 | Build `SlashCommandOverlay` | 1 hour |
| 11 | Build `UpdateBanner` | 30 min |
| 12 | Build session drawer (grouping + footer chips) | 1.5 hours |
| 13 | Wire bottom nav with gold active indicator | 30 min |
| 14 | End-to-end visual review on physical device | 30 min |

**Total: ~5–6 days**

---

*CARMEN PTY LTD — Hermes Commander Design System Spec v1.0*  
*Visual reference: nesquena/hermes-webui live screenshots — 2026-05-14*
