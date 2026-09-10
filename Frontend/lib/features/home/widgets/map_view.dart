import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';

/// Identifies which location is currently being selected from the map.
enum MapSelectionMode {
  source,
  destination,
}

/// Interactive Live Map View.
///
/// Location architecture:
///
///     Phone GPS
///         │
///         ▼
///   LocationService
///         │
///         └── livePositionStream
///                  │
///                  ▼
///               MapView
///
/// MapView does NOT:
/// - create its own GPS stream
/// - persist GPS locations
/// - monitor GPS service status
/// - read SharedPreferences directly
///
/// All location ownership belongs to LocationService.
///
/// Other features:
/// - Safe meeting node markers
/// - Active corridor polylines
/// - Actual road route polyline
/// - Source/destination selection directly from map
/// - Mouse drag support
/// - Mouse wheel zoom support
/// - Repeated location selection
/// - Recenter button
/// - Normal / Satellite toggle
/// - Fullscreen toggle
class MapView extends StatefulWidget {
  final bool isFullscreen;

  final ValueChanged<bool>? onFullscreenChanged;

  final LatLng? source;
  final LatLng? destination;

  /// Actual road route coordinates.
  final List<LatLng>? routeCoordinates;

  final bool showLiveLocationMarker;

  final MapSelectionMode? selectionMode;

  final ValueChanged<LatLng>? onSourceSelectedFromMap;
  final ValueChanged<LatLng>? onDestinationSelectedFromMap;

  const MapView({
    super.key,
    this.isFullscreen = false,
    this.onFullscreenChanged,
    this.source,
    this.destination,
    this.routeCoordinates,
    this.showLiveLocationMarker = false,
    this.selectionMode,
    this.onSourceSelectedFromMap,
    this.onDestinationSelectedFromMap,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with AutomaticKeepAliveClientMixin {
  // ============================================================
  // MAP
  // ============================================================

  GoogleMapController? _mapController;

  bool _mapCreated = false;

  bool _hasMovedToInitialPosition = false;

  MapType _mapType = MapType.normal;

  // ============================================================
  // CENTRALIZED LOCATION SERVICE
  // ============================================================

  final LocationService _locationService =
      LocationService.instance;

  /// Listen to the ONE centralized live GPS stream.
  StreamSubscription<LatLng>?
      _livePositionSubscription;

  /// Current live/fallback position used by the map.
  ///
  /// It is initialized from LocationService instead of
  /// MockData.userLocation whenever a persisted/current
  /// location is available.
  late LatLng _currentPosition;

  /// Whether we currently have a real location.
  bool _hasRealLocation = false;

  /// Prevents repeated recenter requests while obtaining GPS.
  bool _isLocating = false;

  // ============================================================
  // MARKERS
  // ============================================================

  BitmapDescriptor? _sourceIcon;

  BitmapDescriptor? _destinationIcon;

  // ============================================================
  // KEEP ALIVE
  // ============================================================

  @override
  bool get wantKeepAlive => true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // Determine the initial map position.
    //
    // LocationService has already loaded the persisted location
    // or may already have a live GPS position.
    //
    // If neither exists, use the existing MockData fallback.
    // ----------------------------------------------------------

    final servicePosition =
        _locationService.currentPosition;

    if (servicePosition != null) {
      _currentPosition =
          servicePosition;

      _hasRealLocation =
          _locationService.hasRealLocation;
    } else {
      _currentPosition = LatLng(
        MockData.userLocation.latitude,
        MockData.userLocation.longitude,
      );

      _hasRealLocation = false;
    }

    // ----------------------------------------------------------
    // Listen to centralized live location.
    // ----------------------------------------------------------

    _listenToLiveLocation();

    // ----------------------------------------------------------
    // Load custom route markers.
    // ----------------------------------------------------------

    _initCustomMarkers();
  }

  // ============================================================
  // LIVE LOCATION LISTENER
  // ============================================================

  void _listenToLiveLocation() {
    _livePositionSubscription =
        _locationService.livePositionStream.listen(
      (LatLng position) {
        if (!mounted) return;

        debugPrint(
          'MapView: CENTRALIZED LIVE LOCATION: '
          '${position.latitude}, '
          '${position.longitude}',
        );

        _updateLivePosition(
          position,
          moveCamera:
              !_hasMovedToInitialPosition,
        );
      },
      onError: (error) {
        debugPrint(
          'MapView centralized location stream error: $error',
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    // ----------------------------------------------------------
    // IMPORTANT:
    //
    // Do NOT dispose LocationService here.
    //
    // HomeScreen and MapView both use the same singleton.
    // ----------------------------------------------------------

    _livePositionSubscription
        ?.cancel();

    _mapController = null;

    super.dispose();
  }

  // ============================================================
  // UPDATE LIVE POSITION
  // ============================================================

  void _updateLivePosition(
    LatLng position, {
    bool moveCamera = false,
  }) {
    if (!mounted) return;

    setState(() {
      _currentPosition =
          position;

      _hasRealLocation = true;
    });

    if (moveCamera &&
        _mapCreated) {
      _hasMovedToInitialPosition =
          true;

      _moveCameraTo(
        position,
        zoom: 15,
      );
    }
  }

  // ============================================================
  // CUSTOM MARKERS
  // ============================================================

  Future<void> _initCustomMarkers() async {
    try {
      final pickup =
          await _createPickupMarker();

      final destination =
          await _createDestinationMarker();

      if (!mounted) return;

      setState(() {
        _sourceIcon =
            pickup;

        _destinationIcon =
            destination;
      });
    } catch (error) {
      debugPrint(
        'Custom marker creation error: $error',
      );
    }
  }

  Future<BitmapDescriptor>
      _createPickupMarker() async {
    final recorder =
        ui.PictureRecorder();

    final canvas =
        Canvas(recorder);

    const size = 30.0;

    final paint =
        Paint()
          ..isAntiAlias = true;

    paint.color =
        const Color(0xFF00C853)
            .withValues(
          alpha: 0.25,
        );

    canvas.drawCircle(
      const Offset(
        size / 2,
        size / 2,
      ),
      14,
      paint,
    );

    paint.color =
        const Color(0xFF00A86B);

    canvas.drawCircle(
      const Offset(
        size / 2,
        size / 2,
      ),
      10,
      paint,
    );

    paint.color =
        Colors.white;

    canvas.drawCircle(
      const Offset(
        size / 2,
        size / 2,
      ),
      4.5,
      paint,
    );

    paint.color =
        const Color(0xFF00A86B);

    canvas.drawCircle(
      const Offset(
        size / 2,
        size / 2,
      ),
      2.2,
      paint,
    );

    final picture =
        recorder.endRecording();

    final image =
        await picture.toImage(
      size.toInt(),
      size.toInt(),
    );

    final byteData =
        await image.toByteData(
      format:
          ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
    );
  }

  Future<BitmapDescriptor>
      _createDestinationMarker() async {
    final recorder =
        ui.PictureRecorder();

    final canvas =
        Canvas(recorder);

    const width = 28.0;
    const height = 36.0;

    final paint =
        Paint()
          ..isAntiAlias = true;

    final path =
        Path();

    path.moveTo(
      width / 2,
      height - 2,
    );

    path.quadraticBezierTo(
      4,
      22,
      4,
      13,
    );

    path.arcToPoint(
      const Offset(
        width - 4,
        13,
      ),
      radius:
          const Radius.circular(
        10,
      ),
      clockwise: true,
    );

    path.quadraticBezierTo(
      width - 4,
      22,
      width / 2,
      height - 2,
    );

    path.close();

    paint.color =
        const Color(0xFFE53935);

    canvas.drawPath(
      path,
      paint,
    );

    paint.color =
        const Color(0xFFB71C1C);

    paint.style =
        PaintingStyle.stroke;

    paint.strokeWidth =
        1.8;

    canvas.drawPath(
      path,
      paint,
    );

    paint.style =
        PaintingStyle.fill;

    paint.color =
        Colors.white;

    canvas.drawCircle(
      const Offset(
        width / 2,
        13,
      ),
      5,
      paint,
    );

    paint.color =
        const Color(0xFFE53935);

    canvas.drawCircle(
      const Offset(
        width / 2,
        13,
      ),
      2.5,
      paint,
    );

    final picture =
        recorder.endRecording();

    final image =
        await picture.toImage(
      width.toInt(),
      height.toInt(),
    );

    final byteData =
        await image.toByteData(
      format:
          ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
    );
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _moveCameraTo(
    LatLng position, {
    double zoom = 15,
  }) async {
    final controller =
        _mapController;

    if (!_mapCreated ||
        controller == null) {
      return;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                position,
            zoom:
                zoom,
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'Camera movement error: $error',
      );
    }
  }

  // ============================================================
  // FIT ROUTE
  // ============================================================

  Future<void> _fitRouteInView() async {
    final controller =
        _mapController;

    if (!_mapCreated ||
        controller == null) {
      return;
    }

    final source =
        widget.source;

    final destination =
        widget.destination;

    if (source == null ||
        destination == null) {
      return;
    }

    final points =
        <LatLng>[
      source,
      ...?widget.routeCoordinates,
      destination,
    ];

    double minLat =
        points.first.latitude;

    double maxLat =
        points.first.latitude;

    double minLng =
        points.first.longitude;

    double maxLng =
        points.first.longitude;

    for (final point in points) {
      if (point.latitude <
          minLat) {
        minLat =
            point.latitude;
      }

      if (point.latitude >
          maxLat) {
        maxLat =
            point.latitude;
      }

      if (point.longitude <
          minLng) {
        minLng =
            point.longitude;
      }

      if (point.longitude >
          maxLng) {
        maxLng =
            point.longitude;
      }
    }

    if ((maxLat - minLat).abs() <
        0.0001) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }

    if ((maxLng - minLng).abs() <
        0.0001) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest:
                LatLng(
              minLat,
              minLng,
            ),
            northeast:
                LatLng(
              maxLat,
              maxLng,
            ),
          ),
          70,
        ),
      );
    } catch (error) {
      debugPrint(
        'Route fitting error: $error',
      );
    }
  }

  // ============================================================
  // MAP TAP
  // ============================================================

  void _handleMapTap(
    LatLng position,
  ) {
    final mode =
        widget.selectionMode;

    if (mode == null) {
      return;
    }

    if (mode ==
        MapSelectionMode.source) {
      widget
          .onSourceSelectedFromMap
          ?.call(position);

      return;
    }

    if (mode ==
        MapSelectionMode.destination) {
      widget
          .onDestinationSelectedFromMap
          ?.call(position);
    }
  }

  // ============================================================
  // POLYLINES
  // ============================================================

  Set<Polyline> get _polylines {
    final polylines =
        <Polyline>{};

    final hasActiveRoute =
        widget.source != null &&
            widget.destination != null;

    if (!hasActiveRoute) {
      final corridor =
          MockData.activeCorridor
              .map(
                (point) => LatLng(
                  point.latitude,
                  point.longitude,
                ),
              )
              .toList();

      polylines.add(
        Polyline(
          polylineId:
              const PolylineId(
            'corridor_glow',
          ),
          points:
              corridor,
          width: 10,
          color:
              AppColors
                  .primaryTeal
                  .withAlpha(70),
        ),
      );

      polylines.add(
        Polyline(
          polylineId:
              const PolylineId(
            'corridor_core',
          ),
          points:
              corridor,
          width: 5,
          color:
              AppColors
                  .midnightBlue,
        ),
      );
    }

    if (hasActiveRoute &&
        widget.routeCoordinates !=
            null &&
        widget.routeCoordinates!
                .length >
            1) {
      final points =
          widget.routeCoordinates!;

      polylines.add(
        Polyline(
          polylineId:
              const PolylineId(
            'searched_route_shadow',
          ),
          points:
              points,
          width: 9,
          color:
              AppColors
                  .midnightBlue
                  .withValues(
                alpha: 0.22,
              ),
          startCap:
              Cap.roundCap,
          endCap:
              Cap.roundCap,
          jointType:
              JointType.round,
        ),
      );

      polylines.add(
        Polyline(
          polylineId:
              const PolylineId(
            'searched_route_core',
          ),
          points:
              points,
          width: 5,
          color:
              const Color(
            0xFF00897B,
          ),
          startCap:
              Cap.roundCap,
          endCap:
              Cap.roundCap,
          jointType:
              JointType.round,
        ),
      );
    }

    return polylines;
  }

  // ============================================================
  // MARKERS
  // ============================================================

  Set<Marker> get _markers {
    final markers =
        <Marker>{};

    final hasActiveRoute =
        widget.source != null &&
            widget.destination != null;

    // ==========================================================
    // USER LOCATION
    // ==========================================================

    if (_hasRealLocation &&
        (!hasActiveRoute ||
            widget
                .showLiveLocationMarker)) {
      markers.add(
        Marker(
          markerId:
              const MarkerId(
            'user_location',
          ),
          position:
              _currentPosition,
          icon:
              BitmapDescriptor
                  .defaultMarkerWithHue(
            BitmapDescriptor
                .hueAzure,
          ),
          infoWindow:
              const InfoWindow(
            title:
                'Your Current Location',
          ),
        ),
      );
    }

    // ==========================================================
    // SAFE MEETING NODES
    // ==========================================================

    if (!hasActiveRoute) {
      for (final node
          in MockData.safeMeetingNodes) {
        markers.add(
          Marker(
            markerId:
                MarkerId(
              'node_${node.name}',
            ),
            position:
                LatLng(
              node.location.latitude,
              node.location.longitude,
            ),
            icon:
                BitmapDescriptor
                    .defaultMarkerWithHue(
              BitmapDescriptor
                  .hueCyan,
            ),
            infoWindow:
                InfoWindow(
              title:
                  node.name,
              snippet:
                  'Verified Meeting Point',
            ),
          ),
        );
      }
    }

    // ==========================================================
    // SOURCE
    // ==========================================================

    if (widget.source !=
        null) {
      markers.add(
        Marker(
          markerId:
              const MarkerId(
            'route_source',
          ),
          position:
              widget.source!,
          anchor:
              const Offset(
            0.5,
            0.5,
          ),
          icon:
              _sourceIcon ??
                  BitmapDescriptor
                      .defaultMarkerWithHue(
                BitmapDescriptor
                    .hueGreen,
              ),
          infoWindow:
              const InfoWindow(
            title:
                'Pickup Location',
          ),
        ),
      );
    }

    // ==========================================================
    // DESTINATION
    // ==========================================================

    if (widget.destination !=
        null) {
      markers.add(
        Marker(
          markerId:
              const MarkerId(
            'route_destination',
          ),
          position:
              widget.destination!,
          anchor:
              const Offset(
            0.5,
            1.0,
          ),
          icon:
              _destinationIcon ??
                  BitmapDescriptor
                      .defaultMarkerWithHue(
                BitmapDescriptor
                    .hueRed,
              ),
          infoWindow:
              const InfoWindow(
            title:
                'Destination',
          ),
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // LOCATION REQUEST
  // ============================================================

  Future<void> _refreshLocation() async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      // --------------------------------------------------------
      // LocationService owns the GPS logic.
      //
      // It:
      // - checks GPS
      // - checks permissions
      // - gets fresh GPS
      // - starts the continuous stream
      // - broadcasts live position
      // - handles 50m persistence
      // --------------------------------------------------------

      await _locationService
          .refreshAfterResume();

      if (!mounted) return;

      // --------------------------------------------------------
      // Use the latest position supplied by LocationService.
      // --------------------------------------------------------

      final position =
          _locationService.currentPosition;

      if (position != null) {
        _updateLivePosition(
          position,
          moveCamera: true,
        );
      } else {
        _showLocationServiceMessage();
      }
    } catch (error) {
      debugPrint(
        'MapView location refresh error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  // ============================================================
  // LOCATION MESSAGES
  // ============================================================

  Future<void>
      _showLocationServiceMessage() async {
    if (!mounted) return;

    final enabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!mounted) return;

    if (!enabled) {
      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              const Text(
            'Please enable GPS / Location Services.',
          ),
          action:
              SnackBarAction(
            label:
                'Settings',
            onPressed:
                Geolocator
                    .openLocationSettings,
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text(
          'Unable to get your current location.',
        ),
      ),
    );
  }

  // ============================================================
  // MAP CONTROLS
  // ============================================================

  void _recenter() {
    _moveCameraTo(
      _currentPosition,
      zoom: 15,
    );
  }

  void _toggleMapType() {
    setState(() {
      _mapType =
          _mapType ==
                  MapType.normal
              ? MapType.satellite
              : MapType.normal;
    });
  }

  void _toggleFullscreen() {
    widget
        .onFullscreenChanged
        ?.call(
          !widget.isFullscreen,
        );
  }

  // ============================================================
  // CONTROL BUTTON
  // ============================================================

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Widget? child,
  }) {
    return Material(
      elevation: 3,
      shadowColor:
          Colors.black.withValues(
        alpha: 0.18,
      ),
      color:
          AppColors.white,
      shape:
          const CircleBorder(),
      child:
          Tooltip(
        message:
            tooltip ?? '',
        child:
            InkWell(
          customBorder:
              const CircleBorder(),
          onTap:
              onTap,
          child:
              SizedBox(
            width: 38,
            height: 38,
            child:
                Center(
              child:
                  child ??
                      Icon(
                    icon,
                    color:
                        AppColors
                            .midnightBlue,
                    size: 20,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SELECTION BANNER
  // ============================================================

  Widget _buildSelectionBanner() {
    final mode =
        widget.selectionMode;

    if (mode == null) {
      return const SizedBox.shrink();
    }

    final isSource =
        mode ==
            MapSelectionMode.source;

    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child:
          SafeArea(
        child:
            Material(
          elevation: 6,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          color:
              AppColors.white,
          child:
              Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child:
                Row(
              children: [
                Icon(
                  isSource
                      ? Icons
                          .trip_origin_rounded
                      : Icons
                          .location_on_rounded,
                  color:
                      isSource
                          ? AppColors
                              .primaryTealDark
                          : AppColors
                              .midnightBlue,
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                      Text(
                    isSource
                        ? 'Tap anywhere on the map to select your pickup location'
                        : 'Tap anywhere on the map to select your destination',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    super.build(context);

    return ClipRRect(
      borderRadius:
          BorderRadius.zero,
      child:
          Stack(
        children: [
          // =====================================================
          // GOOGLE MAP
          // =====================================================

          Positioned.fill(
            child:
                GoogleMap(
              key:
                  const ValueKey(
                'liftoff_main_google_map',
              ),

              onMapCreated:
                  (controller) {
                _mapController =
                    controller;

                _mapCreated =
                    true;

                WidgetsBinding
                    .instance
                    .addPostFrameCallback(
                  (_) async {
                    if (!mounted ||
                        !_mapCreated) {
                      return;
                    }

                    // ------------------------------------------------
                    // LocationService is the source of truth.
                    // ------------------------------------------------

                    final servicePosition =
                        _locationService
                            .currentPosition;

                    if (servicePosition !=
                        null) {
                      _currentPosition =
                          servicePosition;

                      _hasRealLocation =
                          _locationService
                              .hasRealLocation;

                      _hasMovedToInitialPosition =
                          true;

                      await _moveCameraTo(
                        servicePosition,
                        zoom: 13.8,
                      );
                    } else if (!_hasMovedToInitialPosition) {
                      _hasMovedToInitialPosition =
                          true;

                      // ------------------------------------------------
                      // First launch / no persisted location.
                      //
                      // Preserve the existing fallback behavior.
                      // ------------------------------------------------

                      await _moveCameraTo(
                        _currentPosition,
                        zoom: 13.8,
                      );
                    }

                    if (widget.source !=
                            null &&
                        widget.destination !=
                            null) {
                      _fitRouteInView();
                    }
                  },
                );
              },

              initialCameraPosition:
                  CameraPosition(
                target:
                    _currentPosition,
                zoom:
                    13.8,
              ),

              mapType:
                  _mapType,

              myLocationEnabled:
                  true,

              myLocationButtonEnabled:
                  false,

              zoomControlsEnabled:
                  false,

              mapToolbarEnabled:
                  false,

              zoomGesturesEnabled:
                  true,

              scrollGesturesEnabled:
                  true,

              rotateGesturesEnabled:
                  true,

              tiltGesturesEnabled:
                  true,

              compassEnabled:
                  true,

              onTap:
                  _handleMapTap,

              polylines:
                  _polylines,

              markers:
                  _markers,

              gestureRecognizers:
                  <Factory<
                      OneSequenceGestureRecognizer>>{
                Factory<
                    OneSequenceGestureRecognizer>(
                  () =>
                      EagerGestureRecognizer(),
                ),
              },
            ),
          ),

          // =====================================================
          // SELECTION BANNER
          // =====================================================

          _buildSelectionBanner(),

          // =====================================================
          // MAP CONTROLS
          // =====================================================

          Positioned(
            left: 16,
            bottom: 20,
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _mapControlButton(
                  icon:
                      widget.isFullscreen
                          ? Icons
                              .fullscreen_exit_rounded
                          : Icons
                              .fullscreen_rounded,
                  tooltip:
                      widget.isFullscreen
                          ? 'Exit fullscreen'
                          : 'View fullscreen map',
                  onTap:
                      _toggleFullscreen,
                ),

                const SizedBox(
                  height: 10,
                ),

                _mapControlButton(
                  icon:
                      _mapType ==
                              MapType.normal
                          ? Icons
                              .satellite_alt_rounded
                          : Icons
                              .map_rounded,
                  tooltip:
                      _mapType ==
                              MapType.normal
                          ? 'Satellite view'
                          : 'Normal map view',
                  onTap:
                      _toggleMapType,
                ),

                const SizedBox(
                  height: 10,
                ),

                _mapControlButton(
                  icon:
                      Icons
                          .my_location_rounded,
                  tooltip:
                      'Recenter on my location',
                  onTap:
                      _refreshLocation,
                  child:
                      _isLocating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .my_location_rounded,
                              color:
                                  AppColors
                                      .primaryTealDark,
                              size: 23,
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}