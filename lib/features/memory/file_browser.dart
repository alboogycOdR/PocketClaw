/// Expandable tree view for server memory files
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/memory_note.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';

class FileBrowser extends ConsumerWidget {
  final List<MemoryFile> files;

  const FileBrowser({super.key, required this.files});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'No files found',
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        return _FileNode(file: files[index], depth: 0);
      },
    );
  }
}

class _FileNode extends ConsumerStatefulWidget {
  final MemoryFile file;
  final int depth;

  const _FileNode({required this.file, required this.depth});

  @override
  ConsumerState<_FileNode> createState() => _FileNodeState();
}

class _FileNodeState extends ConsumerState<_FileNode> {
  bool _expanded = false;
  List<MemoryFile>? _children;
  bool _loadingChildren = false;

  IconData get _icon {
    if (widget.file.isDirectory) {
      return _expanded ? Icons.folder_open : Icons.folder;
    }
    final name = widget.file.name.toLowerCase();
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    return Icons.insert_drive_file;
  }

  Color get _iconColor {
    if (widget.file.isDirectory) return PocketClawTheme.warning;
    final name = widget.file.name.toLowerCase();
    if (name.endsWith('.md')) return PocketClawTheme.electricTeal;
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (widget.file.isDirectory) {
              setState(() => _expanded = !_expanded);
              if (_expanded && _children == null && !_loadingChildren) {
                _loadChildren();
              }
            } else {
              _showFileContent(context);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0 * widget.depth + 8,
              top: 8,
              bottom: 8,
              right: 8,
            ),
            child: Row(
              children: [
                if (widget.file.isDirectory)
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: Colors.white38,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 4),
                Icon(_icon, size: 18, color: _iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.file.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.file.isDirectory
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ),
                ),
                if (widget.file.modified != null)
                  Text(
                    widget.file.modified!.shortDate,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: Colors.white30,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded && widget.file.isDirectory) ...[
          if (_loadingChildren)
            Padding(
              padding: EdgeInsets.only(left: 16.0 * (widget.depth + 1) + 28),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_children != null && _children!.isEmpty)
            Padding(
              padding: EdgeInsets.only(
                  left: 16.0 * (widget.depth + 1) + 28),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '(empty)',
                  style: TextStyle(fontSize: 11, color: Colors.white24),
                ),
              ),
            )
          else if (_children != null)
            ...(_children!.map((child) =>
                _FileNode(file: child, depth: widget.depth + 1))),
        ],
      ],
    );
  }

  Future<void> _loadChildren() async {
    final rest = ref.read(gatewayRestClientProvider);
    if (rest == null) return;

    setState(() => _loadingChildren = true);
    try {
      final children = await rest.getMemoryFiles(path: widget.file.path);
      if (!mounted) return;
      setState(() {
        _children = children;
        _loadingChildren = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _children = [];
        _loadingChildren = false;
      });
    }
  }

  void _showFileContent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PocketClawTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(_icon, size: 18, color: _iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.file.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _FileContentView(
                    filePath: widget.file.path,
                    scrollController: scrollController,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Loads file content from the gateway and renders as Markdown.
class _FileContentView extends ConsumerStatefulWidget {
  final String filePath;
  final ScrollController scrollController;

  const _FileContentView({
    required this.filePath,
    required this.scrollController,
  });

  @override
  ConsumerState<_FileContentView> createState() => _FileContentViewState();
}

class _FileContentViewState extends ConsumerState<_FileContentView> {
  String? _content;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final rest = ref.read(gatewayRestClientProvider);
    if (rest == null) {
      setState(() {
        _loading = false;
        _error = 'Gateway not configured';
      });
      return;
    }

    try {
      final content = await rest.getMemoryFileContent(widget.filePath);
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load file: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return Markdown(
      controller: widget.scrollController,
      data: _content ?? '',
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(color: Colors.white70, height: 1.6),
        h1: GoogleFonts.jetBrainsMono(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        h2: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        code: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: PocketClawTheme.electricTeal,
          backgroundColor: PocketClawTheme.surfaceContainerLow,
        ),
        codeblockDecoration: BoxDecoration(
          color: PocketClawTheme.surfaceDim,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
