library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/hermes_commander_theme.dart';
import '../../core/ambient/radio_garden_service.dart';
import '../../core/intelligence/intelligence_models.dart';
import '../../data/providers/ambient_providers.dart';
import '../../data/providers/intelligence_providers.dart';
import '../ambient/models/favorite_station.dart';
import '../ambient/models/radio_models.dart';

class WorldIntelligenceScreen extends ConsumerStatefulWidget {
  const WorldIntelligenceScreen({super.key});

  @override
  ConsumerState<WorldIntelligenceScreen> createState() =>
      _WorldIntelligenceScreenState();
}

class _WorldIntelligenceScreenState
    extends ConsumerState<WorldIntelligenceScreen> {
  final MapController _mapController = MapController();
  Timer? _refreshTimer;
  _IntelMode _selectedMode = _IntelMode.overview;
  _FlightFilter _selectedFlightFilter = _FlightFilter.all;
  _MaritimeFilter _selectedMaritimeFilter = _MaritimeFilter.ports;
  _HazardFilter _selectedHazardFilter = _HazardFilter.earthquakes;
  _SurveillanceFilter _selectedSurveillanceFilter = _SurveillanceFilter.news;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshActiveLayers(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for RECON map focus and fly to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(reconFocusProvider, (_, next) {
        if (next != null && mounted) {
          _mapController.move(LatLng(next.lat, next.lon), next.zoom);
          setState(() {}); // triggers RECON marker repaint
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshActiveLayers() {
    ref.invalidate(earthquakesProvider);
    ref.invalidate(flightsProvider);
    ref.invalidate(firesProvider);
    ref.invalidate(newsProvider);
    ref.invalidate(conflictZonesProvider);
    ref.invalidate(satellitesProvider);
    ref.invalidate(maritimePortsProvider);
    ref.invalidate(maritimeChokepointsProvider);
    ref.invalidate(weatherEventsProvider);
    ref.invalidate(intelligenceRadioPlacesProvider);
  }

  void _activateMode(_IntelMode mode) {
    setState(() {
      _selectedMode = mode;
      if (mode != _IntelMode.aviation) {
        _selectedFlightFilter = _FlightFilter.all;
      }
      if (mode != _IntelMode.maritimeSpace) {
        _selectedMaritimeFilter = _MaritimeFilter.ports;
      }
      if (mode != _IntelMode.hazards) {
        _selectedHazardFilter = _HazardFilter.earthquakes;
      }
      if (mode != _IntelMode.surveillance) {
        _selectedSurveillanceFilter = _SurveillanceFilter.news;
      }
    });

    final notifier = ref.read(intelligenceLayersProvider.notifier);
    switch (mode) {
      case _IntelMode.overview:
        notifier.state = const IntelligenceLayers(
          earthquakes: true,
          flights: false,
          fires: true,
          news: true,
          conflicts: true,
          satellites: false,
          radio: true,
          maritime: false,
          weather: false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.global);
        });
      case _IntelMode.aviation:
        notifier.state = const IntelligenceLayers(
          earthquakes: false,
          flights: true,
          fires: false,
          news: false,
          conflicts: false,
          satellites: false,
          radio: false,
          maritime: false,
          weather: false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.flights);
        });
      case _IntelMode.maritimeSpace:
        notifier.state = const IntelligenceLayers(
          earthquakes: false,
          flights: false,
          fires: false,
          news: false,
          conflicts: false,
          satellites: true,
          radio: false,
          maritime: true,
          weather: false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.maritimePorts);
        });
      case _IntelMode.surveillance:
        notifier.state = const IntelligenceLayers(
          earthquakes: false,
          flights: false,
          fires: false,
          news: true,
          conflicts: false,
          satellites: false,
          radio: false,
          maritime: false,
          weather: false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.news);
        });
      case _IntelMode.hazards:
        notifier.state = const IntelligenceLayers(
          earthquakes: true,
          flights: false,
          fires: true,
          news: false,
          conflicts: false,
          satellites: false,
          radio: false,
          maritime: false,
          weather: true,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.earthquakes);
        });
      case _IntelMode.conflict:
        notifier.state = const IntelligenceLayers(
          earthquakes: false,
          flights: false,
          fires: false,
          news: false,
          conflicts: true,
          satellites: false,
          radio: false,
          maritime: false,
          weather: false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.conflicts);
        });
      case _IntelMode.radio:
        notifier.state = const IntelligenceLayers(
          earthquakes: false,
          flights: false,
          fires: false,
          news: false,
          conflicts: false,
          satellites: false,
          radio: true,
          maritime: false,
          weather: false,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusLayer(_MapFocus.radio);
        });
    }
    _refreshActiveLayers();
  }

  List<FlightState> _filterFlights(List<FlightState> flights) {
    if (_selectedFlightFilter == _FlightFilter.all) return flights;
    final wanted = switch (_selectedFlightFilter) {
      _FlightFilter.all => '',
      _FlightFilter.commercial => 'commercial',
      _FlightFilter.private => 'private',
      _FlightFilter.privateJets => 'jet',
      _FlightFilter.military => 'military',
    };
    return flights.where((flight) {
      final category = (flight.category ?? '').toLowerCase();
      if (wanted == 'jet') {
        return category == 'jet' ||
            category == 'private_jet' ||
            category == 'private jet';
      }
      return category == wanted;
    }).toList();
  }

  bool _isHighConflictSeverity(String severity) {
    final normalized = severity.toLowerCase().replaceAll('_', ' ');
    return normalized.contains('critical') ||
        normalized.contains('severe') ||
        normalized.contains('high') ||
        normalized.contains('active');
  }

  void _showRadioPlaceSheet(BuildContext context, RadioPlace place) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: HCTheme.bgPanel,
      showDragHandle: true,
      builder: (_) => _RadioPlaceSheet(place: place),
    );
  }

  void _focusLayer(_MapFocus focus) {
    final earthquakes = ref.read(earthquakesProvider).valueOrNull ?? const [];
    final flights = ref.read(flightsProvider).valueOrNull ?? const [];
    final visibleFlights = _selectedMode == _IntelMode.aviation
        ? _filterFlights(flights)
        : flights;
    final fires = ref.read(firesProvider).valueOrNull ?? const [];
    final conflicts = ref.read(conflictZonesProvider).valueOrNull ?? const [];
    final news = ref.read(newsProvider).valueOrNull ?? const [];
    final satellites = ref.read(satellitesProvider).valueOrNull ?? const [];
    final maritimePorts =
        ref.read(maritimePortsProvider).valueOrNull ?? const [];
    final maritimeChokepoints =
        ref.read(maritimeChokepointsProvider).valueOrNull ?? const [];
    final weather = ref.read(weatherEventsProvider).valueOrNull ?? const [];
    final radioPlaces =
        ref.read(intelligenceRadioPlacesProvider).valueOrNull ?? const [];

    late final Iterable<LatLng> points;
    late final double zoom;
    switch (focus) {
      case _MapFocus.global:
        _mapController.move(const LatLng(-28.0, 25.0), 2.8);
        return;
      case _MapFocus.earthquakes:
        points = earthquakes.map(
          (event) => LatLng(event.latitude, event.longitude),
        );
        zoom = 3.3;
      case _MapFocus.flights:
        points = visibleFlights
            .where(
              (flight) => flight.latitude != null && flight.longitude != null,
            )
            .map((flight) => LatLng(flight.latitude!, flight.longitude!));
        zoom = 3.0;
      case _MapFocus.fires:
        points = fires.map((fire) => LatLng(fire.latitude, fire.longitude));
        zoom = 3.6;
      case _MapFocus.weather:
        points = weather.map(
          (event) => LatLng(event.latitude, event.longitude),
        );
        zoom = 3.4;
      case _MapFocus.conflicts:
        points = conflicts.map((zone) => LatLng(zone.latitude, zone.longitude));
        zoom = 4.0;
      case _MapFocus.news:
        points = news
            .where((item) => item.latitude != null && item.longitude != null)
            .map((item) => LatLng(item.latitude!, item.longitude!));
        zoom = 3.4;
      case _MapFocus.satellites:
        points = satellites.map((satellite) {
          return LatLng(satellite.latitude, satellite.longitude);
        });
        zoom = 2.4;
      case _MapFocus.maritimePorts:
        points = maritimePorts.map(
          (port) => LatLng(port.latitude, port.longitude),
        );
        zoom = 2.8;
      case _MapFocus.maritimeChokepoints:
        points = maritimeChokepoints.map(
          (point) => LatLng(point.latitude, point.longitude),
        );
        zoom = 3.2;
      case _MapFocus.radio:
        points = radioPlaces.map(
          (place) => LatLng(place.latitude, place.longitude),
        );
        zoom = 3.0;
    }

    final usable = points.take(200).toList();
    if (usable.isEmpty) return;
    final lat =
        usable.fold<double>(0, (sum, point) => sum + point.latitude) /
        usable.length;
    final lon =
        usable.fold<double>(0, (sum, point) => sum + point.longitude) /
        usable.length;
    _mapController.move(LatLng(lat, lon), zoom);
  }

  @override
  Widget build(BuildContext context) {
    final reachable = ref.watch(osirisReachableProvider);
    final earthquakes = ref.watch(earthquakesProvider);
    final flights = ref.watch(flightsProvider);
    final fires = ref.watch(firesProvider);
    final news = ref.watch(newsProvider);
    final conflicts = ref.watch(conflictZonesProvider);
    final maritimePorts = ref.watch(maritimePortsProvider);
    final maritimeChokepoints = ref.watch(maritimeChokepointsProvider);
    final weatherEvents = ref.watch(weatherEventsProvider);
    final satellites = ref.watch(satellitesProvider);
    final radioPlaces = ref.watch(intelligenceRadioPlacesProvider);
    final radioFavorites = ref.watch(radioFavoritesProvider);
    final activeRadioChannel = ref.watch(activeRadioChannelProvider);
    final nowPlaying = ref.watch(radioNowPlayingProvider);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = screenHeight < 760 ? 360.0 : 420.0;
    final flightsData = flights.valueOrNull ?? const <FlightState>[];
    final maritimePortsData =
        maritimePorts.valueOrNull ?? const <MaritimePort>[];
    final maritimeChokepointsData =
        maritimeChokepoints.valueOrNull ?? const <MaritimeChokepoint>[];
    final weatherEventsData =
        weatherEvents.valueOrNull ?? const <WeatherEvent>[];
    final satelliteData = satellites.valueOrNull ?? const <SatellitePosition>[];
    final newsData = news.valueOrNull ?? const <NewsItem>[];
    final conflictsData = conflicts.valueOrNull ?? const <ConflictZone>[];
    final radioPlacesData = radioPlaces.valueOrNull ?? const <RadioPlace>[];
    final filteredFlights = _filterFlights(flightsData);
    final commercialCount = flightsData
        .where(
          (flight) => (flight.category ?? '').toLowerCase() == 'commercial',
        )
        .length;
    final privateCount = flightsData
        .where((flight) => (flight.category ?? '').toLowerCase() == 'private')
        .length;
    final privateJetCount = flightsData.where((flight) {
      final category = (flight.category ?? '').toLowerCase();
      return category == 'jet' ||
          category == 'private_jet' ||
          category == 'private jet';
    }).length;
    final militaryCount = flightsData
        .where((flight) => (flight.category ?? '').toLowerCase() == 'military')
        .length;
    final highConflictCount = conflictsData
        .where((zone) => _isHighConflictSeverity(zone.severity))
        .length;
    final describedConflictCount = conflictsData
        .where(
          (zone) => zone.description != null && zone.description!.isNotEmpty,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'World Intelligence',
                style: TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: HCTheme.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _refreshActiveLayers,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh layers',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          reachable.when(
            data: (ok) => ok
                ? 'Osiris is online. Layered intelligence feeds are active.'
                : 'Osiris is offline or not configured. Configure a base URL in Settings to enable live layers.',
            loading: () => 'Checking Osiris connection...',
            error: (error, stackTrace) => 'Osiris connection check failed.',
          ),
          style: const TextStyle(
            fontFamily: 'GeistSans',
            fontSize: 13,
            color: HCTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _IntelModeRow(
          selectedMode: _selectedMode,
          onModeSelected: _activateMode,
        ),
        if (_selectedMode == _IntelMode.overview) ...[
          const SizedBox(height: 10),
          _LayerToggleRow(onRefresh: _refreshActiveLayers),
        ] else if (_selectedMode == _IntelMode.aviation) ...[
          const SizedBox(height: 10),
          _FlightFilterRow(
            selectedFilter: _selectedFlightFilter,
            onFilterSelected: (filter) {
              setState(() => _selectedFlightFilter = filter);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _focusLayer(_MapFocus.flights);
              });
            },
          ),
        ] else if (_selectedMode == _IntelMode.maritimeSpace) ...[
          const SizedBox(height: 10),
          _MaritimeFilterRow(
            selectedFilter: _selectedMaritimeFilter,
            onFilterSelected: (filter) {
              setState(() => _selectedMaritimeFilter = filter);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _focusLayer(switch (filter) {
                  _MaritimeFilter.ports => _MapFocus.maritimePorts,
                  _MaritimeFilter.chokepoints => _MapFocus.maritimeChokepoints,
                  _MaritimeFilter.satellites => _MapFocus.satellites,
                });
              });
            },
          ),
        ] else if (_selectedMode == _IntelMode.surveillance) ...[
          const SizedBox(height: 10),
          _SurveillanceFilterRow(
            selectedFilter: _selectedSurveillanceFilter,
            onFilterSelected: (filter) {
              setState(() => _selectedSurveillanceFilter = filter);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _focusLayer(_MapFocus.news);
              });
            },
          ),
        ] else if (_selectedMode == _IntelMode.hazards) ...[
          const SizedBox(height: 10),
          _HazardFilterRow(
            selectedFilter: _selectedHazardFilter,
            onFilterSelected: (filter) {
              setState(() => _selectedHazardFilter = filter);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _focusLayer(switch (filter) {
                  _HazardFilter.earthquakes => _MapFocus.earthquakes,
                  _HazardFilter.fires => _MapFocus.fires,
                  _HazardFilter.weather => _MapFocus.weather,
                });
              });
            },
          ),
        ],
        if (activeRadioChannel != null) ...[
          const SizedBox(height: 12),
          _ActiveRadioCard(channel: activeRadioChannel, nowPlaying: nowPlaying),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HCTheme.bgPanel,
                border: Border.all(color: HCTheme.border),
              ),
              child: _IntelligenceMap(
                mapController: _mapController,
                mode: _selectedMode,
                flights: filteredFlights,
                maritimeFilter: _selectedMaritimeFilter,
                hazardFilter: _selectedHazardFilter,
                surveillanceFilter: _selectedSurveillanceFilter,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_selectedMode == _IntelMode.aviation)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Commercial',
                value: commercialCount,
                icon: Icons.flight,
              ),
              _MetricCard(
                title: 'Private',
                value: privateCount,
                icon: Icons.flight_outlined,
              ),
              _MetricCard(
                title: 'Private Jets',
                value: privateJetCount,
                icon: Icons.airplanemode_active,
              ),
              _MetricCard(
                title: 'Military',
                value: militaryCount,
                icon: Icons.security,
              ),
            ],
          )
        else if (_selectedMode == _IntelMode.maritimeSpace)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Ports',
                value: maritimePortsData.length,
                icon: Icons.anchor,
              ),
              _MetricCard(
                title: 'Chokepoints',
                value: maritimeChokepointsData.length,
                icon: Icons.alt_route,
              ),
              _MetricCard(
                title: 'Satellites',
                value: satelliteData.length,
                icon: Icons.satellite_alt_outlined,
              ),
            ],
          )
        else if (_selectedMode == _IntelMode.surveillance)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Live News',
                value: newsData.length,
                icon: Icons.public_outlined,
              ),
              const _StatusCard(
                title: 'CCTV Cameras',
                description:
                    'Current Osiris host does not expose a stable CCTV API yet.',
                icon: Icons.videocam_outlined,
              ),
            ],
          )
        else if (_selectedMode == _IntelMode.hazards)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Earthquakes',
                value: earthquakes.valueOrNull?.length ?? 0,
                icon: Icons.waves,
              ),
              _MetricCard(
                title: 'Fires',
                value: fires.valueOrNull?.length ?? 0,
                icon: Icons.local_fire_department_outlined,
              ),
              _MetricCard(
                title: 'Weather',
                value: weatherEventsData.length,
                icon: Icons.thunderstorm_outlined,
              ),
            ],
          )
        else if (_selectedMode == _IntelMode.conflict)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Conflict Zones',
                value: conflictsData.length,
                icon: Icons.warning_amber_outlined,
              ),
              _MetricCard(
                title: 'High Severity',
                value: highConflictCount,
                icon: Icons.priority_high,
              ),
              _MetricCard(
                title: 'With Briefs',
                value: describedConflictCount,
                icon: Icons.article_outlined,
              ),
            ],
          )
        else if (_selectedMode == _IntelMode.radio)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Radio Places',
                value: radioPlacesData.length,
                icon: Icons.radio_outlined,
              ),
              _MetricCard(
                title: 'Favorites',
                value: radioFavorites.length,
                icon: Icons.star_border,
              ),
              _StatusCard(
                title: activeRadioChannel == null
                    ? 'No Station Active'
                    : 'Streaming',
                description: activeRadioChannel == null
                    ? 'Tap a mapped place or a city below to open its stations.'
                    : activeRadioChannel.title,
                icon: activeRadioChannel == null
                    ? Icons.radio_button_unchecked
                    : Icons.play_circle_outline,
              ),
            ],
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'Earthquakes',
                value: earthquakes.valueOrNull?.length ?? 0,
                icon: Icons.waves,
              ),
              _MetricCard(
                title: 'Flights',
                value: flights.valueOrNull?.length ?? 0,
                icon: Icons.flight,
              ),
              _MetricCard(
                title: 'Fires',
                value: fires.valueOrNull?.length ?? 0,
                icon: Icons.local_fire_department_outlined,
              ),
              _MetricCard(
                title: 'Conflicts',
                value: conflicts.valueOrNull?.length ?? 0,
                icon: Icons.warning_amber_outlined,
              ),
              _MetricCard(
                title: 'News Feeds',
                value: news.valueOrNull?.length ?? 0,
                icon: Icons.public_outlined,
              ),
            ],
          ),
        const SizedBox(height: 14),
        if (_selectedMode == _IntelMode.aviation)
          _IntelSectionCard(
            title: switch (_selectedFlightFilter) {
              _FlightFilter.all => 'All Flights',
              _FlightFilter.commercial => 'Commercial Flights',
              _FlightFilter.private => 'Private Flights',
              _FlightFilter.privateJets => 'Private Jets',
              _FlightFilter.military => 'Military Flights',
            },
            child: _AviationDetailList(flights: filteredFlights),
          ),
        if (_selectedMode == _IntelMode.maritimeSpace)
          _IntelSectionCard(
            title: switch (_selectedMaritimeFilter) {
              _MaritimeFilter.ports => 'Major Ports',
              _MaritimeFilter.chokepoints => 'Strategic Chokepoints',
              _MaritimeFilter.satellites => 'Tracked Satellites',
            },
            child: _MaritimeDetailList(
              filter: _selectedMaritimeFilter,
              ports: maritimePortsData,
              chokepoints: maritimeChokepointsData,
              satellites: satelliteData,
            ),
          ),
        if (_selectedMode == _IntelMode.surveillance)
          _IntelSectionCard(
            title: _selectedSurveillanceFilter == _SurveillanceFilter.news
                ? 'Live News Feeds'
                : 'CCTV Cameras',
            child: _selectedSurveillanceFilter == _SurveillanceFilter.news
                ? _NewsDetailList(newsItems: newsData)
                : const _UnavailablePanel(
                    icon: Icons.videocam_off_outlined,
                    message:
                        'CCTV camera feeds are not available from the current Osiris host.',
                  ),
          ),
        if (_selectedMode == _IntelMode.hazards)
          _IntelSectionCard(
            title: switch (_selectedHazardFilter) {
              _HazardFilter.earthquakes => 'Seismic Activity',
              _HazardFilter.fires => 'Active Fires',
              _HazardFilter.weather => 'Severe Weather',
            },
            child: _HazardDetailList(
              filter: _selectedHazardFilter,
              earthquakes: earthquakes.valueOrNull ?? const [],
              fires: fires.valueOrNull ?? const [],
              weather: weatherEventsData,
            ),
          ),
        if (_selectedMode == _IntelMode.conflict)
          _IntelSectionCard(
            title: 'Conflict Watch',
            child: _ConflictDetailList(conflicts: conflictsData),
          ),
        if (_selectedMode == _IntelMode.radio)
          _IntelSectionCard(
            title: 'Radio Places',
            child: _RadioPlaceDetailList(
              places: radioPlacesData,
              onPlaceSelected: (place) => _showRadioPlaceSheet(context, place),
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: HCTheme.gold),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 12,
                  color: HCTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: HCTheme.gold),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HCTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: 'GeistSans',
                  fontSize: 11,
                  color: HCTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntelSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _IntelSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HCTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _UnavailablePanel({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HCTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 13,
              color: HCTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _AviationDetailList extends StatelessWidget {
  final List<FlightState> flights;

  const _AviationDetailList({required this.flights});

  @override
  Widget build(BuildContext context) {
    if (flights.isEmpty) {
      return const _UnavailablePanel(
        icon: Icons.flight_outlined,
        message: 'No flights in the selected category.',
      );
    }

    // Sort: airborne first, then by callsign
    final sorted = [...flights]..sort((a, b) {
        if (a.onGround != b.onGround) return a.onGround ? 1 : -1;
        return (a.callsign ?? '').compareTo(b.callsign ?? '');
      });

    return Column(
      children: sorted.take(8).map((flight) {
        final callsign = flight.callsign?.trim();
        final displayId = callsign?.isNotEmpty == true
            ? callsign!
            : flight.icao24.toUpperCase();
        final parts = <String>[
          if (flight.country != null && flight.country!.isNotEmpty)
            flight.country!,
          if (flight.model != null && flight.model!.isNotEmpty) flight.model!,
          if (flight.altitude != null)
            '${(flight.altitude! / 1000).toStringAsFixed(1)} km alt',
        ];
        final trailing = flight.onGround
            ? 'Ground'
            : flight.velocity != null
            ? '${flight.velocity!.toStringAsFixed(0)} kt'
            : '-';
        return _DetailRow(
          icon: flight.onGround ? Icons.flight_land : Icons.flight,
          title: displayId,
          subtitle: parts.isEmpty ? 'No details' : parts.join(' · '),
          trailing: trailing,
        );
      }).toList(),
    );
  }
}

class _MaritimeDetailList extends StatelessWidget {
  final _MaritimeFilter filter;
  final List<MaritimePort> ports;
  final List<MaritimeChokepoint> chokepoints;
  final List<SatellitePosition> satellites;

  const _MaritimeDetailList({
    required this.filter,
    required this.ports,
    required this.chokepoints,
    required this.satellites,
  });

  @override
  Widget build(BuildContext context) {
    switch (filter) {
      case _MaritimeFilter.ports:
        return Column(
          children: ports.take(6).map((port) {
            return _DetailRow(
              icon: Icons.anchor,
              title: port.name,
              subtitle: '${port.country} • ${port.type}',
              trailing: port.congestion ?? '-',
            );
          }).toList(),
        );
      case _MaritimeFilter.chokepoints:
        return Column(
          children: chokepoints.take(6).map((point) {
            return _DetailRow(
              icon: Icons.alt_route,
              title: point.name,
              subtitle: point.traffic ?? 'Strategic passage',
              trailing: point.risk ?? '-',
            );
          }).toList(),
        );
      case _MaritimeFilter.satellites:
        return Column(
          children: satellites.take(6).map((satellite) {
            return _DetailRow(
              icon: Icons.satellite_alt_outlined,
              title: satellite.name,
              subtitle: satellite.mission ?? 'Orbital asset',
              trailing: '${satellite.altitude.toStringAsFixed(0)} km',
            );
          }).toList(),
        );
    }
  }
}

class _NewsDetailList extends StatelessWidget {
  final List<NewsItem> newsItems;

  const _NewsDetailList({required this.newsItems});

  @override
  Widget build(BuildContext context) {
    if (newsItems.isEmpty) {
      return const _UnavailablePanel(
        icon: Icons.newspaper_outlined,
        message:
            'No live news items are available from the current Osiris feed.',
      );
    }

    return Column(
      children: newsItems.take(6).map((item) {
        return _DetailRow(
          icon: Icons.public_outlined,
          title: item.source,
          subtitle: item.title,
          trailing: item.latitude != null && item.longitude != null
              ? 'Mapped'
              : 'Feed',
        );
      }).toList(),
    );
  }
}

class _HazardDetailList extends StatelessWidget {
  final _HazardFilter filter;
  final List<EarthquakeEvent> earthquakes;
  final List<FireHotspot> fires;
  final List<WeatherEvent> weather;

  const _HazardDetailList({
    required this.filter,
    required this.earthquakes,
    required this.fires,
    required this.weather,
  });

  @override
  Widget build(BuildContext context) {
    switch (filter) {
      case _HazardFilter.earthquakes:
        return Column(
          children: earthquakes.take(6).map((quake) {
            return _DetailRow(
              icon: Icons.waves,
              title: 'M${quake.magnitude.toStringAsFixed(1)}',
              subtitle: quake.place,
              trailing: '${quake.depth.toStringAsFixed(0)} km',
            );
          }).toList(),
        );
      case _HazardFilter.fires:
        return Column(
          children: fires.take(6).map((fire) {
            return _DetailRow(
              icon: Icons.local_fire_department_outlined,
              title: 'Fire hotspot',
              subtitle:
                  '${fire.latitude.toStringAsFixed(2)}, ${fire.longitude.toStringAsFixed(2)}',
              trailing: fire.brightness.toStringAsFixed(0),
            );
          }).toList(),
        );
      case _HazardFilter.weather:
        return Column(
          children: weather.take(6).map((event) {
            return _DetailRow(
              icon: Icons.thunderstorm_outlined,
              title: event.title,
              subtitle: event.type,
              trailing: event.severity ?? '-',
            );
          }).toList(),
        );
    }
  }
}

class _ConflictDetailList extends StatelessWidget {
  final List<ConflictZone> conflicts;

  const _ConflictDetailList({required this.conflicts});

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) {
      return const _UnavailablePanel(
        icon: Icons.warning_amber_outlined,
        message:
            'No conflict zones are available from the current Osiris feed.',
      );
    }

    final sorted = [...conflicts]
      ..sort(
        (a, b) =>
            _severityRank(b.severity).compareTo(_severityRank(a.severity)),
      );

    return Column(
      children: sorted.take(8).map((zone) {
        return _DetailRow(
          icon: Icons.warning_amber_outlined,
          title: zone.name,
          subtitle: zone.description == null || zone.description!.isEmpty
              ? 'Lat/Lon: ${zone.latitude.toStringAsFixed(2)}, ${zone.longitude.toStringAsFixed(2)}'
              : zone.description!,
          trailing: _formatSeverity(zone.severity),
        );
      }).toList(),
    );
  }

  int _severityRank(String severity) {
    final normalized = severity.toLowerCase().replaceAll('_', ' ');
    if (normalized.contains('critical')) return 4;
    if (normalized.contains('severe') || normalized.contains('high')) return 3;
    if (normalized.contains('active') || normalized.contains('elevated')) {
      return 2;
    }
    if (normalized.contains('watch') || normalized.contains('medium')) return 1;
    return 0;
  }

  String _formatSeverity(String severity) {
    final normalized = severity.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return '-';
    return normalized.length > 12 ? normalized.substring(0, 12) : normalized;
  }
}

class _RadioPlaceDetailList extends StatelessWidget {
  final List<RadioPlace> places;
  final void Function(RadioPlace place) onPlaceSelected;

  const _RadioPlaceDetailList({
    required this.places,
    required this.onPlaceSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return const _UnavailablePanel(
        icon: Icons.radio_outlined,
        message: 'No radio places are available from Radio Garden right now.',
      );
    }

    final sorted = [...places]..sort((a, b) => b.size.compareTo(a.size));

    return Column(
      children: sorted.take(8).map((place) {
        return _TappableDetailRow(
          icon: Icons.radio_outlined,
          title: place.title,
          subtitle: place.country.isEmpty
              ? '${place.size} stations indexed'
              : '${place.country} • ${place.size} stations indexed',
          trailing: 'Open',
          onTap: () => onPlaceSelected(place),
        );
      }).toList(),
    );
  }
}

class _TappableDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  const _TappableDetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: HCTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HCTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'GeistSans',
                      fontSize: 12,
                      color: HCTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: const TextStyle(
                fontFamily: 'GeistMono',
                fontSize: 11,
                color: HCTheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: HCTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HCTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 12,
                    color: HCTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 11,
              color: HCTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerToggleRow extends ConsumerWidget {
  final VoidCallback onRefresh;

  const _LayerToggleRow({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layers = ref.watch(intelligenceLayersProvider);
    final notifier = ref.read(intelligenceLayersProvider.notifier);

    final toggles = [
      _ToggleSpec(
        icon: Icons.waves,
        label: 'Seismic',
        active: layers.earthquakes,
        onTap: () {
          notifier.state = layers.copyWith(earthquakes: !layers.earthquakes);
          onRefresh();
        },
      ),
      _ToggleSpec(
        icon: Icons.flight,
        label: 'Flights',
        active: layers.flights,
        onTap: () {
          notifier.state = layers.copyWith(flights: !layers.flights);
          onRefresh();
        },
      ),
      _ToggleSpec(
        icon: Icons.local_fire_department_outlined,
        label: 'Fires',
        active: layers.fires,
        onTap: () {
          notifier.state = layers.copyWith(fires: !layers.fires);
          onRefresh();
        },
      ),
      _ToggleSpec(
        icon: Icons.warning_amber_outlined,
        label: 'Conflict',
        active: layers.conflicts,
        onTap: () {
          notifier.state = layers.copyWith(conflicts: !layers.conflicts);
          onRefresh();
        },
      ),
      _ToggleSpec(
        icon: Icons.public_outlined,
        label: 'News',
        active: layers.news,
        onTap: () {
          notifier.state = layers.copyWith(news: !layers.news);
          onRefresh();
        },
      ),
      _ToggleSpec(
        icon: Icons.radio_outlined,
        label: 'Radio',
        active: layers.radio,
        onTap: () {
          notifier.state = layers.copyWith(radio: !layers.radio);
          onRefresh();
        },
      ),
      _ToggleSpec(
        icon: Icons.satellite_alt_outlined,
        label: 'Sat',
        active: layers.satellites,
        onTap: () {
          notifier.state = layers.copyWith(satellites: !layers.satellites);
          onRefresh();
        },
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: toggles.length,
        itemBuilder: (context, index) {
          final toggle = toggles[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index == toggles.length - 1 ? 0 : 8,
            ),
            child: FilterChip(
              selected: toggle.active,
              onSelected: (_) => toggle.onTap(),
              label: Text(toggle.label),
              avatar: Icon(
                toggle.icon,
                size: 14,
                color: toggle.active ? HCTheme.gold : HCTheme.textSecondary,
              ),
              selectedColor: HCTheme.goldBg,
              checkmarkColor: HCTheme.gold,
              side: const BorderSide(color: HCTheme.border),
              backgroundColor: HCTheme.bgSurface,
              labelStyle: TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 12,
                color: toggle.active ? HCTheme.gold : HCTheme.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToggleSpec {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleSpec({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
}

enum _IntelMode {
  overview,
  aviation,
  maritimeSpace,
  surveillance,
  hazards,
  conflict,
  radio,
}

enum _MapFocus {
  global,
  earthquakes,
  flights,
  fires,
  weather,
  conflicts,
  news,
  satellites,
  maritimePorts,
  maritimeChokepoints,
  radio,
}

enum _FlightFilter { all, commercial, private, privateJets, military }

enum _MaritimeFilter { ports, chokepoints, satellites }

enum _SurveillanceFilter { news, cctv }

enum _HazardFilter { earthquakes, fires, weather }

class _IntelModeRow extends StatelessWidget {
  final _IntelMode selectedMode;
  final void Function(_IntelMode mode) onModeSelected;

  const _IntelModeRow({
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final modes = const [
      (mode: _IntelMode.overview, label: 'Overview', icon: Icons.public),
      (mode: _IntelMode.aviation, label: 'Aviation', icon: Icons.flight),
      (mode: _IntelMode.maritimeSpace, label: 'Maritime', icon: Icons.anchor),
      (
        mode: _IntelMode.surveillance,
        label: 'Surveillance',
        icon: Icons.visibility_outlined,
      ),
      (
        mode: _IntelMode.hazards,
        label: 'Hazards',
        icon: Icons.local_fire_department_outlined,
      ),
      (
        mode: _IntelMode.conflict,
        label: 'Conflict',
        icon: Icons.warning_amber_outlined,
      ),
      (mode: _IntelMode.radio, label: 'Radio', icon: Icons.radio_outlined),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final selected = selectedMode == mode.mode;
          return FilterChip(
            selected: selected,
            onSelected: (_) => onModeSelected(mode.mode),
            label: Text(mode.label),
            avatar: Icon(
              mode.icon,
              size: 14,
              color: selected ? HCTheme.gold : HCTheme.textSecondary,
            ),
            selectedColor: HCTheme.goldBg,
            checkmarkColor: HCTheme.gold,
            side: const BorderSide(color: HCTheme.border),
            backgroundColor: HCTheme.bgSurface,
            labelStyle: TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 12,
              color: selected ? HCTheme.gold : HCTheme.textSecondary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          );
        },
      ),
    );
  }
}

class _MaritimeFilterRow extends StatelessWidget {
  final _MaritimeFilter selectedFilter;
  final void Function(_MaritimeFilter filter) onFilterSelected;

  const _MaritimeFilterRow({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = const [
      (filter: _MaritimeFilter.ports, label: 'Ports'),
      (filter: _MaritimeFilter.chokepoints, label: 'Chokepoints'),
      (filter: _MaritimeFilter.satellites, label: 'Satellites'),
    ];
    return _ChoiceChipRow<_MaritimeFilter>(
      entries: filters,
      selected: selectedFilter,
      onSelected: onFilterSelected,
    );
  }
}

class _SurveillanceFilterRow extends StatelessWidget {
  final _SurveillanceFilter selectedFilter;
  final void Function(_SurveillanceFilter filter) onFilterSelected;

  const _SurveillanceFilterRow({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = const [
      (filter: _SurveillanceFilter.news, label: 'Live News'),
      (filter: _SurveillanceFilter.cctv, label: 'CCTV'),
    ];
    return _ChoiceChipRow<_SurveillanceFilter>(
      entries: filters,
      selected: selectedFilter,
      onSelected: onFilterSelected,
    );
  }
}

class _HazardFilterRow extends StatelessWidget {
  final _HazardFilter selectedFilter;
  final void Function(_HazardFilter filter) onFilterSelected;

  const _HazardFilterRow({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = const [
      (filter: _HazardFilter.earthquakes, label: 'Earthquakes'),
      (filter: _HazardFilter.fires, label: 'Fires'),
      (filter: _HazardFilter.weather, label: 'Weather'),
    ];
    return _ChoiceChipRow<_HazardFilter>(
      entries: filters,
      selected: selectedFilter,
      onSelected: onFilterSelected,
    );
  }
}

class _ChoiceChipRow<T> extends StatelessWidget {
  final List<({T filter, String label})> entries;
  final T selected;
  final void Function(T value) onSelected;

  const _ChoiceChipRow({
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isSelected = selected == entry.filter;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(entry.filter),
            label: Text(entry.label),
            selectedColor: HCTheme.goldBg,
            side: const BorderSide(color: HCTheme.border),
            backgroundColor: HCTheme.bgSurface,
            labelStyle: TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 12,
              color: isSelected ? HCTheme.gold : HCTheme.textSecondary,
            ),
          );
        },
      ),
    );
  }
}

class _FlightFilterRow extends StatelessWidget {
  final _FlightFilter selectedFilter;
  final void Function(_FlightFilter filter) onFilterSelected;

  const _FlightFilterRow({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = const [
      (filter: _FlightFilter.all, label: 'All'),
      (filter: _FlightFilter.commercial, label: 'Commercial'),
      (filter: _FlightFilter.private, label: 'Private'),
      (filter: _FlightFilter.privateJets, label: 'Private Jets'),
      (filter: _FlightFilter.military, label: 'Military'),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter.filter;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onFilterSelected(filter.filter),
            label: Text(filter.label),
            selectedColor: HCTheme.goldBg,
            side: const BorderSide(color: HCTheme.border),
            backgroundColor: HCTheme.bgSurface,
            labelStyle: TextStyle(
              fontFamily: 'GeistSans',
              fontSize: 12,
              color: selected ? HCTheme.gold : HCTheme.textSecondary,
            ),
          );
        },
      ),
    );
  }
}

class _IntelligenceMap extends ConsumerWidget {
  final MapController mapController;
  final _IntelMode mode;
  final List<FlightState> flights;
  final _MaritimeFilter maritimeFilter;
  final _HazardFilter hazardFilter;
  final _SurveillanceFilter surveillanceFilter;

  const _IntelligenceMap({
    required this.mapController,
    required this.mode,
    required this.flights,
    required this.maritimeFilter,
    required this.hazardFilter,
    required this.surveillanceFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earthquakes =
        ref.watch(earthquakesProvider).valueOrNull ?? const <EarthquakeEvent>[];
    final fires = ref.watch(firesProvider).valueOrNull ?? const <FireHotspot>[];
    final conflicts =
        ref.watch(conflictZonesProvider).valueOrNull ?? const <ConflictZone>[];
    final news = ref.watch(newsProvider).valueOrNull ?? const <NewsItem>[];
    final satellites =
        ref.watch(satellitesProvider).valueOrNull ??
        const <SatellitePosition>[];
    final maritimePorts =
        ref.watch(maritimePortsProvider).valueOrNull ?? const <MaritimePort>[];
    final maritimeChokepoints =
        ref.watch(maritimeChokepointsProvider).valueOrNull ??
        const <MaritimeChokepoint>[];
    final weather =
        ref.watch(weatherEventsProvider).valueOrNull ?? const <WeatherEvent>[];
    final radioPlaces =
        ref.watch(intelligenceRadioPlacesProvider).valueOrNull ??
        const <RadioPlace>[];
    final activeRadioChannel = ref.watch(activeRadioChannelProvider);
    final reconFocus = ref.watch(reconFocusProvider);
    final showEarthquakes =
        mode == _IntelMode.overview ||
        (mode == _IntelMode.hazards &&
            hazardFilter == _HazardFilter.earthquakes);
    final showFires =
        mode == _IntelMode.overview ||
        (mode == _IntelMode.hazards && hazardFilter == _HazardFilter.fires);
    final showWeather =
        mode == _IntelMode.hazards && hazardFilter == _HazardFilter.weather;
    final showFlights = mode == _IntelMode.aviation;
    final showNews =
        mode == _IntelMode.overview ||
        (mode == _IntelMode.surveillance &&
            surveillanceFilter == _SurveillanceFilter.news);
    final showConflicts =
        mode == _IntelMode.overview || mode == _IntelMode.conflict;
    final showSatellites =
        (mode == _IntelMode.maritimeSpace &&
        maritimeFilter == _MaritimeFilter.satellites);
    final showMaritimePorts =
        mode == _IntelMode.maritimeSpace &&
        maritimeFilter == _MaritimeFilter.ports;
    final showMaritimeChokepoints =
        mode == _IntelMode.maritimeSpace &&
        maritimeFilter == _MaritimeFilter.chokepoints;
    final showRadio = mode == _IntelMode.overview || mode == _IntelMode.radio;
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: const MapOptions(
            initialCenter: LatLng(-28.0, 25.0),
            initialZoom: 2.8,
            minZoom: 1.5,
            maxZoom: 11,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.nuburo.hermescommander',
            ),
            MarkerLayer(
              markers: showFires
                  ? fires.map((fire) {
                      return Marker(
                        point: LatLng(fire.latitude, fire.longitude),
                        width: 16,
                        height: 16,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title: 'Active Fire Hotspot',
                            lines: [
                              'Brightness: ${fire.brightness.toStringAsFixed(0)} K',
                              'Confidence: ${fire.confidence.toStringAsFixed(0)}%',
                              'Lat/Lon: ${fire.latitude.toStringAsFixed(2)}, ${fire.longitude.toStringAsFixed(2)}',
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withAlpha(200),
                              border: Border.all(color: Colors.orangeAccent),
                            ),
                            child: const Center(
                              child: Text('F', style: TextStyle(fontSize: 8)),
                            ),
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showEarthquakes
                  ? earthquakes.map((quake) {
                      final color = _earthquakeColor(quake.magnitude);
                      final size =
                          16 + quake.magnitude.clamp(0, 7).toDouble() * 2.8;
                      return Marker(
                        point: LatLng(quake.latitude, quake.longitude),
                        width: size,
                        height: size,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title:
                                'M${quake.magnitude.toStringAsFixed(1)} Earthquake',
                            lines: [
                              quake.place,
                              'Depth: ${quake.depth.toStringAsFixed(0)} km',
                              'Time: ${quake.time.toLocal()}',
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withAlpha(160),
                              border: Border.all(color: color, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                quake.magnitude.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showConflicts
                  ? conflicts.map((zone) {
                      return Marker(
                        point: LatLng(zone.latitude, zone.longitude),
                        width: 26,
                        height: 26,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title: zone.name,
                            lines: [
                              'Severity: ${zone.severity.replaceAll('_', ' ')}',
                              if (zone.description != null &&
                                  zone.description!.isNotEmpty)
                                zone.description!,
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withAlpha(48),
                              border: Border.all(
                                color: Colors.redAccent,
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.warning_amber_outlined,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showFlights
                  ? flights
                        .take(200)
                        .where((flight) {
                          return flight.latitude != null &&
                              flight.longitude != null;
                        })
                        .map((flight) {
                          return Marker(
                            point: LatLng(flight.latitude!, flight.longitude!),
                            width: 18,
                            height: 18,
                            child: GestureDetector(
                              onTap: () => _showDetailSheet(
                                context,
                                title:
                                    flight.callsign?.trim().isNotEmpty == true
                                    ? flight.callsign!.trim()
                                    : flight.icao24.toUpperCase(),
                                lines: [
                                  if (flight.model != null &&
                                      flight.model!.isNotEmpty)
                                    'Model: ${flight.model}',
                                  if (flight.country != null &&
                                      flight.country!.isNotEmpty)
                                    flight.country!,
                                  if (flight.registration != null &&
                                      flight.registration!.isNotEmpty)
                                    'Registration: ${flight.registration}',
                                  if (flight.altitude != null)
                                    'Altitude: ${flight.altitude!.toStringAsFixed(0)} m',
                                  if (flight.velocity != null)
                                    'Speed: ${flight.velocity!.toStringAsFixed(1)} kt',
                                  if (flight.heading != null)
                                    'Heading: ${flight.heading!.toStringAsFixed(0)}°',
                                  if (flight.squawk != null &&
                                      flight.squawk!.isNotEmpty)
                                    'Squawk: ${flight.squawk}',
                                  if (flight.category != null &&
                                      flight.category!.isNotEmpty)
                                    'Category: ${flight.category}',
                                  if (flight.onGround) 'On ground',
                                ],
                              ),
                              child: Transform.rotate(
                                angle:
                                    ((flight.heading ?? 0) / 180) *
                                    3.1415926535,
                                child: const Icon(
                                  Icons.flight,
                                  size: 12,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                          );
                        })
                        .toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showNews
                  ? news
                        .where((item) {
                          return item.latitude != null &&
                              item.longitude != null;
                        })
                        .map((item) {
                          return Marker(
                            point: LatLng(item.latitude!, item.longitude!),
                            width: 16,
                            height: 16,
                            child: GestureDetector(
                              onTap: () => _showDetailSheet(
                                context,
                                title: item.source,
                                lines: [
                                  item.title,
                                  if (item.url != null && item.url!.isNotEmpty)
                                    item.url!,
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HCTheme.statusBlue.withAlpha(180),
                                  border: Border.all(color: HCTheme.statusBlue),
                                ),
                                child: const Center(
                                  child: Text(
                                    'N',
                                    style: TextStyle(fontSize: 8),
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                        .toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showSatellites
                  ? satellites.take(120).map((satellite) {
                      return Marker(
                        point: LatLng(satellite.latitude, satellite.longitude),
                        width: 18,
                        height: 18,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title: satellite.name,
                            lines: [
                              'Catalog ID: ${satellite.satId}',
                              'Altitude: ${satellite.altitude.toStringAsFixed(0)} km',
                              if (satellite.mission != null &&
                                  satellite.mission!.isNotEmpty)
                                'Mission: ${satellite.mission}',
                            ],
                          ),
                          child: const Icon(
                            Icons.satellite_alt_outlined,
                            size: 14,
                            color: HCTheme.gold,
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showMaritimePorts
                  ? maritimePorts.take(120).map((port) {
                      return Marker(
                        point: LatLng(port.latitude, port.longitude),
                        width: 20,
                        height: 20,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title: port.name,
                            lines: [
                              '${port.country} • ${port.type}',
                              if (port.volume != null &&
                                  port.volume!.isNotEmpty)
                                port.volume!,
                              if (port.congestion != null &&
                                  port.congestion!.isNotEmpty)
                                'Congestion: ${port.congestion}',
                              if (port.dwellTime != null &&
                                  port.dwellTime!.isNotEmpty)
                                'Dwell time: ${port.dwellTime}',
                            ],
                          ),
                          child: const Icon(
                            Icons.anchor,
                            size: 15,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showMaritimeChokepoints
                  ? maritimeChokepoints.map((point) {
                      return Marker(
                        point: LatLng(point.latitude, point.longitude),
                        width: 20,
                        height: 20,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title: point.name,
                            lines: [
                              if (point.traffic != null &&
                                  point.traffic!.isNotEmpty)
                                point.traffic!,
                              if (point.risk != null && point.risk!.isNotEmpty)
                                'Risk: ${point.risk}',
                            ],
                          ),
                          child: const Icon(
                            Icons.alt_route,
                            size: 15,
                            color: Colors.orangeAccent,
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showWeather
                  ? weather.map((event) {
                      return Marker(
                        point: LatLng(event.latitude, event.longitude),
                        width: 18,
                        height: 18,
                        child: GestureDetector(
                          onTap: () => _showDetailSheet(
                            context,
                            title: event.title,
                            lines: [
                              event.type,
                              if (event.severity != null &&
                                  event.severity!.isNotEmpty)
                                'Severity: ${event.severity}',
                              if (event.provider != null &&
                                  event.provider!.isNotEmpty)
                                'Provider: ${event.provider}',
                            ],
                          ),
                          child: const Icon(
                            Icons.thunderstorm_outlined,
                            size: 15,
                            color: Colors.deepOrangeAccent,
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            MarkerLayer(
              markers: showRadio
                  ? radioPlaces.take(400).map((place) {
                      final isActive =
                          activeRadioChannel?.placeTitle == place.title;
                      return Marker(
                        point: LatLng(place.latitude, place.longitude),
                        width: 10,
                        height: 10,
                        child: GestureDetector(
                          onTap: () =>
                              _showRadioPlaceSheet(context, ref, place),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? HCTheme.gold
                                  : HCTheme.statusGreen.withAlpha(150),
                              border: Border.all(
                                color: isActive
                                    ? HCTheme.goldLight
                                    : HCTheme.statusGreen,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList()
                  : const [],
            ),
            // RECON focus pin
            if (reconFocus != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(reconFocus.lat, reconFocus.lon),
                    width: 32,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showDetailSheet(
                        context,
                        title: 'RECON: ${reconFocus.label}',
                        lines: [
                          '${reconFocus.lat.toStringAsFixed(4)}, ${reconFocus.lon.toStringAsFixed(4)}',
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, size: 20, color: HCTheme.gold),
                          SizedBox(height: 2),
                          Text(
                            '▼',
                            style: TextStyle(
                              fontSize: 8,
                              color: HCTheme.gold,
                              height: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _MapLegendCard(
            earthquakes: showEarthquakes ? earthquakes.length : 0,
            fires: showFires ? fires.length : 0,
            weather: showWeather ? weather.length : 0,
            conflicts: showConflicts ? conflicts.length : 0,
            news: showNews ? news.length : 0,
            satellites: showSatellites ? satellites.length : 0,
            radioPlaces: showRadio ? radioPlaces.length : 0,
            ports: showMaritimePorts ? maritimePorts.length : 0,
            chokepoints: showMaritimeChokepoints
                ? maritimeChokepoints.length
                : 0,
          ),
        ),
      ],
    );
  }

  Color _earthquakeColor(double magnitude) {
    if (magnitude >= 7.0) return Colors.redAccent;
    if (magnitude >= 5.5) return Colors.orangeAccent;
    if (magnitude >= 4.0) return Colors.amber;
    return Colors.greenAccent;
  }

  void _showDetailSheet(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HCTheme.bgPanel,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HCTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 13,
                    color: HCTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRadioPlaceSheet(
    BuildContext context,
    WidgetRef ref,
    RadioPlace place,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: HCTheme.bgPanel,
      showDragHandle: true,
      builder: (_) => _RadioPlaceSheet(place: place),
    );
  }
}

class _MapLegendCard extends StatelessWidget {
  final int earthquakes;
  final int fires;
  final int weather;
  final int conflicts;
  final int news;
  final int satellites;
  final int radioPlaces;
  final int ports;
  final int chokepoints;

  const _MapLegendCard({
    required this.earthquakes,
    required this.fires,
    required this.weather,
    required this.conflicts,
    required this.news,
    required this.satellites,
    required this.radioPlaces,
    required this.ports,
    required this.chokepoints,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HCTheme.bgPanel.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE LAYERS',
              style: TextStyle(
                fontFamily: 'GeistMono',
                fontSize: 10,
                color: HCTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (earthquakes > 0)
              _LegendLine(
                color: Colors.amber,
                label: 'Quakes',
                value: earthquakes,
              ),
            if (fires > 0)
              _LegendLine(
                color: Colors.orangeAccent,
                label: 'Fires',
                value: fires,
              ),
            if (weather > 0)
              _LegendLine(
                color: Colors.deepOrangeAccent,
                label: 'Weather',
                value: weather,
              ),
            if (conflicts > 0)
              _LegendLine(
                color: Colors.redAccent,
                label: 'Conflict',
                value: conflicts,
              ),
            if (news > 0)
              _LegendLine(
                color: HCTheme.statusBlue,
                label: 'News',
                value: news,
              ),
            if (satellites > 0)
              _LegendLine(color: HCTheme.gold, label: 'Sat', value: satellites),
            if (ports > 0)
              _LegendLine(
                color: Colors.lightBlueAccent,
                label: 'Ports',
                value: ports,
              ),
            if (chokepoints > 0)
              _LegendLine(
                color: Colors.orangeAccent,
                label: 'Choke',
                value: chokepoints,
              ),
            if (radioPlaces > 0)
              _LegendLine(
                color: HCTheme.statusGreen,
                label: 'Radio',
                value: radioPlaces,
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendLine({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'GeistSans',
                fontSize: 11,
                color: HCTheme.textSecondary,
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 11,
              color: HCTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRadioCard extends ConsumerWidget {
  final RadioChannel channel;
  final String? nowPlaying;

  const _ActiveRadioCard({required this.channel, required this.nowPlaying});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HCTheme.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HCTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio, size: 18, color: HCTheme.statusGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HCTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  channel.country.isEmpty
                      ? channel.placeTitle
                      : '${channel.placeTitle} · ${channel.country}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 11,
                    color: HCTheme.textSecondary,
                  ),
                ),
                if (nowPlaying != null && nowPlaying!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    nowPlaying!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 11,
                      color: HCTheme.gold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final player = ref.read(radioPlayerProvider);
              await player.stop();
              ref.read(activeRadioChannelProvider.notifier).state = null;
            },
            icon: const Icon(Icons.stop_circle_outlined, size: 20),
            tooltip: 'Stop radio',
          ),
        ],
      ),
    );
  }
}

class _RadioPlaceSheet extends ConsumerWidget {
  final RadioPlace place;

  const _RadioPlaceSheet({required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.title,
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HCTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  place.country.isEmpty
                      ? '${place.size} stations indexed'
                      : '${place.country} · ${place.size} stations indexed',
                  style: const TextStyle(
                    fontFamily: 'GeistSans',
                    fontSize: 12,
                    color: HCTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: HCTheme.border),
          Expanded(
            child: FutureBuilder<List<RadioChannel>>(
              future: radioGardenService.channelsForPlace(place.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${snapshot.error}',
                        style: const TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 11,
                          color: HCTheme.statusRed,
                        ),
                      ),
                    ),
                  );
                }
                final channels = snapshot.data ?? const <RadioChannel>[];
                if (channels.isEmpty) {
                  return const Center(
                    child: Text(
                      'No stations available.',
                      style: TextStyle(
                        fontFamily: 'GeistSans',
                        fontSize: 13,
                        color: HCTheme.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (_, index) =>
                      _RadioChannelTile(channel: channels[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioChannelTile extends ConsumerWidget {
  final RadioChannel channel;

  const _RadioChannelTile({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref
        .watch(radioFavoritesProvider)
        .any((favorite) => favorite.channelId == channel.id);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.radio, size: 18, color: HCTheme.statusGreen),
      title: Text(
        channel.title,
        style: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 13,
          color: HCTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        channel.country.isEmpty ? channel.placeTitle : channel.country,
        style: const TextStyle(
          fontFamily: 'GeistSans',
          fontSize: 11,
          color: HCTheme.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              size: 18,
              color: isFavorite ? HCTheme.gold : HCTheme.textMuted,
            ),
            tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
            onPressed: () {
              ref
                  .read(radioFavoritesProvider.notifier)
                  .toggle(
                    FavoriteStation(
                      channelId: channel.id,
                      title: channel.title,
                      placeTitle: channel.placeTitle,
                      country: channel.country,
                      savedAt: DateTime.now(),
                    ),
                  );
            },
          ),
          const Icon(Icons.play_arrow, size: 18, color: HCTheme.statusGreen),
        ],
      ),
      onTap: () async {
        final player = ref.read(radioPlayerProvider);
        ref.read(activeRadioChannelProvider.notifier).state = channel;
        try {
          await player.setUrl(channel.streamUrl);
          await player.play();
          if (context.mounted) Navigator.of(context).pop();
        } catch (_) {
          ref.read(activeRadioChannelProvider.notifier).state = null;
        }
      },
    );
  }
}
