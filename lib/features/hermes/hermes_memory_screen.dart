/// Hermes memory editor.
///
/// MEMORY.md gets the §-delimited **entries view** — a list of cards
/// with timestamp headers, edit and delete affordances, and an "Add
/// entry" button. There's a "Raw" toggle for advanced editing of the
/// underlying file (in case the parser misreads or the user wants to
/// fix quoting).
///
/// USER.md and SOUL.md keep the simple textarea editor — they're
/// single documents, not append-only logs.
///
/// SPEC-MultiTransport §11.3 + SPEC-HermesDesktopImprovements §Fix 2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/hermes/hermes_paths.dart';
import '../../core/hermes/models/hermes_memory_entry.dart';
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
  bool _rawMode = false;

  // Raw textarea state — used by USER/SOUL always, MEMORY when raw.
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

  bool get _useEntriesView => _kind == _MemoryKind.memory && !_rawMode;

  Future<void> _hydrateRaw() async {
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

  Future<void> _saveRaw() async {
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
      switch (_kind) {
        case _MemoryKind.memory:
          ref.invalidate(hermesMemoryProvider);
          ref.invalidate(hermesMemoryEntriesProvider);
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
    if (!_useEntriesView && _dirty) {
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
      _rawMode = false;
      _hydrated = false;
      _initialContent = '';
      _controller.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _useEntriesView
        ? _buildEntriesView()
        : _buildRawView();

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
              if (_kind == _MemoryKind.memory)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _rawMode = !_rawMode),
                  icon: Icon(
                    _rawMode ? Icons.list : Icons.code,
                    size: 14,
                  ),
                  label: Text(
                    _rawMode ? 'Entries' : 'Raw',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(50, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  // ── Entries view (MEMORY mode) ────────────────────────────────────

  Widget _buildEntriesView() {
    final entriesAsync = ref.watch(hermesMemoryEntriesProvider);
    return entriesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        message: 'Failed to load entries: $e',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(hermesMemoryEntriesProvider),
      ),
      data: (entries) => Stack(
        children: [
          if (entries.isEmpty)
            const EmptyState(
              icon: Icons.note_alt_outlined,
              message:
                  'No memory entries yet.\nTap + to add the first one.',
            )
          else
            RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(hermesMemoryEntriesProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 84),
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) => _EntryCard(
                  index: i,
                  entry: entries[i],
                  onEdit: () => _editEntry(i, entries[i]),
                  onDelete: () => _deleteEntry(i),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'hermes-memory-add',
              onPressed: _addEntry,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry() async {
    final body = await _showEntrySheet(
      title: 'Add memory entry',
      initial: '',
    );
    if (body == null || body.trim().isEmpty) return;
    final svc = await ref.read(hermesDataServiceProvider.future);
    if (svc == null) return;
    try {
      await svc.addMemoryEntry(body);
      ref.invalidate(hermesMemoryEntriesProvider);
      ref.invalidate(hermesMemoryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add failed: $e')),
        );
      }
    }
  }

  Future<void> _editEntry(int index, HermesMemoryEntry entry) async {
    final body = await _showEntrySheet(
      title: 'Edit entry',
      initial: entry.body,
    );
    if (body == null) return;
    final svc = await ref.read(hermesDataServiceProvider.future);
    if (svc == null) return;
    try {
      await svc.updateMemoryEntry(index, body);
      ref.invalidate(hermesMemoryEntriesProvider);
      ref.invalidate(hermesMemoryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
            'This permanently removes the entry from MEMORY.md.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PocketClawTheme.lobsterRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final svc = await ref.read(hermesDataServiceProvider.future);
    if (svc == null) return;
    try {
      await svc.deleteMemoryEntry(index);
      ref.invalidate(hermesMemoryEntriesProvider);
      ref.invalidate(hermesMemoryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<String?> _showEntrySheet({
    required String title,
    required String initial,
  }) async {
    final ctl = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheet).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              maxLines: 8,
              minLines: 4,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
                hintText: 'What should Hermes remember?',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(sheet, ctl.text),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Raw view (USER, SOUL, or MEMORY-raw) ──────────────────────────

  Widget _buildRawView() {
    if (!_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hydrated) _hydrateRaw();
      });
      return const Center(child: CircularProgressIndicator());
    }

    final length = _controller.text.length;
    final overLimit = length > _limit;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            children: [
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
                onPressed: (_saving || !_dirty) ? null : _saveRaw,
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

class _EntryCard extends StatelessWidget {
  final int index;
  final HermesMemoryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.index,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTimestamp(DateTime ts) {
    final local = ts.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0 && local.day == now.day) {
      return 'Today ${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    size: 12,
                    color: PocketClawTheme.electricTeal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.timestamp != null
                          ? _formatTimestamp(entry.timestamp!)
                          : 'Untimestamped',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: PocketClawTheme.lobsterRed,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.body,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Minimal connectivity check used by the management screen container.
final hermesConfiguredProvider = Provider<bool>((ref) {
  final clientAsync = ref.watch(hermesDataServiceProvider);
  return clientAsync.maybeWhen(
      data: (svc) => svc != null, orElse: () => false);
});

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
