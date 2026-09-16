import 'package:flutter/material.dart';

import 'route_selection_module.dart';

/// A vehicle already owned by the user and verified through the vehicle/RC
/// flow. Module 3 only selects it; it never creates or verifies a vehicle.
class RideVehicleOption {
  final int id;
  final String vehicleModel;
  final String registrationNumber;
  final String? color;
  final String vehicleType;
  final int seatingCapacity;
  final bool rcVerified;

  const RideVehicleOption({
    required this.id,
    required this.vehicleModel,
    required this.registrationNumber,
    this.color,
    required this.vehicleType,
    required this.seatingCapacity,
    this.rcVerified = true,
  });
}

/// Data collected by Module 3.
///
/// IMPORTANT:
/// There is intentionally NO fare/contribution input here.
/// The backend will calculate the final ride fare from route distance,
/// duration, vehicle and ride preferences after publishing.
class RideDetailsData {
  final int seats;

  final int vehicleId;
  final String vehicleModel;
  final String vehicleNumber;
  final String? vehicleColor;

  final bool womenOnly;
  final bool strictConsent;

  // Advanced ride preferences.
  final bool flexiblePickup;
  final bool allowLuggage;
  final bool allowPets;
  final bool allowMusic;
  final bool isAc;
  final String additionalNotes;

  final bool termsAccepted;

  const RideDetailsData({
    required this.seats,
    required this.vehicleId,
    required this.vehicleModel,
    required this.vehicleNumber,
    this.vehicleColor,
    required this.womenOnly,
    required this.strictConsent,
    required this.flexiblePickup,
    required this.allowLuggage,
    required this.allowPets,
    required this.allowMusic,
    required this.isAc,
    required this.additionalNotes,
    required this.termsAccepted,
  });
}

class RideDetailsModule extends StatefulWidget {
  final RouteSelectionData routeData;
  final VoidCallback onBack;
  final ValueChanged<RideDetailsData> onPublish;
  final bool isPublishing;

  /// Already loaded vehicles can be supplied by the parent.
  final List<RideVehicleOption> vehicles;

  /// Recommended integration when the vehicle API is loaded asynchronously.
  ///
  /// Example:
  /// loadVehicles: () => VehicleService.getVehicles(...)
  ///
  /// This keeps API/network code outside the UI while allowing Module 3 to
  /// display the user's actual database vehicles.
  final Future<List<RideVehicleOption>> Function()? loadVehicles;

  /// Opens the Add Vehicle / RC Verification flow.
  ///
  /// The Future completes when the verification screen is closed. Module 3
  /// then reloads the vehicle list from the backend.
  final Future<void> Function()? onAddVehicle;

  const RideDetailsModule({
    super.key,
    required this.routeData,
    required this.onBack,
    required this.onPublish,
    required this.isPublishing,
    this.vehicles = const <RideVehicleOption>[],
    this.loadVehicles,
    this.onAddVehicle,
  });

  @override
  State<RideDetailsModule> createState() => _RideDetailsModuleState();
}

class _RideDetailsModuleState extends State<RideDetailsModule> {
  int _seats = 1;

  int? _selectedVehicleId;

  bool _womenOnly = false;
  bool _strictConsent = true;

  // Advanced preferences.
  bool _flexiblePickup = false;
  bool _allowLuggage = true;
  bool _allowPets = false;
  bool _allowMusic = true;
  bool _isAc = true;

  final _notesController = TextEditingController();

  bool _termsAccepted = false;
  bool _showPreview = false;

  bool _loadingVehicles = false;
  String? _vehicleLoadError;
  List<RideVehicleOption> _loadedVehicles = const <RideVehicleOption>[];

  List<RideVehicleOption> get _allVehicles {
    if (widget.vehicles.isNotEmpty) {
      return widget.vehicles;
    }
    return _loadedVehicles;
  }

  List<RideVehicleOption> get _verifiedVehicles =>
      _allVehicles.where((vehicle) => vehicle.rcVerified).toList();

  RideVehicleOption? get _selectedVehicle {
    final id = _selectedVehicleId;
    if (id == null) return null;

    for (final vehicle in _verifiedVehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  int get _maxAvailableSeats {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return 1;

    return vehicle.seatingCapacity > 1
        ? vehicle.seatingCapacity - 1
        : 1;
  }

  bool _isTwoWheeler(RideVehicleOption vehicle) {
    final type = vehicle.vehicleType.trim().toUpperCase();
    return type == 'BIKE' || type == 'SCOOTY' || type == 'SCOOTER' || type.contains('2 WHEELER');
  }

  bool _isThreeWheeler(RideVehicleOption vehicle) {
    final type = vehicle.vehicleType.trim().toUpperCase();
    return type == 'AUTO' || type == 'E-RICKSHAW' || type == 'E RICKSHAW' || type == 'TOTO' || type == 'RICKSHAW' || type.contains('3 WHEELER');
  }

  bool _supportsAc(RideVehicleOption vehicle) => !_isTwoWheeler(vehicle) && !_isThreeWheeler(vehicle);

  bool _supportsMusic(RideVehicleOption vehicle) => !_isTwoWheeler(vehicle);

  void _applyVehicleSelection(RideVehicleOption vehicle) {
    final maxSeats = vehicle.seatingCapacity > 1
        ? vehicle.seatingCapacity - 1
        : 1;

    setState(() {
      _selectedVehicleId = vehicle.id;

      if (_seats > maxSeats) {
        _seats = maxSeats;
      } else if (_seats < 1) {
        _seats = 1;
      }

      if (!_supportsAc(vehicle)) {
        _isAc = false;
      }

      if (!_supportsMusic(vehicle)) {
        _allowMusic = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  @override
  void didUpdateWidget(covariant RideDetailsModule oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.vehicles != widget.vehicles) {
      _reconcileVehicleSelection();
    }

    if (oldWidget.loadVehicles != widget.loadVehicles &&
        widget.vehicles.isEmpty) {
      _loadVehicleData();
    }
  }

  Future<void> _loadVehicleData() async {
    if (widget.vehicles.isNotEmpty || widget.loadVehicles == null) {
      _reconcileVehicleSelection();
      return;
    }

    setState(() {
      _loadingVehicles = true;
      _vehicleLoadError = null;
    });

    try {
      final vehicles = await widget.loadVehicles!();

      if (!mounted) return;

      setState(() {
        _loadedVehicles = List<RideVehicleOption>.unmodifiable(vehicles);
        _loadingVehicles = false;
      });

      _reconcileVehicleSelection();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingVehicles = false;
        _vehicleLoadError = 'Unable to load your vehicles.';
      });

      debugPrint('LiftOff: Module 3 vehicle loading failed: $error');
    }
  }

  /// Runs the parent Add Vehicle flow and refreshes the vehicle list after
  /// the verification screen closes.
  Future<void> _handleAddVehicle() async {
    final onAddVehicle = widget.onAddVehicle;
    if (onAddVehicle == null) return;

    await onAddVehicle();

    if (!mounted) return;

    debugPrint(
      'LiftOff: Module 3 refreshing vehicles after Add Vehicle flow.',
    );

    await _loadVehicleData();
  }

  void _reconcileVehicleSelection() {
    final verified = _verifiedVehicles;

    if (_selectedVehicleId != null &&
        verified.any((vehicle) => vehicle.id == _selectedVehicleId)) {
      final selected = verified.firstWhere(
        (vehicle) => vehicle.id == _selectedVehicleId,
      );
      final maxSeats = selected.seatingCapacity > 1
          ? selected.seatingCapacity - 1
          : 1;

      if (_seats > maxSeats) {
        _seats = maxSeats;
      }

      if (!_supportsAc(selected)) {
        _isAc = false;
      }
      if (!_supportsMusic(selected)) {
        _allowMusic = false;
      }

      if (mounted) setState(() {});
      return;
    }

    if (verified.length == 1) {
      _selectedVehicleId = verified.first.id;

      final maxSeats = verified.first.seatingCapacity > 1
          ? verified.first.seatingCapacity - 1
          : 1;

      if (_seats > maxSeats) {
        _seats = maxSeats;
      }

      if (!_supportsAc(verified.first)) {
        _isAc = false;
      }
      if (!_supportsMusic(verified.first)) {
        _allowMusic = false;
      }
    } else {
      _selectedVehicleId = null;
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPreview) {
      return _buildPreviewScreen();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),

        _buildFinalRouteCard(),
        const SizedBox(height: 18),

        _buildSeatsSection(),
        const SizedBox(height: 16),

        _buildVehicleSection(),
        const SizedBox(height: 16),

        _buildPassengerPreferences(),
        const SizedBox(height: 16),

        _buildAdvancedSection(),
        const SizedBox(height: 16),

        _buildTermsSection(),
        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.isPublishing ? null : widget.onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: widget.isPublishing ? null : _continueToPreview,
                icon: const Icon(Icons.preview_rounded),
                label: const Text('Review & Preview'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Offer your ride',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Your fare will be calculated automatically by LiftOff.',
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.black.withOpacity(.48),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildFinalRouteCard() {
    final route = widget.routeData.route;
    final names = <String>[
      widget.routeData.sourceName,
      ...widget.routeData.stops.map((s) => s.name),
      widget.routeData.destinationName,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2F7FF),
            Color(0xFFF9FBFE),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.route_rounded),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Confirmed route',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.verified_rounded,
                size: 19,
                color: Color(0xFF188038),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            names.join('  →  '),
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              _routeChip(
                Icons.straighten_rounded,
                route.distanceText,
              ),
              _routeChip(
                Icons.schedule_rounded,
                route.durationText,
              ),
              _routeChip(
                widget.routeData.rideNow
                    ? Icons.bolt_rounded
                    : Icons.event_rounded,
                widget.routeData.rideNow
                    ? 'Ride now'
                    : _formatDate(widget.routeData.departure),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 19,
        color: const Color(0xFF1677FF),
      ),
    );
  }

  Widget _routeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF1677FF),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsSection() {
    final vehicle = _selectedVehicle;
    final maxSeats = _maxAvailableSeats;

    return _buildCardSection(
      title: 'Passenger capacity',
      subtitle: vehicle == null
          ? 'Select a vehicle to set the available seat limit.'
          : 'Maximum ${maxSeats} passenger ${maxSeats == 1 ? 'seat' : 'seats'} available for LiftOff.',
      icon: Icons.airline_seat_recline_normal_rounded,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Available seats',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
              _counterButton(
                Icons.remove_rounded,
                _seats > 1
                    ? () => setState(() => _seats--)
                    : null,
              ),
              SizedBox(
                width: 45,
                child: Center(
                  child: Text(
                    '$_seats',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _counterButton(
                Icons.add_rounded,
                vehicle != null && _seats < maxSeats
                    ? () => setState(() => _seats++)
                    : null,
              ),
            ],
          ),
          if (vehicle != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Vehicle capacity: ${vehicle.seatingCapacity} • '
                '1 seat is reserved for the host',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.black45,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback? onTap) {
    return Material(
      color: const Color(0xFFF0F3F7),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 35,
          height: 35,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.black26 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleSection() {
    return _buildCardSection(
      title: 'Your vehicle',
      subtitle: 'Select one of your verified vehicles for this ride.',
      icon: Icons.directions_car_rounded,
      child: _buildVehicleContent(),
    );
  }

  Widget _buildVehicleContent() {
    if (_loadingVehicles) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: const Column(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(height: 10),
            Text(
              'Loading your verified vehicles...',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      );
    }

    if (_vehicleLoadError != null) {
      return _buildVehicleMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load vehicles',
        message: 'Please try again. Your verified vehicle is not lost.',
        actionLabel: 'Retry',
        onAction: _loadVehicleData,
      );
    }

    final vehicles = _verifiedVehicles;

    if (vehicles.isEmpty) {
      return _buildVehicleMessage(
        icon: Icons.directions_car_outlined,
        title: 'No verified vehicle found',
        message:
            'Add and verify a vehicle before it can be used to offer a ride.',
        actionLabel: widget.onAddVehicle == null ? null : 'Add Vehicle',
        onAction: widget.onAddVehicle == null ? null : _handleAddVehicle,
      );
    }

    return Column(
      children: [
        ...vehicles.map(_buildVehicleTile),
        if (widget.onAddVehicle != null) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onAddVehicle == null ? null : _handleAddVehicle,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                size: 17,
              ),
              label: const Text(
                'Add another vehicle',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(
              Icons.shield_rounded,
              size: 15,
              color: Color(0xFF188038),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Only RC-verified vehicles are available for ride offers.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E7ED)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF1677FF),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.black45,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 7),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTile(RideVehicleOption vehicle) {
    final selected = vehicle.id == _selectedVehicleId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => _applyVehicleSelection(vehicle),
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFF1F7FF)
                : const Color(0xFFFAFBFC),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1677FF)
                  : const Color(0xFFE0E6EC),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Color(0xFF1677FF),
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.vehicleModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.registrationNumber,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .35,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle.vehicleType,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                      ),
                    ),
                    if (vehicle.color != null &&
                        vehicle.color!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        vehicle.color!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 21,
                    color: selected
                        ? const Color(0xFF1677FF)
                        : Colors.black26,
                  ),
                  const SizedBox(height: 3),
                  const Icon(
                    Icons.verified_rounded,
                    size: 15,
                    color: Color(0xFF188038),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerPreferences() {
    return _buildCardSection(
      title: 'Passenger preferences',
      subtitle: 'Set the conditions passengers should know before joining.',
      icon: Icons.people_alt_outlined,
      child: Column(
        children: [
          _preferenceTile(
            title: 'Women passengers only',
            subtitle: 'Only eligible women passengers can request this ride.',
            value: _womenOnly,
            onChanged: (value) {
              setState(() => _womenOnly = value);
            },
          ),
          const Divider(height: 1),
          _preferenceTile(
            title: 'Passenger consent required',
            subtitle: 'Passengers must agree to ride-sharing terms before joining.',
            value: _strictConsent,
            onChanged: (value) {
              setState(() => _strictConsent = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return _buildCardSection(
      title: 'Advanced options',
      subtitle: 'These preferences help LiftOff match suitable passengers.',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          if (_selectedVehicle == null || _supportsAc(_selectedVehicle!))
            _preferenceTile(
              title: 'AC',
              subtitle: _isAc
                  ? 'Air conditioning available during the ride.'
                  : 'Non-AC ride.',
              value: _isAc,
              onChanged: (value) {
                setState(() => _isAc = value);
              },
            ),
          if (_selectedVehicle == null || _supportsAc(_selectedVehicle!))
            const Divider(height: 1),
          _preferenceTile(
            title: 'Flexible pickup',
            subtitle: 'Allow a small pickup adjustment when coordinating.',
            value: _flexiblePickup,
            onChanged: (value) {
              setState(() => _flexiblePickup = value);
            },
          ),
          const Divider(height: 1),
          _preferenceTile(
            title: 'Allow luggage',
            subtitle: 'Reasonable personal luggage is allowed.',
            value: _allowLuggage,
            onChanged: (value) {
              setState(() => _allowLuggage = value);
            },
          ),
          const Divider(height: 1),
          _preferenceTile(
            title: 'Allow pets',
            subtitle: 'Pets are allowed when safely accommodated.',
            value: _allowPets,
            onChanged: (value) {
              setState(() => _allowPets = value);
            },
          ),
          if (_selectedVehicle == null || _supportsMusic(_selectedVehicle!))
            const Divider(height: 1),
          if (_selectedVehicle == null || _supportsMusic(_selectedVehicle!))
            _preferenceTile(
              title: 'Music is okay',
              subtitle: 'Passengers may expect normal in-vehicle music.',
              value: _allowMusic,
              onChanged: (value) {
                setState(() => _allowMusic = value);
              },
            ),
          const SizedBox(height: 9),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 250,
            decoration: _inputDecoration(
              'Additional notes',
              'Anything passengers should know before requesting?',
              Icons.notes_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferenceTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 10.5,
          color: Colors.black45,
          height: 1.3,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildTermsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: _termsAccepted
            ? const Color(0xFFF1F8F3)
            : const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _termsAccepted
              ? const Color(0xFFB9DEC1)
              : const Color(0xFFE1E7ED),
        ),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _termsAccepted,
        onChanged: (value) {
          setState(() => _termsAccepted = value ?? false);
        },
        title: const Text(
          'I agree to LiftOff ride-sharing terms',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            'I confirm that the ride information is accurate and that this '
            'ride is offered for legitimate ride-sharing purposes.',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.black45,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2E7EC)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 4),
            color: Color(0x08000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Colors.black45,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE0E5EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE0E5EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF1677FF)),
      ),
    );
  }

  void _continueToPreview() {
    if (_selectedVehicle == null) {
      _showError('Please select a verified vehicle.');
      return;
    }

    if (_seats > _maxAvailableSeats) {
      setState(() => _seats = _maxAvailableSeats);
      _showError(
        'Available seats cannot exceed ${_maxAvailableSeats}.',
      );
      return;
    }

    if (!_termsAccepted) {
      _showError('Please accept the LiftOff ride-sharing terms.');
      return;
    }

    setState(() => _showPreview = true);
  }

  RideDetailsData _buildRideDetailsData() {
    final vehicle = _selectedVehicle!;

    final maxSeats = vehicle.seatingCapacity > 1
        ? vehicle.seatingCapacity - 1
        : 1;

    final safeSeats = _seats.clamp(1, maxSeats);

    return RideDetailsData(
      seats: safeSeats.toInt(),
      vehicleId: vehicle.id,
      vehicleModel: vehicle.vehicleModel,
      vehicleNumber: vehicle.registrationNumber,
      vehicleColor: vehicle.color,
      womenOnly: _womenOnly,
      strictConsent: _strictConsent,
      flexiblePickup: _flexiblePickup,
      allowLuggage: _allowLuggage,
      allowPets: _allowPets,
      allowMusic: _allowMusic,
      isAc: _isAc,
      additionalNotes: _notesController.text.trim(),
      termsAccepted: _termsAccepted,
    );
  }

  Widget _buildPreviewScreen() {
    final details = _buildRideDetailsData();
    final vehicle = _selectedVehicle!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.isPublishing
                  ? null
                  : () => setState(() => _showPreview = false),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Edit ride',
            ),
            const SizedBox(width: 2),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview your ride',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Review everything before publishing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildPreviewHero(vehicle, details),
        const SizedBox(height: 14),

        _buildPreviewSection(
          title: 'Route',
          icon: Icons.route_rounded,
          child: _buildRoutePreview(),
        ),
        const SizedBox(height: 12),

        _buildPreviewSection(
          title: 'Ride details',
          icon: Icons.airline_seat_recline_normal_rounded,
          child: Column(
            children: [
              _previewRow('Available seats', '${details.seats}'),
              _previewRow(
                'Timing',
                widget.routeData.rideNow
                    ? 'Ride now'
                    : _formatDateTime(widget.routeData.departure),
              ),
              _previewRow(
                'Fare',
                'Calculated automatically by LiftOff',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildPreviewSection(
          title: 'Vehicle',
          icon: Icons.directions_car_rounded,
          child: Column(
            children: [
              _previewRow('Model', vehicle.vehicleModel),
              _previewRow('Type', vehicle.vehicleType),
              _previewRow('Registration', vehicle.registrationNumber),
              _previewRow(
                'Vehicle capacity',
                '${vehicle.seatingCapacity} seats',
              ),
              if (vehicle.color != null &&
                  vehicle.color!.trim().isNotEmpty)
                _previewRow('Color', vehicle.color!),
              _previewBadge(
                Icons.verified_rounded,
                'RC verified',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildPreviewSection(
          title: 'Passenger preferences',
          icon: Icons.people_alt_outlined,
          child: Column(
            children: [
              _previewRow(
                'Women passengers only',
                details.womenOnly ? 'Yes' : 'No',
              ),
              _previewRow(
                'Passenger consent',
                details.strictConsent ? 'Required' : 'Not required',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildPreviewSection(
          title: 'Advanced options',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              _previewRow(
                'AC',
                _supportsAc(vehicle)
                    ? (details.isAc ? 'AC' : 'Non-AC')
                    : 'Not applicable',
              ),
              _previewRow(
                'Flexible pickup',
                details.flexiblePickup ? 'Allowed' : 'No',
              ),
              _previewRow(
                'Luggage',
                details.allowLuggage ? 'Allowed' : 'Not allowed',
              ),
              _previewRow(
                'Pets',
                details.allowPets ? 'Allowed' : 'Not allowed',
              ),
              _previewRow(
                'Music',
                _supportsMusic(vehicle)
                    ? (details.allowMusic ? 'Okay' : 'Not allowed')
                    : 'Not applicable',
              ),
              if (details.additionalNotes.isNotEmpty)
                _previewRow('Notes', details.additionalNotes),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8F3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB9DEC1)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF188038),
                size: 19,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Terms accepted. LiftOff will calculate the appropriate '
                  'fare from the finalized ride information.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF245B31),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.isPublishing
                    ? null
                    : () => setState(() => _showPreview = false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: widget.isPublishing
                    ? null
                    : _publishFromPreview,
                icon: widget.isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(
                  widget.isPublishing
                      ? 'Publishing...'
                      : 'Publish Ride',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF1677FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewHero(
    RideVehicleOption vehicle,
    RideDetailsData details,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF1F6FF),
            Color(0xFFFAFCFF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E6F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: Color(0xFF1677FF),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.vehicleModel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vehicle.registrationNumber,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${vehicle.vehicleType} • '
                  '${details.seats} passenger seats • '
                  '${details.isAc ? 'AC' : 'Non-AC'}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF188038),
            size: 23,
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePreview() {
    final route = widget.routeData.route;
    final names = <String>[
      widget.routeData.sourceName,
      ...widget.routeData.stops.map((s) => s.name),
      widget.routeData.destinationName,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          names.join('  →  '),
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black87,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 8,
          runSpacing: 7,
          children: [
            _routeChip(Icons.straighten_rounded, route.distanceText),
            _routeChip(Icons.schedule_rounded, route.durationText),
          ],
        ),
        if (widget.routeData.routeLegs.isNotEmpty) ...[
          const SizedBox(height: 11),
          Text(
            '${widget.routeData.routeLegs.length} confirmed route '
            '${widget.routeData.routeLegs.length == 1 ? 'leg' : 'legs'} '
            'preserved for backend matching.',
            style: const TextStyle(
              fontSize: 10.5,
              color: Colors.black45,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFF1677FF),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBadge(IconData icon, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: const Color(0xFF188038),
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF188038),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _publishFromPreview() {
    if (!_termsAccepted) {
      setState(() => _showPreview = false);
      _showError('Please accept the LiftOff ride-sharing terms.');
      return;
    }

    if (_selectedVehicle == null) {
      setState(() => _showPreview = false);
      _showError('Please select a verified vehicle.');
      return;
    }

    widget.onPublish(_buildRideDetailsData());
  }

  String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${value.day} ${months[value.month - 1]}';
  }

  String _formatDateTime(DateTime value) {
    final date = _formatDate(value);
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$date, $hour:$minute $period';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
