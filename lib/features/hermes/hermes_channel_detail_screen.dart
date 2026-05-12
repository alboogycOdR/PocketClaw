/// Edit one channel's settings — renders the right widget per field
/// type (bool toggle, CSV chip editor, text field, raw-YAML map
/// editor). Writes back to `~/.hermes/config.yaml` via SSH using
/// `yaml_edit` so comments and unrelated keys are untouched.
///
/// Bot tokens are NEVER edited from here — they live in
/// `~/.hermes/.env` and the user manages them with their preferred
/// secret manager.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yaml/yaml.dart';

import '../../app/theme.dart';
import '../../core/hermes/models/hermes_channel.dart';
import '../../data/providers/channels_providers.dart';
import '../../data/providers/hermes_data_providers.dart';

class HermesChannelDetailScreen extends ConsumerStatefulWidget {
  final HermesChannelKind kind;
  const HermesChannelDetailScreen({super.key, required this.kind});

  @override
  ConsumerState<HermesChannelDetailScreen> createState() =>
      _HermesChannelDetailScreenState();
}

class _HermesChannelDetailScreenState
    extends ConsumerState<HermesChannelDetailScreen> {
  late Map<String, dynamic> _draft;
  Map<String, dynamic> _initial = const {};
  bool _hydrated = false;
  bool _saving = false;

  bool get _dirty => !_mapsEqual(_draft, _initial);

  Future<void> _hydrate() async {
    final bundle = await ref.read(hermesChannelsProvider.future);
    final ch = bundle.byKind(widget.kind);
    if (!mounted) return;
    setState(() {
      _initial = Map<String, dynamic>.from(ch?.settings ?? const {});
      _draft = Map<String, dynamic>.from(_initial);
      _hydrated = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final svc = await ref.read(hermesDataServiceProvider.future);
      if (svc == null) throw 'SSH not configured';
      await svc.saveChannelSettings(widget.kind, _draft);
      _initial = Map<String, dynamic>.from(_draft);
      ref.invalidate(hermesChannelsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${widget.kind.displayName} settings saved')),
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

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hydrated) _hydrate();
      });
      return Scaffold(
        appBar: AppBar(title: Text(widget.kind.displayName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final keys = _draft.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.displayName),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _draft =
                      Map<String, dynamic>.from(_initial)),
              child: const Text('Revert'),
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 20),
            onPressed: (_saving || !_dirty) ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: PocketClawTheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 16, color: PocketClawTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bot token lives in ~/.hermes/.env and is not '
                      'editable from the app. Update it on the server '
                      'with your preferred editor.',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        height: 1.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (keys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No settings under this channel yet.\n'
                  'Add fields server-side or edit raw YAML below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            )
          else
            for (final key in keys)
              _FieldEditor(
                fieldKey: key,
                value: _draft[key],
                onChanged: (v) => setState(() => _draft[key] = v),
              ),
        ],
      ),
    );
  }

  bool _mapsEqual(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
      final av = a[k];
      final bv = b[k];
      if (av is Map && bv is Map) {
        if (!_mapsEqual(av, bv)) return false;
      } else if (av != bv) {
        return false;
      }
    }
    return true;
  }
}

class _FieldEditor extends StatelessWidget {
  final String fieldKey;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _FieldEditor({
    required this.fieldKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final type = HermesChannelConfig.inferType(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldKey,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PocketClawTheme.electricTeal,
            ),
          ),
          const SizedBox(height: 4),
          switch (type) {
            HermesChannelFieldType.bool_ => _BoolField(
                value: value as bool? ?? false,
                onChanged: onChanged,
              ),
            HermesChannelFieldType.map => _MapField(
                value: (value as Map?)?.cast<String, dynamic>() ?? const {},
                onChanged: onChanged,
              ),
            HermesChannelFieldType.csv ||
            HermesChannelFieldType.text =>
              _TextField(
                value: value?.toString() ?? '',
                onChanged: onChanged,
              ),
          },
        ],
      ),
    );
  }
}

class _BoolField extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BoolField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Text(
          value ? 'enabled' : 'disabled',
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TextField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctl = TextEditingController(text: value);
    ctl.selection = TextSelection.collapsed(offset: ctl.text.length);
    return TextField(
      controller: ctl,
      style: GoogleFonts.jetBrainsMono(fontSize: 13),
      onChanged: onChanged,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        hintText: 'Empty',
      ),
    );
  }
}

class _MapField extends StatefulWidget {
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const _MapField({required this.value, required this.onChanged});

  @override
  State<_MapField> createState() => _MapFieldState();
}

class _MapFieldState extends State<_MapField> {
  late final TextEditingController _ctl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: _encode(widget.value));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _encode(Map<String, dynamic> m) {
    if (m.isEmpty) return '{}';
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  void _onChanged(String raw) {
    setState(() {
      try {
        if (raw.trim().isEmpty || raw.trim() == '{}') {
          widget.onChanged(<String, dynamic>{});
          _error = null;
          return;
        }
        // Accept either JSON or inline YAML — yaml package handles both.
        final parsed = loadYaml(raw);
        if (parsed is! Map) {
          _error = 'Top-level must be an object/map.';
          return;
        }
        final m = parsed.map((k, v) => MapEntry('$k', v));
        widget.onChanged(Map<String, dynamic>.from(m));
        _error = null;
      } catch (e) {
        _error = 'Invalid: $e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctl,
          maxLines: null,
          minLines: 3,
          onChanged: _onChanged,
          style: GoogleFonts.jetBrainsMono(fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            hintText: '{}',
            helperText: 'JSON or inline YAML, top-level must be a map',
            helperMaxLines: 2,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 11,
              color: PocketClawTheme.lobsterRed,
            ),
          ),
        ],
      ],
    );
  }
}
