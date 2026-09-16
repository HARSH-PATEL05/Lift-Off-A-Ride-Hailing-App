import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/google_places_service.dart';
import 'route_selection_module.dart';

class RouteConfirmationModule extends StatefulWidget {
  final RouteSelectionData data;
  final ValueChanged<RouteResult> onConfirm;
  final VoidCallback onChangeRoute;
  final List<RouteResult>? routeOptions;

  const RouteConfirmationModule({
    super.key,
    required this.data,
    required this.onConfirm,
    required this.onChangeRoute,
    this.routeOptions,
  });

  @override
  State<RouteConfirmationModule> createState() =>
      _RouteConfirmationModuleState();
}

class _RouteConfirmationModuleState extends State<RouteConfirmationModule> {
  GoogleMapController? _mapController;
  int _selectedRouteIndex = 0;
  bool _mapReady = false;
  int _fitGeneration = 0;
  MapType _mapType = MapType.normal;

  // Let the embedded GoogleMap claim pointer sequences so a parent
  // SingleChildScrollView/ListView cannot steal map-drag gestures.
  //
  // On Web, webGestureHandling.greedy makes the Google Maps JS map
  // consume normal mouse/touch gestures (drag to pan, wheel/pinch to zoom)
  // instead of the cooperative "two fingers / Ctrl+scroll" behavior.
  final Set<Factory<OneSequenceGestureRecognizer>> _mapGestureRecognizers = {
    Factory<OneSequenceGestureRecognizer>(
      EagerGestureRecognizer.new,
    ),
  };

  List<RouteResult> get _routes {
    final options = widget.routeOptions ?? widget.data.routeOptions;
    return options.isNotEmpty ? options : <RouteResult>[widget.data.route];
  }

  RouteResult get _selectedRoute {
    final routes = _routes;
    if (routes.isEmpty) return widget.data.route;

    final index = _selectedRouteIndex.clamp(0, routes.length - 1);
    return routes[index];
  }

  @override
  void initState() {
    super.initState();

    final routes = _routes;
    debugPrint(
      'LiftOff: Confirmation received ${routes.length} route option(s): '
      '${routes.map((r) => r.points.length).toList()} geometry points.',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitSelectedRoute(retry: true);
    });
  }

  @override
  void didUpdateWidget(covariant RouteConfirmationModule oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldRoutes = oldWidget.routeOptions ?? oldWidget.data.routeOptions;
    final newRoutes = widget.routeOptions ?? widget.data.routeOptions;

    if (oldRoutes.length != newRoutes.length ||
        oldWidget.data.source != widget.data.source ||
        oldWidget.data.destination != widget.data.destination) {
      _selectedRouteIndex = 0;
    } else {
      _selectedRouteIndex =
          _selectedRouteIndex.clamp(0, math.max(0, newRoutes.length - 1));
    }

    _fitGeneration++;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitSelectedRoute(retry: true);
    });
  }

  List<LatLng> _routePoints(RouteResult route) {
    // The Routes API has already produced the decoded road geometry.
    // Only remove impossible coordinates; NEVER filter based on distance
    // between neighbouring points.
    return route.points
        .where(
          (p) =>
              p.latitude.isFinite &&
              p.longitude.isFinite &&
              p.latitude >= -90 &&
              p.latitude <= 90 &&
              p.longitude >= -180 &&
              p.longitude <= 180,
        )
        .toList(growable: false);
  }

  Future<void> _fitSelectedRoute({bool retry = false}) async {
    if (!mounted) return;

    final selectedRoute = _selectedRoute;
    final selectedGeometry = _routePoints(selectedRoute);

    debugPrint(
      'LiftOff: Confirmation selected route $_selectedRouteIndex: '
      'raw=${selectedRoute.points.length}, valid=${selectedGeometry.length}',
    );

    if (selectedGeometry.length < 2) {
      debugPrint(
        'LiftOff: ERROR - selected route contains fewer than 2 geometry '
        'points. The problem is before GoogleMap rendering.',
      );
      return;
    }

    final controller = _mapController;

    if (!_mapReady || controller == null) {
      if (retry) {
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _fitSelectedRoute(retry: false);
          }
        });
      }
      return;
    }

    final generation = ++_fitGeneration;

    // The confirmation map displays every available route.
    // Fit the camera around all route geometries, not only the selected one.
    final allPoints = <LatLng>[
      widget.data.source,
      for (final route in _routes) ..._routePoints(route),
      widget.data.destination,
    ];

    if (allPoints.length < 2) {
      return;
    }

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final point in allPoints.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if ((maxLat - minLat).abs() < 0.0001) {
      minLat -= 0.01;
      maxLat += 0.01;
    }

    if ((maxLng - minLng).abs() < 0.0001) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));

      if (!mounted || generation != _fitGeneration) return;

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          45,
        ),
      );

      debugPrint(
        'LiftOff: Confirmation map fitted all ${_routes.length} '
        'route(s). Selected route=$_selectedRouteIndex.',
      );
    } catch (e) {
      debugPrint(
        'LiftOff: Confirmation camera fit failed: $e',
      );

      try {
        final center = LatLng(
          (widget.data.source.latitude +
                  widget.data.destination.latitude) /
              2,
          (widget.data.source.longitude +
                  widget.data.destination.longitude) /
              2,
        );

        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(center, 11),
        );
      } catch (fallbackError) {
        debugPrint(
          'LiftOff: Confirmation camera fallback failed: $fallbackError',
        );
      }
    }
  }


  void _selectRoute(int index) {
    if (index < 0 || index >= _routes.length) return;

    setState(() {
      _selectedRouteIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitSelectedRoute(retry: true);
    });
  }

  void _confirmRoute() {
    if (_routes.isEmpty) return;

    // Build the finalized RouteSelectionData snapshot before handing the
    // selected route back to the parent. This does not change the existing
    // callback contract or UI. RouteSelectionData.copyWith() keeps the
    // stored routeLegs synchronized with the selected direct-route
    // alternative; for journeys with stops, the existing ordered legs are
    // preserved.
    final finalizedData = widget.data.copyWith(
      route: _selectedRoute,
    );

    debugPrint(
      'LiftOff: Confirmation finalized route: '
      'index=$_selectedRouteIndex, '
      'points=${finalizedData.route.points.length}, '
      'distance=${finalizedData.route.distanceMeters}, '
      'duration=${finalizedData.route.durationSeconds}, '
      'legs=${finalizedData.routeLegs.length}.',
    );

    // Keep the existing callback API exactly unchanged. The parent receives
    // the finalized RouteResult as before, while the updated
    // RouteSelectionData remains internally synchronized and ready for the
    // publishing layer to carry forward.
    widget.onConfirm(finalizedData.route);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('route_origin'),
        position: widget.data.source,
        infoWindow: InfoWindow(title: widget.data.sourceName),
      ),
      Marker(
        markerId: const MarkerId('route_destination'),
        position: widget.data.destination,
        infoWindow: InfoWindow(title: widget.data.destinationName),
      ),
    };

    for (int i = 0; i < widget.data.stops.length; i++) {
      final stop = widget.data.stops[i];
      markers.add(
        Marker(
          markerId: MarkerId('route_stop_$i'),
          position: stop.position,
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: stop.name,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    if (_routes.isEmpty) {
      return polylines;
    }

    // Draw every available route.
    //
    // Unselected routes:
    //   Light Google-Maps-like blue
    //
    // Selected route:
    //   Dark blue and thicker, drawn above the alternatives.
    for (int index = 0; index < _routes.length; index++) {
      final route = _routes[index];
      final geometry = _routePoints(route);

      if (geometry.length < 2) {
        continue;
      }

      final selected = index == _selectedRouteIndex;

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_$index'),
          points: geometry,

          // Google Maps style:
          // selected = dark blue
          // alternatives = light blue
          color: selected
              ? const Color(0xFF1A73E8)
              : const Color(0xFF8AB4F8),

          width: selected ? 7 : 5,
          visible: true,
          geodesic: false,

          // Always put selected route above alternatives.
          zIndex: selected ? 100 : 10 + index,

          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    debugPrint(
      'LiftOff: Confirmation drawing '
      '${polylines.length} route polyline(s). '
      'Selected route=$_selectedRouteIndex.',
    );

    return polylines;
  }


  String _formatDistance(num meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(num seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
  }

  @override
  Widget build(BuildContext context) {
    final route = _selectedRoute;
    final geometry = _routePoints(route);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_routes.length > 1) ...[
          _buildRouteOptions(),
          const SizedBox(height: 16),
        ],
        _buildMap(geometry),
        const SizedBox(height: 18),
        _buildRouteSummary(route),
        const SizedBox(height: 18),
        _buildRoutePoints(),
        const SizedBox(height: 20),
        _buildActions(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm Your Route',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          _routes.length > 1
              ? 'Choose the route that works best for your ride.'
              : 'Review your route before continuing.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildRouteOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Routes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...List.generate(
          _routes.length,
          (index) => _buildRouteOptionCard(index, _routes[index]),
        ),
      ],
    );
  }

  Widget _buildRouteOptionCard(int index, RouteResult route) {
    final selected = index == _selectedRouteIndex;

    return GestureDetector(
      onTap: () => _selectRoute(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.06)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    index == 0
                        ? 'Recommended Route'
                        : 'Alternative Route ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${route.distanceText} • ${route.durationText}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
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

  Widget _buildMap(List<LatLng> geometry) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildGoogleMap(
                geometry: geometry,
                fullscreen: false,
              ),
            ),

            // --------------------------------------------------
            // MAP CONTROLS
            // --------------------------------------------------

            Positioned(
              right: 12,
              top: 12,
              child: _buildMapControlColumn(
                fullscreen: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMap({
    required List<LatLng> geometry,
    required bool fullscreen,
  }) {
    return GoogleMap(
      // Recreate the map when the selected route changes.
      key: ValueKey(
        'confirmation-map-'
        '${fullscreen ? 'fullscreen' : 'embedded'}-'
        'route-$_selectedRouteIndex-'
        '${_routes.length}-'
        '${geometry.length}',
      ),

      initialCameraPosition: CameraPosition(
        target: widget.data.source,
        zoom: 12,
      ),

      mapType: _mapType,

      myLocationEnabled: false,
      myLocationButtonEnabled: false,

      // We provide custom zoom buttons so this works consistently
      // across Android, iOS and Web.
      zoomControlsEnabled: false,

      compassEnabled: true,
      mapToolbarEnabled: false,

      // Fully interactive map on every supported target.
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      indoorViewEnabled: true,
      buildingsEnabled: true,

      // Prevent surrounding Flutter scrollables from stealing the
      // map's drag gesture. This is especially important on Android/iOS
      // platform views and on Web when the map sits inside a scrollable.
      gestureRecognizers: _mapGestureRecognizers,

      // Web only. On Android/iOS this is ignored by the platform plugin.
      //
      // GREEDY = normal desktop/mobile map interaction:
      // drag to pan, wheel/pinch to zoom, without the cooperative
      // "use two fingers / Ctrl+scroll" restriction.
      webGestureHandling: kIsWeb
          ? WebGestureHandling.greedy
          : null,

      markers: _buildMarkers(),

      // Display ALL routes at the same time.
      polylines: _buildPolylines(),

      onMapCreated: (controller) {
        // Keep the controller for the normal embedded map.
        // Fullscreen has its own controller.
        if (!fullscreen) {
          _mapController = controller;
          _mapReady = true;

          debugPrint(
            'LiftOff: Confirmation GoogleMap created. '
            'Current route geometry=${geometry.length} points. '
            'Showing ${_routes.length} route(s).',
          );

          for (final delay in const [0, 100, 300, 600]) {
            Future<void>.delayed(
              Duration(milliseconds: delay),
              () {
                if (mounted) {
                  _fitSelectedRoute(retry: false);
                }
              },
            );
          }
        } else {
          // In fullscreen mode, fit the camera using the fullscreen
          // controller after the map has been created.
          Future<void>.delayed(
            const Duration(milliseconds: 150),
            () async {
              if (!mounted) return;

              try {
                final allPoints = <LatLng>[
                  widget.data.source,
                  for (final route in _routes)
                    ..._routePoints(route),
                  widget.data.destination,
                ];

                if (allPoints.length < 2) return;

                double minLat = allPoints.first.latitude;
                double maxLat = allPoints.first.latitude;
                double minLng = allPoints.first.longitude;
                double maxLng = allPoints.first.longitude;

                for (final point in allPoints.skip(1)) {
                  minLat = math.min(minLat, point.latitude);
                  maxLat = math.max(maxLat, point.latitude);
                  minLng = math.min(minLng, point.longitude);
                  maxLng = math.max(maxLng, point.longitude);
                }

                if ((maxLat - minLat).abs() < 0.0001) {
                  minLat -= 0.01;
                  maxLat += 0.01;
                }

                if ((maxLng - minLng).abs() < 0.0001) {
                  minLng -= 0.01;
                  maxLng += 0.01;
                }

                await controller.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    LatLngBounds(
                      southwest: LatLng(minLat, minLng),
                      northeast: LatLng(maxLat, maxLng),
                    ),
                    55,
                  ),
                );
              } catch (e) {
                debugPrint(
                  'LiftOff: Fullscreen map fit failed: $e',
                );
              }
            },
          );
        }
      },
    );
  }

  Widget _buildMapControlColumn({
    required bool fullscreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapControlButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onPressed: () {
              _zoomMap(1);
            },
          ),

          const SizedBox(height: 6),

          _buildMapControlButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onPressed: () {
              _zoomMap(-1);
            },
          ),

          const SizedBox(height: 10),

          _buildMapControlButton(
            icon: _mapType == MapType.satellite
                ? Icons.map_outlined
                : Icons.satellite_alt_outlined,
            tooltip: _mapType == MapType.satellite
                ? 'Normal map'
                : 'Satellite view',
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.satellite
                    ? MapType.normal
                    : MapType.satellite;
              });
            },
          ),

          const SizedBox(height: 6),

          _buildMapControlButton(
            icon: fullscreen
                ? Icons.fullscreen_exit
                : Icons.fullscreen,
            tooltip: fullscreen
                ? 'Exit fullscreen'
                : 'Fullscreen',
            onPressed: () {
              if (fullscreen) {
                Navigator.of(context).pop();
              } else {
                _openFullscreenMap();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 3,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 21,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _zoomMap(double amount) async {
    final controller = _mapController;

    if (!_mapReady || controller == null) {
      return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.zoomBy(amount),
      );
    } catch (e) {
      debugPrint(
        'LiftOff: Map zoom failed: $e',
      );
    }
  }

  void _openFullscreenMap() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildGoogleMap(
                      geometry: _routePoints(_selectedRoute),
                      fullscreen: true,
                    ),
                  ),

                  // Fullscreen map controls.
                  // The fullscreen exit button is included here,
                  // so there is only ONE minimize/exit control.
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _buildMapControlColumn(
                      fullscreen: true,
                    ),
                  ),

                  // Small route legend.
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: _buildMapLegend(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapLegend() {
    return Material(
      elevation: 3,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendRow(
              const Color(0xFF1A73E8),
              'Selected route',
            ),
            const SizedBox(height: 6),
            _buildLegendRow(
              const Color(0xFF8AB4F8),
              'Alternative route',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(
    Color color,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }


  Widget _buildRouteSummary(RouteResult route) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              Icons.route,
              'Distance',
              route.distanceText.isNotEmpty
                  ? route.distanceText
                  : _formatDistance(route.distanceMeters),
            ),
          ),
          Container(height: 42, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: _summaryItem(
              Icons.schedule,
              'Duration',
              route.durationText.isNotEmpty
                  ? route.durationText
                  : _formatDuration(route.durationSeconds),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoutePoints() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _buildLocationRow(
          icon: Icons.radio_button_checked,
          title: 'Pickup',
          value: widget.data.sourceName,
          isFirst: true,
        ),
        for (int i = 0; i < widget.data.stops.length; i++)
          _buildLocationRow(
            icon: Icons.location_on_outlined,
            title: 'Stop ${i + 1}',
            value: widget.data.stops[i].name,
          ),
        _buildLocationRow(
          icon: Icons.location_on,
          title: 'Destination',
          value: widget.data.destinationName,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String title,
    required String value,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Icon(
                icon,
                size: 19,
                color: isLast
                    ? Colors.redAccent
                    : Theme.of(context).colorScheme.primary,
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.grey.shade300,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onChangeRoute,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Change Route',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _confirmRoute,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Confirm Route',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
