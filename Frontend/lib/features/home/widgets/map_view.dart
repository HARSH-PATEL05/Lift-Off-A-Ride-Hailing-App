import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = LatLng(
    MockData.userLocation.latitude,
    MockData.userLocation.longitude,
  );
  bool _isLocating = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  Set<Polyline> get _polylines => {
        // Outer glow buffer
        Polyline(
          polylineId: const PolylineId('corridor_glow'),
          points: MockData.activeCorridor
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          width: 10,
          color: AppColors.primaryTeal.withAlpha(70),
        ),
        // Core corridor route
        Polyline(
          polylineId: const PolylineId('corridor_core'),
          points: MockData.activeCorridor
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          width: 5,
          color: AppColors.midnightBlue,
        ),
      };

  Set<Marker> get _markers => {
        // Live User Location Marker
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
        // Safe Smart Meeting Nodes
        ...MockData.safeMeetingNodes.map(
          (node) => Marker(
            markerId: MarkerId('node_${node.name}'),
            position: LatLng(node.location.latitude, node.location.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            infoWindow: InfoWindow(
              title: node.name,
              snippet: '✅ Verified Meeting Point',
            ),
          ),
        ),
      };

  @override
  void initState() {
    super.initState();
    _initLiveLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
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
          if (mounted) setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Location permission is permanently denied. Please enable in App Settings.'),
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

      // 3. Fast initial fix using last known position (not supported on web)
      if (!kIsWeb) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_currentPosition),
          );
        }
      }

      // 4. Fetch fresh current GPS fix
      // Note: timeLimit is not supported on web — omit it to avoid errors
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: kIsWeb ? null : const Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLocating = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );
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
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition, zoom: 15.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            // Move to current position once map is ready
            controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _currentPosition, zoom: 13.8),
              ),
            );
          },
          initialCameraPosition: CameraPosition(
            target: _currentPosition,
            zoom: 13.8,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We use our own recenter button
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          polylines: _polylines,
          markers: _markers,
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
