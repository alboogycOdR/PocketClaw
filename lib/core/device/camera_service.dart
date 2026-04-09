/// Wraps camera / image_picker for photo capture
library;

import 'package:image_picker/image_picker.dart';

import '../local_agent/tool_executor.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  /// Captures a photo using the device camera.
  ///
  /// [purpose] is a human-readable string describing why the photo is being
  /// taken (e.g. "save", "analyse", "share"). It is forwarded to the caller
  /// as metadata.
  Future<ToolResult> capture({required String purpose}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) {
        return ToolResult.error('Camera capture cancelled by user.');
      }

      final bytes = await photo.length();
      final sizeKb = (bytes / 1024).toStringAsFixed(1);

      return ToolResult.ok(
        'Photo captured successfully ($sizeKb KB). Path: ${photo.path}',
        data: {
          'path': photo.path,
          'name': photo.name,
          'mimeType': photo.mimeType ?? 'image/jpeg',
          'sizeBytes': bytes,
          'purpose': purpose,
        },
      );
    } catch (e) {
      return ToolResult.error('Camera capture failed: $e');
    }
  }

  /// Picks an image from the gallery instead of taking a new photo.
  Future<ToolResult> pickFromGallery({String purpose = 'select'}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) {
        return ToolResult.error('Image selection cancelled by user.');
      }

      final bytes = await image.length();
      final sizeKb = (bytes / 1024).toStringAsFixed(1);

      return ToolResult.ok(
        'Image selected ($sizeKb KB). Path: ${image.path}',
        data: {
          'path': image.path,
          'name': image.name,
          'mimeType': image.mimeType ?? 'image/jpeg',
          'sizeBytes': bytes,
          'purpose': purpose,
        },
      );
    } catch (e) {
      return ToolResult.error('Image pick failed: $e');
    }
  }
}
