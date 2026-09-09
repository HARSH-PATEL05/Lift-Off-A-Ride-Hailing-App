import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../widgets/floating_top_bar.dart';
import '../widgets/map_view.dart';
import '../widgets/booking_bottom_sheet.dart';

import '../../ride/widgets/live_ride_drawer.dart';
import '../../host/screens/rider_host_dashboard.dart';
import '../../profile/screens/profile_screen.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/services/google_places_service.dart';

/// LiftOff Main Home Screen.
///
/// Traveller mode:
/// - Google Map
/// - Floating top bar
/// - Booking/search area
///
/// Host mode:
/// - RiderHostDashboard
///
/// Platform behavior:
/// - Web/Windows keep the existing layout.
/// - Android manually moves the COMPLETE booking panel
///   above the keyboard when text input is active.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // MODE
  // ============================================================

  /// false = Traveller
  /// true  = Host
  bool _isHostMode = false;

  bool _isMapFullscreen = false;

  // ============================================================
  // SERVICE
  // ============================================================

  String _selectedServiceId =
      MockData.communityRides.first.id;

  bool _showRideStatus = false;

  // ============================================================
  // ROUTE STATE
  // ============================================================

  String? _sourceAddress;
  String? _destinationAddress;

  LatLng? _routeSource;
  LatLng? _routeDestination;

  List<LatLng> _routeCoordinates = [];

  String? _routeDistance;
  String? _routeDuration;

  bool _isSearchingRoute = false;

  /// Prevents an older route response from overwriting
  /// a newer route request.
  int _routeRequestId = 0;

  // ============================================================
  // LIVE LOCATION STATE
  // ============================================================

  /// Complete address internally.
  String? _liveLocationAddress;

  /// Short Area + City address shown in FloatingTopBar.
  String? _shortLiveLocationAddress;

  bool _showLiveLocationMarker = false;

  // ============================================================
  // MAP SELECTION MODE
  // ============================================================

  MapSelectionMode? _mapSelectionMode;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initLiveLocationAddress();
  }

  // ============================================================
  // LIVE LOCATION
  // ============================================================

  Future<void> _initLiveLocationAddress() async {
    try {
      if (mounted) {
        setState(() {
          _liveLocationAddress =
              'Getting your location...';

          _shortLiveLocationAddress =
              'Getting your location...';
        });
      }

      // ========================================================
      // CHECK LOCATION SERVICE
      // ========================================================

      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _liveLocationAddress =
              'Location services are turned off';

          _shortLiveLocationAddress =
              'Location services are turned off';
        });

        return;
      }

      // ========================================================
      // CHECK LOCATION PERMISSION
      // ========================================================

      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _liveLocationAddress =
              'Location permission permanently denied';

          _shortLiveLocationAddress =
              'Location permission permanently denied';
        });

        return;
      }

      if (permission ==
          LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _liveLocationAddress =
              'Location permission denied';

          _shortLiveLocationAddress =
              'Location permission denied';
        });

        return;
      }

      // ========================================================
      // GET CURRENT GPS LOCATION
      // ========================================================

      Position position;

      try {
        position =
            await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(
            accuracy:
                LocationAccuracy.high,
          ),
        );
      } catch (e) {
        debugPrint(
          'Current location error: $e',
        );

        final lastPosition =
            await Geolocator.getLastKnownPosition();

        if (lastPosition == null) {
          if (!mounted) return;

          setState(() {
            _liveLocationAddress =
                'Unable to get current location';

            _shortLiveLocationAddress =
                'Unable to get current location';
          });

          return;
        }

        position = lastPosition;
      }

      debugPrint(
        'LIVE LOCATION: '
        '${position.latitude}, '
        '${position.longitude}',
      );

      // ========================================================
      // GET COMPLETE GOOGLE ADDRESS
      // ========================================================

      String fullAddress = '';

      try {
        fullAddress =
            await GooglePlacesService.instance
                .getAddressFromCoordinates(
          LatLng(
            position.latitude,
            position.longitude,
          ),
        );
      } catch (e) {
        debugPrint(
          'Reverse geocoding error: $e',
        );
      }

      if (!mounted) return;

      // ========================================================
      // UPDATE LOCATION
      // ========================================================

      if (fullAddress.trim().isNotEmpty) {
        final cleanedAddress =
            fullAddress.trim();

        setState(() {
          _liveLocationAddress =
              cleanedAddress;

          _shortLiveLocationAddress =
              _getAreaAndCity(
            cleanedAddress,
          );
        });
      } else {
        final coordinateText =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';

        setState(() {
          _liveLocationAddress =
              coordinateText;

          _shortLiveLocationAddress =
              'Current Location';
        });
      }
    } catch (e) {
      debugPrint(
        'Error getting live location: $e',
      );

      if (!mounted) return;

      setState(() {
        _liveLocationAddress =
            'Unable to fetch location';

        _shortLiveLocationAddress =
            'Unable to fetch location';
      });
    }
  }

  // ============================================================
  // AREA + CITY FORMATTER
  // ============================================================

  String _getAreaAndCity(
    String fullAddress,
  ) {
    final address =
        fullAddress.trim();

    const systemMessages = [
      'Getting your location...',
      'Location services are turned off',
      'Location permission permanently denied',
      'Location permission denied',
      'Unable to get current location',
      'Unable to fetch location',
    ];

    if (systemMessages.contains(address)) {
      return address;
    }

    if (address
        .toLowerCase()
        .startsWith('location near')) {
      return 'Current Location';
    }

    final parts =
        address
            .split(',')
            .map(
              (part) => part.trim(),
            )
            .where(
              (part) => part.isNotEmpty,
            )
            .toList();

    if (parts.isEmpty) {
      return 'Current Location';
    }

    // ----------------------------------------------------------
    // Remove country.
    // ----------------------------------------------------------

    final filteredParts =
        parts.where((part) {
      final lower =
          part.toLowerCase();

      return lower != 'india';
    }).toList();

    if (filteredParts.isEmpty) {
      return 'Current Location';
    }

    // ----------------------------------------------------------
    // Remove state / PIN from end.
    // ----------------------------------------------------------

    final locationParts =
        List<String>.from(
      filteredParts,
    );

    final indianStates = [
      'andhra pradesh',
      'arunachal pradesh',
      'assam',
      'bihar',
      'chhattisgarh',
      'goa',
      'gujarat',
      'haryana',
      'himachal pradesh',
      'jharkhand',
      'karnataka',
      'kerala',
      'madhya pradesh',
      'maharashtra',
      'manipur',
      'meghalaya',
      'mizoram',
      'nagaland',
      'odisha',
      'punjab',
      'rajasthan',
      'sikkim',
      'tamil nadu',
      'telangana',
      'tripura',
      'uttar pradesh',
      'uttarakhand',
      'west bengal',
      'delhi',
    ];

    while (locationParts.isNotEmpty) {
      final last =
          locationParts.last;

      final lower =
          last.toLowerCase();

      final hasPinCode =
          RegExp(
        r'\b\d{6}\b',
      ).hasMatch(last);

      final isState =
          indianStates.any(
        (state) =>
            lower.contains(state),
      );

      if (hasPinCode || isState) {
        locationParts.removeLast();
      } else {
        break;
      }
    }

    if (locationParts.length >= 2) {
      return '${locationParts[locationParts.length - 2]}, '
          '${locationParts.last}';
    }

    return locationParts.first;
  }

  // ============================================================
  // LIVE LOCATION TAP
  // ============================================================

  void _onLiveLocationTap() {
    setState(() {
      _showLiveLocationMarker = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          _liveLocationAddress != null
              ? 'Showing live location: '
                  '$_liveLocationAddress'
              : 'Showing your current live location',
        ),
        duration:
            const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // PROFILE
  // ============================================================

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            const ProfileScreen(),
      ),
    );
  }

  // ============================================================
  // MODE
  // ============================================================

  void _onModeChanged(
    bool isHost,
  ) {
    // Already in requested mode.
    if (_isHostMode == isHost) {
      return;
    }

    // Close keyboard before changing mode.
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isHostMode = isHost;

      // Host mode does not use map fullscreen.
      if (isHost) {
        _isMapFullscreen = false;
      }

      // Clear map-selection mode when changing mode.
      _mapSelectionMode = null;
    });
  }

  // ============================================================
  // MAP FULLSCREEN
  // ============================================================

  void _onMapFullscreenChanged(
    bool value,
  ) {
    setState(() {
      _isMapFullscreen = value;
    });
  }

  // ============================================================
  // SERVICE
  // ============================================================

  void _onServiceSelected(
    String serviceId,
  ) {
    setState(() {
      _selectedServiceId = serviceId;
    });
  }

  // ============================================================
  // BOOKING
  // ============================================================

  void _onBook() {
    setState(() {
      _showRideStatus = true;
    });
  }

  void _onCloseRideStatus() {
    setState(() {
      _showRideStatus = false;
    });
  }

  // ============================================================
  // ROUTE SEARCH
  // ============================================================

  Future<void> _onRouteSearch(
    LatLng source,
    LatLng destination,
    String sourceName,
    String destinationName,
  ) async {
    final requestId =
        ++_routeRequestId;

    setState(() {
      _routeSource = source;

      _routeDestination = destination;

      _sourceAddress = sourceName;

      _destinationAddress = destinationName;

      _routeCoordinates = [];

      _routeDistance = null;

      _routeDuration = null;

      _isSearchingRoute = true;

      _showLiveLocationMarker = false;
    });

    try {
      final routeResult =
          await GooglePlacesService.instance
              .getDirections(
        source,
        destination,
      );

      if (!mounted ||
          requestId !=
              _routeRequestId) {
        return;
      }

      setState(() {
        _routeCoordinates =
            routeResult.points;

        _routeDistance =
            routeResult.distanceText;

        _routeDuration =
            routeResult.durationText;

        _isSearchingRoute = false;
      });
    } catch (e) {
      debugPrint(
        'Error getting route directions: $e',
      );

      if (!mounted ||
          requestId !=
              _routeRequestId) {
        return;
      }

      setState(() {
        _routeCoordinates = [];

        _routeDistance = null;

        _routeDuration = null;

        _isSearchingRoute = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to find a road route for these locations.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // MAP LOCATION SELECTION
  // ============================================================

  void _onSelectSourceFromMap() {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _mapSelectionMode =
          MapSelectionMode.source;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Tap anywhere on the map to set your pickup location',
        ),
        duration:
            Duration(seconds: 3),
      ),
    );
  }

  void _onSelectDestinationFromMap() {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _mapSelectionMode =
          MapSelectionMode.destination;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Tap anywhere on the map to set your destination',
        ),
        duration:
            Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // SOURCE SELECTED FROM MAP
  // ============================================================

  Future<void> _onSourceSelectedFromMap(
    LatLng position,
  ) async {
    final selectionRequestId =
        ++_routeRequestId;

    setState(() {
      _routeSource = position;

      _routeCoordinates = [];

      _routeDistance = null;

      _routeDuration = null;

      _mapSelectionMode = null;

      _showLiveLocationMarker = false;
    });

    String address;

    try {
      address =
          await GooglePlacesService.instance
              .getAddressFromCoordinates(
        position,
      );
    } catch (e) {
      debugPrint(
        'Error reverse geocoding source: $e',
      );

      address =
          'Selected Pickup Location';
    }

    if (!mounted ||
        selectionRequestId !=
            _routeRequestId) {
      return;
    }

    setState(() {
      _sourceAddress = address;
    });

    if (_routeSource != null &&
        _routeDestination != null) {
      await _onRouteSearch(
        _routeSource!,
        _routeDestination!,
        _sourceAddress ??
            'Selected Pickup Location',
        _destinationAddress ??
            'Selected Destination',
      );
    }
  }

  // ============================================================
  // DESTINATION SELECTED FROM MAP
  // ============================================================

  Future<void> _onDestinationSelectedFromMap(
    LatLng position,
  ) async {
    final selectionRequestId =
        ++_routeRequestId;

    setState(() {
      _routeDestination = position;

      _routeCoordinates = [];

      _routeDistance = null;

      _routeDuration = null;

      _mapSelectionMode = null;

      _showLiveLocationMarker = false;
    });

    String address;

    try {
      address =
          await GooglePlacesService.instance
              .getAddressFromCoordinates(
        position,
      );
    } catch (e) {
      debugPrint(
        'Error reverse geocoding destination: $e',
      );

      address =
          'Selected Destination';
    }

    if (!mounted ||
        selectionRequestId !=
            _routeRequestId) {
      return;
    }

    setState(() {
      _destinationAddress = address;
    });

    if (_routeSource != null &&
        _routeDestination != null) {
      await _onRouteSearch(
        _routeSource!,
        _routeDestination!,
        _sourceAddress ??
            'Selected Pickup Location',
        _destinationAddress ??
            'Selected Destination',
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final mediaQuery =
        MediaQuery.of(context);

    final screenHeight =
        mediaQuery.size.height;

    final topPadding =
        mediaQuery.padding.top;

    final isAndroid =
        defaultTargetPlatform ==
            TargetPlatform.android;

    // ==========================================================
    // KEYBOARD
    // ==========================================================

    final keyboardHeight =
        isAndroid
            ? mediaQuery.viewInsets.bottom
            : 0.0;

    final isKeyboardOpen =
        isAndroid &&
        keyboardHeight > 0;

    // ==========================================================
    // MAP HEIGHT
    // ==========================================================
    //
    // IMPORTANT:
    //
    // The map keeps its normal height.
    //
    // The keyboard does NOT resize the map.
    // ==========================================================

    final mapHeight =
        (screenHeight * 0.60).clamp(
      300.0,
      520.0,
    );

    const sheetOverlap = 60.0;

    final normalBookingTop =
        mapHeight - sheetOverlap;

    // ==========================================================
    // BOOKING PANEL HEIGHT
    // ==========================================================
    //
    // This is the key fix.
    //
    // Previously:
    //
    // Positioned(
    //   top: normalBookingTop,
    //   bottom: 0,
    // )
    //
    // followed by Transform.translate().
    //
    // That moved the visual panel but its original layout
    // rectangle remained in place, producing the white gap.
    //
    // Now the panel is ACTUALLY repositioned.
    // ==========================================================

    final bookingPanelHeight =
        screenHeight -
            normalBookingTop;

    // ==========================================================
    // BOOKING PANEL BOTTOM
    // ==========================================================
    //
    // Normal:
    // bottom = 0
    //
    // Keyboard:
    // bottom = keyboardHeight
    //
    // Therefore the COMPLETE panel sits directly above
    // the keyboard.
    // ==========================================================

    final bookingPanelBottom =
        isKeyboardOpen
            ? keyboardHeight
            : 0.0;

    return Scaffold(
      // ========================================================
      // KEYBOARD RESIZE
      // ========================================================
      //
      // Android:
      // We manually position the booking panel.
      //
      // Web / Windows:
      // Keep the original Flutter behavior.
      // ========================================================

      resizeToAvoidBottomInset:
          !isAndroid,

      body: Stack(
        clipBehavior:
            Clip.none,
        children: [
          // ======================================================
          // HOST MODE
          // ======================================================

          if (_isHostMode)
            const Positioned.fill(
              child:
                  RiderHostDashboard(),
            ),

          // ======================================================
          // TRAVELLER MAP
          // ======================================================

          if (!_isHostMode)
            AnimatedPositioned(
              duration:
                  const Duration(
                milliseconds: 250,
              ),
              curve:
                  Curves.easeInOut,

              top: 0,
              left: 0,
              right: 0,

              bottom:
                  _isMapFullscreen
                      ? 0
                      : screenHeight -
                          mapHeight,

              child:
                  MapView(
                isFullscreen:
                    _isMapFullscreen,

                onFullscreenChanged:
                    _onMapFullscreenChanged,

                source:
                    _routeSource,

                destination:
                    _routeDestination,

                routeCoordinates:
                    _routeCoordinates,

                showLiveLocationMarker:
                    _showLiveLocationMarker,

                selectionMode:
                    _mapSelectionMode,

                onSourceSelectedFromMap:
                    _onSourceSelectedFromMap,

                onDestinationSelectedFromMap:
                    _onDestinationSelectedFromMap,
              ),
            ),

          // ======================================================
          // TRAVELLER BOOKING PANEL
          // ======================================================
          //
          // IMPORTANT:
          //
          // We do NOT use Transform.translate anymore.
          //
          // The entire panel is physically repositioned using:
          //
          //   bottom: keyboardHeight
          //   height: bookingPanelHeight
          //
          // This removes the white empty layout area.
          // ======================================================

          if (!_isHostMode &&
              !_isMapFullscreen)
            Positioned(
              left: 0,
              right: 0,

              bottom:
                  bookingPanelBottom,

              height:
                  bookingPanelHeight,

              child:
                  _showRideStatus
                      ? LiveRideDrawer(
                          onClose:
                              _onCloseRideStatus,
                        )
                      : BookingBottomSheet(
                          selectedServiceId:
                              _selectedServiceId,

                          onServiceSelected:
                              _onServiceSelected,

                          onBook:
                              _onBook,

                          initialSource:
                              _sourceAddress,

                          initialDestination:
                              _destinationAddress,

                          isSearchingRoute:
                              _isSearchingRoute,

                          routeDistance:
                              _routeDistance,

                          routeDuration:
                              _routeDuration,

                          onSelectSourceFromMap:
                              _onSelectSourceFromMap,

                          onSelectDestinationFromMap:
                              _onSelectDestinationFromMap,

                          onRouteSearch:
                              _onRouteSearch,
                        ),
            ),

          // ======================================================
          // FLOATING TOP BAR
          // ======================================================
          //
          // FloatingTopBar already contains SafeArea.
          //
          // Android:
          // top = 0
          //
          // Web / Windows:
          // preserve existing top positioning.
          // ======================================================

          if (!_isMapFullscreen)
            Positioned(
              top:
                  isAndroid
                      ? 0
                      : topPadding + 4,

              left: 0,
              right: 0,

              child:
                  FloatingTopBar(
                isRiderMode:
                    _isHostMode,

                onModeChanged:
                    _onModeChanged,

                liveLocationAddress:
                    _shortLiveLocationAddress,

                onLiveLocationTap:
                    _onLiveLocationTap,

                onProfileTap:
                    _openProfile,
              ),
            ),

          // ======================================================
          // FULLSCREEN BACK BUTTON
          // ======================================================

          if (!_isHostMode &&
              _isMapFullscreen)
            Positioned(
              top:
                  topPadding + 8,

              left: 12,

              child:
                  Material(
                elevation: 5,

                color:
                    Colors.white,

                shape:
                    const CircleBorder(),

                child:
                    IconButton(
                  tooltip:
                      'Exit fullscreen',

                  icon:
                      const Icon(
                    Icons
                        .arrow_back_rounded,
                  ),

                  onPressed:
                      () {
                    _onMapFullscreenChanged(
                      false,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}