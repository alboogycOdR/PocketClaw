/// Governance draft provider — reads drafts from paperclipProvider
/// and provides create/update actions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paperclip_state.dart';
import 'paperclip_provider.dart';

/// Read-only view of governance drafts from the Paperclip state.
final governanceDraftsProvider = Provider<List<GovernanceDraft>>((ref) {
  final state = ref.watch(paperclipProvider);
  return state.governanceDrafts;
});

/// Filtered drafts by status.
final governanceDraftsByStatusProvider =
    Provider.family<List<GovernanceDraft>, String>((ref, status) {
  final drafts = ref.watch(governanceDraftsProvider);
  return drafts.where((d) => d.status == status).toList();
});
