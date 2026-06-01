library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'core_providers.dart';

final agentMemoryBaseUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('agentmemory_base_url') ?? '';
});

final openNotebookBaseUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('opennotebook_base_url') ?? '';
});

final agentMemoryReachableProvider = FutureProvider<bool>((ref) async {
  final url = ref.watch(agentMemoryBaseUrlProvider).trim();
  if (url.isEmpty) return false;
  try {
    final response = await http
        .get(Uri.parse('$url/health'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
});

final openNotebookReachableProvider = FutureProvider<bool>((ref) async {
  final url = ref.watch(openNotebookBaseUrlProvider).trim();
  if (url.isEmpty) return false;
  try {
    final response = await http
        .get(Uri.parse('$url/api/notebooks'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
});

/// Pending text to prefill into the chat composer on next Chat tab visit.
/// The ChatScreen reads and clears this on initState / didChangeDependencies.
final pendingChatContextProvider = StateProvider<String?>((ref) => null);
