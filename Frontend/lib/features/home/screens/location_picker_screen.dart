import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/location_trie_service.dart';

/// Rapido-Style Dedicated Full-Screen Location Picker
class LocationPickerResult {
  final String pickupName;
  final LatLng? pickupLatLng;
  final String destinationName;
  final LatLng? destinationLatLng;
  final LatLng selectedLatLng;
  final bool isPickupSelection;

  const LocationPickerResult({
    required this.pickupName,
    this.pickupLatLng,
    required this.destinationName,
    this.destinationLatLng,
    required this.selectedLatLng,
    required this.isPickupSelection,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final String initialPickup;
  final String initialDestination;
  final bool focusOnPickup;

  const LocationPickerScreen({
    super.key,
    required this.initialPickup,
    required this.initialDestination,
    this.focusOnPickup = true,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late TextEditingController _pickupController;
  late TextEditingController _destinationController;
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  late bool _isEditingPickup;

  @override
  void initState() {
    super.initState();
    _isEditingPickup = widget.focusOnPickup;
    _pickupController = TextEditingController(text: widget.initialPickup);
    _destinationController = TextEditingController(text: widget.initialDestination);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEditingPickup) {
        _pickupFocus.requestFocus();
      } else {
        _destinationFocus.requestFocus();
      }
    });

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() => _isEditingPickup = true);
      }
    });

    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() => _isEditingPickup = false);
      }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  void _swapLocations() {
    HapticFeedback.selectionClick();
    final temp = _pickupController.text;
    setState(() {
      _pickupController.text = _destinationController.text;
      _destinationController.text = temp;
    });
  }

  void _selectLocation(LocationItem item) {
    HapticFeedback.selectionClick();
    final result = LocationPickerResult(
      pickupName: _isEditingPickup ? item.name : _pickupController.text,
      pickupLatLng: _isEditingPickup ? item.latLng : null,
      destinationName: !_isEditingPickup ? item.name : _destinationController.text,
      destinationLatLng: !_isEditingPickup ? item.latLng : null,
      selectedLatLng: item.latLng,
      isPickupSelection: _isEditingPickup,
    );
    Navigator.of(context).pop(result);
  }

  void _selectCurrentLocation() {
    HapticFeedback.selectionClick();
    const currentLoc = LatLng(LocationTrieService.defaultUserLat, LocationTrieService.defaultUserLng);
    final result = LocationPickerResult(
      pickupName: 'Current Location (Rajiv Chowk)',
      pickupLatLng: currentLoc,
      destinationName: _destinationController.text,
      destinationLatLng: null,
      selectedLatLng: currentLoc,
      isPickupSelection: true,
    );
    Navigator.of(context).pop(result);
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'metro':
        return Icons.subway_rounded;
      case 'airport':
        return Icons.flight_takeoff_rounded;
      case 'hub':
        return Icons.business_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeQuery = _isEditingPickup ? _pickupController.text : _destinationController.text;
    final searchResults = LocationTrieService.instance.search(
      query: activeQuery,
      maxRadiusKm: 100.0,
      limit: 10,
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.midnightBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditingPickup ? 'Select Pickup Location' : 'Select Destination',
          style: AppTextStyles.h3.copyWith(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Top Input Card with connected Pickup & Destination inputs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderGray, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pickup Field
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meeting Node (Pickup)',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.mediumGray,
                              fontSize: 10,
                            ),
                          ),
                          TextField(
                            controller: _pickupController,
                            focusNode: _pickupFocus,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _isEditingPickup ? AppColors.primaryTealDark : AppColors.deepSlate,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.only(top: 2, bottom: 2),
                              border: InputBorder.none,
                              hintText: 'Enter pickup location...',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    if (_pickupController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _pickupController.clear();
                          setState(() {});
                        },
                        child: const Icon(Icons.close, size: 16, color: AppColors.mediumGray),
                      ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 5),
                      Container(width: 2, height: 18, color: AppColors.borderGray),
                      const SizedBox(width: 19),
                      const Expanded(child: Divider(height: 1)),
                      GestureDetector(
                        onTap: _swapLocations,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.lightGray,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.swap_vert_rounded,
                            size: 18,
                            color: AppColors.midnightBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Destination Field
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.midnightBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Where are you heading?',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.mediumGray,
                              fontSize: 10,
                            ),
                          ),
                          TextField(
                            controller: _destinationController,
                            focusNode: _destinationFocus,
                            style: AppTextStyles.label.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: !_isEditingPickup ? AppColors.primaryTealDark : AppColors.midnightBlue,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.only(top: 2, bottom: 2),
                              border: InputBorder.none,
                              hintText: 'Enter destination...',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    if (_destinationController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _destinationController.clear();
                          setState(() {});
                        },
                        child: const Icon(Icons.close, size: 16, color: AppColors.mediumGray),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Action Shortcuts: Current Location & Select on Map
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectCurrentLocation,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTealSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primaryTealDark),
                          const SizedBox(width: 6),
                          Text(
                            'Current Location',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_outlined, size: 16, color: AppColors.deepSlate),
                        const SizedBox(width: 6),
                        Text(
                          '100km Geofence Active',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepSlate,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Trie Search Results Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, size: 14, color: AppColors.mediumGray),
                const SizedBox(width: 6),
                Text(
                  _isEditingPickup
                      ? 'SUGGESTED PICKUP NODES (TRIE AUTOCOMPLETE)'
                      : 'SUGGESTED DESTINATION HUBS (TRIE AUTOCOMPLETE)',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mediumGray,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Autocomplete Trie Results List
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Text(
                      'No matching locations found within 100km',
                      style: AppTextStyles.caption.copyWith(color: AppColors.mediumGray),
                    ),
                  )
                : ListView.separated(
                    itemCount: searchResults.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 50),
                    itemBuilder: (context, index) {
                      final res = searchResults[index];
                      final item = res.location;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getCategoryIcon(item.category),
                            size: 18,
                            color: _isEditingPickup ? AppColors.primaryTealDark : AppColors.midnightBlue,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: AppTextStyles.label.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.mediumGray,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTealSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            res.formattedDistance,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTealDark,
                            ),
                          ),
                        ),
                        onTap: () => _selectLocation(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
