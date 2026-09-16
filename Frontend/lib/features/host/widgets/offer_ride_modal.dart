import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/services/vehicle_service.dart';
import '../../../core/services/google_places_service.dart';
import '../../auth/screens/vehicle_rc_verification_screen.dart';
import 'route_selection_module.dart';
import 'route_confirmation_module.dart';
import 'ride_details_module.dart';

/// Orchestrator for the Offer Ride flow.
///
/// The actual sections are intentionally kept in separate modules:
/// 1. RouteSelectionModule
/// 2. RouteConfirmationModule
/// 3. RideDetailsModule
///
/// This widget owns only the step navigation and the final API request.
///
/// Route-selection draft behavior:
/// - The current RouteSelectionModule keeps the user's search in memory while
///   this modal recreates its step widgets.
/// - The draft is NOT cleared when moving between Route / Confirm / Details.
/// - The draft is cleared only when the user closes the modal with X or when
///   the ride is successfully published.
class OfferRideModal extends StatefulWidget {
  const OfferRideModal({super.key});

  @override
  State<OfferRideModal> createState() => _OfferRideModalState();
}

class _OfferRideModalState extends State<OfferRideModal> {
  int _currentStep = 0;

  RouteSelectionData? _routeData;

  bool _isPublishing = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.94,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // HEADER
  // ================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Color(0xFF1677FF),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offer a Ride',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Share your route with passengers',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeModalAndClearDraft,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STEP INDICATOR
  // ================================================================

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: [
          _stepCircle(
            1,
            'Route',
            _currentStep >= 0,
            _currentStep > 0,
          ),
          _stepLine(_currentStep > 0),
          _stepCircle(
            2,
            'Confirm',
            _currentStep >= 1,
            _currentStep > 1,
          ),
          _stepLine(_currentStep > 1),
          _stepCircle(
            3,
            'Details',
            _currentStep >= 2,
            false,
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(
    int number,
    String title,
    bool active,
    bool completed,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? const Color(0xFF1677FF)
                  : const Color(0xFFE8ECF1),
            ),
            alignment: Alignment.center,
            child: completed
                ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: Colors.white,
                  )
                : Text(
                    '$number',
                    style: TextStyle(
                      color: active ? Colors.white : Colors.black45,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.black87 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: active
            ? const Color(0xFF1677FF)
            : const Color(0xFFE0E4E8),
      ),
    );
  }

  // ================================================================
  // CURRENT STEP
  // ================================================================

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return RouteSelectionModule(
          onRouteCalculated: _onRouteCalculated,
        );

      case 1:
        final data = _routeData;

        if (data == null) {
          return const SizedBox.shrink();
        }

        return RouteConfirmationModule(
          data: data,
          routeOptions: data.routeOptions,
          onChangeRoute: () {
            setState(() => _currentStep = 0);
          },
          onConfirm: _confirmRoute,
        );

      case 2:
        final data = _routeData;

        if (data == null) {
          return const SizedBox.shrink();
        }

        return RideDetailsModule(
          routeData: data,
          onBack: () {
            setState(() => _currentStep = 1);
          },
          onPublish: _publishRide,
          isPublishing: _isPublishing,
          loadVehicles: _loadRideVehicles,
          onAddVehicle: _addVehicle,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ================================================================
  // LOAD VERIFIED VEHICLES
  // ================================================================

  Future<List<RideVehicleOption>> _loadRideVehicles() async {
    final vehicles = await VehicleService.instance.getMyVehicles();

    final availableVehicles = vehicles
        .where(
          (vehicle) =>
              vehicle.isActive &&
              vehicle.rcVerified,
        )
        .map(
          (vehicle) => RideVehicleOption(
            id: vehicle.id,
            vehicleModel: vehicle.vehicleModel,
            registrationNumber: vehicle.registrationNumber,
            color: vehicle.vehicleColor,
            vehicleType: vehicle.vehicleSubtype,
            seatingCapacity: vehicle.seatingCapacity,
            rcVerified: vehicle.rcVerified,
          ),
        )
        .toList(growable: false);

    debugPrint(
      'OfferRideModal: Loaded '
      '${availableVehicles.length} active verified vehicle(s).',
    );

    for (final vehicle in availableVehicles) {
      debugPrint(
        'OfferRideModal: Vehicle '
        'id=${vehicle.id}, '
        'type=${vehicle.vehicleType}, '
        'capacity=${vehicle.seatingCapacity}, '
        'maxLiftOffSeats=${vehicle.seatingCapacity - 1}.',
      );
    }

    return availableVehicles;
  }

  // ================================================================
  // ADD VEHICLE
  // ================================================================

  Future<void> _addVehicle() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const VehicleRcVerificationScreen(),
      ),
    );

    if (!mounted) return;

    debugPrint(
      'OfferRideModal: Vehicle verification flow completed. '
      'Module 3 will refresh the vehicle list.',
    );
  }

  // ================================================================
  // ROUTE FLOW
  // ================================================================

  void _onRouteCalculated(RouteSelectionData data) {
    setState(() {
      _routeData = data;
      _currentStep = 1;
    });
  }

  void _confirmRoute(RouteResult selectedRoute) {
    final data = _routeData;

    if (data == null || selectedRoute.points.length < 2) {
      _showError('Please calculate the route first.');
      return;
    }

    setState(() {
      _routeData = data.copyWith(
        route: selectedRoute,
      );
      _currentStep = 2;
    });
  }

  // ================================================================
  // BUILD ROUTE GEOMETRY
  // ================================================================

  List<Map<String, double>> _buildRouteGeometry(
    RouteResult route,
  ) {
    return [
      for (final point in route.points)
        {
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
    ];
  }

  // ================================================================
  // BUILD STOPS
  // ================================================================

  List<Map<String, dynamic>> _buildStops(
    RouteSelectionData route,
  ) {
    return [
      for (int index = 0; index < route.stops.length; index++)
        {
          'stop_order': index + 1,
          'stop_name': route.stops[index].name,
          'stop_lat': route.stops[index].position.latitude,
          'stop_lng': route.stops[index].position.longitude,
        },
    ];
  }

  // ================================================================
  // BUILD ROUTE LEGS
  // ================================================================

  List<Map<String, dynamic>> _buildRouteLegs(
    RouteSelectionData route,
  ) {
    return [
      for (final leg in route.routeLegs)
        {
          'leg_order': leg.order,

          'start_name': leg.startName,
          'start_lat': leg.start.latitude,
          'start_lng': leg.start.longitude,

          'end_name': leg.endName,
          'end_lat': leg.end.latitude,
          'end_lng': leg.end.longitude,

          'distance_meters': leg.distanceMeters,
          'duration_seconds': leg.durationSeconds,

          'geometry': [
            for (final point in leg.points)
              {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
          ],
        },
    ];
  }

  // ================================================================
  // VALIDATE ROUTE DATA BEFORE PUBLISHING
  // ================================================================

  String? _validateRouteData(
    RouteSelectionData route,
  ) {
    if (route.route.points.length < 2) {
      return 'The confirmed route geometry is incomplete.';
    }

    if (route.routeLegs.isEmpty) {
      return 'The confirmed route legs are missing.';
    }

    for (int i = 0; i < route.route.points.length; i++) {
      final point = route.route.points[i];

      if (point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        return 'The confirmed route contains invalid coordinates.';
      }
    }

    for (int i = 0; i < route.routeLegs.length; i++) {
      final leg = route.routeLegs[i];

      if (leg.order != i + 1) {
        return 'The confirmed route legs are out of order.';
      }

      if (leg.points.length < 2) {
        return 'Route leg ${i + 1} has incomplete geometry.';
      }
    }

    for (int i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];

      if (stop.name.trim().isEmpty) {
        return 'A route stop is missing its name.';
      }

      if (stop.position.latitude < -90 ||
          stop.position.latitude > 90 ||
          stop.position.longitude < -180 ||
          stop.position.longitude > 180) {
        return 'A route stop contains invalid coordinates.';
      }
    }

    return null;
  }

  // ================================================================
  // PUBLISH RIDE
  // ================================================================

  Future<void> _publishRide(
    RideDetailsData details,
  ) async {
    final route = _routeData;

    if (route == null) {
      _showError(
        'Please confirm your route before publishing.',
      );
      return;
    }

    // ------------------------------------------------------------
    // Timing validation
    // ------------------------------------------------------------

    if (!route.rideNow &&
        !route.departure.isAfter(DateTime.now())) {
      _showError(
        'Please choose a future departure time.',
      );
      return;
    }

    // ------------------------------------------------------------
    // Vehicle validation
    // ------------------------------------------------------------

    if (details.vehicleId <= 0) {
      _showError(
        'Please select a valid verified vehicle.',
      );
      return;
    }

    // ------------------------------------------------------------
    // Terms validation
    // ------------------------------------------------------------

    if (!details.termsAccepted) {
      _showError(
        'Please accept the LiftOff ride-sharing terms.',
      );
      return;
    }

    // ------------------------------------------------------------
    // Route validation
    // ------------------------------------------------------------

    final routeError = _validateRouteData(route);

    if (routeError != null) {
      _showError(routeError);
      return;
    }

    // ------------------------------------------------------------
    // Build finalized route snapshot
    // ------------------------------------------------------------

    final routeGeometry = _buildRouteGeometry(
      route.route,
    );

    final routeLegs = _buildRouteLegs(
      route,
    );

    final stops = _buildStops(
      route,
    );

    // ------------------------------------------------------------
    // Final safety checks
    // ------------------------------------------------------------

    if (routeGeometry.length < 2) {
      _showError(
        'The route geometry is incomplete.',
      );
      return;
    }

    if (routeLegs.isEmpty) {
      _showError(
        'No route legs are available for publishing.',
      );
      return;
    }

    for (final leg in routeLegs) {
      final geometry = leg['geometry'];

      if (geometry is! List || geometry.length < 2) {
        _showError(
          'One of the confirmed route legs has incomplete geometry.',
        );
        return;
      }
    }

    // ------------------------------------------------------------
    // Start publishing
    // ------------------------------------------------------------

    setState(() {
      _isPublishing = true;
    });

    try {
      // ----------------------------------------------------------
      // FINAL API PAYLOAD
      // ----------------------------------------------------------

      final payload = <String, dynamic>{
        // ========================================================
        // ORIGIN
        // ========================================================

        'origin_name': route.sourceName,
        'origin_lat': route.source.latitude,
        'origin_lng': route.source.longitude,

        // ========================================================
        // DESTINATION
        // ========================================================

        'destination_name': route.destinationName,
        'destination_lat': route.destination.latitude,
        'destination_lng': route.destination.longitude,

        // ========================================================
        // TIMING
        // ========================================================

        'departure_time':
            route.departure.toUtc().toIso8601String(),

        'ride_now': route.rideNow,

        // ========================================================
        // SEATS
        // ========================================================

        // Module 3 already restricts this to:
        //
        // vehicle.seatingCapacity - 1
        //
        'available_seats': details.seats,

        // ========================================================
        // NORMALIZED VEHICLE
        // ========================================================

        // The backend resolves model, registration number,
        // color, RC and ownership from this vehicle ID.
        'vehicle_id': details.vehicleId,

        // ========================================================
        // FINALIZED COMPLETE ROUTE
        // ========================================================

        'route_distance_meters':
            route.route.distanceMeters,

        'route_duration_seconds':
            route.route.durationSeconds,

        'route_geometry':
            routeGeometry,

        // ========================================================
        // ROUTE STOPS
        // ========================================================

        'stops': stops,

        // ========================================================
        // ROUTE LEGS
        // ========================================================

        'route_legs': routeLegs,

        // ========================================================
        // PASSENGER PREFERENCES
        // ========================================================

        'is_women_only': details.womenOnly,

        'democratic_consent': details.strictConsent,

        // ========================================================
        // ADVANCED PREFERENCES
        // ========================================================

        'flexible_pickup':
            details.flexiblePickup,

        'allow_luggage':
            details.allowLuggage,

        'allow_pets':
            details.allowPets,

        'allow_music':
            details.allowMusic,

        'is_ac':
            details.isAc,

        'additional_notes':
            details.additionalNotes,

        // ========================================================
        // TERMS
        // ========================================================

        'terms_accepted':
            details.termsAccepted,
      };

      // ----------------------------------------------------------
      // DEBUG INFORMATION
      // ----------------------------------------------------------

      debugPrint(
        'LiftOff: Preparing finalized ride payload.',
      );

      debugPrint(
        'LiftOff: origin='
        '${route.sourceName}',
      );

      debugPrint(
        'LiftOff: destination='
        '${route.destinationName}',
      );

      debugPrint(
        'LiftOff: rideNow='
        '${route.rideNow}',
      );

      debugPrint(
        'LiftOff: departure='
        '${route.departure.toUtc().toIso8601String()}',
      );

      debugPrint(
        'LiftOff: vehicleId='
        '${details.vehicleId}',
      );

      debugPrint(
        'LiftOff: availableSeats='
        '${details.seats}',
      );

      debugPrint(
        'LiftOff: routePoints='
        '${routeGeometry.length}',
      );

      debugPrint(
        'LiftOff: routeDistance='
        '${route.route.distanceMeters} m',
      );

      debugPrint(
        'LiftOff: routeDuration='
        '${route.route.durationSeconds} sec',
      );

      debugPrint(
        'LiftOff: routeLegs='
        '${routeLegs.length}',
      );

      debugPrint(
        'LiftOff: stops='
        '${stops.length}',
      );

      debugPrint(
        'OfferRideModal: Publishing ride payload: '
        '$payload',
      );

      // ----------------------------------------------------------
      // POST /rides
      // ----------------------------------------------------------

      await ApiClient.instance.post(
        ApiEndpoints.rides,
        body: payload,
      );

      // ----------------------------------------------------------
      // SUCCESS
      // ----------------------------------------------------------

      // Clear saved route-search draft ONLY after successful
      // backend publishing.
      RouteSelectionModule.clearSavedSearch();

      if (!mounted) return;

      setState(() {
        _isPublishing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride published successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      debugPrint(
        'OfferRideModal API error: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _isPublishing = false;
      });

      _showError(
        'Failed to publish ride: ${e.message}',
      );
    } catch (e) {
      debugPrint(
        'OfferRideModal publish error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isPublishing = false;
      });

      _showError(
        'Unable to publish the ride. Please try again.',
      );
    }
  }

  // ================================================================
  // CLOSE
  // ================================================================

  void _closeModalAndClearDraft() {
    RouteSelectionModule.clearSavedSearch();

    Navigator.of(context).pop();
  }

  // ================================================================
  // ERROR
  // ================================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}