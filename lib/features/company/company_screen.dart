/// Company screen — seven tabs over the Paperclip REST API.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers/core_providers.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/connection_indicator.dart';
import '../../data/models/gateway_event.dart';
import 'budgets_tab.dart';
import 'goals_tab.dart';
import 'governance_tab.dart';
import 'org_chart_tab.dart';
import 'overview_tab.dart';
import 'security_dashboard_tab.dart';
import 'tickets_tab.dart';

class CompanyScreen extends ConsumerWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(paperclipRestClientProvider);
    final paperclipAsync = ref.watch(paperclipProvider);

    // Connection indicator tracks the Paperclip AsyncNotifier: loading means
    // we're trying, error means we failed, data with a resolved company
    // means we're up. Unconfigured ⇒ disconnected.
    final indicatorState = client == null
        ? GatewayState.disconnected
        : paperclipAsync.when(
            loading: () => GatewayState.connecting,
            error: (_, __) => GatewayState.error,
            data: (s) => s.configured
                ? GatewayState.connected
                : GatewayState.disconnected,
          );

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                'Company',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              ConnectionIndicator(state: indicatorState),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh',
              onPressed: () {
                ref.read(paperclipProvider.notifier).refresh();
                ref.invalidate(paperclipAgentsProvider);
                ref.invalidate(paperclipIssuesProvider);
                ref.invalidate(paperclipGoalsProvider);
                ref.invalidate(paperclipCostSummaryProvider);
                ref.invalidate(paperclipCostByAgentProvider);
                ref.invalidate(paperclipApprovalsProvider);
                ref.invalidate(paperclipActivityProvider);
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Org Chart'),
              Tab(text: 'Goals'),
              Tab(text: 'Budgets'),
              Tab(text: 'Tickets'),
              Tab(text: 'Governance'),
              Tab(text: 'Security'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OverviewTab(),
            OrgChartTab(),
            GoalsTab(),
            BudgetsTab(),
            TicketsTab(),
            GovernanceTab(),
            SecurityDashboardTab(),
          ],
        ),
      ),
    );
  }
}
