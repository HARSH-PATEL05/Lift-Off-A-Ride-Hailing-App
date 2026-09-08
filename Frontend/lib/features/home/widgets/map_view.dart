import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/theme/app_colors.dart';

/// Identifies which location is currently being selected from the map.
enum MapSelectionMode {
  source,
  destination,
}

/// Interactive Live Map View.
///
/// Features:
/// - Live GPS tracking
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
  GoogleMapController? _mapController;

  LatLng _currentPosition = LatLng(
    MockData.userLocation.latitude,
    MockData.userLocation.longitude,
  );

  bool _isLocating = false;

  MapType _mapType = MapType.normal;

  StreamSubscription<Position>? _positionStreamSubscription;

  bool _mapCreated = false;

  bool _hasMovedToInitialPosition = false;

  BitmapDescriptor? _sourceIcon;
  BitmapDescriptor? _destinationIcon;

  @override
  bool get wantKeepAlive => true;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initLiveLocation();
    _initCustomMarkers();
  }

  @override
  void didUpdateWidget(
    covariant MapView oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final sourceChanged =
        oldWidget.source != widget.source;

    final destinationChanged =
        oldWidget.destination != widget.destination;

    final routeChanged =
        oldWidget.routeCoordinates !=
            widget.routeCoordinates;

    final liveLocationTapped =
        !oldWidget.showLiveLocationMarker &&
            widget.showLiveLocationMarker;

    if (liveLocationTapped) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (!mounted) return;

          _moveCameraTo(
            _currentPosition,
            zoom: 15.5,
          );
        },
      );
    }

    /// Fit route when:
    /// - both locations exist
    /// - route coordinates are available
    ///
    /// This prevents fitting only the straight line before
    /// the actual OSRM / Google road route arrives.
    if ((sourceChanged ||
            destinationChanged ||
            routeChanged) &&
        widget.source != null &&
        widget.destination != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (!mounted) return;

          _fitRouteInView();
        },
      );
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();

    /// Do not manually dispose GoogleMapController.
    ///
    /// Flutter Web manages the underlying Google Maps instance.
    _mapController = null;

    super.dispose();
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
        _sourceIcon = pickup;
        _destinationIcon = destination;
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
        Paint()..isAntiAlias = true;

    // Outer halo
    paint.color =
        const Color(0xFF00C853)
            .withValues(alpha: 0.25);

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      14,
      paint,
    );

    // Main green circle
    paint.color =
        const Color(0xFF00A86B);

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      10,
      paint,
    );

    // White center
    paint.color =
        Colors.white;

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      4.5,
      paint,
    );

    // Inner green dot
    paint.color =
        const Color(0xFF00A86B);

    canvas.drawCircle(
      const Offset(size / 2, size / 2),
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
        Paint()..isAntiAlias = true;

    final path = Path();

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
          const Radius.circular(10),
      clockwise: true,
    );

    path.quadraticBezierTo(
      width - 4,
      22,
      width / 2,
      height - 2,
    );

    path.close();

    // Red pin
    paint.color =
        const Color(0xFFE53935);

    canvas.drawPath(
      path,
      paint,
    );

    // Border
    paint.color =
        const Color(0xFFB71C1C);

    paint.style =
        PaintingStyle.stroke;

    paint.strokeWidth = 1.8;

    canvas.drawPath(
      path,
      paint,
    );

    // White center
    paint.style =
        PaintingStyle.fill;

    paint.color =
        Colors.white;

    canvas.drawCircle(
      const Offset(width / 2, 13),
      5,
      paint,
    );

    // Red center
    paint.color =
        const Color(0xFFE53935);

    canvas.drawCircle(
      const Offset(width / 2, 13),
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
  // LIVE LOCATION
  // ============================================================

  Future<void> _initLiveLocation() async {
    if (!mounted) return;

    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationServiceMessage();
        return;
      }

      var permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        _showPermissionSettingsMessage();
        return;
      }

      if (!kIsWeb) {
        final lastKnown =
            await Geolocator
                .getLastKnownPosition();

        if (lastKnown != null &&
            mounted) {
          _updateCurrentPosition(
            LatLng(
              lastKnown.latitude,
              lastKnown.longitude,
            ),
            moveCamera:
                !_hasMovedToInitialPosition,
          );
        }
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            LocationSettings(
          accuracy:
              LocationAccuracy.high,
          timeLimit: kIsWeb
              ? null
              : const Duration(
                  seconds: 10,
                ),
        ),
      );

      if (!mounted) return;

      _updateCurrentPosition(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        moveCamera: true,
      );

      await _positionStreamSubscription
          ?.cancel();

      _positionStreamSubscription =
          Geolocator
              .getPositionStream(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (position) {
          if (!mounted) return;

          setState(() {
            _currentPosition =
                LatLng(
              position.latitude,
              position.longitude,
            );
          });
        },
        onError: (error) {
          debugPrint(
            'Location stream error: $error',
          );
        },
      );
    } catch (error) {
      debugPrint(
        'Live location error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  void _updateCurrentPosition(
    LatLng position, {
    bool moveCamera = false,
  }) {
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
    });

    if (moveCamera &&
        _mapCreated) {
      _moveCameraTo(
        position,
        zoom: 15,
      );
    }
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
        CameraUpdate
            .newCameraPosition(
          CameraPosition(
            target: position,
            zoom: zoom,
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
      if (point.latitude < minLat) {
        minLat =
            point.latitude;
      }

      if (point.latitude > maxLat) {
        maxLat =
            point.latitude;
      }

      if (point.longitude < minLng) {
        minLng =
            point.longitude;
      }

      if (point.longitude > maxLng) {
        maxLng =
            point.longitude;
      }
    }

    // Prevent invalid bounds when points are very close.
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
        CameraUpdate
            .newLatLngBounds(
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
          points: corridor,
          width: 10,
          color: AppColors
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
          points: corridor,
          width: 5,
          color:
              AppColors.midnightBlue,
        ),
      );
    }

    if (hasActiveRoute &&
        widget.routeCoordinates != null &&
        widget.routeCoordinates!.length >
            1) {
      final points =
          widget.routeCoordinates!;

      polylines.add(
        Polyline(
          polylineId:
              const PolylineId(
            'searched_route_shadow',
          ),
          points: points,
          width: 9,
          color: AppColors
              .midnightBlue
              .withValues(alpha: 0.22),
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
          points: points,
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

    if (!hasActiveRoute ||
        widget.showLiveLocationMarker) {
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
                'Your Location',
          ),
        ),
      );
    }

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

    if (widget.source != null) {
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

    if (widget.destination != null) {
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
  // LOCATION MESSAGES
  // ============================================================

  void _showLocationServiceMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: const Text(
          'Please enable GPS / Location Services.',
        ),
        action:
            SnackBarAction(
          label: 'Settings',
          onPressed:
              Geolocator
                  .openLocationSettings,
        ),
      ),
    );
  }

  void _showPermissionSettingsMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: const Text(
          'Location permission is permanently denied.',
        ),
        action:
            SnackBarAction(
          label: 'Settings',
          onPressed:
              Geolocator
                  .openAppSettings,
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
      child: Tooltip(
        message:
            tooltip ?? '',
        child: InkWell(
          customBorder:
              const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
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
                  (_) {
                    if (!mounted ||
                        !_mapCreated) {
                      return;
                    }

                    if (!_hasMovedToInitialPosition) {
                      _hasMovedToInitialPosition =
                          true;

                      _moveCameraTo(
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
                zoom: 13.8,
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

              // =================================================
              // GESTURES
              // =================================================

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

              // =================================================
              // MAP TAP
              // =================================================

              onTap:
                  _handleMapTap,

              polylines:
                  _polylines,

              markers:
                  _markers,

              // =================================================
              // FLUTTER WEB
              //
              // Allows mouse drag and mouse wheel interaction.
              // =================================================

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
                      () async {
                    await _initLiveLocation();
                    _recenter();
                  },
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
                              color: AppColors
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