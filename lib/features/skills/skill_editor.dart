/// Create/edit SKILL.md with form fields for frontmatter and markdown body
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/core_providers.dart';

class SkillEditor extends ConsumerStatefulWidget {
  final String? existingSkillName;

  const SkillEditor({super.key, this.existingSkillName});

  @override
  ConsumerState<SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends ConsumerState<SkillEditor> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emojiController = TextEditingController();
  final _bodyController = TextEditingController();
  final _envController = TextEditingController();
  final _binController = TextEditingController();

  String _runtime = 'server';
  List<String> _requiredEnv = [];
  List<String> _requiredBins = [];
  List<String> _requiredApis = [];
  bool _saving = false;

  static const _runtimes = ['local', 'server', 'bridge'];
  static const _deviceApis = [
    'camera',
    'calendar',
    'location',
    'notifications',
    'tts',
    'contacts',
    'file_picker',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingSkillName != null) {
      _loadExistingSkill();
    }
  }

  void _loadExistingSkill() {
    final registry = ref.read(skillRegistryProvider);
    final skill = registry.getSkill(widget.existingSkillName!);
    if (skill != null) {
      _nameController.text = skill.name;
      _descriptionController.text = skill.description;
      _emojiController.text = skill.emoji ?? '';
      _runtime = skill.runtime;
      _requiredApis = List.from(skill.requiredDeviceApis);
      _requiredEnv = List.from(skill.requiredEnv);
      _requiredBins = List.from(skill.requiredBins);
      _bodyController.text = skill.cachedBody ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emojiController.dispose();
    _bodyController.dispose();
    _envController.dispose();
    _binController.dispose();
    super.dispose();
  }

  void _addEnv() {
    final val = _envController.text.trim();
    if (val.isNotEmpty && !_requiredEnv.contains(val)) {
      setState(() {
        _requiredEnv.add(val);
        _envController.clear();
      });
    }
  }

  void _addBin() {
    final val = _binController.text.trim();
    if (val.isNotEmpty && !_requiredBins.contains(val)) {
      setState(() {
        _requiredBins.add(val);
        _binController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skill name is required')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final registry = ref.read(skillRegistryProvider);
      final userDir = await registry.getUserSkillsDir();

      // Build SKILL.md content
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final emoji = _emojiController.text.trim();
      final body = _bodyController.text;

      final buffer = StringBuffer('---\n');
      buffer.writeln('name: "$name"');
      buffer.writeln('description: "$description"');
      if (emoji.isNotEmpty) buffer.writeln('emoji: "$emoji"');
      buffer.writeln('runtime: "$_runtime"');

      if (_requiredApis.isNotEmpty ||
          _requiredEnv.isNotEmpty ||
          _requiredBins.isNotEmpty) {
        buffer.writeln('metadata:');
        buffer.writeln('  pocketclaw:');
        buffer.writeln('    runtime: "$_runtime"');
        buffer.writeln('    requires:');
        if (_requiredApis.isNotEmpty) {
          buffer.writeln(
              '      device_apis: [${_requiredApis.map((a) => '"$a"').join(', ')}]');
        }
        if (_requiredEnv.isNotEmpty) {
          buffer.writeln(
              '      env: [${_requiredEnv.map((e) => '"$e"').join(', ')}]');
        }
        if (_requiredBins.isNotEmpty) {
          buffer.writeln(
              '      bins: [${_requiredBins.map((b) => '"$b"').join(', ')}]');
        }
      }

      buffer.writeln('---\n');
      buffer.write(body);

      // Write the file
      final safeName = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'-+$'), '');
      final file = File('${userDir.path}/$safeName.md');
      await file.writeAsString(buffer.toString());

      // Reload skills to pick up the new/updated skill
      ref.invalidate(skillsLoadedProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skill "$name" saved')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save skill: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingSkillName != null ? 'Edit Skill' : 'New Skill',
        ),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name & Emoji row
          Row(
            children: [
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _emojiController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                  decoration: const InputDecoration(
                    hintText: '🔧',
                    hintStyle: TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: GoogleFonts.jetBrainsMono(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Skill Name',
                    hintText: 'my-skill',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What does this skill do?',
            ),
          ),

          const SizedBox(height: 16),

          // Runtime selector
          Text(
            'Runtime',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _runtimes.map((r) {
              final selected = r == _runtime;
              final color = switch (r) {
                'local' => PocketClawTheme.electricTeal,
                'server' => PocketClawTheme.lobsterRed,
                'bridge' => PocketClawTheme.warning,
                _ => Colors.white54,
              };
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: r != _runtimes.last ? 8 : 0,
                  ),
                  child: ChoiceChip(
                    label: Text(r),
                    selected: selected,
                    selectedColor: color.withAlpha(40),
                    onSelected: (_) => setState(() => _runtime = r),
                    labelStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: selected ? color : Colors.white54,
                    ),
                    showCheckmark: false,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Device APIs
          Text(
            'Required Device APIs',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _deviceApis.map((api) {
              final selected = _requiredApis.contains(api);
              return FilterChip(
                label: Text(api),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _requiredApis.add(api);
                    } else {
                      _requiredApis.remove(api);
                    }
                  });
                },
                selectedColor: PocketClawTheme.electricTeal.withAlpha(40),
                checkmarkColor: PocketClawTheme.electricTeal,
                labelStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: selected
                      ? PocketClawTheme.electricTeal
                      : Colors.white54,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Environment variables
          _TagInput(
            label: 'Required Environment Variables',
            hint: 'API_KEY',
            controller: _envController,
            items: _requiredEnv,
            onAdd: _addEnv,
            onRemove: (item) => setState(() => _requiredEnv.remove(item)),
          ),

          const SizedBox(height: 16),

          // Required binaries
          _TagInput(
            label: 'Required Binaries',
            hint: 'ffmpeg',
            controller: _binController,
            items: _requiredBins,
            onAdd: _addBin,
            onRemove: (item) => setState(() => _requiredBins.remove(item)),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Markdown body
          Text(
            'Skill Instructions (Markdown)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: null,
            minLines: 15,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              height: 1.6,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: '# My Skill\n\nDescribe the skill behavior...',
              hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: Colors.white24,
              ),
              filled: true,
              fillColor: PocketClawTheme.surfaceDim,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TagInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _TagInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white70,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: GoogleFonts.jetBrainsMono(fontSize: 13),
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, size: 24),
              color: PocketClawTheme.electricTeal,
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(
                      item,
                      style: GoogleFonts.jetBrainsMono(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => onRemove(item),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
