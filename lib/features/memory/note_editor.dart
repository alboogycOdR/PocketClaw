/// Markdown editor for notes with title, folder, tags, and content
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/memory_note.dart';
import '../../data/providers/core_providers.dart';

class NoteEditor extends ConsumerStatefulWidget {
  final MemoryNote? existingNote;

  const NoteEditor({super.key, this.existingNote});

  @override
  ConsumerState<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<NoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  String _selectedFolder = 'general';
  List<String> _tags = [];

  static const _folders = [
    'general',
    'work',
    'personal',
    'projects',
    'research',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingNote?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existingNote?.content ?? '',
    );
    _tagController = TextEditingController();
    _selectedFolder = widget.existingNote?.folder ?? 'general';
    _tags = List.from(widget.existingNote?.tags ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final localMemory = ref.read(localMemoryProvider);
      final result = await localMemory.createNote(
        title: _titleController.text.trim(),
        content: _contentController.text,
        folder: _selectedFolder,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved')),
        );
        Navigator.of(context).pop(true); // return true to signal refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.output)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
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
          widget.existingNote != null ? 'Edit Note' : 'New Note',
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
          // Title
          TextField(
            controller: _titleController,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: 'Note title',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          const Divider(),

          // Folder picker
          Row(
            children: [
              const Icon(Icons.folder_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              const Text(
                'Folder:',
                style: TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedFolder,
                underline: const SizedBox(),
                dropdownColor: PocketClawTheme.surfaceContainer,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: PocketClawTheme.electricTeal,
                ),
                items: _folders
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFolder = val);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tags
          Row(
            children: [
              const Icon(Icons.tag, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ..._tags.map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon:
                              const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            setState(() => _tags.remove(tag));
                          },
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        )),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _tagController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Add tag',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(),
          const SizedBox(height: 8),

          // Content area
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 20,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'Write your note in Markdown...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: PocketClawTheme.surfaceContainerLow,
            ),
          ),
        ],
      ),
    );
  }
}
