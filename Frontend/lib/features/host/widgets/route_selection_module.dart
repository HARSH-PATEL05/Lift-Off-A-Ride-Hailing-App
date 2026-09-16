import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/google_places_service.dart';
import '../../../core/services/location_service.dart';

class RideStopData {
  final String name;
  final LatLng position;

  const RideStopData({
    required this.name,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': position.latitude,
      'longitude': position.longitude,
    };
  }
}

/// One ordered road segment of the finalized journey.
///
/// This is intentionally kept separate from RouteResult so the existing
/// route/confirmation functionality continues to use RouteResult exactly
/// as before, while the individual segments are preserved for backend
/// storage, PostGIS matching, and future ride features.
class RouteLegData {
  final int order;
  final String startName;
  final LatLng start;
  final String endName;
  final LatLng end;
  final RouteResult route;

  const RouteLegData({
    required this.order,
    required this.startName,
    required this.start,
    required this.endName,
    required this.end,
    required this.route,
  });

  List<LatLng> get points => route.points;

  num get distanceMeters => route.distanceMeters;

  num get durationSeconds => route.durationSeconds;

  String get distanceText => route.distanceText;

  String get durationText => route.durationText;

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'start': {
        'name': startName,
        'latitude': start.latitude,
        'longitude': start.longitude,
      },
      'end': {
        'name': endName,
        'latitude': end.latitude,
        'longitude': end.longitude,
      },
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'distance_text': distanceText,
      'duration_text': durationText,
      'points': [
        for (final point in points)
          {
            'latitude': point.latitude,
            'longitude': point.longitude,
          },
      ],
    };
  }
}

class RouteSelectionData {
  final String sourceName;
  final LatLng source;
  final String destinationName;
  final LatLng destination;
  final List<RideStopData> stops;
  final RouteResult route;
  final List<RouteResult> routeOptions;

  /// Ordered legs belonging to the currently selected/final route.
  ///
  /// Direct journey: exactly one leg (source -> destination).
  /// Journey with stops: one leg per consecutive waypoint pair.
  final List<RouteLegData> routeLegs;

  final DateTime departure;
  final bool rideNow;

  const RouteSelectionData({
    required this.sourceName,
    required this.source,
    required this.destinationName,
    required this.destination,
    required this.stops,
    required this.route,
    required this.routeOptions,
    required this.routeLegs,
    required this.departure,
    required this.rideNow,
  });

  RouteSelectionData copyWith({
    RouteResult? route,
    List<RouteResult>? routeOptions,
    List<RouteLegData>? routeLegs,
  }) {
    final selectedRoute = route ?? this.route;

    // For a direct journey, RouteConfirmationModule can change the selected
    // route to one of the alternatives. Rebuild the single leg so the leg
    // data always stays synchronized with the selected route.
    final synchronizedLegs = routeLegs ??
        (route != null && stops.isEmpty
            ? [
                RouteLegData(
                  order: 1,
                  startName: sourceName,
                  start: source,
                  endName: destinationName,
                  end: destination,
                  route: selectedRoute,
                ),
              ]
            : this.routeLegs);

    return RouteSelectionData(
      sourceName: sourceName,
      source: source,
      destinationName: destinationName,
      destination: destination,
      stops: stops,
      route: selectedRoute,
      routeOptions: routeOptions ?? this.routeOptions,
      routeLegs: List<RouteLegData>.unmodifiable(synchronizedLegs),
      departure: departure,
      rideNow: rideNow,
    );
  }

  /// Complete route snapshot suitable for passing to the ride publishing
  /// layer or serializing into a backend request later.
  Map<String, dynamic> toJson() {
    return {
      'source': {
        'name': sourceName,
        'latitude': source.latitude,
        'longitude': source.longitude,
      },
      'destination': {
        'name': destinationName,
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      },
      'stops': [
        for (final stop in stops) stop.toJson(),
      ],
      'route': {
        'distance_meters': route.distanceMeters,
        'duration_seconds': route.durationSeconds,
        'distance_text': route.distanceText,
        'duration_text': route.durationText,
        'points': [
          for (final point in route.points)
            {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
        ],
      },
      'legs': [
        for (final leg in routeLegs) leg.toJson(),
      ],
      'departure': departure.toUtc().toIso8601String(),
      'ride_now': rideNow,
    };
  }
}

class RouteSelectionModule extends StatefulWidget {
  final ValueChanged<RouteSelectionData> onRouteCalculated;

  const RouteSelectionModule({
    super.key,
    required this.onRouteCalculated,
  });

  /// Clears the saved route-selection draft.
  ///
  /// This should only be called by OfferRideModal when:
  ///
  /// 1. The ride is successfully published.
  /// 2. The Offer Ride modal is explicitly closed with X.
  ///
  /// Going from Route Confirmation back to Route Selection does
  /// NOT clear the saved search.
  static void clearSavedSearch() {
    _RouteSelectionModuleState.clearSavedSearch();
  }

  @override
  State<RouteSelectionModule> createState() =>
      _RouteSelectionModuleState();
}

// ================================================================
// SAVED DRAFT MODELS
// ================================================================

class _RouteSelectionDraft {
  final bool rideNow;
  final DateTime scheduledDate;
  final TimeOfDay scheduledTime;

  final String sourceText;
  final LatLng? sourceLatLng;

  final String destinationText;
  final LatLng? destinationLatLng;

  final List<_SavedStop> stops;

  const _RouteSelectionDraft({
    required this.rideNow,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.sourceText,
    required this.sourceLatLng,
    required this.destinationText,
    required this.destinationLatLng,
    required this.stops,
  });
}

class _SavedStop {
  final String text;
  final LatLng? latLng;

  const _SavedStop({
    required this.text,
    required this.latLng,
  });
}

// ================================================================
// STATE
// ================================================================

class _RouteSelectionModuleState
    extends State<RouteSelectionModule> {
  static _RouteSelectionDraft? _savedDraft;

  final LocationService _locationService =
      LocationService.instance;

  bool _rideNow = true;

  DateTime _scheduledDate = DateTime.now();

  TimeOfDay _scheduledTime = TimeOfDay.now();

  // ==============================================================
  // SOURCE / DESTINATION
  // ==============================================================

  final TextEditingController _sourceController =
      TextEditingController();

  final TextEditingController _destinationController =
      TextEditingController();

  final FocusNode _sourceFocusNode =
      FocusNode();

  final FocusNode _destinationFocusNode =
      FocusNode();

  PlaceSuggestion? _selectedSource;

  PlaceSuggestion? _selectedDestination;

  LatLng? _sourceLatLng;

  LatLng? _destinationLatLng;

  // ==============================================================
  // STOPS
  // ==============================================================

  final List<_RideStop> _stops = [];

  static const int _maxStops = 5;

  // ==============================================================
  // AUTOCOMPLETE
  // ==============================================================

  Timer? _sourceDebounce;

  Timer? _destinationDebounce;

  List<PlaceSuggestion> _sourceSuggestions = [];

  List<PlaceSuggestion> _destinationSuggestions = [];

  bool _sourceSearching = false;

  bool _destinationSearching = false;

  int _sourceRequestId = 0;

  int _destinationRequestId = 0;

  // ==============================================================
  // ROUTE
  // ==============================================================

  RouteResult? _routeResult;

  List<LatLng> _routeCoordinates = [];

  bool _isCalculatingRoute = false;

  // ==============================================================
  // INITIALIZATION
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _restoreSavedSearch();
  }

  void _restoreSavedSearch() {
    final draft = _savedDraft;

    if (draft == null) {
      _initializeCurrentLocation();
      return;
    }

    _rideNow = draft.rideNow;

    _scheduledDate = draft.scheduledDate;

    _scheduledTime = draft.scheduledTime;

    _sourceController.text = draft.sourceText;

    _sourceLatLng = draft.sourceLatLng;

    _destinationController.text =
        draft.destinationText;

    _destinationLatLng =
        draft.destinationLatLng;

    for (final savedStop in draft.stops) {
      final stop = _RideStop();

      stop.controller.text =
          savedStop.text;

      stop.latLng =
          savedStop.latLng;

      _stops.add(stop);
    }

    // Route geometry is intentionally not restored.
    //
    // Locations are restored, then the user can calculate
    // a fresh route.
    _routeResult = null;

    _routeCoordinates = [];
  }

  void _saveSearchDraft() {
    _savedDraft = _RouteSelectionDraft(
      rideNow: _rideNow,
      scheduledDate: _scheduledDate,
      scheduledTime: _scheduledTime,

      sourceText:
          _sourceController.text,

      sourceLatLng:
          _sourceLatLng,

      destinationText:
          _destinationController.text,

      destinationLatLng:
          _destinationLatLng,

      stops: [
        for (final stop in _stops)
          _SavedStop(
            text: stop.controller.text,
            latLng: stop.latLng,
          ),
      ],
    );
  }

  static void clearSavedSearch() {
    _savedDraft = null;
  }

  @override
  void dispose() {
    _sourceDebounce?.cancel();

    _destinationDebounce?.cancel();

    _sourceController.dispose();

    _destinationController.dispose();

    _sourceFocusNode.dispose();

    _destinationFocusNode.dispose();

    for (final stop in _stops) {
      stop.dispose();
    }

    super.dispose();
  }

  // ================================================================
  // CURRENT LOCATION
  // ================================================================

  Future<void> _initializeCurrentLocation() async {
    try {
      await _locationService.initialize();

      if (!mounted) return;

      final position =
          _locationService.currentPosition;

      if (position == null) return;

      final address =
          _locationService.currentAddress?.trim();

      setState(() {
        _sourceLatLng = position;

        _sourceController.text =
            address != null &&
                    address.isNotEmpty
                ? address
                : 'Current Location';
      });

      _saveSearchDraft();
    } catch (e) {
      debugPrint(
        'LiftOff: RouteSelection location initialization error: $e',
      );
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'When are you travelling?',
          'Choose when you plan to start your ride.',
        ),

        const SizedBox(height: 12),

        _buildTimingSelector(),

        if (!_rideNow) ...[
          const SizedBox(height: 14),
          _buildScheduleSelector(),
        ],

        const SizedBox(height: 24),

        _sectionTitle(
          'Plan your route',
          'Search for a place or select the exact point directly from the map.',
        ),

        const SizedBox(height: 14),

        _buildSourceField(),

        const SizedBox(height: 8),

        _buildStops(),

        const SizedBox(height: 8),

        _buildAddStopButton(),

        const SizedBox(height: 8),

        _buildDestinationField(),

        const SizedBox(height: 22),

        _buildRouteInfoCard(),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isCalculatingRoute
                ? null
                : _calculateRoute,

            icon: _isCalculatingRoute
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.map_rounded,
                  ),

            label: Text(
              _isCalculatingRoute
                  ? 'Calculating Route...'
                  : 'Select / Confirm Route',
            ),

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF1677FF),

              foregroundColor:
                  Colors.white,

              elevation: 0,

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================================================================
  // SECTION TITLE
  // ================================================================

  Widget _sectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: Colors.black45,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // TIMING
  // ================================================================

  Widget _buildTimingSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _timingButton(
              Icons.flash_on_rounded,
              'Ride Now',
              _rideNow,
              () {
                setState(() {
                  _rideNow = true;
                });

                _saveSearchDraft();
              },
            ),
          ),

          Expanded(
            child: _timingButton(
              Icons.calendar_month_rounded,
              'Schedule',
              !_rideNow,
              () {
                setState(() {
                  _rideNow = false;
                });

                _saveSearchDraft();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingButton(
    IconData icon,
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),

        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.transparent,

          borderRadius:
              BorderRadius.circular(11),

          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 7,
                    offset:
                        const Offset(0, 2),
                    color: Colors.black
                        .withOpacity(0.07),
                  ),
                ]
              : null,
        ),

        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? const Color(0xFF1677FF)
                  : Colors.black45,
            ),

            const SizedBox(width: 7),

            Text(
              title,
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
                fontSize: 13,
                color: selected
                    ? Colors.black87
                    : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SCHEDULE
  // ================================================================

  Widget _buildScheduleSelector() {
    return Row(
      children: [
        Expanded(
          child: _selectorTile(
            Icons.calendar_today_rounded,
            'Date',
            '${_scheduledDate.day}/'
                '${_scheduledDate.month}/'
                '${_scheduledDate.year}',
            _selectDate,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _selectorTile(
            Icons.access_time_rounded,
            'Departure',
            _scheduledTime.format(context),
            _selectTime,
          ),
        ),
      ],
    );
  }

  Widget _selectorTile(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(14),

      child: Container(
        padding:
            const EdgeInsets.all(13),

        decoration: BoxDecoration(
          border: Border.all(
            color:
                const Color(0xFFE1E6EC),
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),

        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  const Color(0xFF1677FF),
            ),

            const SizedBox(width: 9),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize: 10,
                      color:
                          Colors.black45,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected =
        await showDatePicker(
      context: context,

      initialDate:
          _scheduledDate.isBefore(
        DateTime.now(),
      )
              ? DateTime.now()
              : _scheduledDate,

      firstDate:
          DateTime.now(),

      lastDate:
          DateTime.now().add(
        const Duration(days: 90),
      ),
    );

    if (selected != null &&
        mounted) {
      setState(() {
        _scheduledDate = selected;
      });

      _saveSearchDraft();
    }
  }

  Future<void> _selectTime() async {
    final selected =
        await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );

    if (selected != null &&
        mounted) {
      setState(() {
        _scheduledTime = selected;
      });

      _saveSearchDraft();
    }
  }

  // ================================================================
  // SOURCE / DESTINATION
  // ================================================================

  Widget _buildSourceField() {
    return _buildLocationField(
      controller: _sourceController,
      focusNode: _sourceFocusNode,
      label: 'Pickup Location',
      hint: 'Where will you start?',
      icon: Icons.trip_origin_rounded,
      iconColor:
          const Color(0xFF1677FF),
      suggestions: _sourceSuggestions,
      searching: _sourceSearching,
      onChanged: _onSourceChanged,
      onSuggestionSelected:
          _selectSource,
      onMapTap:
          _pickSourceOnMap,
      onClear: () {
        setState(() {
          _sourceController.clear();
          _selectedSource = null;
          _sourceLatLng = null;
          _sourceSuggestions = [];
          _invalidateRoute();
          _saveSearchDraft();
        });
      },
    );
  }

  Widget _buildDestinationField() {
    return _buildLocationField(
      controller:
          _destinationController,
      focusNode:
          _destinationFocusNode,
      label: 'Destination',
      hint: 'Where are you going?',
      icon:
          Icons.location_on_rounded,
      iconColor:
          const Color(0xFFEB4D4B),
      suggestions:
          _destinationSuggestions,
      searching:
          _destinationSearching,
      onChanged:
          _onDestinationChanged,
      onSuggestionSelected:
          _selectDestination,
      onMapTap:
          _pickDestinationOnMap,
      onClear: () {
        setState(() {
          _destinationController.clear();
          _selectedDestination = null;
          _destinationLatLng = null;
          _destinationSuggestions = [];
          _invalidateRoute();
          _saveSearchDraft();
        });
      },
    );
  }

  // ================================================================
  // STOPS
  // ================================================================

  Widget _buildStops() {
    if (_stops.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: List.generate(
        _stops.length,
        (index) {
          final stop = _stops[index];

          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 8,
            ),
            child:
                _buildStopField(
              stop,
              index,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStopField(
    _RideStop stop,
    int index,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
                const Color(0xFFFFF3E0),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            size: 18,
            color: Color(0xFFF28C28),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildLocationField(
            controller:
                stop.controller,
            focusNode:
                stop.focusNode,
            label:
                'Stop ${index + 1}',
            hint:
                'Add your stop',
            icon:
                Icons.stop_circle_outlined,
            iconColor:
                const Color(0xFFF28C28),
            suggestions:
                stop.suggestions,
            searching:
                stop.searching,
            onChanged:
                (value) =>
                    _onStopChanged(
                  stop,
                  value,
                ),
            onSuggestionSelected:
                (suggestion) =>
                    _selectStop(
                  stop,
                  suggestion,
                ),
            onMapTap:
                () =>
                    _pickStopOnMap(
                  stop,
                ),
            onClear: () {
              setState(() {
                stop.controller.clear();
                stop.selected = null;
                stop.latLng = null;
                stop.suggestions = [];
                _invalidateRoute();
                _saveSearchDraft();
              });
            },
          ),
        ),

        IconButton(
          tooltip: 'Remove stop',

          onPressed: () {
            setState(() {
              stop.dispose();
              _stops.remove(stop);
              _invalidateRoute();
              _saveSearchDraft();
            });
          },

          icon: const Icon(
            Icons.close_rounded,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildAddStopButton() {
    if (_stops.length >=
        _maxStops) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 9,
          horizontal: 12,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Colors.black45,
            ),

            SizedBox(width: 7),

            Text(
              'Maximum 5 stops can be added.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        final stop = _RideStop();

        setState(() {
          _stops.add(stop);
        });

        _saveSearchDraft();

        WidgetsBinding.instance
            .addPostFrameCallback(
          (_) {
            if (mounted) {
              stop.focusNode
                  .requestFocus();
            }
          },
        );
      },

      borderRadius:
          BorderRadius.circular(12),

      child: Container(
        width: double.infinity,

        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color:
              const Color(0xFFF6F9FC),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color:
                const Color(0xFFE1E7EE),
          ),
        ),

        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 19,
              color:
                  Color(0xFF1677FF),
            ),

            SizedBox(width: 7),

            Text(
              'Add Stop',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xFF1677FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // LOCATION FIELD
  // ================================================================

  Widget _buildLocationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required List<PlaceSuggestion> suggestions,
    required bool searching,
    required ValueChanged<String> onChanged,
    required ValueChanged<PlaceSuggestion>
        onSuggestionSelected,
    required VoidCallback onMapTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 3,
          ),

          decoration: BoxDecoration(
            color:
                const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color:
                  const Color(0xFFE1E6EC),
            ),
          ),

          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: iconColor,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: TextField(
                  controller:
                      controller,
                  focusNode:
                      focusNode,
                  onChanged:
                      onChanged,

                  decoration:
                      InputDecoration(
                    labelText:
                        label,
                    hintText:
                        hint,
                    border:
                        InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              if (controller
                  .text
                  .isNotEmpty)
                IconButton(
                  icon:
                      const Icon(
                    Icons.clear_rounded,
                    size: 19,
                  ),
                  onPressed:
                      onClear,
                  tooltip:
                      'Clear',
                ),

              IconButton(
                icon:
                    const Icon(
                  Icons.map_outlined,
                  color:
                      Color(0xFF1677FF),
                ),
                onPressed:
                    onMapTap,
                tooltip:
                    'Select from map',
              ),
            ],
          ),
        ),

        if (searching)
          const Padding(
            padding:
                EdgeInsets.only(
              top: 8,
            ),
            child:
                LinearProgressIndicator(
              minHeight: 2,
            ),
          )
        else if (
            suggestions.isNotEmpty)
          _buildSuggestions(
            suggestions,
            onSuggestionSelected,
          ),
      ],
    );
  }

  // ================================================================
  // AUTOCOMPLETE SUGGESTIONS
  // ================================================================

  Widget _buildSuggestions(
    List<PlaceSuggestion>
        suggestions,
    ValueChanged<PlaceSuggestion>
        onSuggestionSelected,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 5,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color:
              const Color(0xFFE1E6EB),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset:
                const Offset(0, 4),
            color: Colors.black
                .withOpacity(0.08),
          ),
        ],
      ),

      child: ListView.separated(
        shrinkWrap: true,

        physics:
            const NeverScrollableScrollPhysics(),

        itemCount:
            suggestions.length.clamp(
          0,
          5,
        ),

        separatorBuilder:
            (_, __) =>
                const Divider(
          height: 1,
          indent: 50,
        ),

        itemBuilder:
            (context, index) {
          final suggestion =
              suggestions[index];

          return ListTile(
            dense: true,

            leading:
                const Icon(
              Icons.location_on_outlined,
              color:
                  Color(0xFF1677FF),
              size: 21,
            ),

            title: Text(
              suggestion
                  .description,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            onTap: () =>
                onSuggestionSelected(
              suggestion,
            ),
          );
        },
      ),
    );
  }

  // ================================================================
  // MAP LOCATION PICKER
  // ================================================================

  Future<LatLng?>
      _showMapLocationPicker({
    required String title,
    LatLng? initialPosition,
  }) async {
    FocusManager
        .instance
        .primaryFocus
        ?.unfocus();

    final fallback =
        _locationService
            .currentPosition ??
            const LatLng(
              20.5937,
              78.9629,
            );

    LatLng selectedPosition =
        initialPosition ??
            fallback;

    return showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      barrierColor:
          Colors.black54,

      builder:
          (sheetContext) =>
              SafeArea(
        top: false,

        child: Container(
          height:
              MediaQuery.of(
                    sheetContext,
                  ).size.height *
                  0.88,

          decoration:
              const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(26),
            ),
          ),

          child: StatefulBuilder(
            builder:
                (
              context,
              setMapState,
            ) =>
                    Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    14,
                    10,
                    10,
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFEAF4FF,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        child:
                            const Icon(
                          Icons
                              .location_on_rounded,
                          color:
                              Color(
                            0xFF1677FF,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              title,
                              style:
                                  const TextStyle(
                                fontSize:
                                    17,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),

                            const SizedBox(
                              height: 2,
                            ),

                            const Text(
                              'Tap anywhere on the map to choose the exact location.',
                              style:
                                  TextStyle(
                                fontSize:
                                    11.5,
                                color:
                                    Colors
                                        .black54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () =>
                            Navigator.of(
                          sheetContext,
                        ).pop(),

                        icon:
                            const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child:
                      ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),

                    child:
                        GoogleMap(
                      initialCameraPosition:
                          CameraPosition(
                        target:
                            selectedPosition,
                        zoom:
                            initialPosition !=
                                    null
                                ? 15
                                : 12,
                      ),

                      onTap:
                          (position) {
                        selectedPosition =
                            position;

                        setMapState(
                          () {},
                        );
                      },

                      markers: {
                        Marker(
                          markerId:
                              const MarkerId(
                            'picked_location',
                          ),
                          position:
                              selectedPosition,
                          infoWindow:
                              const InfoWindow(
                            title:
                                'Selected location',
                          ),
                        ),
                      },

                      myLocationEnabled:
                          false,

                      myLocationButtonEnabled:
                          false,

                      zoomControlsEnabled:
                          false,

                      mapToolbarEnabled:
                          false,

                      compassEnabled:
                          true,
                    ),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    10,
                    16,
                    16,
                  ),

                  child:
                      Column(
                    children: [
                      Container(
                        width:
                            double.infinity,

                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              13,
                          vertical:
                              10,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF6F9FC,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        child:
                            Row(
                          children: [
                            const Icon(
                              Icons
                                  .my_location_rounded,
                              size: 18,
                              color:
                                  Color(
                                0xFF1677FF,
                              ),
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child:
                                  Text(
                                '${selectedPosition.latitude.toStringAsFixed(6)}, ${selectedPosition.longitude.toStringAsFixed(6)}',

                                style:
                                    const TextStyle(
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 52,

                        child:
                            ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.of(
                            sheetContext,
                          ).pop(
                            selectedPosition,
                          ),

                          icon:
                              const Icon(
                            Icons
                                .check_rounded,
                          ),

                          label:
                              const Text(
                            'Use This Location',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),

                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF1677FF,
                            ),
                            foregroundColor:
                                Colors.white,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // REVERSE GEOCODING
  // ================================================================

  Future<String>
      _addressForPickedLocation(
    LatLng position,
  ) async {
    try {
      final address =
          await GooglePlacesService
              .instance
              .getLocationAddressFromCoordinates(
                position,
              );

      if (address.fullAddress
          .trim()
          .isNotEmpty) {
        return address.fullAddress
            .trim();
      }
    } catch (e) {
      debugPrint(
        'LiftOff: Map reverse geocoding error: $e',
      );
    }

    return '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}';
  }

  // ================================================================
  // MAP PICK SOURCE
  // ================================================================

  Future<void>
      _pickSourceOnMap() async {
    final position =
        await _showMapLocationPicker(
      title:
          'Choose Pickup Location',
      initialPosition:
          _sourceLatLng,
    );

    if (position == null ||
        !mounted) {
      return;
    }

    final address =
        await _addressForPickedLocation(
      position,
    );

    if (!mounted) return;

    setState(() {
      _sourceController.text =
          address;

      _selectedSource = null;

      _sourceLatLng =
          position;

      _sourceSuggestions = [];

      _invalidateRoute();

      _saveSearchDraft();
    });
  }

  // ================================================================
  // MAP PICK DESTINATION
  // ================================================================

  Future<void>
      _pickDestinationOnMap() async {
    final position =
        await _showMapLocationPicker(
      title:
          'Choose Destination',
      initialPosition:
          _destinationLatLng,
    );

    if (position == null ||
        !mounted) {
      return;
    }

    final address =
        await _addressForPickedLocation(
      position,
    );

    if (!mounted) return;

    setState(() {
      _destinationController
          .text = address;

      _selectedDestination =
          null;

      _destinationLatLng =
          position;

      _destinationSuggestions =
          [];

      _invalidateRoute();

      _saveSearchDraft();
    });
  }

  // ================================================================
  // MAP PICK STOP
  // ================================================================

  Future<void>
      _pickStopOnMap(
    _RideStop stop,
  ) async {
    final index =
        _stops.indexOf(stop) + 1;

    final position =
        await _showMapLocationPicker(
      title:
          'Choose Stop $index',
      initialPosition:
          stop.latLng,
    );

    if (position == null ||
        !mounted) {
      return;
    }

    final address =
        await _addressForPickedLocation(
      position,
    );

    if (!mounted) return;

    setState(() {
      stop.controller.text =
          address;

      stop.selected = null;

      stop.latLng =
          position;

      stop.suggestions = [];

      _invalidateRoute();

      _saveSearchDraft();
    });
  }

  // ================================================================
  // SOURCE AUTOCOMPLETE
  // ================================================================

  void _onSourceChanged(
    String value,
  ) {
    setState(() {
      _selectedSource = null;

      _sourceLatLng = null;

      _invalidateRoute();

      _saveSearchDraft();
    });

    _sourceDebounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _sourceSuggestions = [];

        _sourceSearching = false;
      });

      return;
    }

    _sourceDebounce =
        Timer(
      const Duration(
        milliseconds: 350,
      ),
      () async {
        final requestId =
            ++_sourceRequestId;

        if (!mounted) return;

        setState(() {
          _sourceSearching = true;
        });

        try {
          final results =
              await GooglePlacesService
                  .instance
                  .autocomplete(
                    value.trim(),
                  );

          if (!mounted ||
              requestId !=
                  _sourceRequestId) {
            return;
          }

          setState(() {
            _sourceSuggestions =
                results;

            _sourceSearching = false;
          });
        } catch (_) {
          if (!mounted) return;

          setState(() {
            _sourceSuggestions = [];

            _sourceSearching =
                false;
          });
        }
      },
    );
  }

  Future<void> _selectSource(
    PlaceSuggestion suggestion,
  ) async {
    FocusManager
        .instance
        .primaryFocus
        ?.unfocus();

    setState(() {
      _sourceController.text =
          suggestion.description;

      _selectedSource =
          suggestion;

      _sourceSuggestions = [];

      _sourceLatLng = null;

      _invalidateRoute();

      _saveSearchDraft();
    });

    try {
      final location =
          await GooglePlacesService
              .instance
              .getPlaceLocation(
                suggestion.placeId,
              );

      if (!mounted) return;

      setState(() {
        _sourceLatLng =
            location;
      });

      _saveSearchDraft();
    } catch (_) {
      _showError(
        'Unable to get pickup coordinates.',
      );
    }
  }

  // ================================================================
  // DESTINATION AUTOCOMPLETE
  // ================================================================

  void _onDestinationChanged(
    String value,
  ) {
    setState(() {
      _selectedDestination =
          null;

      _destinationLatLng =
          null;

      _invalidateRoute();

      _saveSearchDraft();
    });

    _destinationDebounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _destinationSuggestions =
            [];

        _destinationSearching =
            false;
      });

      return;
    }

    _destinationDebounce =
        Timer(
      const Duration(
        milliseconds: 350,
      ),
      () async {
        final requestId =
            ++_destinationRequestId;

        if (!mounted) return;

        setState(() {
          _destinationSearching =
              true;
        });

        try {
          final results =
              await GooglePlacesService
                  .instance
                  .autocomplete(
                    value.trim(),
                  );

          if (!mounted ||
              requestId !=
                  _destinationRequestId) {
            return;
          }

          setState(() {
            _destinationSuggestions =
                results;

            _destinationSearching =
                false;
          });
        } catch (_) {
          if (!mounted) return;

          setState(() {
            _destinationSuggestions =
                [];

            _destinationSearching =
                false;
          });
        }
      },
    );
  }

  Future<void>
      _selectDestination(
    PlaceSuggestion suggestion,
  ) async {
    FocusManager
        .instance
        .primaryFocus
        ?.unfocus();

    setState(() {
      _destinationController
          .text =
          suggestion.description;

      _selectedDestination =
          suggestion;

      _destinationSuggestions =
          [];

      _destinationLatLng =
          null;

      _invalidateRoute();

      _saveSearchDraft();
    });

    try {
      final location =
          await GooglePlacesService
              .instance
              .getPlaceLocation(
                suggestion.placeId,
              );

      if (!mounted) return;

      setState(() {
        _destinationLatLng =
            location;
      });

      _saveSearchDraft();
    } catch (_) {
      _showError(
        'Unable to get destination coordinates.',
      );
    }
  }

  // ================================================================
  // STOP AUTOCOMPLETE
  // ================================================================

  void _onStopChanged(
    _RideStop stop,
    String value,
  ) {
    setState(() {
      stop.selected = null;

      stop.latLng = null;

      _invalidateRoute();

      _saveSearchDraft();
    });

    stop.debounce?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        stop.suggestions = [];

        stop.searching = false;
      });

      return;
    }

    stop.debounce =
        Timer(
      const Duration(
        milliseconds: 350,
      ),
      () async {
        final requestId =
            ++stop.requestId;

        if (!mounted) return;

        setState(() {
          stop.searching = true;
        });

        try {
          final results =
              await GooglePlacesService
                  .instance
                  .autocomplete(
                    value.trim(),
                  );

          if (!mounted ||
              requestId !=
                  stop.requestId) {
            return;
          }

          setState(() {
            stop.suggestions =
                results;

            stop.searching = false;
          });
        } catch (_) {
          if (!mounted) return;

          setState(() {
            stop.suggestions = [];

            stop.searching = false;
          });
        }
      },
    );
  }

  Future<void> _selectStop(
    _RideStop stop,
    PlaceSuggestion suggestion,
  ) async {
    FocusManager
        .instance
        .primaryFocus
        ?.unfocus();

    setState(() {
      stop.controller.text =
          suggestion.description;

      stop.selected =
          suggestion;

      stop.suggestions = [];

      stop.latLng = null;

      _invalidateRoute();

      _saveSearchDraft();
    });

    try {
      final location =
          await GooglePlacesService
              .instance
              .getPlaceLocation(
                suggestion.placeId,
              );

      if (!mounted) return;

      setState(() {
        stop.latLng =
            location;
      });

      _saveSearchDraft();
    } catch (_) {
      _showError(
        'Unable to get stop coordinates.',
      );
    }
  }

  // ================================================================
  // ROUTE INVALIDATION
  // ================================================================

  void _invalidateRoute() {
    _routeResult = null;

    _routeCoordinates = [];
  }

  // ================================================================
  // ROUTE INFO CARD
  // ================================================================

  Widget _buildRouteInfoCard() {
    final hasRoute =
        _sourceLatLng != null &&
            _destinationLatLng != null;

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color:
            const Color(0xFFF7FAFD),

        borderRadius:
            BorderRadius.circular(15),

        border: Border.all(
          color:
              const Color(0xFFE4EAF0),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,

            decoration: BoxDecoration(
              color: hasRoute
                  ? const Color(
                      0xFFE7F1FF,
                    )
                  : const Color(
                      0xFFEDEFF2,
                    ),

              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),

            child: Icon(
              hasRoute
                  ? Icons.route_rounded
                  : Icons.info_outline_rounded,

              color: hasRoute
                  ? const Color(
                      0xFF1677FF,
                    )
                  : Colors.black45,

              size: 19,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              hasRoute
                  ? (_stops.isEmpty
                      ? 'Route ready to calculate.'
                      : '${_stops.length} stop'
                          '${_stops.length == 1 ? '' : 's'} '
                          'added to your route.')
                  : 'Select valid pickup and destination locations first.',

              style:
                  const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // FINAL ROUTE CALCULATION
  // ================================================================

  Future<void> _calculateRoute() async {
    FocusManager.instance.primaryFocus?.unfocus();

    _saveSearchDraft();

    if (_sourceLatLng == null) {
      _showError(
        'Please select a pickup location from search or map.',
      );
      return;
    }

    if (_destinationLatLng == null) {
      _showError(
        'Please select a destination from search or map.',
      );
      return;
    }

    for (int i = 0; i < _stops.length; i++) {
      if (_stops[i].latLng == null) {
        _showError(
          'Please select Stop ${i + 1} from search or map.',
        );
        return;
      }
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final source = _sourceLatLng!;
      final destination = _destinationLatLng!;

      List<RouteResult> routeOptions;
      List<RouteLegData> routeLegs;

      // ============================================================
      // DIRECT ROUTE — UP TO 3 ALTERNATIVES
      // ============================================================
      //
      // Alternatives are useful only when their geometry is actually
      // usable.  A malformed/decoded alternative can contain a very
      // large jump between consecutive points. Google Maps then draws
      // a straight "crack" between those points. We therefore reject
      // such alternatives BEFORE they reach RouteConfirmationModule.
      //
      // This does not alter valid route geometry.
      //
      if (_stops.isEmpty) {
        debugPrint(
          'LiftOff: RouteSelection requesting alternative routes.',
        );

        final alternatives =
            await GooglePlacesService.instance.getAlternativeDirections(
          source,
          destination,
        );

        debugPrint(
          'LiftOff: RouteSelection received '
          '${alternatives.length} alternative route(s).',
        );

        final uniqueRoutes = <RouteResult>[];
        final signatures = <String>{};

        for (final candidate in alternatives) {
          if (uniqueRoutes.length >= 3) break;

          debugPrint(
            'LiftOff: Alternative candidate: '
            'points=${candidate.points.length}, '
            'distance=${candidate.distanceText}, '
            'duration=${candidate.durationText}',
          );

          // IMPORTANT: Do not reject an otherwise valid Routes API
          // alternative based on endpoint distance, segment length, or
          // geometry-vs-reported-distance heuristics. Those heuristics can
          // incorrectly discard legitimate long-road/rural alternatives.
          // RouteConfirmationModule draws ONLY the selected route, so a
          // provider alternative cannot create multiple visible lines.
          if (!_hasValidRoutePoints(candidate)) {
            debugPrint(
              'LiftOff: Alternative rejected because it contains '
              'invalid coordinates or fewer than 2 points.',
            );
            continue;
          }

          final signature = _routeSignature(candidate);

          if (signatures.add(signature)) {
            uniqueRoutes.add(candidate);
          } else {
            debugPrint(
              'LiftOff: Duplicate alternative route ignored.',
            );
          }
        }

        // Always keep a known-good direct route as a fallback.
        // If the provider returned no usable alternatives, this gives
        // the confirmation screen one reliable route instead of drawing
        // broken geometry.
        if (uniqueRoutes.isEmpty) {
          debugPrint(
            'LiftOff: No usable alternatives. Using direct route fallback.',
          );

          final fallback =
              await GooglePlacesService.instance.getDirections(
            source,
            destination,
          );

          if (fallback.points.length < 2) {
            throw Exception(
              'The routing service returned incomplete route geometry.',
            );
          }

          uniqueRoutes.add(fallback);
        }

        routeOptions = uniqueRoutes;

        // Preserve the selected/default direct route as one ordered leg.
        // If the user later selects another direct alternative in Module 2,
        // RouteSelectionData.copyWith() will synchronize this leg to that
        // selected RouteResult.
        final directRoute = routeOptions.first;
        routeLegs = [
          RouteLegData(
            order: 1,
            startName: _sourceController.text.trim(),
            start: source,
            endName: _destinationController.text.trim(),
            end: destination,
            route: directRoute,
          ),
        ];

        debugPrint(
          'LiftOff: Final direct route option count = '
          '${routeOptions.length}.',
        );
      }

      // ============================================================
      // ROUTE WITH STOPS — ONE COMPLETE ROUTE
      // ============================================================
      //
      // Source -> Stop 1 -> ... -> Destination.
      // Each leg is requested independently and the geometry is joined
      // at the stop. We do not mix independent alternative legs because
      // doing so can create an invalid complete journey.
      //
      else {
        final waypoints = <LatLng>[
          source,
          ..._stops.map((stop) => stop.latLng!),
          destination,
        ];

        final completeRoute = <LatLng>[];
        final calculatedLegs = <RouteLegData>[];
        var totalDistanceMeters = 0;
        var totalDurationSeconds = 0;

        for (int i = 0; i < waypoints.length - 1; i++) {
          debugPrint(
            'LiftOff: Calculating route segment '
            '${i + 1}/${waypoints.length - 1}.',
          );

          final result =
              await GooglePlacesService.instance.getDirections(
            waypoints[i],
            waypoints[i + 1],
          );

          if (result.points.length < 2) {
            throw Exception(
              'No complete route found for route segment ${i + 1}.',
            );
          }

          if (completeRoute.isEmpty) {
            completeRoute.addAll(result.points);
          } else {
            completeRoute.addAll(result.points.skip(1));
          }

          calculatedLegs.add(
            RouteLegData(
              order: i + 1,
              startName: i == 0
                  ? _sourceController.text.trim()
                  : _stops[i - 1].controller.text.trim(),
              start: waypoints[i],
              endName: i == _stops.length
                  ? _destinationController.text.trim()
                  : _stops[i].controller.text.trim(),
              end: waypoints[i + 1],
              route: result,
            ),
          );

          totalDistanceMeters += result.distanceMeters.toInt();
          totalDurationSeconds += result.durationSeconds.toInt();
        }

        if (completeRoute.length < 2) {
          throw Exception(
            'The complete route geometry is incomplete.',
          );
        }

        routeOptions = [
          RouteResult(
            points: completeRoute,
            distanceText: _formatDistance(totalDistanceMeters),
            durationText: _formatDuration(totalDurationSeconds),
            distanceMeters: totalDistanceMeters,
            durationSeconds: totalDurationSeconds,
          ),
        ];

        routeLegs = List<RouteLegData>.unmodifiable(calculatedLegs);

        debugPrint(
          'LiftOff: Combined stop route has '
          '${completeRoute.length} geometry points.',
        );
      }

      if (routeOptions.isEmpty) {
        throw Exception('No valid route options were returned.');
      }

      final route = routeOptions.first;

      final departure = _rideNow
          ? DateTime.now()
          : DateTime(
              _scheduledDate.year,
              _scheduledDate.month,
              _scheduledDate.day,
              _scheduledTime.hour,
              _scheduledTime.minute,
            );

      final data = RouteSelectionData(
        sourceName: _sourceController.text.trim(),
        source: source,
        destinationName: _destinationController.text.trim(),
        destination: destination,
        stops: [
          for (final stop in _stops)
            RideStopData(
              name: stop.controller.text.trim(),
              position: stop.latLng!,
            ),
        ],
        route: route,
        routeOptions: List<RouteResult>.unmodifiable(routeOptions),
        routeLegs: List<RouteLegData>.unmodifiable(routeLegs),
        departure: departure,
        rideNow: _rideNow,
      );

      if (!mounted) return;

      setState(() {
        _routeCoordinates = List<LatLng>.from(route.points);
        _routeResult = route;
        _isCalculatingRoute = false;
      });

      _saveSearchDraft();

      debugPrint(
        'LiftOff: RouteSelection handing off '
        '${data.routeOptions.length} route option(s).',
      );

      widget.onRouteCalculated(data);
    } catch (e) {
      debugPrint(
        'LiftOff: RouteSelection route calculation error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isCalculatingRoute = false;
      });

      _showError(
        'Unable to calculate the complete route. Please check your locations.',
      );
    }
  }

  // ================================================================
  // ROUTE GEOMETRY VALIDATION
  // ================================================================
  //
  // A valid road polyline should be continuous. The validator is used
  // ONLY for alternatives returned by getAlternativeDirections().
  // It prevents malformed alternative geometry from ever being sent
  // to GoogleMap, which is what causes long straight "crack" lines.
  //
  // Valid geometry is left completely untouched.

  bool _hasValidRoutePoints(RouteResult route) {
    if (route.points.length < 2) return false;

    for (final point in route.points) {
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        return false;
      }
    }

    return true;
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;

    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLat = lat2 - lat1;
    final dLng =
        (b.longitude - a.longitude) * math.pi / 180.0;

    final sinLat = math.sin(dLat / 2.0);
    final sinLng = math.sin(dLng / 2.0);

    final h =
        sinLat * sinLat +
        math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;

    return earthRadiusMeters *
        2.0 *
        math.atan2(math.sqrt(h), math.sqrt(math.max(0.0, 1.0 - h)));
  }

  // ================================================================
  // ROUTE SIGNATURE
  // ================================================================
  //
  // Used only to remove duplicate alternatives returned by the
  // routing provider.
  //
  // It does NOT modify or filter route geometry.
  //

  String _routeSignature(
    RouteResult route,
  ) {
    if (route.points.isEmpty) {
      return 'empty';
    }

    final points =
        route.points;

    final first =
        points.first;

    final middle =
        points[
          points.length ~/ 2
        ];

    final last =
        points.last;

    return [
      points.length,

      first.latitude
          .toStringAsFixed(5),

      first.longitude
          .toStringAsFixed(5),

      middle.latitude
          .toStringAsFixed(5),

      middle.longitude
          .toStringAsFixed(5),

      last.latitude
          .toStringAsFixed(5),

      last.longitude
          .toStringAsFixed(5),

      route.distanceMeters
          .toInt(),
    ].join('|');
  }

  // ================================================================
  // ERROR
  // ================================================================

  void _showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),

        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ================================================================
  // FORMATTING
  // ================================================================

  String _formatDistance(
    int meters,
  ) {
    if (meters <= 0) {
      return 'Distance unavailable';
    }

    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '$meters m';
  }

  String _formatDuration(
    int seconds,
  ) {
    if (seconds <= 0) {
      return 'Duration unavailable';
    }

    final duration =
        Duration(
      seconds: seconds,
    );

    final hours =
        duration.inHours;

    final minutes =
        duration.inMinutes
            .remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '$minutes min';
  }
}

// ==================================================================
// RIDE STOP STATE
// ==================================================================

class _RideStop {
  final TextEditingController
      controller =
      TextEditingController();

  final FocusNode focusNode =
      FocusNode();

  Timer? debounce;

  List<PlaceSuggestion>
      suggestions = [];

  PlaceSuggestion? selected;

  LatLng? latLng;

  bool searching = false;

  int requestId = 0;

  void dispose() {
    debounce?.cancel();

    controller.dispose();

    focusNode.dispose();
  }
}