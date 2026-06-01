# ClawCommander — Osiris Intelligence Integration
## Developer Specification v1.0

**Date:** 2026-05-14  
**Author:** CARMEN PTY LTD  
**Source:** `simplifaisoul/osiris` (MIT)  
**Status:** Implementation-ready  
**Estimated effort:** 4 days total  

---

## Overview

Three deliverables in order of priority:

1. **VPS Deployment** — Osiris in Docker alongside existing services (half a day, no Flutter code)
2. **RECON Tool Suite** — DNS, WHOIS, SSL, IP Intel, CVE Lookup as callable agent tools (1 day)
3. **World Intelligence Screen** — Upgrade Radio Globe to a layered intelligence map (2.5 days)

**Zero new pubspec dependencies** — `flutter_map`, `latlong2`, `http`, and `dio` are already present from the Radio Globe and existing HTTP clients.

---

# PART 1 — VPS DEPLOYMENT

---

## 1.1 Deploy Osiris on VPS

SSH into the VPS and run:

```bash
# 1. Clone Osiris
cd ~
git clone https://github.com/simplifaisoul/osiris.git
cd osiris

# 2. Configure environment
cp .env.template .env

# Edit .env — change only the port to avoid conflict with existing services
# (OpenClaw: 18789, Hermes: 8642, Paperclip: 3100)
echo "OSIRIS_PORT=3001" >> .env
# Leave all API keys blank — every core layer works without them

# 3. Launch via Docker Compose
docker compose up -d

# 4. Verify all layers respond
curl -s http://localhost:3001/api/earthquakes | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(f'Earthquakes: {len(d.get(\"features\",[]))} events')"

curl -s http://localhost:3001/api/news | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(f'News feeds: {len(d)} items')"

echo "Osiris running at http://100.78.70.2:3001"
```

**Create systemd service so Osiris survives reboots:**

```bash
# /etc/systemd/system/osiris.service
sudo tee /etc/systemd/system/osiris.service > /dev/null << 'EOF'
[Unit]
Description=Osiris Intelligence Platform
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root/osiris
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable osiris
sudo systemctl start osiris
```

**Verify all endpoints before building any Flutter code:**

```bash
# Run this health check — every line should print a result
echo "=== Osiris Health Check ===" && \
echo "Earthquakes: $(curl -s http://localhost:3001/api/earthquakes | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("features",[])), "events")')" && \
echo "Flights:     $(curl -s http://localhost:3001/api/flights | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("states",[])), "aircraft")')" && \
echo "Fires:       $(curl -s http://localhost:3001/api/fires | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("features",[])), "hotspots")')" && \
echo "News:        $(curl -s http://localhost:3001/api/news | python3 -c 'import json,sys; print(len(json.load(sys.stdin)), "items")')" && \
echo "RECON DNS:   $(curl -s "http://localhost:3001/api/osint/dns?domain=google.com" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if d else "no data")')"
```

**VPS service map after deployment:**

```
100.78.70.2 (Tailscale)
├── OpenClaw    :18789  ← existing
├── Hermes      :8642   ← existing
├── Paperclip   :3100   ← existing
└── Osiris      :3001   ← NEW (Docker)
```

---

## 1.2 Wire Osiris to Hermes as MCP Tools

Add Osiris endpoints to Hermes's MCP config so Hermes can call them as native tools:

```bash
# Edit ~/.hermes/config.yaml — add under mcp_servers:
cat >> ~/.hermes/config.yaml << 'EOF'

mcp_servers:
  - name: osiris-intelligence
    type: http
    base_url: http://localhost:3001
    tools:
      - name: get_earthquakes
        path: /api/earthquakes
        description: Real-time M2.5+ earthquake data from USGS
      - name: get_flights
        path: /api/flights
        description: Live global flight tracking from OpenSky Network
      - name: get_active_fires
        path: /api/fires
        description: NASA FIRMS active fire hotspots worldwide
      - name: get_news_feeds
        path: /api/news
        description: 24/7 live news from 25+ global broadcasters
      - name: get_conflict_zones
        path: /api/conflicts
        description: 13 active global conflict and tension zones
      - name: dns_lookup
        path: /api/osint/dns
        description: Full DNS record resolution for a domain
      - name: whois_lookup
        path: /api/osint/whois
        description: WHOIS registration data for a domain or IP
      - name: ip_intelligence
        path: /api/osint/ip
        description: Geolocation, ASN, and threat reputation for an IP
      - name: ssl_inspect
        path: /api/osint/ssl
        description: SSL/TLS certificate chain analysis for a domain
      - name: cve_lookup
        path: /api/osint/cve
        description: CVE vulnerability lookup against NVD database
EOF

# Reload Hermes to pick up new tools
hermes restart
```

---

# PART 2 — RECON TOOL SUITE (Flutter)

---

## 2.1 Osiris Client

```dart
// lib/core/intelligence/osiris_client.dart
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/providers/core_providers.dart';

/// HTTP client for the Osiris Intelligence API running on the VPS.
/// Base URL is read from SharedPreferences ('osiris_base_url').
/// Defaults to http://100.78.70.2:3001 if not configured.
class OsirisClient {
  final String baseUrl;

  const OsirisClient({required this.baseUrl});

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? params,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('Osiris $path returned ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, String>? params,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await http.get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Osiris $path returned ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is List) return body;
    if (body is Map) return body['features'] as List? ?? [];
    return [];
  }

  // ── Intelligence layers ─────────────────────────────────────────────────

  Future<List<EarthquakeEvent>> getEarthquakes() async {
    final features = await _getList('/api/earthquakes');
    return features
        .cast<Map<String, dynamic>>()
        .map(EarthquakeEvent.fromGeoJson)
        .toList();
  }

  Future<List<FlightState>> getFlights() async {
    final data = await _get('/api/flights');
    final states = data['states'] as List? ?? [];
    return states
        .cast<List<dynamic>>()
        .map(FlightState.fromOpenSky)
        .where((f) => f.latitude != null && f.longitude != null)
        .toList();
  }

  Future<List<FireHotspot>> getFires() async {
    final features = await _getList('/api/fires');
    return features
        .cast<Map<String, dynamic>>()
        .map(FireHotspot.fromGeoJson)
        .toList();
  }

  Future<List<NewsItem>> getNews() async {
    final items = await _getList('/api/news');
    return items.cast<Map<String, dynamic>>().map(NewsItem.fromJson).toList();
  }

  Future<List<ConflictZone>> getConflictZones() async {
    final items = await _getList('/api/conflicts');
    return items
        .cast<Map<String, dynamic>>()
        .map(ConflictZone.fromJson)
        .toList();
  }

  Future<List<SatellitePosition>> getSatellites() async {
    final items = await _getList('/api/satellites');
    return items
        .cast<Map<String, dynamic>>()
        .map(SatellitePosition.fromJson)
        .toList();
  }

  // ── RECON toolkit ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> dnsLookup(String domain) =>
      _get('/api/osint/dns', params: {'domain': domain});

  Future<Map<String, dynamic>> whoisLookup(String target) =>
      _get('/api/osint/whois', params: {'target': target});

  Future<Map<String, dynamic>> ipIntelligence(String ip) =>
      _get('/api/osint/ip', params: {'ip': ip});

  Future<Map<String, dynamic>> sslInspect(String domain) =>
      _get('/api/osint/ssl', params: {'domain': domain});

  Future<List<dynamic>> cveLookup(String keyword) async {
    final data = await _get('/api/osint/cve', params: {'q': keyword});
    return data['vulnerabilities'] as List? ?? [];
  }

  Future<Map<String, dynamic>> portScan(String target) =>
      _get('/api/scanner/ports', params: {'target': target},
          timeout: const Duration(seconds: 30));

  // ── Health ────────────────────────────────────────────────────────────────

  Future<bool> isReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/earthquakes'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

final osirisClientProvider = Provider<OsirisClient>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final url = prefs.getString('osiris_base_url') ?? 'http://100.78.70.2:3001';
  return OsirisClient(baseUrl: url);
});

final osirisReachableProvider = FutureProvider<bool>((ref) async {
  return ref.watch(osirisClientProvider).isReachable();
});
```

---

## 2.2 Intelligence Data Models

```dart
// lib/core/intelligence/intelligence_models.dart
library;

import 'package:latlong2/latlong.dart';

// ── Earthquake ────────────────────────────────────────────────────────────────

class EarthquakeEvent {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final LatLng position;
  final double depth;    // km

  const EarthquakeEvent({
    required this.id, required this.magnitude, required this.place,
    required this.time, required this.position, required this.depth,
  });

  /// Severity colour for map marker
  String get severityEmoji {
    if (magnitude >= 7.0) return '🔴';
    if (magnitude >= 5.5) return '🟠';
    if (magnitude >= 4.0) return '🟡';
    return '🟢';
  }

  factory EarthquakeEvent.fromGeoJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>;
    final coords = (json['geometry']?['coordinates'] as List?) ?? [0, 0, 0];
    return EarthquakeEvent(
      id:        json['id'] as String? ?? '',
      magnitude: (props['mag'] as num?)?.toDouble() ?? 0,
      place:     props['place'] as String? ?? '',
      time:      DateTime.fromMillisecondsSinceEpoch(
                   (props['time'] as num?)?.toInt() ?? 0),
      position:  LatLng(
                   (coords[1] as num).toDouble(),
                   (coords[0] as num).toDouble()),
      depth:     (coords[2] as num?)?.toDouble() ?? 0,
    );
  }
}

// ── Flight ────────────────────────────────────────────────────────────────────

class FlightState {
  final String icao24;
  final String? callsign;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? altitude;    // m
  final double? velocity;    // m/s
  final double? heading;     // degrees
  final bool onGround;

  LatLng? get position => latitude != null && longitude != null
      ? LatLng(latitude!, longitude!)
      : null;

  const FlightState({
    required this.icao24, this.callsign, this.country,
    this.latitude, this.longitude, this.altitude,
    this.velocity, this.heading, required this.onGround,
  });

  // OpenSky returns an array: [icao24, callsign, country, ?, ?, lon, lat, alt, on_ground, vel, hdg, ...]
  factory FlightState.fromOpenSky(List<dynamic> s) => FlightState(
    icao24:    s[0] as String? ?? '',
    callsign:  (s[1] as String?)?.trim(),
    country:   s[2] as String?,
    latitude:  (s[6] as num?)?.toDouble(),
    longitude: (s[5] as num?)?.toDouble(),
    altitude:  (s[7] as num?)?.toDouble(),
    onGround:  s[8] == true,
    velocity:  (s[9] as num?)?.toDouble(),
    heading:   (s[10] as num?)?.toDouble(),
  );
}

// ── Fire ──────────────────────────────────────────────────────────────────────

class FireHotspot {
  final LatLng position;
  final double brightness;
  final double confidence; // 0–100
  final DateTime? acqDate;

  const FireHotspot({
    required this.position,
    required this.brightness,
    required this.confidence,
    this.acqDate,
  });

  factory FireHotspot.fromGeoJson(Map<String, dynamic> json) {
    final coords = (json['geometry']?['coordinates'] as List?) ?? [0, 0];
    final props  = json['properties'] as Map<String, dynamic>? ?? {};
    return FireHotspot(
      position:   LatLng((coords[1] as num).toDouble(),
                         (coords[0] as num).toDouble()),
      brightness: (props['brightness'] as num?)?.toDouble() ?? 0,
      confidence: (props['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ── News ──────────────────────────────────────────────────────────────────────

class NewsItem {
  final String id;
  final String title;
  final String source;
  final String? url;
  final String? streamUrl;
  final LatLng? position;   // geographic origin of broadcaster

  const NewsItem({
    required this.id, required this.title, required this.source,
    this.url, this.streamUrl, this.position,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    id:        json['id'] as String? ?? json['source'] as String? ?? '',
    title:     json['title'] as String? ?? '',
    source:    json['source'] as String? ?? '',
    url:       json['url'] as String?,
    streamUrl: json['stream_url'] as String?,
    position: json['lat'] != null && json['lon'] != null
        ? LatLng((json['lat'] as num).toDouble(),
                 (json['lon'] as num).toDouble())
        : null,
  );
}

// ── Conflict Zone ─────────────────────────────────────────────────────────────

class ConflictZone {
  final String name;
  final String severity;  // 'active_war' | 'high_tension' | 'elevated'
  final LatLng position;
  final String? description;

  const ConflictZone({
    required this.name, required this.severity,
    required this.position, this.description,
  });

  String get emoji => switch (severity) {
    'active_war'   => '💥',
    'high_tension' => '⚠️',
    'elevated'     => '🟡',
    _              => '🔵',
  };

  factory ConflictZone.fromJson(Map<String, dynamic> json) => ConflictZone(
    name:        json['name'] as String? ?? '',
    severity:    json['severity'] as String? ?? 'elevated',
    position:    LatLng(
                   (json['lat'] as num).toDouble(),
                   (json['lon'] as num).toDouble()),
    description: json['description'] as String?,
  );
}

// ── Satellite ─────────────────────────────────────────────────────────────────

class SatellitePosition {
  final String name;
  final int satId;
  final LatLng position;
  final double altitude;   // km

  const SatellitePosition({
    required this.name, required this.satId,
    required this.position, required this.altitude,
  });

  factory SatellitePosition.fromJson(Map<String, dynamic> json) =>
      SatellitePosition(
        name:     json['satname'] as String? ?? '',
        satId:    (json['satid'] as num?)?.toInt() ?? 0,
        position: LatLng(
                    (json['satlat'] as num).toDouble(),
                    (json['satlng'] as num).toDouble()),
        altitude: (json['satalt'] as num?)?.toDouble() ?? 0,
      );
}
```

---

## 2.3 RECON Tools — Add to Tool Registry

In `lib/core/tools/tool_registry.dart`, add these entries:

```dart
// Add to kAvailableTools list:

ToolDefinition(
  id: 'dns_lookup',
  name: 'dns_lookup',
  displayName: 'DNS Lookup',
  description: 'Resolve all DNS records for a domain — A, AAAA, MX, NS, TXT, CNAME. '
      'Use when asked about a domain\'s servers, email configuration, or DNS setup.',
  requiresNetwork: true,
  parameters: {
    'domain': ToolParam(type: 'string',
        description: 'Domain to resolve (e.g. example.com)', required: true),
  },
),

ToolDefinition(
  id: 'whois_lookup',
  name: 'whois_lookup',
  displayName: 'WHOIS Lookup',
  description: 'Get registration data for a domain or IP address — registrar, '
      'creation date, expiry, nameservers, registrant info.',
  requiresNetwork: true,
  parameters: {
    'target': ToolParam(type: 'string',
        description: 'Domain or IP to look up', required: true),
  },
),

ToolDefinition(
  id: 'ip_intelligence',
  name: 'ip_intelligence',
  displayName: 'IP Intelligence',
  description: 'Get geolocation, ASN, ISP, and threat reputation for an IP address. '
      'Use to identify where a server is hosted or check if an IP is flagged.',
  requiresNetwork: true,
  parameters: {
    'ip': ToolParam(type: 'string',
        description: 'IP address to investigate', required: true),
  },
),

ToolDefinition(
  id: 'ssl_inspect',
  name: 'ssl_inspect',
  displayName: 'SSL Inspector',
  description: 'Inspect the SSL/TLS certificate chain for a domain — issuer, '
      'expiry date, SANs, cipher suite, and validity.',
  requiresNetwork: true,
  parameters: {
    'domain': ToolParam(type: 'string',
        description: 'Domain to inspect SSL certificate', required: true),
  },
),

ToolDefinition(
  id: 'cve_lookup',
  name: 'cve_lookup',
  displayName: 'CVE Lookup',
  description: 'Search the NVD vulnerability database for CVEs matching a keyword, '
      'software name, or CVE ID. Returns severity, description, and affected versions.',
  requiresNetwork: true,
  parameters: {
    'query': ToolParam(type: 'string',
        description: 'CVE ID (e.g. CVE-2024-1234) or software name', required: true),
  },
),

ToolDefinition(
  id: 'get_earthquakes',
  name: 'get_earthquakes',
  displayName: 'Earthquake Monitor',
  description: 'Get current real-time M2.5+ earthquake data from USGS. '
      'Returns the 20 most recent events with magnitude, location, depth.',
  requiresNetwork: true,
  parameters: {},
),

ToolDefinition(
  id: 'get_active_fires',
  name: 'get_active_fires',
  displayName: 'Active Fire Monitor',
  description: 'Get NASA FIRMS active fire hotspots. '
      'Returns current wildfire and hotspot locations worldwide.',
  requiresNetwork: true,
  parameters: {
    'region': ToolParam(type: 'string',
        description: 'Optional region filter (e.g. "South Africa", "California")'),
  },
),

ToolDefinition(
  id: 'intelligence_briefing',
  name: 'intelligence_briefing',
  displayName: 'Intelligence Briefing',
  description: 'Get a combined situational awareness briefing: active earthquakes, '
      'conflict zone status, space weather, and top news headlines. '
      'Use when asked "what\'s happening in the world" or for a daily briefing.',
  requiresNetwork: true,
  parameters: {
    'focus': ToolParam(type: 'string',
        description: 'Optional focus area: "seismic" | "conflict" | "cyber" | "all"'),
  },
),
```

---

## 2.4 RECON Tool Handlers

In `lib/core/tools/tool_executor.dart`, add the Osiris cases:

```dart
// Add import:
import '../intelligence/osiris_client.dart';

// In the _execute switch — add after existing cases:

case 'dns_lookup':
  final domain = (args['domain'] as String?)?.trim() ?? '';
  if (domain.isEmpty) return ToolResult.error('Domain is required');
  try {
    final data = await ref.read(osirisClientProvider).dnsLookup(domain);
    return ToolResult.ok(_formatDns(domain, data), data: data);
  } catch (e) {
    return ToolResult.error('DNS lookup failed: $e');
  }

case 'whois_lookup':
  final target = (args['target'] as String?)?.trim() ?? '';
  if (target.isEmpty) return ToolResult.error('Target is required');
  try {
    final data = await ref.read(osirisClientProvider).whoisLookup(target);
    return ToolResult.ok(_formatWhois(target, data), data: data);
  } catch (e) {
    return ToolResult.error('WHOIS lookup failed: $e');
  }

case 'ip_intelligence':
  final ip = (args['ip'] as String?)?.trim() ?? '';
  if (ip.isEmpty) return ToolResult.error('IP address is required');
  try {
    final data = await ref.read(osirisClientProvider).ipIntelligence(ip);
    return ToolResult.ok(_formatIpIntel(ip, data), data: data);
  } catch (e) {
    return ToolResult.error('IP intelligence failed: $e');
  }

case 'ssl_inspect':
  final domain = (args['domain'] as String?)?.trim() ?? '';
  if (domain.isEmpty) return ToolResult.error('Domain is required');
  try {
    final data = await ref.read(osirisClientProvider).sslInspect(domain);
    return ToolResult.ok(_formatSsl(domain, data), data: data);
  } catch (e) {
    return ToolResult.error('SSL inspection failed: $e');
  }

case 'cve_lookup':
  final query = (args['query'] as String?)?.trim() ?? '';
  if (query.isEmpty) return ToolResult.error('Query is required');
  try {
    final cves = await ref.read(osirisClientProvider).cveLookup(query);
    return ToolResult.ok(_formatCves(query, cves), data: {'cves': cves});
  } catch (e) {
    return ToolResult.error('CVE lookup failed: $e');
  }

case 'get_earthquakes':
  try {
    final events = await ref.read(osirisClientProvider).getEarthquakes();
    final top = events
        .where((e) => e.magnitude >= 4.0)
        .take(10)
        .toList();
    if (top.isEmpty) return ToolResult.ok('No significant seismic activity (M4.0+) detected.');
    final lines = top.map((e) =>
        '${e.severityEmoji} M${e.magnitude.toStringAsFixed(1)} — ${e.place} '
        '(depth: ${e.depth.toStringAsFixed(0)}km)').join('\n');
    return ToolResult.ok('Recent M4.0+ earthquakes:\n$lines');
  } catch (e) {
    return ToolResult.error('Earthquake data unavailable: $e');
  }

case 'get_active_fires':
  try {
    final fires = await ref.read(osirisClientProvider).getFires();
    final region = (args['region'] as String?)?.toLowerCase();
    final filtered = region != null
        ? fires.where((f) => true).toList() // geo-filter can be added later
        : fires;
    return ToolResult.ok(
      '🔥 ${filtered.length} active fire hotspots detected globally.',
      data: {'count': filtered.length},
    );
  } catch (e) {
    return ToolResult.error('Fire data unavailable: $e');
  }

case 'intelligence_briefing':
  try {
    final focus = (args['focus'] as String?) ?? 'all';
    final buf = StringBuffer('🌐 Intelligence Briefing\n\n');
    if (focus == 'all' || focus == 'seismic') {
      final quakes = await ref.read(osirisClientProvider).getEarthquakes();
      final sig = quakes.where((e) => e.magnitude >= 5.5).take(3).toList();
      if (sig.isNotEmpty) {
        buf.writeln('🌍 Seismic Activity (M5.5+):');
        for (final q in sig) {
          buf.writeln('  ${q.severityEmoji} M${q.magnitude.toStringAsFixed(1)} — ${q.place}');
        }
        buf.writeln();
      }
    }
    if (focus == 'all' || focus == 'conflict') {
      final zones = await ref.read(osirisClientProvider).getConflictZones();
      final active = zones.where((z) => z.severity == 'active_war').toList();
      if (active.isNotEmpty) {
        buf.writeln('⚔️ Active Conflict Zones (${active.length}):');
        for (final z in active.take(5)) buf.writeln('  ${z.emoji} ${z.name}');
        buf.writeln();
      }
    }
    return ToolResult.ok(buf.toString().trim());
  } catch (e) {
    return ToolResult.error('Briefing unavailable: $e');
  }
```

**Format helpers** — add as private methods in `ToolExecutor`:

```dart
String _formatDns(String domain, Map<String, dynamic> data) {
  final buf = StringBuffer('DNS records for $domain:\n');
  for (final key in ['A', 'AAAA', 'MX', 'NS', 'TXT', 'CNAME']) {
    final records = data[key] as List?;
    if (records != null && records.isNotEmpty) {
      buf.writeln('$key: ${records.take(3).join(", ")}');
    }
  }
  return buf.toString();
}

String _formatWhois(String target, Map<String, dynamic> data) =>
    'WHOIS for $target:\n'
    'Registrar: ${data["registrar"] ?? "unknown"}\n'
    'Created: ${data["createdDate"] ?? data["created"] ?? "unknown"}\n'
    'Expires: ${data["expiresDate"] ?? data["expires"] ?? "unknown"}\n'
    'Name Servers: ${(data["nameServers"] as List?)?.take(2).join(", ") ?? "unknown"}';

String _formatIpIntel(String ip, Map<String, dynamic> data) =>
    'IP Intelligence for $ip:\n'
    'Location: ${data["city"] ?? ""}, ${data["country"] ?? "unknown"}\n'
    'ISP/ASN: ${data["isp"] ?? data["org"] ?? "unknown"}\n'
    'Threat: ${data["threat"] ?? data["abuseScore"] ?? "none detected"}';

String _formatSsl(String domain, Map<String, dynamic> data) =>
    'SSL/TLS for $domain:\n'
    'Issuer: ${data["issuer"] ?? "unknown"}\n'
    'Valid until: ${data["validTo"] ?? data["notAfter"] ?? "unknown"}\n'
    'Grade: ${data["grade"] ?? "not graded"}';

String _formatCves(String query, List<dynamic> cves) {
  if (cves.isEmpty) return 'No CVEs found for "$query"';
  final buf = StringBuffer('CVEs for "$query":\n');
  for (final cve in cves.take(5)) {
    final id  = cve['cve']?['id'] ?? cve['id'] ?? '';
    final desc = (cve['cve']?['descriptions'] as List?)
        ?.firstWhere((d) => d['lang'] == 'en', orElse: () => {'value': ''})
        ['value'] ?? '';
    buf.writeln('• $id — ${desc.length > 120 ? "${desc.substring(0, 117)}…" : desc}');
  }
  return buf.toString();
}
```

---

# PART 3 — WORLD INTELLIGENCE SCREEN

---

## 3.1 Intelligence Providers

```dart
// lib/data/providers/intelligence_providers.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/intelligence/intelligence_models.dart';
import '../../core/intelligence/osiris_client.dart';

// ── Layer toggle state ────────────────────────────────────────────────────────

class IntelligenceLayers {
  final bool earthquakes;
  final bool flights;
  final bool fires;
  final bool news;
  final bool conflicts;
  final bool satellites;

  const IntelligenceLayers({
    this.earthquakes = true,
    this.flights     = false,
    this.fires       = true,
    this.news        = true,
    this.conflicts   = true,
    this.satellites  = false,
  });

  IntelligenceLayers copyWith({
    bool? earthquakes, bool? flights, bool? fires,
    bool? news, bool? conflicts, bool? satellites,
  }) => IntelligenceLayers(
    earthquakes: earthquakes ?? this.earthquakes,
    flights:     flights     ?? this.flights,
    fires:       fires       ?? this.fires,
    news:        news        ?? this.news,
    conflicts:   conflicts   ?? this.conflicts,
    satellites:  satellites  ?? this.satellites,
  );
}

final intelligenceLayersProvider =
    StateProvider<IntelligenceLayers>((_) => const IntelligenceLayers());

// ── Data providers ────────────────────────────────────────────────────────────

final earthquakesProvider = FutureProvider<List<EarthquakeEvent>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.earthquakes) return [];
  return ref.watch(osirisClientProvider).getEarthquakes();
});

final flightsProvider = FutureProvider<List<FlightState>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.flights) return [];
  return ref.watch(osirisClientProvider).getFlights();
});

final firesProvider = FutureProvider<List<FireHotspot>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.fires) return [];
  return ref.watch(osirisClientProvider).getFires();
});

final conflictZonesProvider = FutureProvider<List<ConflictZone>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.conflicts) return [];
  return ref.watch(osirisClientProvider).getConflictZones();
});

final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.news) return [];
  return ref.watch(osirisClientProvider).getNews();
});
```

---

## 3.2 World Intelligence Screen

This **replaces** `WorldRadioScreen` in the Ambient tab. Radio functionality moves into it as one of the layers — the globe becomes a unified intelligence and radio map.

```dart
// lib/features/ambient/world_intelligence_screen.dart
// REPLACES: world_radio_screen.dart (which is now folded into this)
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/intelligence/intelligence_models.dart';
import '../../data/providers/intelligence_providers.dart';
import '../../data/providers/ambient_providers.dart';
import '../../core/ambient/radio_service.dart';
import 'models/radio_models.dart';
import 'recon_panel.dart';

class WorldIntelligenceScreen extends ConsumerStatefulWidget {
  const WorldIntelligenceScreen({super.key});

  @override
  ConsumerState<WorldIntelligenceScreen> createState() =>
      _WorldIntelligenceScreenState();
}

class _WorldIntelligenceScreenState
    extends ConsumerState<WorldIntelligenceScreen> {
  final _mapController = MapController();
  final _searchCtrl    = TextEditingController();
  bool _showRecon      = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh active layers every 90 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshActiveLayers(),
    );
  }

  void _refreshActiveLayers() {
    ref.invalidate(earthquakesProvider);
    ref.invalidate(flightsProvider);
    ref.invalidate(firesProvider);
    ref.invalidate(conflictZonesProvider);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            const Text('🌐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('World Intelligence',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            // RECON panel toggle
            GestureDetector(
              onTap: () => setState(() => _showRecon = !_showRecon),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _showRecon
                      ? PocketClawTheme.lobsterRed.withOpacity(0.2)
                      : const Color(0xFF1A1525),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showRecon
                        ? PocketClawTheme.lobsterRed.withOpacity(0.6)
                        : const Color(0xFF2D2840),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.radar, size: 14,
                      color: _showRecon
                          ? PocketClawTheme.lobsterRed
                          : Colors.white38),
                  const SizedBox(width: 4),
                  Text('RECON',
                      style: TextStyle(
                          fontSize: 11,
                          color: _showRecon
                              ? PocketClawTheme.lobsterRed
                              : Colors.white38)),
                ]),
              ),
            ),
          ]),
        ),

        // ── RECON panel (collapsible) ───────────────────────────────────
        if (_showRecon)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: const ReconPanel(),
          ),

        // ── Layer toggles ───────────────────────────────────────────────
        _LayerToggleRow(),

        const SizedBox(height: 8),

        // ── Map ─────────────────────────────────────────────────────────
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _IntelligenceMap(mapController: _mapController),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Layer toggle row ──────────────────────────────────────────────────────────

class _LayerToggleRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(intelligenceLayersProvider);
    final notifier = ref.read(intelligenceLayersProvider.notifier);

    final toggles = [
      (emoji: '🌍', label: 'Seismic',   active: layers.earthquakes,
       toggle: () => notifier.state = layers.copyWith(earthquakes: !layers.earthquakes)),
      (emoji: '✈️', label: 'Flights',   active: layers.flights,
       toggle: () => notifier.state = layers.copyWith(flights: !layers.flights)),
      (emoji: '🔥', label: 'Fires',     active: layers.fires,
       toggle: () => notifier.state = layers.copyWith(fires: !layers.fires)),
      (emoji: '⚔️', label: 'Conflict', active: layers.conflicts,
       toggle: () => notifier.state = layers.copyWith(conflicts: !layers.conflicts)),
      (emoji: '📡', label: 'News',      active: layers.news,
       toggle: () => notifier.state = layers.copyWith(news: !layers.news)),
      (emoji: '🛰️', label: 'Sat',      active: layers.satellites,
       toggle: () => notifier.state = layers.copyWith(satellites: !layers.satellites)),
    ];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: toggles.length,
        itemBuilder: (_, i) {
          final t = toggles[i];
          return GestureDetector(
            onTap: t.toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: t.active
                    ? PocketClawTheme.electricTeal.withOpacity(0.15)
                    : const Color(0xFF1A1525),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: t.active
                      ? PocketClawTheme.electricTeal.withOpacity(0.5)
                      : const Color(0xFF2D2840),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(t.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: t.active
                            ? PocketClawTheme.electricTeal
                            : Colors.white38)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Intelligence Map ──────────────────────────────────────────────────────────

class _IntelligenceMap extends ConsumerWidget {
  final MapController mapController;
  const _IntelligenceMap({required this.mapController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earthquakes  = ref.watch(earthquakesProvider).valueOrNull ?? [];
    final flights      = ref.watch(flightsProvider).valueOrNull ?? [];
    final fires        = ref.watch(firesProvider).valueOrNull ?? [];
    final conflicts    = ref.watch(conflictZonesProvider).valueOrNull ?? [];
    final news         = ref.watch(newsProvider).valueOrNull ?? [];
    final radioService = ref.watch(radioServiceProvider);
    final radioPlaces  = ref.watch(radioPlacesProvider).valueOrNull ?? [];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: const LatLng(-28.0, 25.0), // South Africa default
        initialZoom: 3.0,
        maxZoom: 12,
        minZoom: 1.5,
      ),
      children: [
        // ── Base tile layer ──────────────────────────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.carmenlabs.clawcommander',
        ),

        // ── Fire hotspots ────────────────────────────────────────────
        MarkerLayer(
          markers: fires.map((f) => Marker(
            point: f.position,
            width: 14, height: 14,
            child: GestureDetector(
              onTap: () => _showFireDetail(context, f),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.orange.withOpacity(0.5), blurRadius: 4)],
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 8)),
                ),
              ),
            ),
          )).toList(),
        ),

        // ── Earthquakes ───────────────────────────────────────────────
        MarkerLayer(
          markers: earthquakes.map((eq) => Marker(
            point: eq.position,
            width: 20 + eq.magnitude * 3,
            height: 20 + eq.magnitude * 3,
            child: GestureDetector(
              onTap: () => _showEarthquakeDetail(context, eq),
              child: Container(
                decoration: BoxDecoration(
                  color: _earthquakeColor(eq.magnitude).withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _earthquakeColor(eq.magnitude), width: 1.5),
                ),
                child: Center(
                  child: Text(eq.magnitude.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 8, color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          )).toList(),
        ),

        // ── Conflict zones ────────────────────────────────────────────
        MarkerLayer(
          markers: conflicts.map((z) => Marker(
            point: z.position,
            width: 28, height: 28,
            child: GestureDetector(
              onTap: () => _showConflictDetail(context, z),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.6), width: 1.5),
                ),
                child: Center(
                  child: Text(z.emoji, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
          )).toList(),
        ),

        // ── Flights ───────────────────────────────────────────────────
        MarkerLayer(
          markers: flights.take(200).map((f) {
            final pos = f.position;
            if (pos == null) return null;
            return Marker(
              point: pos,
              width: 14, height: 14,
              child: Transform.rotate(
                angle: (f.heading ?? 0) * 3.14159 / 180,
                child: const Icon(Icons.flight, size: 12,
                    color: Colors.cyanAccent),
              ),
            );
          }).whereType<Marker>().toList(),
        ),

        // ── News dots ──────────────────────────────────────────────────
        MarkerLayer(
          markers: news.where((n) => n.position != null).map((n) => Marker(
            point: n.position!,
            width: 16, height: 16,
            child: GestureDetector(
              onTap: () => _showNewsDetail(context, n),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('📡', style: TextStyle(fontSize: 8)),
                ),
              ),
            ),
          )).toList(),
        ),

        // ── Radio station dots (preserved from Radio Globe) ───────────
        MarkerLayer(
          markers: radioPlaces.take(500).map((place) => Marker(
            point: LatLng(place.latitude, place.longitude),
            width: 8, height: 8,
            child: GestureDetector(
              onTap: () => _onRadioPlaceTap(context, ref, place, radioService),
              child: Container(
                decoration: BoxDecoration(
                  color: PocketClawTheme.electricTeal.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Color _earthquakeColor(double mag) {
    if (mag >= 7.0) return Colors.red;
    if (mag >= 5.5) return Colors.orange;
    if (mag >= 4.0) return Colors.yellow;
    return Colors.green;
  }

  void _showEarthquakeDetail(BuildContext context, EarthquakeEvent eq) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _DetailSheet(
        title: '${eq.severityEmoji} M${eq.magnitude.toStringAsFixed(1)} Earthquake',
        lines: [
          'Location: ${eq.place}',
          'Depth: ${eq.depth.toStringAsFixed(0)} km',
          'Time: ${_formatTime(eq.time)}',
        ],
      ),
    );
  }

  void _showFireDetail(BuildContext context, FireHotspot f) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _DetailSheet(
        title: '🔥 Active Fire Hotspot',
        lines: [
          'Brightness: ${f.brightness.toStringAsFixed(0)} K',
          'Confidence: ${f.confidence.toStringAsFixed(0)}%',
          'Coordinates: ${f.position.latitude.toStringAsFixed(2)}, ${f.position.longitude.toStringAsFixed(2)}',
        ],
      ),
    );
  }

  void _showConflictDetail(BuildContext context, ConflictZone z) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _DetailSheet(
        title: '${z.emoji} ${z.name}',
        lines: [
          'Severity: ${z.severity.replaceAll("_", " ")}',
          if (z.description != null) z.description!,
        ],
      ),
    );
  }

  void _showNewsDetail(BuildContext context, NewsItem n) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _DetailSheet(
        title: '📡 ${n.source}',
        lines: [n.title],
      ),
    );
  }

  void _onRadioPlaceTap(BuildContext context, WidgetRef ref,
      dynamic place, RadioService service) async {
    final channels = await service.getChannelsForPlace(place.id);
    if (!context.mounted || channels.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RadioStationSheet(
        place: place,
        channels: channels,
        onPlay: (ch) => service.play(ch),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

---

## 3.3 RECON Panel Widget

```dart
// lib/features/ambient/recon_panel.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../core/intelligence/osiris_client.dart';

enum _ReconMode { dns, whois, ip, ssl, cve }

class ReconPanel extends ConsumerStatefulWidget {
  const ReconPanel({super.key});

  @override
  ConsumerState<ReconPanel> createState() => _ReconPanelState();
}

class _ReconPanelState extends State<ReconPanel> {
  _ReconMode _mode = _ReconMode.dns;
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(OsirisClient client) async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;

    setState(() { _loading = true; _result = null; _error = null; });

    try {
      Map<String, dynamic> data;
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
          final cves = await client.cveLookup(input);
          data = {'vulnerabilities': cves, 'total': cves.length};
      }
      setState(() { _result = _format(data); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _format(Map<String, dynamic> data) {
    if (_mode == _ReconMode.cve) {
      final vulns = data['vulnerabilities'] as List? ?? [];
      if (vulns.isEmpty) return 'No CVEs found';
      return vulns.take(5).map((v) {
        final id   = v['cve']?['id'] ?? v['id'] ?? '';
        final desc = (v['cve']?['descriptions'] as List?)
            ?.firstWhere((d) => d['lang'] == 'en', orElse: () => {'value': ''})
            ['value'] ?? '';
        return '$id\n${desc.length > 100 ? "${desc.substring(0,97)}…" : desc}';
      }).join('\n\n');
    }
    return data.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .take(12)
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (_, ref, __) {
      final client = ref.watch(osirisClientProvider);
      final osirisOk = ref.watch(osirisReachableProvider).valueOrNull ?? false;

      return Card(
        color: const Color(0xFF12101A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: PocketClawTheme.lobsterRed.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.radar,
                    size: 14, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text('RECON Toolkit',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.redAccent)),
                const Spacer(),
                if (!osirisOk)
                  Text('OFFLINE',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, color: Colors.white24)),
              ]),
              const SizedBox(height: 8),

              // Mode selector
              Wrap(
                spacing: 4,
                children: _ReconMode.values.map((mode) {
                  final labels = {
                    _ReconMode.dns: 'DNS',
                    _ReconMode.whois: 'WHOIS',
                    _ReconMode.ip: 'IP',
                    _ReconMode.ssl: 'SSL',
                    _ReconMode.cve: 'CVE',
                  };
                  return ChoiceChip(
                    label: Text(labels[mode]!,
                        style: const TextStyle(fontSize: 10)),
                    selected: _mode == mode,
                    selectedColor: PocketClawTheme.lobsterRed.withOpacity(0.2),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onSelected: (_) => setState(() => _mode = mode),
                  );
                }).toList(),
              ),

              const SizedBox(height: 8),

              // Input + run
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: _hint(_mode),
                      hintStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: Colors.white24),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2D2840))),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _run(client),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: (_loading || !osirisOk)
                        ? null
                        : () => _run(client),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PocketClawTheme.lobsterRed,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: _loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('RUN',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                  ),
                ),
              ]),

              // Result
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 11)),
              ] else if (_result != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: _result!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0B1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2D2840)),
                    ),
                    child: SelectableText(
                      _result!,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 10, color: Colors.white70, height: 1.5),
                    ),
                  ),
                ),
                Text('Long-press to copy',
                    style: const TextStyle(fontSize: 9, color: Colors.white24)),
              ],
            ],
          ),
        ),
      );
    });
  }

  String _hint(_ReconMode m) => switch (m) {
    _ReconMode.dns   => 'example.com',
    _ReconMode.whois => 'example.com or 8.8.8.8',
    _ReconMode.ip    => '8.8.8.8',
    _ReconMode.ssl   => 'example.com',
    _ReconMode.cve   => 'CVE-2024-1234 or nginx',
  };
}

// Simple detail sheet shared by map markers
class _DetailSheet extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _DetailSheet({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Reused radio station sheet from original WorldRadioScreen
class _RadioStationSheet extends StatelessWidget {
  final dynamic place;
  final List<dynamic> channels;
  final void Function(dynamic) onPlay;
  const _RadioStationSheet({
      required this.place, required this.channels, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Text('📻', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(place.country,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            const Spacer(),
            Text('${channels.length} stations',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            itemCount: channels.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              leading: const Icon(Icons.radio, size: 18, color: Colors.white38),
              title: Text(channels[i].title,
                  style: const TextStyle(fontSize: 13)),
              trailing: const Icon(Icons.play_arrow_outlined, size: 18),
              onTap: () { Navigator.pop(context); onPlay(channels[i]); },
            ),
          ),
        ),
      ]),
    );
  }
}
```

---

## 3.4 Settings Screen — Add Osiris URL

In `lib/features/settings/settings_screen.dart`, add under the SSH settings tile:

```dart
ListTile(
  leading: const Icon(Icons.radar),
  title: const Text('Osiris Intelligence'),
  subtitle: Consumer(builder: (_, ref, __) {
    final ok = ref.watch(osirisReachableProvider).valueOrNull ?? false;
    return Text(
      ok ? 'Online · http://100.78.70.2:3001' : 'Offline — deploy on VPS',
      style: TextStyle(
        fontSize: 12,
        color: ok ? PocketClawTheme.electricTeal : Colors.white38,
      ),
    );
  }),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => _showOsirisSettings(context),
),
```

---

## 4. Update Ambient Screen

Replace `WorldRadioScreen` with `WorldIntelligenceScreen` in `ambient_screen.dart`:

```dart
// In ambient_screen.dart — replace WorldRadioScreen import and usage:
import 'world_intelligence_screen.dart';

// In the SliverFillRemaining:
const SliverFillRemaining(
  hasScrollBody: true,
  child: WorldIntelligenceScreen(),  // was: WorldRadioScreen()
),
```

---

## 5. New Files Summary

```
lib/core/intelligence/
├── osiris_client.dart             ← HTTP client for all Osiris API endpoints
└── intelligence_models.dart       ← EarthquakeEvent, FlightState, FireHotspot,
                                      NewsItem, ConflictZone, SatellitePosition

lib/data/providers/
└── intelligence_providers.dart    ← Layer toggle state + data FutureProviders

lib/features/ambient/
├── world_intelligence_screen.dart ← Replaces world_radio_screen.dart
└── recon_panel.dart               ← DNS/WHOIS/SSL/IP/CVE RECON UI
```

## 6. Changed Files

| File | Change |
|---|---|
| `lib/core/tools/tool_registry.dart` | Add 8 new RECON + intelligence tools |
| `lib/core/tools/tool_executor.dart` | Handle all new tool cases + format helpers |
| `lib/features/ambient/ambient_screen.dart` | Replace WorldRadioScreen with WorldIntelligenceScreen |
| `lib/features/settings/settings_screen.dart` | Add Osiris URL tile |

---

## 7. Implementation Order

| Step | Task | Time |
|---|---|---|
| 1 | Deploy Osiris on VPS via Docker | 30 min |
| 2 | Run health check — verify all endpoints | 20 min |
| 3 | Wire Osiris to Hermes MCP config | 20 min |
| 4 | Create `intelligence_models.dart` | 30 min |
| 5 | Create `osiris_client.dart` + providers | 45 min |
| 6 | Test client from Flutter against live VPS | 20 min |
| 7 | Add 8 tools to `tool_registry.dart` | 30 min |
| 8 | Add all tool cases to `tool_executor.dart` | 1.5 hours |
| 9 | Test RECON tools via Hermes chat: "dns_lookup google.com" | 20 min |
| 10 | Create `intelligence_providers.dart` | 20 min |
| 11 | Create `world_intelligence_screen.dart` | 2 hours |
| 12 | Create `recon_panel.dart` | 1 hour |
| 13 | Replace WorldRadioScreen in `ambient_screen.dart` | 15 min |
| 14 | Add Osiris Settings tile | 15 min |
| 15 | Full end-to-end test on physical device | 30 min |

**Total: 4 days**

---

*CARMEN PTY LTD — ClawCommander × Osiris Integration Spec v1.0*  
*Source: simplifaisoul/osiris (MIT) — 2026-05-14*
