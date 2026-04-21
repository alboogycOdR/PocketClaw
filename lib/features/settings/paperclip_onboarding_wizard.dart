/// Paperclip onboarding wizard — invite token → join request → claim API key.
///
/// Replaces the manual "create agent in dashboard, copy key, paste here"
/// dance for first-time setup. The user only needs to paste a single invite
/// token; the app handles accept/claim and persists the resulting API key.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_onboarding_provider.dart';

class PaperclipOnboardingWizard extends ConsumerStatefulWidget {
  const PaperclipOnboardingWizard({super.key});

  @override
  ConsumerState<PaperclipOnboardingWizard> createState() =>
      _PaperclipOnboardingWizardState();
}

class _PaperclipOnboardingWizardState
    extends ConsumerState<PaperclipOnboardingWizard> {
  final _tokenCtl = TextEditingController();
  final _baseUrlCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _baseUrlCtl.text = ref.read(paperclipBaseUrlProvider);
  }

  @override
  void dispose() {
    _tokenCtl.dispose();
    _baseUrlCtl.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    final url = _baseUrlCtl.text.trim();
    if (url.isEmpty) return;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('paperclip_base_url', url);
    ref.read(paperclipBaseUrlProvider.notifier).state = url;
  }

  Future<void> _accept() async {
    await _saveBaseUrl();
    final token = _tokenCtl.text.trim();
    if (token.isEmpty) return;
    await ref
        .read(paperclipOnboardingProvider.notifier)
        .acceptInvite(_extractToken(token));
  }

  /// The user might paste a full URL like `http://host:3100/accept?token=abc`
  /// or a prompt blob that includes the token. Extract the raw token if
  /// we can recognise a URL; otherwise treat input as the token itself.
  String _extractToken(String raw) {
    try {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        final q = uri.queryParameters['token'];
        if (q != null && q.isNotEmpty) return q;
        // /invites/<token>/... path form
        final segs = uri.pathSegments;
        final idx = segs.indexOf('invites');
        if (idx != -1 && idx + 1 < segs.length) return segs[idx + 1];
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paperclipOnboardingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Paperclip Onboarding')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),

          // Base URL
          Text(
            'Paperclip base URL',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrlCtl,
            enabled: !state.isWorking && state.phase != OnboardingPhase.success,
            decoration: const InputDecoration(
              hintText: 'http://100.x.x.x:3100',
              border: OutlineInputBorder(),
              helperText: '/api suffix added automatically',
            ),
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Body switches based on phase
          if (state.phase == OnboardingPhase.success)
            _SuccessCard(apiKey: state.apiKey!, agentId: state.agentId)
          else if (state.phase == OnboardingPhase.awaitingApproval ||
              state.phase == OnboardingPhase.claiming)
            _WaitingCard(state: state)
          else ...[
            Text(
              'Invite token',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenCtl,
              enabled: !state.isWorking,
              decoration: const InputDecoration(
                hintText: 'Paste invite token or URL',
                border: OutlineInputBorder(),
              ),
              style: GoogleFonts.jetBrainsMono(fontSize: 13),
              maxLines: 2,
            ),
            if (state.phase == OnboardingPhase.error) ...[
              const SizedBox(height: 12),
              _ErrorCard(
                message: state.errorMessage ?? 'Unknown error',
                onDismiss: () => ref
                    .read(paperclipOnboardingProvider.notifier)
                    .dismissError(),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.isWorking ? null : _accept,
              icon: state.phase == OnboardingPhase.accepting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Submit invite'),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: PocketClawTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.outbox_outlined,
                    size: 16, color: PocketClawTheme.electricTeal),
                const SizedBox(width: 8),
                Text(
                  'One-click onboarding',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PocketClawTheme.electricTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '1. In the Paperclip dashboard, create an invite for '
              '"Pocket Claw Mobile" (give it a board role so it can read '
              'company data).\n'
              '2. Copy the invite token and paste below.\n'
              '3. Submit. The app will wait for a board member to approve, '
              'then auto-claim the API key.\n\n'
              'No manual key copying.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingCard extends ConsumerWidget {
  final PaperclipOnboardingState state;

  const _WaitingCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checking = state.phase == OnboardingPhase.claiming;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_empty,
                        color: PocketClawTheme.electricTeal, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for board approval',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PocketClawTheme.electricTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'A board member needs to approve your join request in the '
                  'Paperclip dashboard. The app checks every 15 seconds.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _LabelledRow(
                    label: 'Request ID', value: state.requestId ?? '?'),
                if (state.lastCheckAt != null) ...[
                  const SizedBox(height: 6),
                  _LabelledRow(
                    label: 'Last check',
                    value: state.lastCheckAt!
                        .toLocal()
                        .toString()
                        .split('.')
                        .first,
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PocketClawTheme.lobsterRed.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: PocketClawTheme.lobsterRed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: checking
                    ? null
                    : () => ref
                        .read(paperclipOnboardingProvider.notifier)
                        .checkApproval(),
                icon: checking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: const Text('Check now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: checking
                    ? null
                    : () => ref
                        .read(paperclipOnboardingProvider.notifier)
                        .cancel(),
                icon: Icon(Icons.close,
                    size: 16, color: PocketClawTheme.lobsterRed),
                label: Text(
                  'Cancel',
                  style: TextStyle(color: PocketClawTheme.lobsterRed),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final String apiKey;
  final String? agentId;

  const _SuccessCard({required this.apiKey, this.agentId});

  @override
  Widget build(BuildContext context) {
    final preview = apiKey.length > 12
        ? '${apiKey.substring(0, 8)}…${apiKey.substring(apiKey.length - 4)}'
        : apiKey;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF1B3B1F),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Onboarding complete',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'API key stored securely. Company tab should now populate.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _LabelledRow(label: 'API key', value: preview),
            if (agentId != null) ...[
              const SizedBox(height: 6),
              _LabelledRow(label: 'Agent ID', value: agentId!),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorCard({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PocketClawTheme.lobsterRed.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: PocketClawTheme.lobsterRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: PocketClawTheme.lobsterRed,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _LabelledRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabelledRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 14),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }
}
