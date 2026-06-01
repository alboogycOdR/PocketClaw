library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/hermes_commander_theme.dart';
import '../../data/providers/integration_providers.dart';
import '../../data/providers/intelligence_providers.dart';

enum _ReconMode { dns, whois, ip, ssl, cve }

class ReconPanel extends ConsumerStatefulWidget {
  const ReconPanel({super.key});

  @override
  ConsumerState<ReconPanel> createState() => _ReconPanelState();
}

class _ReconPanelState extends ConsumerState<ReconPanel> {
  _ReconMode _mode = _ReconMode.dns;
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  dynamic _resultData; // raw parsed JSON
  String? _error;
  bool _showRaw = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final input = _inputCtrl.text.trim();
    final client = ref.read(osirisClientProvider);
    if (input.isEmpty || client == null) return;

    setState(() {
      _loading = true;
      _resultData = null;
      _error = null;
      _showRaw = false;
    });

    try {
      dynamic data;
      switch (_mode) {
        case _ReconMode.dns:
          data = await client.dnsLookup(input);
        case _ReconMode.whois:
          data = await client.whoisLookup(input);
        case _ReconMode.ip:
          data = await client.ipIntelligence(input);
        case _ReconMode.ssl:
          data = await client.sslInspect(input);
        case _ReconMode.cve:
          final vulns = await client.cveLookup(input);
          data = {'vulnerabilities': vulns};
      }
      setState(() {
        _resultData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _copyResult() async {
    if (_resultData == null) return;
    final text = const JsonEncoder.withIndent('  ').convert(_resultData);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  void _sendToHermes() {
    if (_resultData == null) return;
    final raw = const JsonEncoder.withIndent('  ').convert(_resultData);
    final label = _label(_mode);
    final input = _inputCtrl.text.trim();
    final prefill =
        '[RECON result — $label: $input]\n```json\n$raw\n```\n\nAnalyse this RECON result.\n\n';
    ref.read(pendingChatContextProvider.notifier).state = prefill;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result sent to Chat — navigate there to continue'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _focusOnMap(double lat, double lon, String label) {
    ref.read(reconFocusProvider.notifier).state = ReconMapFocus(
      lat: lat,
      lon: lon,
      label: label,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Map focused on $label'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final osirisOk = ref.watch(osirisReachableProvider).valueOrNull ?? false;
    final rawJson = _resultData != null
        ? const JsonEncoder.withIndent('  ').convert(_resultData)
        : null;

    return Card(
      margin: EdgeInsets.zero,
      color: HCTheme.bgPanel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radar, size: 16, color: HCTheme.gold),
                const SizedBox(width: 8),
                const Text(
                  'RECON Toolkit',
                  style: TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HCTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  osirisOk ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 10,
                    color: osirisOk ? HCTheme.statusGreen : HCTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _ReconMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(_label(mode)),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() {
                    _mode = mode;
                    _resultData = null;
                    _error = null;
                  }),
                  selectedColor: HCTheme.goldBg,
                  labelStyle: TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 12,
                    color: _mode == mode ? HCTheme.gold : HCTheme.textSecondary,
                  ),
                  side: const BorderSide(color: HCTheme.border),
                  backgroundColor: HCTheme.bgSurface,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: _hint(_mode),
                      hintStyle: const TextStyle(
                        fontFamily: 'GeistMono',
                        color: HCTheme.textMuted,
                        fontSize: 11,
                      ),
                      filled: true,
                      fillColor: HCTheme.bgSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: HCTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: HCTheme.border),
                      ),
                    ),
                    onSubmitted: (_) => _run(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_loading || !osirisOk) ? null : _run,
                  style: FilledButton.styleFrom(
                    backgroundColor: HCTheme.gold,
                    foregroundColor: HCTheme.bgBase,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Run'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  color: HCTheme.statusRed,
                  fontSize: 11,
                ),
              ),
            ] else if (_resultData != null) ...[
              const SizedBox(height: 12),
              // Action bar
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _copyResult,
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      foregroundColor: HCTheme.textSecondary,
                      textStyle: const TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _sendToHermes,
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('Send to Hermes'),
                    style: TextButton.styleFrom(
                      foregroundColor: HCTheme.gold,
                      textStyle: const TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _showRaw = !_showRaw),
                    style: TextButton.styleFrom(
                      foregroundColor: HCTheme.textSecondary,
                      textStyle: const TextStyle(
                        fontFamily: 'GeistMono',
                        fontSize: 11,
                      ),
                    ),
                    child: Text(_showRaw ? 'Structured' : 'Raw JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_showRaw)
                _RawResultBox(json: rawJson!)
              else
                _StructuredResult(
                  mode: _mode,
                  data: _resultData,
                  onFocusMap: _focusOnMap,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _label(_ReconMode mode) => switch (mode) {
    _ReconMode.dns => 'DNS',
    _ReconMode.whois => 'WHOIS',
    _ReconMode.ip => 'IP Intel',
    _ReconMode.ssl => 'SSL',
    _ReconMode.cve => 'CVE',
  };

  String _hint(_ReconMode mode) => switch (mode) {
    _ReconMode.dns => 'example.com',
    _ReconMode.whois => 'example.com or 8.8.8.8',
    _ReconMode.ip => '8.8.8.8',
    _ReconMode.ssl => 'example.com',
    _ReconMode.cve => 'CVE-2024-1234 or nginx',
  };
}

// ── Structured result dispatcher ─────────────────────────────────────────────

class _StructuredResult extends StatelessWidget {
  final _ReconMode mode;
  final dynamic data;
  final void Function(double lat, double lon, String label) onFocusMap;

  const _StructuredResult({
    required this.mode,
    required this.data,
    required this.onFocusMap,
  });

  @override
  Widget build(BuildContext context) {
    if (data is! Map<String, dynamic>) {
      return _RawResultBox(
        json: const JsonEncoder.withIndent('  ').convert(data),
      );
    }
    final map = data as Map<String, dynamic>;
    return switch (mode) {
      _ReconMode.dns => _DnsCard(data: map),
      _ReconMode.ip => _IpCard(data: map, onFocusMap: onFocusMap),
      _ReconMode.ssl => _SslCard(data: map),
      _ReconMode.whois => _WhoisCard(data: map),
      _ReconMode.cve => _CveCard(data: map),
    };
  }
}

// ── DNS Result ────────────────────────────────────────────────────────────────

class _DnsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DnsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // DNS data can come as {A: [...], AAAA: [...], MX: [...], NS: [...], TXT: [...]}
    // or as {records: [...]} or flat. Try both.
    final recordTypes = ['A', 'AAAA', 'MX', 'NS', 'TXT', 'CNAME', 'SOA'];
    final sections = <Widget>[];

    for (final type in recordTypes) {
      final raw = data[type] ?? data[type.toLowerCase()];
      if (raw == null) continue;
      final records = raw is List
          ? raw.map((e) => e.toString()).toList()
          : [raw.toString()];
      if (records.isEmpty) continue;
      sections.add(_DnsSection(type: type, records: records));
    }

    // Fallback: if nothing parsed, show all keys
    if (sections.isEmpty) {
      for (final entry in data.entries) {
        final val = entry.value;
        final records = val is List
            ? val.map((e) => e.toString()).toList()
            : [val.toString()];
        sections.add(_DnsSection(type: entry.key.toUpperCase(), records: records));
      }
    }

    if (sections.isEmpty) {
      return const _EmptyResult(message: 'No DNS records returned.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

class _DnsSection extends StatelessWidget {
  final String type;
  final List<String> records;

  const _DnsSection({required this.type, required this.records});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HCTheme.gold,
            ),
          ),
          const SizedBox(height: 4),
          ...records.map(
            (r) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 3),
              child: SelectableText(
                r,
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 11,
                  color: HCTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── IP Intel Result ───────────────────────────────────────────────────────────

class _IpCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(double lat, double lon, String label) onFocusMap;

  const _IpCard({required this.data, required this.onFocusMap});

  @override
  Widget build(BuildContext context) {
    final ip = _str(data, ['ip', 'query', 'ip_address']);
    final country = _str(data, ['country', 'country_name', 'countryName']);
    final city = _str(data, ['city', 'city_name', 'cityName']);
    final region = _str(data, ['region', 'regionName', 'region_name']);
    final org = _str(data, ['org', 'organization', 'isp']);
    final asn = _str(data, ['asn', 'as', 'as_number', 'asn_number']);
    final threat = _str(data, [
      'threat_level',
      'threatLevel',
      'abuse_score',
      'threat',
    ]);
    final lat = _num(data, ['lat', 'latitude', 'loc_lat']);
    final lon = _num(data, ['lon', 'longitude', 'lng', 'loc_lng']);

    final rows = <(String, String)>[
      if (ip.isNotEmpty) ('IP', ip),
      if (country.isNotEmpty) ('Country', country),
      if (region.isNotEmpty) ('Region', region),
      if (city.isNotEmpty) ('City', city),
      if (org.isNotEmpty) ('Org / ISP', org),
      if (asn.isNotEmpty) ('ASN', asn),
      if (threat.isNotEmpty) ('Threat level', threat),
      if (lat != null) ('Coordinates', '${lat.toStringAsFixed(4)}, ${lon?.toStringAsFixed(4) ?? '-'}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map(
          (row) => _InfoRow(label: row.$1, value: row.$2),
        ),
        if (lat != null && lon != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              final label = [city, country]
                  .where((s) => s.isNotEmpty)
                  .join(', ');
              onFocusMap(lat, lon, label.isEmpty ? ip : label);
            },
            icon: const Icon(Icons.my_location, size: 14, color: HCTheme.gold),
            label: const Text(
              'Focus on map',
              style: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: HCTheme.gold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: HCTheme.gold),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
        if (rows.isEmpty)
          const _EmptyResult(message: 'No IP intelligence data returned.'),
      ],
    );
  }

  String _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  double? _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
    }
    return null;
  }
}

// ── SSL Result ────────────────────────────────────────────────────────────────

class _SslCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SslCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = _str(data, ['subject', 'common_name', 'cn']);
    final issuer = _str(data, ['issuer', 'issuer_cn', 'issuer_org']);
    final validFrom = _str(data, ['valid_from', 'not_before', 'start_date']);
    final validTo = _str(data, ['valid_to', 'not_after', 'expiry', 'expiry_date']);
    final sans = data['san'] ?? data['SANs'] ?? data['subject_alt_names'];
    final cipher = _str(data, ['cipher', 'cipher_suite']);
    final valid = data['valid'] ?? data['is_valid'];

    String? validLabel;
    Color validColor = HCTheme.textSecondary;
    if (valid != null) {
      final isValid = valid == true || valid.toString().toLowerCase() == 'true';
      validLabel = isValid ? 'Valid' : 'Invalid / Expired';
      validColor = isValid ? HCTheme.statusGreen : HCTheme.statusRed;
    }

    final rows = <(String, String)>[
      if (subject.isNotEmpty) ('Subject', subject),
      if (issuer.isNotEmpty) ('Issuer', issuer),
      if (validFrom.isNotEmpty) ('Valid from', validFrom),
      if (validTo.isNotEmpty) ('Valid to', validTo),
      if (cipher.isNotEmpty) ('Cipher', cipher),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (validLabel != null) ...[
          Row(
            children: [
              Icon(
                valid == true || valid.toString().toLowerCase() == 'true'
                    ? Icons.verified_outlined
                    : Icons.warning_amber_outlined,
                size: 14,
                color: validColor,
              ),
              const SizedBox(width: 6),
              Text(
                validLabel,
                style: TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: validColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        ...rows.map((row) => _InfoRow(label: row.$1, value: row.$2)),
        if (sans != null) ...[
          const SizedBox(height: 6),
          const Text(
            'SANs',
            style: TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HCTheme.gold,
            ),
          ),
          const SizedBox(height: 4),
          ..._toList(sans).take(10).map(
            (s) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 3),
              child: SelectableText(
                s,
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 11,
                  color: HCTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
        if (rows.isEmpty && validLabel == null)
          const _EmptyResult(message: 'No SSL data returned.'),
      ],
    );
  }

  String _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  List<String> _toList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) return [v];
    return [];
  }
}

// ── WHOIS Result ──────────────────────────────────────────────────────────────

class _WhoisCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _WhoisCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final registrar = _str(data, ['registrar', 'registrar_name']);
    final created = _str(data, [
      'creation_date',
      'created',
      'created_date',
      'registered',
    ]);
    final updated = _str(data, ['updated_date', 'updated', 'last_updated']);
    final expires = _str(data, ['expiration_date', 'expires', 'expiry_date']);
    final status = _str(data, ['status', 'domain_status']);
    final nameservers = data['nameservers'] ?? data['name_servers'];

    final rows = <(String, String)>[
      if (registrar.isNotEmpty) ('Registrar', registrar),
      if (created.isNotEmpty) ('Created', created),
      if (updated.isNotEmpty) ('Updated', updated),
      if (expires.isNotEmpty) ('Expires', expires),
      if (status.isNotEmpty) ('Status', status),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map((row) => _InfoRow(label: row.$1, value: row.$2)),
        if (nameservers != null) ...[
          const SizedBox(height: 6),
          const Text(
            'Nameservers',
            style: TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HCTheme.gold,
            ),
          ),
          const SizedBox(height: 4),
          ..._toList(nameservers).take(8).map(
            (ns) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 3),
              child: SelectableText(
                ns,
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 11,
                  color: HCTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
        if (rows.isEmpty)
          const _EmptyResult(message: 'No WHOIS data returned.'),
      ],
    );
  }

  String _str(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  List<String> _toList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) return [v];
    return [];
  }
}

// ── CVE Result ────────────────────────────────────────────────────────────────

class _CveCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CveCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final raw = data['vulnerabilities'];
    final vulns = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];

    if (vulns.isEmpty) {
      return const _EmptyResult(message: 'No CVEs found matching that query.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${vulns.length} CVE${vulns.length == 1 ? '' : 's'} found',
          style: const TextStyle(
            fontFamily: 'GeistMono',
            fontSize: 11,
            color: HCTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...vulns.take(5).map((cve) => _CveEntry(cve: cve)),
      ],
    );
  }
}

class _CveEntry extends StatefulWidget {
  final Map<String, dynamic> cve;

  const _CveEntry({required this.cve});

  @override
  State<_CveEntry> createState() => _CveEntryState();
}

class _CveEntryState extends State<_CveEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final id = _str(['cve_id', 'id', 'CVE_ID']);
    final description = _str(['description', 'summary', 'desc']);
    final severity = _str(['severity', 'base_severity', 'baseSeverity']);
    final score = widget.cve['cvss_score'] ??
        widget.cve['base_score'] ??
        widget.cve['score'];

    final severityColor = switch (severity.toUpperCase()) {
      'CRITICAL' => HCTheme.statusRed,
      'HIGH' => Colors.orange,
      'MEDIUM' => Colors.amber,
      'LOW' => HCTheme.statusGreen,
      _ => HCTheme.textSecondary,
    };

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HCTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HCTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    id.isEmpty ? 'Unknown CVE' : id,
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: HCTheme.textPrimary,
                    ),
                  ),
                ),
                if (severity.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: severityColor.withAlpha(80)),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontSize: 10,
                        color: severityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (score != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    score.toString(),
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 12,
                      color: HCTheme.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _expanded
                    ? description
                    : description.length > 120
                    ? '${description.substring(0, 120)}…'
                    : description,
                style: const TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 12,
                  color: HCTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              if (description.length > 120)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: const TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 11,
                      color: HCTheme.gold,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _str(List<String> keys) {
    for (final k in keys) {
      final v = widget.cve[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: HCTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'GeistMono',
                fontSize: 12,
                color: HCTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  final String message;

  const _EmptyResult({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        fontFamily: 'GeistSans',
        fontSize: 12,
        color: HCTheme.textSecondary,
      ),
    );
  }
}

class _RawResultBox extends StatelessWidget {
  final String json;

  const _RawResultBox({required this.json});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HCTheme.bgBase,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.border),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          json,
          style: const TextStyle(
            fontFamily: 'GeistMono',
            fontSize: 11,
            height: 1.5,
            color: HCTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
