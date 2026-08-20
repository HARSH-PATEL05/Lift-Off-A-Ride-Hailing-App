import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';

/// Interactive Live Map View rendering real-time GPS location, shared commute corridors,
/// and safe smart meeting nodes.
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  LatLng _currentPosition = MockData.userLocation;
  bool _isLocating = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLiveLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Request permissions and start live GPS tracking
  Future<void> _initLiveLocation() async {
    if (!mounted) return;
    setState(() => _isLocating = true);

    try {
      // 1. Check if GPS / Location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable GPS / Location Services on your device.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() => _isLocating = false);
        }
        return;
      }

      // 2. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions denied by user.');
          if (mounted) {
            setState(() => _isLocating = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is permanently denied. Please enable in App Settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _isLocating = false);
        }
        return;
      }

      // 3. Fast initial fix using last known position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
        _mapController.move(_currentPosition, 15.0);
      }

      // 4. Fetch fresh current GPS fix with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLocating = false;
        });
        _mapController.move(_currentPosition, 15.0);
      }

      // 5. Start continuous live GPS stream
      _positionStreamSubscription?.cancel();
      const streamSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: streamSettings,
      ).listen(
        (Position pos) {
          if (mounted) {
            setState(() {
              _currentPosition = LatLng(pos.latitude, pos.longitude);
            });
          }
        },
        onError: (err) {
          debugPrint('Location stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Live location error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _recenter() {
    _mapController.move(_currentPosition, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: 13.8,
            maxZoom: 18,
            minZoom: 5,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // High-resolution OpenStreetMap Tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.liftoff_auth_test',
              maxZoom: 19,
            ),

            // Shared Commute Corridor Polylines
            PolylineLayer(
              polylines: [
                // Outer glow buffer
                Polyline(
                  points: MockData.activeCorridor,
                  strokeWidth: 10.0,
                  color: AppColors.primaryTeal.withAlpha(70),
                ),
                // Core corridor route
                Polyline(
                  points: MockData.activeCorridor,
                  strokeWidth: 4.5,
                  color: AppColors.midnightBlue,
                  borderStrokeWidth: 1.5,
                  borderColor: AppColors.primaryTeal,
                ),
              ],
            ),

            // Markers Layer
            MarkerLayer(
              markers: [
                // Live User Location Marker
                Marker(
                  point: _currentPosition,
                  width: 36,
                  height: 36,
                  child: const _LiveUserMarker(),
                ),

                // Safe Smart Meeting Nodes
                ...MockData.safeMeetingNodes.map(
                  (node) => Marker(
                    point: node.location,
                    width: 140,
                    height: 50,
                    child: _MeetingNodeMarker(node: node),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Floating "Recenter on My Location" Action Button
        Positioned(
          bottom: 24,
          right: 16,
          child: Material(
            elevation: 6,
            shape: const CircleBorder(),
            color: AppColors.midnightBlue,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                await _initLiveLocation();
                _recenter();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryTeal, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.tealGlow,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryTeal,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primaryTeal,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveUserMarker extends StatelessWidget {
  const _LiveUserMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.midnightBlue,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryTeal, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.tealGlow,
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.my_location_rounded,
          color: AppColors.primaryTeal,
          size: 18,
        ),
      ),
    );
  }
}

class _MeetingNodeMarker extends StatelessWidget {
  final SafeMeetingNode node;

  const _MeetingNodeMarker({required this.node});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryTeal, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.verifiedGreen,
                size: 12,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  node.name,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.midnightBlue,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          color: AppColors.primaryTealDark,
          size: 20,
        ),
      ],
    );
  }
}
