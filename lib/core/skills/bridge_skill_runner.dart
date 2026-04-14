/// Bridge-runtime skill executor.
///
/// A bridge skill runs in two phases:
///   1. Device capture — photo, gallery pick, calendar query etc., performed
///      locally via the device services.
///   2. Server process — the capture payload is forwarded to the OpenClaw
///      gateway as a `skill.run` task; the gateway dispatches it to a
///      server-side agent that returns a structured result.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/models/skill.dart';
import '../device/calendar_service.dart';
import '../device/camera_service.dart';
import '../gateway/gateway_client.dart';
import '../local_agent/tool_executor.dart';

class BridgeSkillResult {
  final bool ok;
  final String message;
  final Map<String, dynamic>? data;

  const BridgeSkillResult.ok(this.message, {this.data}) : ok = true;
  const BridgeSkillResult.error(this.message)
      : ok = false,
        data = null;
}

class BridgeSkillRunner {
  final CameraService _camera;
  final CalendarService _calendar;
  final GatewayClient? _gateway;

  BridgeSkillRunner({
    required CameraService camera,
    required CalendarService calendar,
    required GatewayClient? gateway,
  })  : _camera = camera,
        _calendar = calendar,
        _gateway = gateway;

  /// Execute [skill] end-to-end. If the gateway is unreachable the capture
  /// payload is still returned so callers can queue or display it.
  Future<BridgeSkillResult> run(Skill skill) async {
    if (skill.runtime != 'bridge') {
      return BridgeSkillResult.error(
        'Skill "${skill.name}" is not a bridge skill.',
      );
    }

    final capture = await _capture(skill);
    if (!capture.success) return BridgeSkillResult.error(capture.output);

    if (_gateway == null) {
      return BridgeSkillResult.ok(
        'Captured locally. Gateway not connected — payload not sent.',
        data: capture.data,
      );
    }

    try {
      await _gateway.sendTask('skill.run', {
        'skill': skill.name,
        'runtime': 'bridge',
        'capture': capture.data ?? {},
      });
      return BridgeSkillResult.ok(
        'Skill "${skill.name}" dispatched to server.',
        data: capture.data,
      );
    } catch (e) {
      return BridgeSkillResult.error('Failed to reach gateway: $e');
    }
  }

  Future<ToolResult> _capture(Skill skill) async {
    // Default to camera when nothing is declared — most bridge skills
    // start with a visual capture in practice.
    final apis = skill.requiredDeviceApis;
    final primary = apis.isEmpty ? 'camera' : apis.first.toLowerCase();

    switch (primary) {
      case 'camera':
        return _attachBytes(
          await _camera.capture(purpose: 'bridge:${skill.name}'),
        );
      case 'gallery':
      case 'photos':
        return _attachBytes(
          await _camera.pickFromGallery(purpose: 'bridge:${skill.name}'),
        );
      case 'calendar':
        final now = DateTime.now();
        return _calendar.getEvents(
          start: now,
          end: now.add(const Duration(days: 7)),
        );
      default:
        return ToolResult.error(
          'Bridge skill requires unsupported device API: $primary',
        );
    }
  }

  /// Read the captured file into base64 so the gateway receives the bytes,
  /// not just a local path that means nothing to a server on the other side.
  Future<ToolResult> _attachBytes(ToolResult capture) async {
    if (!capture.success || capture.data == null) return capture;
    final path = capture.data!['path'];
    if (path is! String) return capture;

    try {
      final file = File(path);
      if (!await file.exists()) return capture;
      final bytes = await file.readAsBytes();
      return ToolResult.ok(
        capture.output,
        data: <String, dynamic>{
          ...capture.data!,
          'base64': base64Encode(bytes),
          'sizeBytes': bytes.length,
        },
      );
    } catch (e) {
      debugPrint('BridgeSkillRunner: could not attach bytes: $e');
      return capture;
    }
  }
}
