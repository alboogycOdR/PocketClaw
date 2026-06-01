library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/intelligence/intelligence_models.dart';
import '../../core/intelligence/osiris_client.dart';
import '../../features/ambient/models/radio_models.dart';
import 'ambient_providers.dart';
import 'core_providers.dart';

class IntelligenceLayers {
  final bool earthquakes;
  final bool flights;
  final bool fires;
  final bool news;
  final bool conflicts;
  final bool satellites;
  final bool radio;
  final bool maritime;
  final bool weather;

  const IntelligenceLayers({
    this.earthquakes = true,
    this.flights = false,
    this.fires = true,
    this.news = true,
    this.conflicts = true,
    this.satellites = false,
    this.radio = true,
    this.maritime = false,
    this.weather = false,
  });

  IntelligenceLayers copyWith({
    bool? earthquakes,
    bool? flights,
    bool? fires,
    bool? news,
    bool? conflicts,
    bool? satellites,
    bool? radio,
    bool? maritime,
    bool? weather,
  }) => IntelligenceLayers(
    earthquakes: earthquakes ?? this.earthquakes,
    flights: flights ?? this.flights,
    fires: fires ?? this.fires,
    news: news ?? this.news,
    conflicts: conflicts ?? this.conflicts,
    satellites: satellites ?? this.satellites,
    radio: radio ?? this.radio,
    maritime: maritime ?? this.maritime,
    weather: weather ?? this.weather,
  );
}

final osirisBaseUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('osiris_base_url') ?? '';
});

final osirisClientProvider = Provider<OsirisClient?>((ref) {
  final url = ref.watch(osirisBaseUrlProvider).trim();
  if (url.isEmpty) return null;
  return OsirisClient(baseUrl: url);
});

final osirisReachableProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return false;
  return client.isReachable();
});

final osirisEarthquakesProvider = FutureProvider<List<EarthquakeEvent>>((
  ref,
) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getEarthquakes();
});

final osirisFlightsProvider = FutureProvider<List<FlightState>>((ref) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getFlights();
});

final osirisFiresProvider = FutureProvider<List<FireHotspot>>((ref) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getFires();
});

final osirisNewsProvider = FutureProvider<List<NewsItem>>((ref) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getNews();
});

final osirisConflictZonesProvider = FutureProvider<List<ConflictZone>>((
  ref,
) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getConflictZones();
});

final osirisSatellitesProvider = FutureProvider<List<SatellitePosition>>((
  ref,
) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getSatellites();
});

final osirisMaritimePortsProvider = FutureProvider<List<MaritimePort>>((ref) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getMaritimePorts();
});

final osirisMaritimeChokepointsProvider =
    FutureProvider<List<MaritimeChokepoint>>((ref) async {
      final client = ref.watch(osirisClientProvider);
      if (client == null) return const [];
      return client.getMaritimeChokepoints();
    });

final osirisWeatherEventsProvider = FutureProvider<List<WeatherEvent>>((ref) async {
  final client = ref.watch(osirisClientProvider);
  if (client == null) return const [];
  return client.getWeatherEvents();
});

final intelligenceLayersProvider = StateProvider<IntelligenceLayers>(
  (_) => const IntelligenceLayers(),
);

final earthquakesProvider = FutureProvider<List<EarthquakeEvent>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.earthquakes) return const [];
  return ref.watch(osirisEarthquakesProvider.future);
});

final flightsProvider = FutureProvider<List<FlightState>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.flights) return const [];
  return ref.watch(osirisFlightsProvider.future);
});

final firesProvider = FutureProvider<List<FireHotspot>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.fires) return const [];
  return ref.watch(osirisFiresProvider.future);
});

final newsProvider = FutureProvider<List<NewsItem>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.news) return const [];
  return ref.watch(osirisNewsProvider.future);
});

final conflictZonesProvider = FutureProvider<List<ConflictZone>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.conflicts) return const [];
  return ref.watch(osirisConflictZonesProvider.future);
});

final satellitesProvider = FutureProvider<List<SatellitePosition>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.satellites) return const [];
  return ref.watch(osirisSatellitesProvider.future);
});

final maritimePortsProvider = FutureProvider<List<MaritimePort>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.maritime) return const [];
  return ref.watch(osirisMaritimePortsProvider.future);
});

final maritimeChokepointsProvider =
    FutureProvider<List<MaritimeChokepoint>>((ref) async {
      final layers = ref.watch(intelligenceLayersProvider);
      if (!layers.maritime) return const [];
      return ref.watch(osirisMaritimeChokepointsProvider.future);
    });

final weatherEventsProvider = FutureProvider<List<WeatherEvent>>((ref) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.weather) return const [];
  return ref.watch(osirisWeatherEventsProvider.future);
});

final intelligenceRadioPlacesProvider = FutureProvider<List<RadioPlace>>((
  ref,
) async {
  final layers = ref.watch(intelligenceLayersProvider);
  if (!layers.radio) return const [];
  return ref.watch(radioPlacesProvider.future);
});

/// RECON-to-map handoff: set this to fly the World Intelligence map to a
/// location derived from a RECON IP lookup result.
class ReconMapFocus {
  final double lat;
  final double lon;
  final String label;
  final double zoom;

  const ReconMapFocus({
    required this.lat,
    required this.lon,
    required this.label,
    this.zoom = 6.0,
  });
}

final reconFocusProvider = StateProvider<ReconMapFocus?>((ref) => null);
