/// Bottom sheet that runs the indexing pipeline. Opens a file picker
/// for the source doc, then streams progress through the four stages
/// (extract → chunk → index → embed). Pops with `true` on success.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/rag/rag_service.dart';

class KnowledgeBaseIndexSheet extends ConsumerStatefulWidget {
  final String projectId;
  const KnowledgeBaseIndexSheet({super.key, required this.projectId});

  @override
  ConsumerState<KnowledgeBaseIndexSheet> createState() =>
      _KnowledgeBaseIndexSheetState();
}

class _KnowledgeBaseIndexSheetState
    extends ConsumerState<KnowledgeBaseIndexSheet> {
  bool _picking = false;
  bool _indexing = false;
  String? _error;
  RagIndexProgress? _progress;

  Future<void> _pickAndIndex() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md', 'markdown', 'log', 'csv'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = result.files.first;
      if (file.path == null) {
        setState(() => _picking = false);
        return;
      }
      setState(() {
        _picking = false;
        _indexing = true;
      });
      await ragService.indexDocument(
        projectId: widget.projectId,
        filePath: file.path!,
        fileName: file.name,
        fileSize: file.size,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _indexing = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add document',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a .txt / .md / .log / .csv file. PDF support comes when '
            'pdfx is added.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          if (!_indexing && _error == null)
            FilledButton.icon(
              icon: _picking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined, size: 16),
              label: Text(_picking ? 'Opening picker…' : 'Pick a file'),
              onPressed: _picking ? null : _pickAndIndex,
            ),
          if (_indexing) ...[
            Text(
              _progress?.message ?? 'Working…',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress?.fraction),
            const SizedBox(height: 8),
            Text(
              _progress == null
                  ? ''
                  : 'Stage: ${_progress!.stage.name}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PocketClawTheme.lobsterRed.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: _pickAndIndex,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
