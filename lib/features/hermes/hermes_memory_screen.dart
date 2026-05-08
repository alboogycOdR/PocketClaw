/// Hermes memory editor — toggles between MEMORY.md, USER.md, SOUL.md
/// with character limits per Scarf's IOSMemoryViewModel.
/// SPEC-MultiTransport §11.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/hermes_paths.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';

enum _MemoryKind { memory, user, soul }

class HermesMemoryTab extends ConsumerStatefulWidget {
  const HermesMemoryTab({super.key});

  @override
  ConsumerState<HermesMemoryTab> createState() => _HermesMemoryTabState();
}

class _HermesMemoryTabState extends ConsumerState<HermesMemoryTab> {
  _MemoryKind _kind = _MemoryKind.memory;
  final _controller = TextEditingController();
  String _initialContent = '';
  bool _hydrated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _limit => switch (_kind) {
        _MemoryKind.memory => HermesMemoryLimits.memoryMd,
        _MemoryKind.user => HermesMemoryLimits.userMd,
        _MemoryKind.soul => HermesMemoryLimits.soulMd,
      };

  bool get _dirty => _controller.text != _initialContent;

  Future<void> _hydrate() async {
    final svc = await ref.read(hermesDataServiceProvider.future);
    if (svc == null) {
      setState(() => _hydrated = true);
      return;
    }
    String content;
    try {
      content = switch (_kind) {
        _MemoryKind.memory => await svc.readMemory(),
        _MemoryKind.user => await svc.readUserProfile(),
        _MemoryKind.soul => await svc.readSoul(),
      };
    } catch (_) {
      content = '';
    }
    if (!mounted) return;
    setState(() {
      _controller.text = content;
      _initialContent = content;
      _hydrated = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = await ref.read(hermesDataServiceProvider.future);
      if (svc == null) return;
      switch (_kind) {
        case _MemoryKind.memory:
          await svc.writeMemory(_controller.text);
          break;
        case _MemoryKind.user:
          await svc.writeUserProfile(_controller.text);
          break;
        case _MemoryKind.soul:
          await svc.writeSoul(_controller.text);
          break;
      }
      _initialContent = _controller.text;
      // Invalidate any caches.
      switch (_kind) {
        case _MemoryKind.memory:
          ref.invalidate(hermesMemoryProvider);
          break;
        case _MemoryKind.user:
          ref.invalidate(hermesUserProfileProvider);
          break;
        case _MemoryKind.soul:
          ref.invalidate(hermesSoulProvider);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _switchKind(_MemoryKind kind) async {
    if (kind == _kind) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text(
            'Switching files will lose your current edits.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PocketClawTheme.lobsterRed,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    setState(() {
      _kind = kind;
      _hydrated = false;
      _initialContent = '';
      _controller.text = '';
    });
    await _hydrate();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      // Lazy hydrate on first build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hydrated) _hydrate();
      });
      return const Center(child: CircularProgressIndicator());
    }

    final length = _controller.text.length;
    final overLimit = length > _limit;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<_MemoryKind>(
            segments: const [
              ButtonSegment(
                value: _MemoryKind.memory,
                icon: Icon(Icons.note_alt_outlined, size: 16),
                label: Text('MEMORY'),
              ),
              ButtonSegment(
                value: _MemoryKind.user,
                icon: Icon(Icons.person_outline, size: 16),
                label: Text('USER'),
              ),
              ButtonSegment(
                value: _MemoryKind.soul,
                icon: Icon(Icons.psychology_outlined, size: 16),
                label: Text('SOUL'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => _switchKind(s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text(
                _pathFor(_kind),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              Text(
                '$length / $_limit',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: overLimit
                      ? PocketClawTheme.lobsterRed
                      : Colors.white54,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.jetBrainsMono(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_dirty)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _controller.text = _initialContent);
                        },
                  child: const Text('Revert'),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_saving || !_dirty) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _pathFor(_MemoryKind k) => switch (k) {
        _MemoryKind.memory => kHermesPaths.memoryMD,
        _MemoryKind.user => kHermesPaths.userMD,
        _MemoryKind.soul => kHermesPaths.soulMD,
      };
}

// Minimal connectivity check used by the management screen container —
// returns true once the SSH client is configured. Re-exposed here so we
// don't import private providers into the container.
final hermesConfiguredProvider = Provider<bool>((ref) {
  final clientAsync = ref.watch(hermesDataServiceProvider);
  return clientAsync.maybeWhen(data: (svc) => svc != null, orElse: () => false);
});

// Empty-state placeholder for any tab when the SSH client isn't set up.
class HermesNotConfigured extends StatelessWidget {
  const HermesNotConfigured({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.terminal,
      message:
          'Configure SSH in Settings → Server SSH to use Hermes management.',
    );
  }
}
