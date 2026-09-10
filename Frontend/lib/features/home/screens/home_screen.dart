import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../../../core/services/location_service.dart';

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
/// Location architecture:
/// - LocationService owns the ONE GPS stream.
/// - HomeScreen listens to livePositionStream.
/// - LocationService handles GPS ON/OFF.
/// - LocationService handles 50m persistence.
/// - LocationService handles live address resolution.
/// - LastLocationService is used internally by LocationService.
/// - HomeScreen does NOT create another GPS stream.
/// - HomeScreen does NOT reverse-geocode normal live GPS updates.
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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
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
  // LIVE LOCATION MARKER
  // ============================================================

  bool _showLiveLocationMarker = false;

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
  ///
  /// This value comes from LocationService.
  String? _liveLocationAddress;

  /// Short Area + City address shown in FloatingTopBar.
  ///
  /// This value comes from LocationService.
  String? _shortLiveLocationAddress;

  /// Latest live GPS position.
  ///
  /// This is supplied by LocationService.
  LatLng? _currentLivePosition;

  // ============================================================
  // CENTRALIZED LOCATION SERVICE
  // ============================================================

  final LocationService _locationService =
      LocationService.instance;

  /// Subscription to the centralized live GPS stream.
  StreamSubscription<LatLng>?
      _livePositionSubscription;

  /// Subscription to centralized GPS service status.
  StreamSubscription<ServiceStatus>?
      _serviceStatusSubscription;

  /// Subscription to centralized location/address state.
  ///
  /// LocationService emits this whenever its important
  /// location state changes, especially after a new address
  /// has been resolved and persisted.
  StreamSubscription<void>?
      _locationStateSubscription;

  /// Prevents repeated lifecycle saves during one
  /// background transition.
  bool _lifecycleSaveTriggered = false;

  // ============================================================
  // MAP LOCATION SELECTION
  // ============================================================

  MapSelectionMode? _mapSelectionMode;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // ----------------------------------------------------------
    // Start centralized location service.
    // ----------------------------------------------------------

    _initializeLocation();

    // ----------------------------------------------------------
    // Listen to live location.
    // ----------------------------------------------------------

    _listenToLiveLocation();

    // ----------------------------------------------------------
    // Listen to GPS ON/OFF.
    // ----------------------------------------------------------

    _listenToServiceStatus();

    // ----------------------------------------------------------
    // Listen to address/location state changes.
    // ----------------------------------------------------------

    _listenToLocationState();
  }

  // ============================================================
  // INITIALIZE LOCATION
  // ============================================================

  Future<void> _initializeLocation() async {
    try {
      debugPrint(
        'HomeScreen: Initializing LocationService...',
      );

      await _locationService.initialize();

      if (!mounted) return;

      // --------------------------------------------------------
      // LocationService restores:
      // - saved coordinates
      // - saved address
      // - saved short address
      //
      // HomeScreen only reads those values.
      // No extra Google API call is performed.
      // --------------------------------------------------------

      _syncLocationDisplayFromService();

      // --------------------------------------------------------
      // LocationService may already have the latest position.
      // --------------------------------------------------------

      final currentPosition =
          _locationService.currentPosition;

      if (currentPosition != null) {
        _updateLivePosition(
          currentPosition,
        );
      }
    } catch (e) {
      debugPrint(
        'HomeScreen location initialization error: $e',
      );
    }
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
          'HomeScreen LIVE LOCATION: '
          '${position.latitude}, '
          '${position.longitude}',
        );

        // ------------------------------------------------------
        // Update map/live position immediately.
        //
        // LocationService controls persistence separately.
        // ------------------------------------------------------

        _updateLivePosition(
          position,
        );
      },
      onError: (error) {
        debugPrint(
          'HomeScreen live location stream error: $error',
        );
      },
    );
  }

  // ============================================================
  // GPS SERVICE STATUS LISTENER
  // ============================================================

  void _listenToServiceStatus() {
    _serviceStatusSubscription =
        _locationService.serviceStatusStream.listen(
      (ServiceStatus status) {
        if (!mounted) return;

        debugPrint(
          'HomeScreen GPS SERVICE STATUS: $status',
        );

        // ------------------------------------------------------
        // GPS ENABLED
        // ------------------------------------------------------

        if (status == ServiceStatus.enabled) {
          debugPrint(
            'HomeScreen: GPS enabled. '
            'LocationService is obtaining live location.',
          );

          ScaffoldMessenger.of(context)
              .hideCurrentSnackBar();

          // ----------------------------------------------------
          // LocationService itself restarts GPS.
          //
          // We only synchronize whatever state is currently
          // available to the UI.
          // ----------------------------------------------------

          _syncLocationDisplayFromService();

          return;
        }

        // ------------------------------------------------------
        // GPS DISABLED
        // ------------------------------------------------------

        if (status == ServiceStatus.disabled) {
          debugPrint(
            'HomeScreen: GPS disabled. '
            'Keeping last known location.',
          );

          // ----------------------------------------------------
          // IMPORTANT:
          //
          // Do NOT clear:
          // - _currentLivePosition
          // - _liveLocationAddress
          // - _shortLiveLocationAddress
          //
          // LocationService intentionally keeps the last
          // known/saved location visible.
          // ----------------------------------------------------
        }
      },
      onError: (error) {
        debugPrint(
          'HomeScreen GPS service status error: $error',
        );
      },
    );
  }

  // ============================================================
  // LOCATION STATE LISTENER
  // ============================================================

  void _listenToLocationState() {
    _locationStateSubscription =
        _locationService.locationStateStream.listen(
      (_) {
        if (!mounted) return;

        debugPrint(
          'HomeScreen: Location state changed. '
          'Synchronizing display.',
        );

        _syncLocationDisplayFromService();
      },
      onError: (error) {
        debugPrint(
          'HomeScreen location state stream error: $error',
        );
      },
    );
  }

  // ============================================================
  // SYNC LOCATION DISPLAY
  // ============================================================

  /// Reads the latest location/address state from the
  /// centralized LocationService.
  ///
  /// IMPORTANT:
  ///
  /// This method NEVER calls Google APIs.
  ///
  /// LocationService owns:
  /// - GPS updates
  /// - 50m persistence
  /// - reverse geocoding
  /// - saved location
  /// - address cache
  void _syncLocationDisplayFromService() {
    if (!mounted) return;

    final serviceAddress =
        _locationService.currentAddress;

    final serviceShortAddress =
        _locationService.currentShortAddress;

    final servicePosition =
        _locationService.currentPosition;

    bool changed = false;

    // ----------------------------------------------------------
    // Synchronize full address.
    // ----------------------------------------------------------

    if (serviceAddress != null &&
        serviceAddress.trim().isNotEmpty &&
        serviceAddress.trim() !=
            _liveLocationAddress) {
      _liveLocationAddress =
          serviceAddress.trim();

      changed = true;
    }

    // ----------------------------------------------------------
    // Synchronize short address.
    // ----------------------------------------------------------

    if (serviceShortAddress != null &&
        serviceShortAddress.trim().isNotEmpty &&
        serviceShortAddress.trim() !=
            _shortLiveLocationAddress) {
      _shortLiveLocationAddress =
          serviceShortAddress.trim();

      changed = true;
    }

    // ----------------------------------------------------------
    // Synchronize current position.
    // ----------------------------------------------------------

    if (servicePosition != null &&
        servicePosition !=
            _currentLivePosition) {
      _currentLivePosition =
          servicePosition;

      changed = true;
    }

    if (changed) {
      setState(() {});
    }
  }

  // ============================================================
  // UPDATE LIVE POSITION
  // ============================================================

  void _updateLivePosition(
    LatLng position,
  ) {
    if (!mounted) return;

    setState(() {
      _currentLivePosition =
          position;
    });
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    debugPrint(
      'HomeScreen APP LIFECYCLE: $state',
    );

    // ----------------------------------------------------------
    // APP RETURNED TO FOREGROUND
    // ----------------------------------------------------------

    if (state == AppLifecycleState.resumed) {
      _lifecycleSaveTriggered = false;

      debugPrint(
        'HomeScreen: App resumed. '
        'Refreshing LocationService...',
      );

      unawaited(
        _locationService.refreshAfterResume(),
      );

      return;
    }

    // ----------------------------------------------------------
    // APP IS NOW HIDDEN / PAUSED
    // ----------------------------------------------------------
    //
    // Do NOT use inactive here.
    //
    // Android may enter inactive during temporary UI events
    // such as keyboard/dialog transitions.
    // ----------------------------------------------------------

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      if (_lifecycleSaveTriggered) {
        debugPrint(
          'HomeScreen: Lifecycle save already triggered.',
        );

        return;
      }

      _lifecycleSaveTriggered = true;

      unawaited(
        _saveCurrentLocationOnLifecycle(),
      );
    }
  }

  // ============================================================
  // LIFECYCLE LOCATION SAVE
  // ============================================================

  Future<void> _saveCurrentLocationOnLifecycle() async {
    try {
      await _locationService
          .saveCurrentLocationOnLifecycle();

      debugPrint(
        'HomeScreen: Lifecycle location save requested.',
      );
    } catch (e) {
      debugPrint(
        'HomeScreen lifecycle location save error: $e',
      );
    }
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
    if (_isHostMode == isHost) {
      return;
    }

    FocusManager.instance
        .primaryFocus
        ?.unfocus();

    setState(() {
      _isHostMode = isHost;

      if (isHost) {
        _isMapFullscreen = false;
      }

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
      _selectedServiceId =
          serviceId;
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
      _routeSource =
          source;

      _routeDestination =
          destination;

      _sourceAddress =
          sourceName;

      _destinationAddress =
          destinationName;

      _routeCoordinates = [];

      _routeDistance =
          null;

      _routeDuration =
          null;

      _isSearchingRoute =
          true;

      _showLiveLocationMarker =
          false;
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

        _isSearchingRoute =
            false;
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

        _routeDistance =
            null;

        _routeDuration =
            null;

        _isSearchingRoute =
            false;
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
    FocusManager.instance
        .primaryFocus
        ?.unfocus();

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
    FocusManager.instance
        .primaryFocus
        ?.unfocus();

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
      _routeSource =
          position;

      _routeCoordinates = [];

      _routeDistance =
          null;

      _routeDuration =
          null;

      _mapSelectionMode =
          null;

      _showLiveLocationMarker =
          false;
    });

    String address;

    try {
      // --------------------------------------------------------
      // Intentional reverse geocoding.
      //
      // This is an explicit user-selected map point.
      // It is NOT a normal live GPS update.
      // --------------------------------------------------------

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
      _sourceAddress =
          address;
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
      _routeDestination =
          position;

      _routeCoordinates = [];

      _routeDistance =
          null;

      _routeDuration =
          null;

      _mapSelectionMode =
          null;

      _showLiveLocationMarker =
          false;
    });

    String address;

    try {
      // --------------------------------------------------------
      // Intentional reverse geocoding.
      //
      // This is an explicit user-selected map point.
      // --------------------------------------------------------

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
      _destinationAddress =
          address;
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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    // ----------------------------------------------------------
    // IMPORTANT:
    //
    // Cancel ONLY HomeScreen's subscriptions.
    //
    // DO NOT dispose LocationService here.
    //
    // LocationService is a singleton shared with MapView.
    // ----------------------------------------------------------

    _livePositionSubscription
        ?.cancel();

    _serviceStatusSubscription
        ?.cancel();

    _locationStateSubscription
        ?.cancel();

    super.dispose();
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

    final mapHeight =
        (screenHeight * 0.60).clamp(
      300.0,
      520.0,
    );

    const sheetOverlap = 60.0;

    final normalBookingTop =
        mapHeight -
            sheetOverlap;

    // ==========================================================
    // BOOKING PANEL HEIGHT
    // ==========================================================

    final bookingPanelHeight =
        screenHeight -
            normalBookingTop;

    // ==========================================================
    // BOOKING PANEL BOTTOM
    // ==========================================================

    final bookingPanelBottom =
        isKeyboardOpen
            ? keyboardHeight
            : 0.0;

    return Scaffold(
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

          if (!_isHostMode &&
              !_isMapFullscreen)
            Positioned(
              left: 0,
              right: 0,

              // ------------------------------------------------
              // ANDROID KEYBOARD FIX
              //
              // The COMPLETE booking panel moves above the
              // keyboard using actual Stack layout positioning.
              //
              // No Transform.translate is used.
              // ------------------------------------------------

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