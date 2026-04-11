/// Company screen with tabbed sub-sections reading from Paperclip
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final paperclip = ref.watch(paperclipProvider);

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
              ConnectionIndicator(
                state: paperclip.isConnected
                    ? GatewayState.connected
                    : GatewayState.disconnected,
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
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
