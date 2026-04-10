/// Wraps camera / image_picker for photo capture + on-device vision/OCR
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image_picker/image_picker.dart';

import '../local_agent/llm_engine.dart';
import '../local_agent/tool_executor.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();
  LlmEngine? _llmEngine;

  /// Inject the LLM engine for vision processing.
  void setLlmEngine(LlmEngine engine) {
    _llmEngine = engine;
  }

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

  /// Process an image with on-device vision model for OCR/analysis.
  ///
  /// Uses flutter_gemma's multimodal support (requires a vision-capable model
  /// like Gemma 4 E2B). Returns extracted text or analysis.
  Future<ToolResult> processImageWithVision({
    required String imagePath,
    String prompt = 'Extract all text from this image. If it is a receipt or document, structure the data.',
  }) async {
    if (_llmEngine == null || !_llmEngine!.isLoaded) {
      return ToolResult.error(
        'Vision model not loaded. Download a vision-capable model (Gemma 4 E2B) in Settings.',
      );
    }

    final config = _llmEngine!.config;
    if (config == null || !config.capabilities.contains(ModelCap.vision)) {
      return ToolResult.error(
        'Current model (${config?.displayName ?? "none"}) does not support vision. '
        'Switch to Gemma 4 E2B for OCR/image analysis.',
      );
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return ToolResult.error('Image file not found: $imagePath');
      }

      final imageBytes = await file.readAsBytes();
      final model = await FlutterGemma.getActiveModel(
        supportImage: true,
        maxTokens: 1024,
      );

      final chat = await model.createChat();
      await chat.addQuery(Message.withImage(
        text: prompt,
        imageBytes: imageBytes,
        isUser: true,
      ));

      final buffer = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      final result = buffer.toString().trim();
      if (result.isEmpty) {
        return ToolResult.ok('No text could be extracted from the image.');
      }

      return ToolResult.ok(
        result,
        data: {
          'imagePath': imagePath,
          'extractedText': result,
          'method': 'on-device-vision',
        },
      );
    } catch (e) {
      debugPrint('CameraService: vision processing failed: $e');
      return ToolResult.error('Vision processing failed: $e');
    }
  }
}
