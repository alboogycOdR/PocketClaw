/// Riverpod surface for Hermes channels. Reads the four channel
/// blocks from `~/.hermes/config.yaml` over SSH + checks `~/.hermes/.env`
/// for bot-token presence per channel. Writes go through
/// `HermesDataService.saveChannelSettings`, which uses `yaml_edit`
/// to preserve comments / formatting on the rest of the file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hermes/models/hermes_channel.dart';
import 'hermes_data_providers.dart';

final hermesChannelsProvider =
    FutureProvider<HermesChannelsBundle>((ref) async {
  final svc = await ref.watch(hermesDataServiceProvider.future);
  if (svc == null) {
    return const HermesChannelsBundle(channels: []);
  }
  return svc.getChannelsBundle();
});
