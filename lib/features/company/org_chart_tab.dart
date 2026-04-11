/// Org Chart tab — simple ListView of agent names/roles from Paperclip
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../data/providers/paperclip_provider.dart';
import '../../shared/widgets/empty_state.dart';

class OrgChartTab extends ConsumerWidget {
  const OrgChartTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperclipProvider);

    if (!state.isConnected) {
      return const EmptyState(
        icon: Icons.cloud_off,
        message: 'Not connected to Paperclip.',
      );
    }

    final members = state.orgChart;
    if (members.isEmpty) {
      return const EmptyState(
        icon: Icons.account_tree_outlined,
        message: 'No organisation members found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: member.isAgent
                  ? PocketClawTheme.lobsterRed.withAlpha(40)
                  : PocketClawTheme.electricTeal.withAlpha(40),
              child: Icon(
                member.isAgent ? Icons.smart_toy : Icons.person,
                color: member.isAgent
                    ? PocketClawTheme.lobsterRed
                    : PocketClawTheme.electricTeal,
                size: 20,
              ),
            ),
            title: Text(
              member.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.role,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                if (member.department != null)
                  Text(
                    member.department!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
              ],
            ),
            trailing: member.reportsTo != null
                ? Tooltip(
                    message: 'Reports to: ${member.reportsTo}',
                    child: const Icon(
                      Icons.subdirectory_arrow_left,
                      size: 16,
                      color: Colors.white24,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
