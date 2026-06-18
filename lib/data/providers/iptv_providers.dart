library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ambient/iptv_service.dart';
import '../../core/ambient/tv_database.dart';
import '../../features/ambient/models/tv_channel.dart';
import '../../features/ambient/models/tv_epg.dart';
import 'core_providers.dart';

final iptvChannelsProvider = FutureProvider<List<TvChannel>>((ref) async {
  final prefs = ref.watch(sharedPrefsProvider);
  return iptvService.getChannels(prefs);
});

final iptvGroupsProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(iptvChannelsProvider).whenData(iptvService.getGroups);
});

final iptvSelectedGroupProvider = StateProvider<String?>((ref) => null);
final iptvShowFavouritesProvider = StateProvider<bool>((ref) => false);
final activeTvChannelProvider = StateProvider<TvChannel?>((ref) => null);

final iptvFavouriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getFavouriteIds();
});

final iptvFavouriteChannelsProvider = FutureProvider<List<TvChannel>>((
  ref,
) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getFavourites();
});

final hiddenChannelsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getHiddenChannels();
});

final customChannelsProvider = FutureProvider<List<TvChannel>>((ref) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getCustomChannels();
});

final epgSourcesProvider = FutureProvider<List<TvEpgSource>>((ref) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getEpgSources();
});

final epgProgrammeCountProvider = FutureProvider<int>((ref) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getEpgProgrammeCount();
});

final epgMappingCountProvider = FutureProvider<int>((ref) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getEpgMappingCount();
});

final tvNowNextProvider = FutureProvider.family<TvNowNext?, TvChannel>((
  ref,
  channel,
) async {
  await tvDatabase.ensureReady();
  return tvDatabase.getNowNextForChannel(channel.id);
});
