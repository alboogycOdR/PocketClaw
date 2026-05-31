/// Runs a single tool call. Each tool is small and self-contained;
/// `web_search` is a stub that returns "not yet wired" because a real
/// implementation needs a search-engine HTML scraper or an API key.
library;

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';

import 'tool_registry.dart';

class ToolCallResult {
  final String toolName;
  final String output;
  final bool failed;
  const ToolCallResult({
    required this.toolName,
    required this.output,
    this.failed = false,
  });

  factory ToolCallResult.error(String toolName, String message) =>
      ToolCallResult(toolName: toolName, output: message, failed: true);
}

class ToolExecutor {
  Future<ToolCallResult> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    final tool = kAvailableTools.firstWhere(
      (t) => t.name == name,
      orElse: () => throw ArgumentError('Unknown tool: $name'),
    );

    try {
      switch (tool.id) {
        case 'web_search':
          return ToolCallResult.error(
            name,
            'web_search is not yet wired in this build. The architecture '
                "is here — drop a search-engine HTML scraper or API key "
                "into ToolExecutor._webSearch and remove this stub.",
          );
        case 'calculator':
          return _calculator(args);
        case 'get_current_datetime':
          return _datetime(args);
        case 'get_device_info':
          return _deviceInfo(args);
      }
    } catch (e) {
      return ToolCallResult.error(name, '$e');
    }
    return ToolCallResult.error(name, 'Tool not implemented');
  }

  ToolCallResult _calculator(Map<String, dynamic> args) {
    final expr = (args['expression'] as String?)?.trim();
    if (expr == null || expr.isEmpty) {
      return ToolCallResult.error('calculator', 'No expression provided.');
    }
    try {
      final parser = Parser();
      final exp = parser.parse(expr);
      final value = exp.evaluate(EvaluationType.REAL, ContextModel());
      return ToolCallResult(toolName: 'calculator', output: '$value');
    } catch (e) {
      return ToolCallResult.error('calculator', 'Could not evaluate: $e');
    }
  }

  ToolCallResult _datetime(Map<String, dynamic> args) {
    final tz = (args['timezone'] as String?)?.trim();
    final now = DateTime.now();
    final iso = now.toIso8601String();
    final pretty = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final tzNote = tz == null || tz.isEmpty
        ? '(device local time)'
        : '(requested timezone: $tz — device-local fallback)';
    return ToolCallResult(
      toolName: 'get_current_datetime',
      output: '$pretty $tzNote\nISO: $iso',
    );
  }

  Future<ToolCallResult> _deviceInfo(Map<String, dynamic> args) async {
    final kind = (args['info_type'] as String?) ?? 'all';
    final lines = <String>[];

    if (kind == 'memory' || kind == 'all') {
      const channel = MethodChannel('com.carmen.clawcommander/device');
      try {
        final ram = await channel.invokeMethod<int>('getTotalRam');
        if (ram != null) {
          lines.add('RAM: ${(ram / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB');
        }
      } catch (_) {}
    }

    if (kind == 'storage' || kind == 'all') {
      try {
        final stat = await Process.run('df', ['-k', '/data']);
        if (stat.exitCode == 0) {
          lines.add('Storage:\n${stat.stdout}');
        }
      } catch (_) {}
    }

    if (kind == 'battery' || kind == 'all') {
      lines.add(
          'Battery: not yet wired (add battery_plus to surface here).');
    }

    if (kind == 'all') {
      try {
        if (Platform.isAndroid) {
          final info = await DeviceInfoPlugin().androidInfo;
          lines
            ..add('Model: ${info.manufacturer} ${info.model}')
            ..add('Android: ${info.version.release} '
                '(SDK ${info.version.sdkInt})');
        }
      } catch (_) {}
    }

    if (lines.isEmpty) {
      return ToolCallResult.error(
          'get_device_info', 'No info available for "$kind".');
    }
    return ToolCallResult(
      toolName: 'get_device_info',
      output: lines.join('\n'),
    );
  }
}

final toolExecutor = ToolExecutor();
