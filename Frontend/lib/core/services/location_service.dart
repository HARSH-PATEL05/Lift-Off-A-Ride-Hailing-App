import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_places_service.dart';
import 'last_location_service.dart';

/// Centralized location service for LiftOff.
///
/// Responsibilities:
/// - Maintains ONE continuous GPS stream.
/// - Provides responsive live location updates.
/// - Keeps live GPS updates separate from persistent storage.
/// - Persists location only after approximately 50 meters of movement.
/// - Persists coordinates together with the latest resolved address.
/// - Restores the last persisted location when GPS is unavailable.
/// - Reacts when Location Services are turned ON/OFF.
/// - Performs best-effort persistence during app lifecycle changes.
///
/// Architecture:
///
///     Phone GPS
///         │
///         ▼
///   LocationService
///         │
///         ├── livePositionStream
///         │       ├── HomeScreen
///         │       └── MapView
///         │
///         ├── locationStateStream
///         │       └── HomeScreen
///         │
///         ├── Address Resolution
///         │       └── GooglePlacesService
///         │
///         └── LastLocationService
///                 │
///                 └── SharedPreferences
///
class LocationService {
  LocationService._();

  static final LocationService instance =
      LocationService._();

  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Distance at which the operating system should provide
  /// another live GPS update.
  ///
  /// This is intentionally LOW because live location should
  /// remain responsive.
  static const int liveLocationDistanceFilter = 5;

  /// Distance required before writing a new location to
  /// persistent storage.
  ///
  /// IMPORTANT:
  ///
  /// This is completely separate from
  /// liveLocationDistanceFilter.
  ///
  /// GPS can update every ~5 meters while persistent storage
  /// is updated only after ~50 meters of movement.
  static const double persistentSaveDistanceMeters = 50.0;

  // ============================================================
  // STATE
  // ============================================================

  /// Latest live GPS position.
  ///
  /// This changes frequently and is NOT written to storage
  /// on every update.
  LatLng? _currentPosition;

  /// Last location actually persisted by LiftOff.
  LatLng? _lastSavedPosition;

  /// Latest address associated with the current location.
  ///
  /// This is kept in memory so UI layers do not need to
  /// repeatedly reverse-geocode the same location.
  String? _currentAddress;

  /// Latest short address associated with the current location.
  ///
  /// Example:
  ///
  /// "Vastrapur, Ahmedabad"
  String? _currentShortAddress;

  /// Whether a genuine GPS position has been obtained.
  bool _hasRealLocation = false;

  /// Prevents multiple initialization requests.
  bool _isInitializing = false;

  /// Prevents multiple startLiveLocation() operations from
  /// running simultaneously.
  bool _isStartingLocation = false;

  /// Prevents multiple persistent writes at the same time.
  bool _isSaving = false;

  /// Prevents multiple address-resolution requests from
  /// running simultaneously.
  bool _isResolvingAddress = false;

  /// Latest position received while a persistent write is
  /// already running.
  ///
  /// This prevents newer GPS positions from being lost.
  LatLng? _pendingSavePosition;

  /// Whether the pending position must be saved regardless
  /// of the normal 50m threshold.
  ///
  /// Used when the app enters a lifecycle boundary.
  bool _pendingForceSave = false;

  // ============================================================
  // STREAM SUBSCRIPTIONS
  // ============================================================

  /// ONE continuous GPS subscription owned by this service.
  StreamSubscription<Position>?
      _positionSubscription;

  /// Location Service ON/OFF subscription.
  StreamSubscription<ServiceStatus>?
      _serviceStatusSubscription;

  // ============================================================
  // STREAM CONTROLLERS
  // ============================================================

  /// Broadcast controller so multiple screens can listen
  /// to the same GPS stream.
  final StreamController<LatLng>
      _livePositionController =
      StreamController<LatLng>.broadcast();

  /// Broadcast controller for GPS service status.
  final StreamController<ServiceStatus>
      _serviceStatusController =
      StreamController<ServiceStatus>.broadcast();

  /// Broadcast controller for changes to location-related
  /// state such as a newly resolved address.
  ///
  /// The event itself does not carry data.
  ///
  /// Consumers should read:
  /// - currentPosition
  /// - currentAddress
  /// - currentShortAddress
  ///
  /// from this service after receiving the event.
  final StreamController<void>
      _locationStateController =
      StreamController<void>.broadcast();

  // ============================================================
  // PUBLIC STREAMS
  // ============================================================

  /// Stream of LIVE GPS positions.
  ///
  /// Multiple widgets can listen to this stream without creating
  /// additional GPS streams.
  Stream<LatLng> get livePositionStream =>
      _livePositionController.stream;

  /// Stream of Location Service status changes.
  Stream<ServiceStatus> get serviceStatusStream =>
      _serviceStatusController.stream;

  /// Stream emitted whenever important location state changes.
  ///
  /// Examples:
  /// - address resolved
  /// - persisted location updated
  /// - location restored
  Stream<void> get locationStateStream =>
      _locationStateController.stream;

  // ============================================================
  // PUBLIC GETTERS
  // ============================================================

  /// Current live position kept in memory.
  ///
  /// If GPS is unavailable, this remains the last known
  /// real position.
  LatLng? get currentPosition =>
      _currentPosition;

  /// Last position persisted by LiftOff.
  LatLng? get lastSavedPosition =>
      _lastSavedPosition;

  /// Latest full address known by the service.
  String? get currentAddress =>
      _currentAddress;

  /// Latest short address known by the service.
  String? get currentShortAddress =>
      _currentShortAddress;

  /// Whether a genuine GPS position has been obtained.
  bool get hasRealLocation =>
      _hasRealLocation;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initializes the centralized location service.
  ///
  /// It:
  /// 1. Loads the previously persisted location.
  /// 2. Restores its address.
  /// 3. Starts watching GPS service ON/OFF state.
  /// 4. Attempts to obtain the current live location.
  Future<void> initialize() async {
    if (_isInitializing) {
      debugPrint(
        'LocationService: Initialization already running.',
      );

      return;
    }

    _isInitializing = true;

    try {
      // --------------------------------------------------------
      // FIRST LOAD PERSISTED LOCATION
      // --------------------------------------------------------

      await _loadLastSavedLocation();

      // --------------------------------------------------------
      // START GPS SERVICE STATUS LISTENER
      // --------------------------------------------------------

      _startServiceStatusListener();

      // --------------------------------------------------------
      // TRY TO START LIVE GPS
      // --------------------------------------------------------

      await startLiveLocation();
    } catch (e) {
      debugPrint(
        'LocationService initialization error: $e',
      );
    } finally {
      _isInitializing = false;
    }
  }

  // ============================================================
  // LOAD LAST PERSISTED LOCATION
  // ============================================================

  Future<void> _loadLastSavedLocation() async {
    try {
      debugPrint(
        'LocationService: Loading persisted location...',
      );

      final savedLocation =
          await LastLocationService.instance
              .getLastLocation();

      if (savedLocation == null) {
        debugPrint(
          'LocationService: No persisted location found.',
        );

        return;
      }

      // --------------------------------------------------------
      // RESTORE COORDINATES
      // --------------------------------------------------------

      _lastSavedPosition =
          savedLocation.position;

      _currentPosition =
          savedLocation.position;

      _hasRealLocation = true;

      // --------------------------------------------------------
      // RESTORE ADDRESS
      // --------------------------------------------------------

      _currentAddress =
          savedLocation.address;

      _currentShortAddress =
          savedLocation.shortAddress;

      debugPrint(
        'LocationService: Restored saved location: '
        '${savedLocation.position.latitude}, '
        '${savedLocation.position.longitude}',
      );

      debugPrint(
        'LocationService: Restored saved address: '
        '${_currentAddress ?? 'none'}',
      );

      debugPrint(
        'LocationService: Restored saved short address: '
        '${_currentShortAddress ?? 'none'}',
      );

      // --------------------------------------------------------
      // Notify UI that persisted location/address is available.
      // --------------------------------------------------------

      _notifyLocationStateChanged();
    } catch (e) {
      debugPrint(
        'LocationService: Failed to load saved location: $e',
      );
    }
  }

  // ============================================================
  // LOCATION SERVICE STATUS LISTENER
  // ============================================================

  void _startServiceStatusListener() {
    // ----------------------------------------------------------
    // WEB
    // ----------------------------------------------------------

    if (kIsWeb) {
      debugPrint(
        'LocationService: Service status stream skipped on Web.',
      );

      return;
    }

    // ----------------------------------------------------------
    // Prevent duplicate listeners.
    // ----------------------------------------------------------

    _serviceStatusSubscription?.cancel();

    _serviceStatusSubscription =
        Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        debugPrint(
          'LocationService: GPS service status = $status',
        );

        // ------------------------------------------------------
        // BROADCAST STATUS
        // ------------------------------------------------------

        if (!_serviceStatusController.isClosed) {
          _serviceStatusController.add(
            status,
          );
        }

        // ------------------------------------------------------
        // GPS ENABLED
        // ------------------------------------------------------

        if (status == ServiceStatus.enabled) {
          debugPrint(
            'LocationService: GPS enabled. '
            'Starting fresh live location.',
          );

          unawaited(
            startLiveLocation(),
          );

          return;
        }

        // ------------------------------------------------------
        // GPS DISABLED
        // ------------------------------------------------------

        if (status == ServiceStatus.disabled) {
          debugPrint(
            'LocationService: GPS disabled. '
            'Stopping live GPS stream.',
          );

          _stopPositionStream();

          // ----------------------------------------------------
          // IMPORTANT:
          //
          // Do NOT clear:
          //
          // _currentPosition
          // _lastSavedPosition
          // _currentAddress
          // _currentShortAddress
          //
          // The application continues using the last known
          // location while GPS is OFF.
          // ----------------------------------------------------
        }
      },
      onError: (error) {
        debugPrint(
          'LocationService: Service status error: $error',
        );
      },
    );
  }

  // ============================================================
  // START LIVE LOCATION
  // ============================================================

  Future<void> startLiveLocation() async {
    // ----------------------------------------------------------
    // PREVENT CONCURRENT START OPERATIONS
    // ----------------------------------------------------------

    if (_isStartingLocation) {
      debugPrint(
        'LocationService: Live location startup already running.',
      );

      return;
    }

    _isStartingLocation = true;

    try {
      // --------------------------------------------------------
      // CHECK GPS SERVICE
      // --------------------------------------------------------

      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          'LocationService: GPS is OFF. '
          'Using persisted location if available.',
        );

        _stopPositionStream();

        return;
      }

      // --------------------------------------------------------
      // CHECK PERMISSION
      // --------------------------------------------------------

      var permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.deniedForever) {
        debugPrint(
          'LocationService: Location permission permanently denied.',
        );

        _stopPositionStream();

        return;
      }

      if (permission ==
          LocationPermission.denied) {
        debugPrint(
          'LocationService: Location permission denied.',
        );

        _stopPositionStream();

        return;
      }

      // --------------------------------------------------------
      // GET FRESH CURRENT POSITION
      // --------------------------------------------------------

      Position? position;

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
          'LocationService: Current GPS error: $e',
        );

        // ------------------------------------------------------
        // FALL BACK TO PLATFORM LAST KNOWN LOCATION
        // ------------------------------------------------------

        try {
          position =
              await Geolocator.getLastKnownPosition();
        } catch (lastKnownError) {
          debugPrint(
            'LocationService: Last-known GPS error: '
            '$lastKnownError',
          );
        }
      }

      // --------------------------------------------------------
      // UPDATE CURRENT POSITION
      // --------------------------------------------------------

      if (position != null) {
        final livePosition =
            LatLng(
          position.latitude,
          position.longitude,
        );

        await _handleLivePosition(
          livePosition,
        );
      } else {
        debugPrint(
          'LocationService: No platform GPS position available. '
          'Keeping persisted location.',
        );
      }

      // --------------------------------------------------------
      // START CONTINUOUS GPS STREAM
      // --------------------------------------------------------

      await _startPositionStream();
    } catch (e) {
      debugPrint(
        'LocationService: Failed to start live location: $e',
      );
    } finally {
      _isStartingLocation = false;
    }
  }

  // ============================================================
  // START CONTINUOUS GPS STREAM
  // ============================================================

  Future<void> _startPositionStream() async {
    // ----------------------------------------------------------
    // Cancel previous stream.
    // ----------------------------------------------------------

    await _positionSubscription?.cancel();

    _positionSubscription = null;

    // ----------------------------------------------------------
    // Create ONE centralized GPS stream.
    // ----------------------------------------------------------

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(
        accuracy:
            LocationAccuracy.high,

        // ------------------------------------------------------
        // LIVE UPDATE FREQUENCY
        //
        // Approximately every 5 meters.
        //
        // This does NOT control persistent storage.
        // ------------------------------------------------------

        distanceFilter:
            liveLocationDistanceFilter,
      ),
    ).listen(
      (Position position) {
        final livePosition =
            LatLng(
          position.latitude,
          position.longitude,
        );

        debugPrint(
          'LocationService LIVE GPS UPDATE: '
          '${position.latitude}, '
          '${position.longitude}',
        );

        // ------------------------------------------------------
        // Do not await here.
        //
        // UI receives live location immediately.
        // Persistence/address work happens asynchronously.
        // ------------------------------------------------------

        unawaited(
          _handleLivePosition(
            livePosition,
          ),
        );
      },
      onError: (error) {
        debugPrint(
          'LocationService: GPS stream error: $error',
        );
      },
    );

    debugPrint(
      'LocationService: Continuous GPS stream started.',
    );
  }

  // ============================================================
  // HANDLE LIVE POSITION
  // ============================================================

  Future<void> _handleLivePosition(
    LatLng position,
  ) async {
    // ----------------------------------------------------------
    // ALWAYS UPDATE LIVE MEMORY
    // ----------------------------------------------------------

    _currentPosition =
        position;

    _hasRealLocation = true;

    // ----------------------------------------------------------
    // BROADCAST LIVE UPDATE IMMEDIATELY
    // ----------------------------------------------------------

    if (!_livePositionController.isClosed) {
      _livePositionController.add(
        position,
      );
    }

    // ----------------------------------------------------------
    // PERSIST ONLY WHEN NECESSARY
    // ----------------------------------------------------------

    await _saveLocationIfMovedEnough(
      position,
    );
  }

  // ============================================================
  // PERSISTENT LOCATION SAVE
  // ============================================================

  Future<void> _saveLocationIfMovedEnough(
    LatLng position,
  ) async {
    // ----------------------------------------------------------
    // IF ANOTHER SAVE IS RUNNING
    //
    // Keep the newest position instead of discarding it.
    // ----------------------------------------------------------

    if (_isSaving) {
      _pendingSavePosition =
          position;

      debugPrint(
        'LocationService: Save already running. '
        'Queued latest position for later persistence.',
      );

      return;
    }

    // ----------------------------------------------------------
    // FIRST REAL LOCATION
    // ----------------------------------------------------------

    if (_lastSavedPosition == null) {
      debugPrint(
        'LocationService: First real location received. '
        'Persisting it.',
      );

      await _persistLocation(
        position,
      );

      await _processPendingSave();

      return;
    }

    // ----------------------------------------------------------
    // CALCULATE DISTANCE FROM LAST PERSISTED LOCATION
    // ----------------------------------------------------------

    final distance =
        Geolocator.distanceBetween(
      _lastSavedPosition!.latitude,
      _lastSavedPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    debugPrint(
      'LocationService: Distance from last saved '
      'location = ${distance.toStringAsFixed(1)}m',
    );

    // ----------------------------------------------------------
    // LESS THAN 50 METERS
    // ----------------------------------------------------------

    if (distance <
        persistentSaveDistanceMeters) {
      return;
    }

    // ----------------------------------------------------------
    // 50+ METERS
    // ----------------------------------------------------------

    debugPrint(
      'LocationService: User moved at least '
      '$persistentSaveDistanceMeters meters. '
      'Updating persistent location.',
    );

    await _persistLocation(
      position,
    );

    await _processPendingSave();
  }

  // ============================================================
  // PROCESS PENDING SAVE
  // ============================================================

  Future<void> _processPendingSave() async {
    if (_isSaving) {
      return;
    }

    final pendingPosition =
        _pendingSavePosition;

    final forceSave =
        _pendingForceSave;

    _pendingSavePosition =
        null;

    _pendingForceSave =
        false;

    if (pendingPosition == null) {
      return;
    }

    // ----------------------------------------------------------
    // FORCE SAVE
    //
    // Used for lifecycle transitions.
    // ----------------------------------------------------------

    if (forceSave) {
      debugPrint(
        'LocationService: Processing pending lifecycle save.',
      );

      await _persistLocation(
        pendingPosition,
      );

      return;
    }

    // ----------------------------------------------------------
    // NORMAL 50m SAVE
    // ----------------------------------------------------------

    await _saveLocationIfMovedEnough(
      pendingPosition,
    );
  }

  // ============================================================
  // ACTUAL PERSISTENT WRITE
  // ============================================================

  Future<void> _persistLocation(
    LatLng position,
  ) async {
    if (_isSaving) {
      return;
    }

    _isSaving = true;

    try {
      // --------------------------------------------------------
      // START WITH CURRENT CACHED ADDRESS
      // --------------------------------------------------------

      String? fullAddress =
          _currentAddress;

      String? shortAddress =
          _currentShortAddress;

      // --------------------------------------------------------
      // RESOLVE ADDRESS
      // --------------------------------------------------------
      //
      // Address lookup happens ONLY when persistence is needed.
      //
      // We do NOT reverse-geocode every 5m GPS update.
      // --------------------------------------------------------

      if (!_isResolvingAddress) {
        _isResolvingAddress = true;

        try {
          final resolvedAddress =
              await GooglePlacesService
                  .instance
                  .getAddressFromCoordinates(
            position,
          );

          if (resolvedAddress
              .trim()
              .isNotEmpty) {
            fullAddress =
                resolvedAddress.trim();

            shortAddress =
                _getAreaAndCity(
              fullAddress,
            );

            _currentAddress =
                fullAddress;

            _currentShortAddress =
                shortAddress;

            debugPrint(
              'LocationService: Address resolved: '
              '$fullAddress',
            );
          }
        } catch (e) {
          debugPrint(
            'LocationService: Address resolution error: $e',
          );

          // ----------------------------------------------------
          // Keep previous address if reverse geocoding fails.
          // ----------------------------------------------------
        } finally {
          _isResolvingAddress = false;
        }
      }

      // --------------------------------------------------------
      // PERSIST COORDINATES + ADDRESS
      // --------------------------------------------------------

      await LastLocationService.instance
          .saveLocation(
        position:
            position,
        address:
            fullAddress,
        shortAddress:
            shortAddress,
      );

      // --------------------------------------------------------
      // IMPORTANT
      //
      // LastLocationService currently handles its own storage
      // errors internally.
      //
      // Therefore reaching this point means the save operation
      // completed from this service's perspective.
      // --------------------------------------------------------

      _lastSavedPosition =
          position;

      debugPrint(
        'LocationService: Location persisted: '
        '${position.latitude}, '
        '${position.longitude}',
      );

      debugPrint(
        'LocationService: Persisted address: '
        '${fullAddress ?? 'none'}',
      );

      debugPrint(
        'LocationService: Persisted short address: '
        '${shortAddress ?? 'none'}',
      );

      // --------------------------------------------------------
      // IMPORTANT:
      //
      // Notify HomeScreen that address/location state has changed.
      // This prevents the TopBar from remaining on an old address.
      // --------------------------------------------------------

      _notifyLocationStateChanged();
    } catch (e) {
      debugPrint(
        'LocationService: Persistent save error: $e',
      );
    } finally {
      _isSaving = false;
    }
  }

  // ============================================================
  // LOCATION STATE NOTIFICATION
  // ============================================================

  void _notifyLocationStateChanged() {
    if (_locationStateController.isClosed) {
      return;
    }

    _locationStateController.add(null);
  }

  // ============================================================
  // LIFECYCLE SAVE
  // ============================================================

  /// Best-effort save of the latest live position.
  ///
  /// This deliberately bypasses the normal 50m threshold because
  /// the application is crossing a lifecycle boundary.
  ///
  /// If a normal persistence operation is already running, the
  /// latest position is queued and marked as a forced save.
  Future<void> saveCurrentLocationOnLifecycle() async {
    final currentPosition =
        _currentPosition;

    if (currentPosition == null ||
        !_hasRealLocation) {
      debugPrint(
        'LocationService: No real live location available '
        'for lifecycle save.',
      );

      return;
    }

    // ----------------------------------------------------------
    // SAVE ALREADY RUNNING
    // ----------------------------------------------------------

    if (_isSaving) {
      _pendingSavePosition =
          currentPosition;

      _pendingForceSave =
          true;

      debugPrint(
        'LocationService: Persistent save already running. '
        'Queued latest position for lifecycle save.',
      );

      return;
    }

    debugPrint(
      'LocationService: Saving latest live location '
      'during lifecycle transition...',
    );

    await _persistLocation(
      currentPosition,
    );

    await _processPendingSave();

    debugPrint(
      'LocationService: Lifecycle location save completed.',
    );
  }

  // ============================================================
  // REFRESH AFTER RESUME
  // ============================================================

  /// Call this when the application returns to the foreground.
  ///
  /// If GPS is still disabled:
  /// - keep the persisted/current location
  /// - do not clear anything
  ///
  /// If GPS is enabled:
  /// - request a fresh position
  /// - restart the continuous GPS stream
  Future<void> refreshAfterResume() async {
    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          'LocationService: GPS still OFF after resume. '
          'Keeping saved location.',
        );

        return;
      }

      debugPrint(
        'LocationService: App resumed. '
        'Refreshing live location.',
      );

      await startLiveLocation();
    } catch (e) {
      debugPrint(
        'LocationService: Resume refresh error: $e',
      );
    }
  }

  // ============================================================
  // GET SAVED LOCATION
  // ============================================================

  /// Returns the last persisted LiftOff location.
  Future<LastLocationData?>
      getLastSavedLocation() async {
    try {
      return await LastLocationService
          .instance
          .getLastLocation();
    } catch (e) {
      debugPrint(
        'LocationService: Failed to get saved location: $e',
      );

      return null;
    }
  }

  // ============================================================
  // ADDRESS FORMATTER
  // ============================================================

  /// Converts a full address into a compact
  /// "Area, City" representation.
  ///
  /// Example:
  ///
  /// Full:
  /// "Vastrapur, Ahmedabad, Gujarat 380015, India"
  ///
  /// Short:
  /// "Vastrapur, Ahmedabad"
  String _getAreaAndCity(
    String fullAddress,
  ) {
    final address =
        fullAddress.trim();

    if (address.isEmpty) {
      return 'Current Location';
    }

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
              (part) =>
                  part.trim(),
            )
            .where(
              (part) =>
                  part.isNotEmpty,
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

    final locationParts =
        List<String>.from(
      filteredParts,
    );

    // ----------------------------------------------------------
    // Indian states.
    // ----------------------------------------------------------

    const indianStates = [
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

    // ----------------------------------------------------------
    // Remove PIN code and state from the end.
    // ----------------------------------------------------------

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

      if (hasPinCode ||
          isState) {
        locationParts.removeLast();
      } else {
        break;
      }
    }

    // ----------------------------------------------------------
    // Return Area + City.
    // ----------------------------------------------------------

    if (locationParts.length >= 2) {
      return '${locationParts[locationParts.length - 2]}, '
          '${locationParts.last}';
    }

    return locationParts.first;
  }

  // ============================================================
  // STOP GPS STREAM
  // ============================================================

  void _stopPositionStream() {
    _positionSubscription?.cancel();

    _positionSubscription =
        null;

    debugPrint(
      'LocationService: Continuous GPS stream stopped.',
    );
  }

  /// Public method in case the application needs to stop
  /// continuous location updates explicitly.
  Future<void> stopLiveLocation() async {
    await _positionSubscription?.cancel();

    _positionSubscription =
        null;

    debugPrint(
      'LocationService: Live location stopped.',
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  /// Permanently shuts down the service.
  ///
  /// IMPORTANT:
  ///
  /// HomeScreen and MapView should NOT call this during normal
  /// navigation because this service is shared by the app.
  Future<void> dispose() async {
    await _positionSubscription?.cancel();

    await _serviceStatusSubscription?.cancel();

    _positionSubscription =
        null;

    _serviceStatusSubscription =
        null;

    await _livePositionController
        .close();

    await _serviceStatusController
        .close();

    await _locationStateController
        .close();

    debugPrint(
      'LocationService: Service disposed.',
    );
  }
}