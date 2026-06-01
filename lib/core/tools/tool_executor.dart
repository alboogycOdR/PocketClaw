/// Runs a single tool call. Each tool is small and self-contained.
library;

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../intelligence/osiris_client.dart';
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
  Future<ToolCallResult> execute(String name, Map<String, dynamic> args) async {
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
            'is here; drop a search provider into ToolExecutor and remove this stub.',
          );
        case 'calculator':
          return _calculator(args);
        case 'get_current_datetime':
          return _datetime(args);
        case 'get_device_info':
          return _deviceInfo(args);
        case 'dns_lookup':
          return _dnsLookup(args);
        case 'whois_lookup':
          return _whoisLookup(args);
        case 'ip_intelligence':
          return _ipIntelligence(args);
        case 'ssl_inspect':
          return _sslInspect(args);
        case 'cve_lookup':
          return _cveLookup(args);
        case 'get_earthquakes':
          return _getEarthquakes();
        case 'get_active_fires':
          return _getActiveFires(args);
        case 'intelligence_briefing':
          return _intelligenceBriefing(args);
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
    final pretty =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final tzNote = tz == null || tz.isEmpty
        ? '(device local time)'
        : '(requested timezone: $tz - device-local fallback)';
    return ToolCallResult(
      toolName: 'get_current_datetime',
      output: '$pretty $tzNote\nISO: $iso',
    );
  }

  Future<ToolCallResult> _deviceInfo(Map<String, dynamic> args) async {
    final kind = (args['info_type'] as String?) ?? 'all';
    final lines = <String>[];

    if (kind == 'memory' || kind == 'all') {
      const channel = MethodChannel('com.nuburo.hermescommander/device');
      try {
        final ram = await channel.invokeMethod<int>('getTotalRam');
        if (ram != null) {
          lines.add(
            'RAM: ${(ram / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB',
          );
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
      lines.add('Battery: not yet wired (add battery_plus to surface here).');
    }

    if (kind == 'all') {
      try {
        if (Platform.isAndroid) {
          final info = await DeviceInfoPlugin().androidInfo;
          lines
            ..add('Model: ${info.manufacturer} ${info.model}')
            ..add(
              'Android: ${info.version.release} (SDK ${info.version.sdkInt})',
            );
        }
      } catch (_) {}
    }

    if (lines.isEmpty) {
      return ToolCallResult.error(
        'get_device_info',
        'No info available for "$kind".',
      );
    }
    return ToolCallResult(
      toolName: 'get_device_info',
      output: lines.join('\n'),
    );
  }

  Future<OsirisClient?> _osirisClient() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = (prefs.getString('osiris_base_url') ?? '').trim();
    if (baseUrl.isEmpty) return null;
    return OsirisClient(baseUrl: baseUrl);
  }

  Future<ToolCallResult> _dnsLookup(Map<String, dynamic> args) async {
    final domain = (args['domain'] as String?)?.trim() ?? '';
    if (domain.isEmpty) {
      return ToolCallResult.error('dns_lookup', 'Domain is required.');
    }
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'dns_lookup',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final data = await client.dnsLookup(domain);
    return ToolCallResult(
      toolName: 'dns_lookup',
      output: _formatDns(domain, data),
    );
  }

  Future<ToolCallResult> _whoisLookup(Map<String, dynamic> args) async {
    final target = (args['target'] as String?)?.trim() ?? '';
    if (target.isEmpty) {
      return ToolCallResult.error('whois_lookup', 'Target is required.');
    }
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'whois_lookup',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final data = await client.whoisLookup(target);
    return ToolCallResult(
      toolName: 'whois_lookup',
      output: _formatWhois(target, data),
    );
  }

  Future<ToolCallResult> _ipIntelligence(Map<String, dynamic> args) async {
    final ip = (args['ip'] as String?)?.trim() ?? '';
    if (ip.isEmpty) {
      return ToolCallResult.error('ip_intelligence', 'IP address is required.');
    }
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'ip_intelligence',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final data = await client.ipIntelligence(ip);
    return ToolCallResult(
      toolName: 'ip_intelligence',
      output: _formatIpIntel(ip, data),
    );
  }

  Future<ToolCallResult> _sslInspect(Map<String, dynamic> args) async {
    final domain = (args['domain'] as String?)?.trim() ?? '';
    if (domain.isEmpty) {
      return ToolCallResult.error('ssl_inspect', 'Domain is required.');
    }
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'ssl_inspect',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final data = await client.sslInspect(domain);
    return ToolCallResult(
      toolName: 'ssl_inspect',
      output: _formatSsl(domain, data),
    );
  }

  Future<ToolCallResult> _cveLookup(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return ToolCallResult.error('cve_lookup', 'Query is required.');
    }
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'cve_lookup',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final items = await client.cveLookup(query);
    return ToolCallResult(
      toolName: 'cve_lookup',
      output: _formatCves(query, items),
    );
  }

  Future<ToolCallResult> _getEarthquakes() async {
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'get_earthquakes',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final events = await client.getEarthquakes();
    final significant = events
        .where((event) => event.magnitude >= 4.0)
        .take(10)
        .toList();
    if (significant.isEmpty) {
      return const ToolCallResult(
        toolName: 'get_earthquakes',
        output: 'No significant seismic activity detected.',
      );
    }
    final lines = significant
        .map(
          (event) =>
              'M${event.magnitude.toStringAsFixed(1)} - ${event.place} '
              '(depth ${event.depth.toStringAsFixed(0)} km)',
        )
        .join('\n');
    return ToolCallResult(
      toolName: 'get_earthquakes',
      output: 'Recent M4.0+ earthquakes:\n$lines',
    );
  }

  Future<ToolCallResult> _getActiveFires(Map<String, dynamic> args) async {
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'get_active_fires',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final region = (args['region'] as String?)?.trim().toLowerCase();
    final fires = await client.getFires();
    final summary = region == null || region.isEmpty
        ? '${fires.length} active fire hotspots detected globally.'
        : '${fires.length} active fire hotspots returned. Region filter "$region" is not yet geocoded client-side.';
    return ToolCallResult(toolName: 'get_active_fires', output: summary);
  }

  Future<ToolCallResult> _intelligenceBriefing(
    Map<String, dynamic> args,
  ) async {
    final client = await _osirisClient();
    if (client == null) {
      return ToolCallResult.error(
        'intelligence_briefing',
        'Osiris is not configured. Set an Osiris base URL first.',
      );
    }
    final focus = ((args['focus'] as String?) ?? 'all').trim().toLowerCase();
    final buffer = StringBuffer('Intelligence Briefing\n');

    if (focus == 'all' || focus == 'seismic') {
      final quakes = await client.getEarthquakes();
      final top = quakes
          .where((event) => event.magnitude >= 5.5)
          .take(3)
          .toList();
      if (top.isNotEmpty) {
        buffer.writeln('\nSeismic:');
        for (final quake in top) {
          buffer.writeln(
            '- M${quake.magnitude.toStringAsFixed(1)} ${quake.place}',
          );
        }
      }
    }

    if (focus == 'all' || focus == 'conflict') {
      final zones = await client.getConflictZones();
      final top = zones.take(5).toList();
      if (top.isNotEmpty) {
        buffer.writeln('\nConflicts:');
        for (final zone in top) {
          buffer.writeln(
            '- ${zone.name} (${zone.severity.replaceAll('_', ' ')})',
          );
        }
      }
    }

    if (focus == 'all' || focus == 'fire') {
      final fires = await client.getFires();
      if (fires.isNotEmpty) {
        buffer.writeln('\nFires: ${fires.length} hotspots active.');
      }
    }

    if (buffer.toString().trim() == 'Intelligence Briefing') {
      buffer.writeln('\nNo current data available for the requested focus.');
    }

    return ToolCallResult(
      toolName: 'intelligence_briefing',
      output: buffer.toString().trim(),
    );
  }

  String _formatDns(String domain, Map<String, dynamic> data) {
    final buffer = StringBuffer('DNS records for $domain:\n');
    for (final key in ['A', 'AAAA', 'MX', 'NS', 'TXT', 'CNAME']) {
      final records = data[key] as List?;
      if (records != null && records.isNotEmpty) {
        buffer.writeln('$key: ${records.take(3).join(', ')}');
      }
    }
    return buffer.toString().trim();
  }

  String _formatWhois(String target, Map<String, dynamic> data) {
    final nameServers = (data['nameServers'] as List?)?.take(2).join(', ');
    return 'WHOIS for $target:\n'
        'Registrar: ${data['registrar'] ?? 'unknown'}\n'
        'Created: ${data['createdDate'] ?? data['created'] ?? 'unknown'}\n'
        'Expires: ${data['expiresDate'] ?? data['expires'] ?? 'unknown'}\n'
        'Name Servers: ${nameServers ?? 'unknown'}';
  }

  String _formatIpIntel(String ip, Map<String, dynamic> data) {
    return 'IP Intelligence for $ip:\n'
        'Location: ${data['city'] ?? ''}, ${data['country'] ?? 'unknown'}\n'
        'ISP/ASN: ${data['isp'] ?? data['org'] ?? 'unknown'}\n'
        'Threat: ${data['threat'] ?? data['abuseScore'] ?? 'none detected'}';
  }

  String _formatSsl(String domain, Map<String, dynamic> data) {
    return 'SSL/TLS for $domain:\n'
        'Issuer: ${data['issuer'] ?? 'unknown'}\n'
        'Valid until: ${data['validTo'] ?? data['notAfter'] ?? 'unknown'}\n'
        'Grade: ${data['grade'] ?? 'not graded'}';
  }

  String _formatCves(String query, List<dynamic> cves) {
    if (cves.isEmpty) return 'No CVEs found for "$query".';
    final buffer = StringBuffer('CVEs for "$query":\n');
    for (final item in cves.take(5)) {
      final cve = item is Map
          ? Map<String, dynamic>.from(item)
          : const <String, dynamic>{};
      final nested = cve['cve'] is Map
          ? Map<String, dynamic>.from(cve['cve'] as Map)
          : const <String, dynamic>{};
      final id = nested['id'] ?? cve['id'] ?? '';
      final descriptions = nested['descriptions'] as List?;
      var description = '';
      if (descriptions != null) {
        for (final entry in descriptions) {
          if (entry is Map && entry['lang'] == 'en') {
            description = entry['value'] as String? ?? '';
            break;
          }
        }
      }
      if (description.length > 120) {
        description = '${description.substring(0, 117)}...';
      }
      buffer.writeln(
        '- $id ${description.isEmpty ? '' : '- $description'}'.trimRight(),
      );
    }
    return buffer.toString().trim();
  }
}

final toolExecutor = ToolExecutor();
