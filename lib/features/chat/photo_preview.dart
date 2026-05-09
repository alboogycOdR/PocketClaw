/// Inline photo preview in chat with tap-to-expand
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class PhotoPreview extends StatelessWidget {
  final String imageUrl;

  const PhotoPreview({super.key, required this.imageUrl});

  bool get _isLocalFile =>
      imageUrl.startsWith('/') || imageUrl.startsWith('file://');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullScreen(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 260),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3A2F26).withAlpha(120),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              _buildImage(),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_isLocalFile) {
      final path = imageUrl.startsWith('file://')
          ? imageUrl.substring(7)
          : imageUrl;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: 260,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: 260,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: 260,
          height: 160,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 260,
      height: 160,
      color: PocketClawTheme.surfaceContainer,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.white24, size: 40),
          SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenPhoto(imageUrl: imageUrl),
      ),
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  final String imageUrl;

  const _FullScreenPhoto({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isLocal =
        imageUrl.startsWith('/') || imageUrl.startsWith('file://');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: isLocal
              ? Image.file(
                  File(imageUrl.startsWith('file://')
                      ? imageUrl.substring(7)
                      : imageUrl),
                  fit: BoxFit.contain,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}
