/// Hermes logs viewer — tails errors.log / gateway.log / agent.log over
/// SSH exec. SPEC-MultiTransport §11.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/hermes_data_providers.dart';
import '../../shared/widgets/empty_state.dart';

enum _LogKind { errors, gateway, agent }

enum _LogFilter { all, errors, warnings, info }

class HermesLogsTab extends ConsumerStatefulWidget {
  const HermesLogsTab({super.key});

  @override
  ConsumerState<HermesLogsTab> createState() => _HermesLogsTabState();
}

class _HermesLogsTabState extends ConsumerState<HermesLogsTab> {
  _LogKind _kind = _LogKind.errors;
  _LogFilter _filter = _LogFilter.all;

  ProviderListenable<AsyncValue<List<String>>> _provider() => switch (_kind) {
        _LogKind.errors => hermesErrorLogProvider,
        _LogKind.gateway => hermesGatewayLogProvider,
        _LogKind.agent => hermesAgentLogProvider,
      };

  void _invalidate() {
    switch (_kind) {
      case _LogKind.errors:
        ref.invalidate(hermesErrorLogProvider);
        break;
      case _LogKind.gateway:
        ref.invalidate(hermesGatewayLogProvider);
        break;
      case _LogKind.agent:
        ref.invalidate(hermesAgentLogProvider);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncLines = ref.watch(_provider());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_LogKind>(
                  segments: const [
                    ButtonSegment(
                      value: _LogKind.errors,
                      icon: Icon(Icons.error_outline, size: 14),
                      label: Text('Errors'),
                    ),
                    ButtonSegment(
                      value: _LogKind.gateway,
                      icon: Icon(Icons.hub_outlined, size: 14),
                      label: Text('Gateway'),
                    ),
                    ButtonSegment(
                      value: _LogKind.agent,
                      icon: Icon(Icons.smart_toy_outlined, size: 14),
                      label: Text('Agent'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) =>
                      setState(() => _kind = s.first),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _invalidate,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Wrap(
            spacing: 6,
            children: _LogFilter.values.map((f) {
              final selected = _filter == f;
              return FilterChip(
                label: Text(
                  switch (f) {
                    _LogFilter.all => 'All',
                    _LogFilter.errors => 'Errors',
                    _LogFilter.warnings => 'Warnings',
                    _LogFilter.info => 'Info',
                  },
                  style: const TextStyle(fontSize: 11),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: asyncLines.when(
            data: (allLines) {
              final lines = _filter == _LogFilter.all
                  ? allLines
                  : allLines.where((l) {
                      final lower = l.toLowerCase();
                      return switch (_filter) {
                        _LogFilter.errors =>
                          lower.contains('error') || lower.contains('fatal'),
                        _LogFilter.warnings => lower.contains('warn'),
                        _LogFilter.info => lower.contains('info'),
                        _LogFilter.all => true,
                      };
                    }).toList();
              if (lines.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _invalidate(),
                  child: ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: Icons.terminal,
                        message: _filter == _LogFilter.all
                            ? 'No log lines (or file is empty)'
                            : 'No ${_filter.name} lines in this log',
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _invalidate(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: lines.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: SelectableText(
                      lines[i],
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: _colorForLine(lines[i]),
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              message: 'Failed to read log: $e',
              actionLabel: 'Retry',
              onAction: _invalidate,
            ),
          ),
        ),
      ],
    );
  }

  Color _colorForLine(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('error') || lower.contains('fatal')) {
      return PocketClawTheme.lobsterRed;
    }
    if (lower.contains('warn')) return PocketClawTheme.warning;
    if (lower.contains('info')) return Colors.white70;
    return Colors.white60;
  }
}
