/// Cost tracking with period selector and charts
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/models/usage_stats.dart';
import '../../data/providers/core_providers.dart';
import '../../shared/extensions.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/stat_card.dart';
import 'mission_control_providers.dart';

class CostScreen extends ConsumerStatefulWidget {
  const CostScreen({super.key});

  @override
  ConsumerState<CostScreen> createState() => _CostScreenState();
}

enum _Period { daily, weekly, monthly }

class _CostScreenState extends ConsumerState<CostScreen> {
  _Period _selectedPeriod = _Period.daily;

  @override
  Widget build(BuildContext context) {
    final restClient = ref.watch(gatewayRestClientProvider);
    final usageAsync = ref.watch(mcUsageProvider);

    if (restClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cost Tracking')),
        body: const EmptyState(
          icon: Icons.cloud_off,
          message: 'Not connected to Gateway',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.invalidate(mcUsageProvider),
          ),
        ],
      ),
      body: usageAsync.when(
        data: (usage) => _buildContent(usage),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: 'Failed to load usage data\n$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(mcUsageProvider),
        ),
      ),
    );
  }

  Widget _buildContent(UsageStats usage) {
    final periodCost = switch (_selectedPeriod) {
      _Period.daily => usage.costToday,
      _Period.weekly => usage.costWeek,
      _Period.monthly => usage.costMonth,
    };

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mcUsageProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          Row(
            children: _Period.values.map((p) {
              final selected = p == _selectedPeriod;
              final label = switch (p) {
                _Period.daily => 'Daily',
                _Period.weekly => 'Weekly',
                _Period.monthly => 'Monthly',
              };
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: p == _Period.daily ? 0 : 4,
                    right: p == _Period.monthly ? 0 : 4,
                  ),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedPeriod = p),
                    selectedColor: PocketClawTheme.lobsterRed.withAlpha(40),
                    labelStyle: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: selected
                          ? PocketClawTheme.lobsterRed
                          : Colors.white54,
                    ),
                    showCheckmark: false,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Total cost card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Total Spend',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    periodCost.asCurrency,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Token summary
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.arrow_downward,
                  title: 'Input',
                  value: '${(usage.inputTokens / 1000).toStringAsFixed(1)}k',
                  subtitle: 'tokens',
                  iconColor: PocketClawTheme.electricTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  icon: Icons.arrow_upward,
                  title: 'Output',
                  value: '${(usage.outputTokens / 1000).toStringAsFixed(1)}k',
                  subtitle: 'tokens',
                  iconColor: const Color(0xFFFFB74D),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Cost by Model pie chart
          _SectionTitle(title: 'Cost by Model'),
          const SizedBox(height: 12),
          _buildPieChart(usage.costByModel),

          const SizedBox(height: 24),

          // Cost by Agent pie chart
          _SectionTitle(title: 'Cost by Agent'),
          const SizedBox(height: 12),
          _buildPieChart(usage.costByAgent),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    final nonZero = Map.fromEntries(
      data.entries.where((e) => e.value > 0),
    );

    if (nonZero.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No cost data',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      );
    }

    final colors = [
      PocketClawTheme.lobsterRed,
      PocketClawTheme.electricTeal,
      const Color(0xFFFFB74D),
      const Color(0xFF7C4DFF),
      const Color(0xFF4CAF50),
      const Color(0xFFFF7043),
    ];

    final entries = nonZero.entries.toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: entries.asMap().entries.map((e) {
                    final idx = e.key;
                    final entry = e.value;
                    return PieChartSectionData(
                      value: entry.value,
                      title: entry.value.asCurrency,
                      color: colors[idx % colors.length],
                      radius: 50,
                      titleStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 30,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[idx % colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white70,
          ),
    );
  }
}
