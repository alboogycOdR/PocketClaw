/// VPS System Monitor — live CPU/RAM/disk/services/top-process panel
/// pulled over the existing pooled SSH connection. Power User Feature
/// Pack §3.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/ssh/hermes_ssh_client.dart';
import '../../data/providers/ssh_providers.dart';

// ── Data models ─────────────────────────────────────────────────────────────

class VpsStats {
  final double cpuLoad1m;
  final double cpuLoad5m;
  final double cpuLoad15m;
  final int ramTotalMb;
  final int ramUsedMb;
  final int ramFreeMb;
  final int diskTotalGb;
  final int diskUsedGb;
  final String uptime;
  final Map<String, bool> services;
  final List<ProcessInfo> topProcesses;
  final DateTime capturedAt;

  const VpsStats({
    required this.cpuLoad1m,
    required this.cpuLoad5m,
    required this.cpuLoad15m,
    required this.ramTotalMb,
    required this.ramUsedMb,
    required this.ramFreeMb,
    required this.diskTotalGb,
    required this.diskUsedGb,
    required this.uptime,
    required this.services,
    required this.topProcesses,
    required this.capturedAt,
  });

  double get ramPercent => ramTotalMb > 0 ? ramUsedMb / ramTotalMb : 0;
  double get diskPercent => diskTotalGb > 0 ? diskUsedGb / diskTotalGb : 0;
}

class ProcessInfo {
  final String user;
  final String pid;
  final double cpu;
  final double mem;
  final String command;
  const ProcessInfo({
    required this.user,
    required this.pid,
    required this.cpu,
    required this.mem,
    required this.command,
  });
}

// ── Monitor provider ────────────────────────────────────────────────────────

final vpsStatsProvider = FutureProvider.autoDispose<VpsStats>((ref) async {
  final client = await ref.watch(sshClientProvider.future);
  if (client == null) {
    throw Exception('SSH not configured');
  }
  return _fetchStats(client);
});

Future<VpsStats> _fetchStats(HermesSshClient client) async {
  // Six exec calls. dartssh2 multiplexes channels, and HermesSshClient
  // already closes each channel — so running them sequentially is the
  // most channel-friendly approach (parallel can collide with the per-
  // session MaxSessions cap on busy gateways).
  final loadavg = await client.exec('cat /proc/loadavg');
  final meminfo = await client.exec(
    'grep -E "^(MemTotal|MemFree|MemAvailable):" /proc/meminfo',
  );
  final df = await client.exec('df -BG / | tail -1');
  final uptime = await client.exec('uptime -p');
  // `is-active` always exits 0 here because of the trailing `true`.
  final services = await client.exec(
    'systemctl --user is-active openclaw-gateway hermes paperclip osiris '
    '2>/dev/null; true',
  );
  final psOut = await client.exec(
    "ps -eo user:20,pid,pcpu,pmem,comm --sort=-pcpu --no-headers | head -6",
  );

  return _parse(
    loadavg: loadavg,
    meminfo: meminfo,
    df: df,
    uptime: uptime,
    services: services,
    psOut: psOut,
  );
}

VpsStats _parse({
  required String loadavg,
  required String meminfo,
  required String df,
  required String uptime,
  required String services,
  required String psOut,
}) {
  // Load average
  final loads = loadavg.trim().split(RegExp(r'\s+'));
  final load1 = double.tryParse(loads.isNotEmpty ? loads[0] : '0') ?? 0;
  final load5 = double.tryParse(loads.length > 1 ? loads[1] : '0') ?? 0;
  final load15 = double.tryParse(loads.length > 2 ? loads[2] : '0') ?? 0;

  // Memory
  int ramTotal = 0, ramFree = 0, ramAvailable = 0;
  for (final line in meminfo.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final kb = int.tryParse(parts[1]) ?? 0;
    if (line.startsWith('MemTotal')) ramTotal = kb ~/ 1024;
    if (line.startsWith('MemFree')) ramFree = kb ~/ 1024;
    if (line.startsWith('MemAvailable')) ramAvailable = kb ~/ 1024;
  }
  final ramUsed = (ramTotal - ramAvailable).clamp(0, ramTotal);

  // Disk
  final diskParts = df.trim().split(RegExp(r'\s+'));
  final diskTotal = int.tryParse(
        diskParts.length > 1 ? diskParts[1].replaceAll('G', '') : '0',
      ) ??
      0;
  final diskUsed = int.tryParse(
        diskParts.length > 2 ? diskParts[2].replaceAll('G', '') : '0',
      ) ??
      0;

  // Services
  const serviceNames = ['openclaw', 'hermes', 'paperclip', 'osiris'];
  final serviceLines = services.trim().split('\n');
  final servicesMap = <String, bool>{};
  for (var i = 0; i < serviceNames.length; i++) {
    final line = i < serviceLines.length ? serviceLines[i].trim() : '';
    servicesMap[serviceNames[i]] = line == 'active';
  }

  // Top processes
  final procs = <ProcessInfo>[];
  for (final line in psOut.trim().split('\n')) {
    if (line.isEmpty) continue;
    final p = line.trim().split(RegExp(r'\s+'));
    if (p.length < 5) continue;
    procs.add(
      ProcessInfo(
        user: p[0],
        pid: p[1],
        cpu: double.tryParse(p[2]) ?? 0,
        mem: double.tryParse(p[3]) ?? 0,
        command: p.sublist(4).join(' '),
      ),
    );
  }

  return VpsStats(
    cpuLoad1m: load1,
    cpuLoad5m: load5,
    cpuLoad15m: load15,
    ramTotalMb: ramTotal,
    ramUsedMb: ramUsed,
    ramFreeMb: ramFree,
    diskTotalGb: diskTotal,
    diskUsedGb: diskUsed,
    uptime: uptime.trim().replaceFirst('up ', ''),
    services: servicesMap,
    topProcesses: procs,
    capturedAt: DateTime.now(),
  );
}

// ── Screen ──────────────────────────────────────────────────────────────────

class VpsMonitorScreen extends ConsumerStatefulWidget {
  const VpsMonitorScreen({super.key});
  @override
  ConsumerState<VpsMonitorScreen> createState() => _VpsMonitorScreenState();
}

class _VpsMonitorScreenState extends ConsumerState<VpsMonitorScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.invalidate(vpsStatsProvider),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(vpsStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'VPS Monitor',
          style: GoogleFonts.jetBrainsMono(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal, size: 18),
            tooltip: 'Open Terminal',
            onPressed: () => context.push('/terminal'),
          ),
          statsAsync.whenOrNull(
                data: (s) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      'Updated ${_ago(s.capturedAt)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: statsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: Colors.white24,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cannot reach VPS\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(vpsStatsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                title: 'CPU Load Average',
                children: [
                  Row(
                    children: [
                      _LoadGauge('1m', stats.cpuLoad1m),
                      const SizedBox(width: 12),
                      _LoadGauge('5m', stats.cpuLoad5m),
                      const SizedBox(width: 12),
                      _LoadGauge('15m', stats.cpuLoad15m),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Uptime',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white38,
                            ),
                          ),
                          Text(
                            stats.uptime,
                            style: GoogleFonts.jetBrainsMono(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Memory',
                children: [
                  _ProgressRow(
                    label: '${stats.ramUsedMb} MB / ${stats.ramTotalMb} MB',
                    value: stats.ramPercent,
                    color: stats.ramPercent > 0.85
                        ? Colors.red
                        : stats.ramPercent > 0.65
                            ? Colors.amber
                            : const Color(0xFF3FB950),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Disk (/)',
                children: [
                  _ProgressRow(
                    label: '${stats.diskUsedGb} GB / ${stats.diskTotalGb} GB',
                    value: stats.diskPercent,
                    color: stats.diskPercent > 0.9
                        ? Colors.red
                        : stats.diskPercent > 0.75
                            ? Colors.amber
                            : const Color(0xFF3FB950),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Services',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stats.services.entries
                        .map(
                          (e) => _ServiceChip(name: e.key, running: e.value),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Top Processes (by CPU)',
                children: [
                  ...stats.topProcesses.map(
                    (p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              p.command,
                              style:
                                  GoogleFonts.jetBrainsMono(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CPU ${p.cpu.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF58A6FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MEM ${p.mem.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3FB950),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'PID ${p.pid}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final s = DateTime.now().difference(dt).inSeconds;
    return s < 60 ? '${s}s ago' : '${s ~/ 60}m ago';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF8B949E),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}

class _LoadGauge extends StatelessWidget {
  final String label;
  final double value;
  const _LoadGauge(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value.toStringAsFixed(2),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: value > 2
                  ? Colors.red
                  : value > 1
                      ? Colors.amber
                      : const Color(0xFF3FB950),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ],
      );
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: value,
            backgroundColor: const Color(0xFF21262D),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      );
}

class _ServiceChip extends StatelessWidget {
  final String name;
  final bool running;
  const _ServiceChip({required this.name, required this.running});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: running
              ? const Color(0xFF3FB950).withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: running
                ? const Color(0xFF3FB950).withValues(alpha: 0.5)
                : Colors.red.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: running ? const Color(0xFF3FB950) : Colors.red,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                color: running ? const Color(0xFF3FB950) : Colors.red,
              ),
            ),
          ],
        ),
      );
}
