import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/services/vehicle_service.dart';
import '../../auth/screens/vehicle_rc_verification_screen.dart';
import '../../../core/services/google_places_service.dart';
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
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;

    // Android does not automatically move a modal-bottom-sheet's bottom edge
    // above the IME. The previous implementation reduced the sheet height,
    // but left the sheet anchored to the physical bottom of the screen. That
    // is why the keyboard covered the lower part of the white sheet.
    //
    // The fix is deliberately split into two dimensions:
    //   1. sheetHeight = the actually visible height.
    //   2. bottom padding = keyboardInset, which moves the whole sheet above
    //      the keyboard instead of leaving it underneath the IME.
    //
    // This keeps one scroll owner: this parent. Child modules remain normal
    // Columns and never add their own keyboard padding.
    final visibleHeight =
        (screenHeight - keyboardInset).clamp(0.0, screenHeight).toDouble();

    final keyboardOpen = keyboardInset > 0.0;

    final closedSheetHeight = (screenHeight * 0.92)
        .clamp(0.0, screenHeight)
        .toDouble();

    // When the keyboard is closed, preserve the comfortable bottom-sheet
    // presentation. As soon as Android opens the keyboard, the sheet becomes
    // the full visible viewport above the IME.
    final targetHeight = keyboardOpen ? visibleHeight : closedSheetHeight;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        width: double.infinity,
        height: targetHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(keyboardOpen ? 0 : 28),
          ),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: true,
              bottom: false,
              child: Column(
              children: [
                _buildHeader(),
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: _buildCurrentStep(),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
          onBack: () => setState(() => _currentStep = 1),
          onPublish: _publishRide,
          isPublishing: _isPublishing,
          loadVehicles: _loadRideVehicles,
          onAddVehicle: _addVehicle,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────
  // LOAD VERIFIED VEHICLES
  // ─────────────────────────────────────────────

  Future<List<RideVehicleOption>> _loadRideVehicles() async {
    final vehicles = await VehicleService.instance.getMyVehicles();

    // Only active vehicles with a verified RC can be offered for a ride.
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

  // ─────────────────────────────────────────────
  // ADD VEHICLE
  // ─────────────────────────────────────────────

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

  void _onRouteCalculated(RouteSelectionData data) {
    setState(() {
      _routeData = data;
      _currentStep = 1;
    });
  }

  void _confirmRoute(RouteResult selectedRoute) {
    final data = _routeData;

    if (data == null || selectedRoute.points.isEmpty) {
      _showError('Please calculate the route first.');
      return;
    }

    setState(() {
      _routeData = data.copyWith(route: selectedRoute);
      _currentStep = 2;
    });
  }

  // ================================================================
  // BUILD CONFIRMED ROUTE PAYLOAD
  // ================================================================

  List<Map<String, dynamic>> _buildStopsPayload(
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

  List<Map<String, dynamic>> _buildRouteLegsPayload(
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

  Future<void> _publishRide(RideDetailsData details) async {
    final route = _routeData;

    if (route == null) {
      _showError('Please confirm your route before publishing.');
      return;
    }

    if (!route.departure.isAfter(DateTime.now()) && !route.rideNow) {
      _showError('Please choose a future departure time.');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final payload = <String, dynamic>{
        // ============================================================
        // WORKING RIDE PAYLOAD
        // ============================================================
        //
        // Keep the normal ride fields identical to the previously
        // working /rides publishing flow.
        'origin_name': route.sourceName,
        'origin_lat': route.source.latitude,
        'origin_lng': route.source.longitude,
        'destination_name': route.destinationName,
        'destination_lat': route.destination.latitude,
        'destination_lng': route.destination.longitude,
        'departure_time': route.departure.toUtc().toIso8601String(),
        'ride_now': route.rideNow,
        'available_seats': details.seats,

        // ============================================================
        // CONFIRMED ROUTE SNAPSHOT
        // ============================================================
        //
        // These values come from the final route selected in
        // RouteConfirmationModule. Do NOT recalculate the route here.
        //
        // IMPORTANT:
        // RouteLegData.toJson() is the frontend route-model format.
        // The /rides API expects a different flat route-leg schema,
        // so route legs are mapped explicitly below.
        'route_distance_meters': route.route.distanceMeters,
        'route_duration_seconds': route.route.durationSeconds,
        'route_geometry': [
          for (final point in route.route.points)
            {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
        ],
        'stops': _buildStopsPayload(route),
        'route_legs': _buildRouteLegsPayload(route),

        // ============================================================
        // VERIFIED VEHICLE
        // ============================================================
        //
        // The vehicle is selected from the user's verified vehicles.
        // The backend validates ownership and verification.
        'vehicle_id': details.vehicleId,
        'vehicle_model': details.vehicleModel,
        'vehicle_number': details.vehicleNumber,
        'vehicle_color': details.vehicleColor,

        // Passenger preferences.
        'is_women_only': details.womenOnly,
        'democratic_consent': details.strictConsent,

        // Advanced ride preferences.
        'flexible_pickup': details.flexiblePickup,
        'allow_luggage': details.allowLuggage,
        'allow_pets': details.allowPets,
        'allow_music': details.allowMusic,
        'is_ac': details.isAc,
        'additional_notes': details.additionalNotes,

        // Module 3 only records acceptance. The backend calculates the
        // actual fare; the host never submits a fare.
        'terms_accepted': details.termsAccepted,
      };

      debugPrint(
        'OfferRideModal: Publishing ride payload: $payload',
      );

      await ApiClient.instance.post(
        ApiEndpoints.rides,
        body: payload,
      );

      // Clear the saved route-search draft ONLY after the Publish action
      // has succeeded. Going back between steps does not clear it.
      RouteSelectionModule.clearSavedSearch();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride published successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      debugPrint('OfferRideModal API error: ${e.message}');

      if (!mounted) return;

      setState(() => _isPublishing = false);
      _showError('Failed to publish ride: ${e.message}');
    } catch (e) {
      debugPrint('OfferRideModal publish error: $e');

      if (!mounted) return;

      setState(() => _isPublishing = false);
      _showError('Unable to publish the ride. Please try again.');
    }
  }

  /// The X/Cut button is the other intentional point where the saved
  /// RouteSelectionModule search is deleted.
  void _closeModalAndClearDraft() {
    RouteSelectionModule.clearSavedSearch();
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;

    // Floating SnackBars can be laid out outside the available viewport
    // while this modal is above the Android IME. Use a fixed SnackBar here
    // so an API/validation error cannot trigger:
    // "Floating SnackBar presented off screen."
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.fixed,
        ),
      );
  }
}
