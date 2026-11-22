import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'route_display.dart';
import 'ride_search_service.dart';
import 'ride_details_screen.dart';

/// Community ride discovery section.
///
/// The finalized route-search section remains in SearchBarWidget. This widget
/// owns only ride filters, the route-matching search boundary, and the returned
/// ride list.
class ServiceSelector extends StatefulWidget {
  final String selectedServiceId;
  final ValueChanged<String> onServiceSelected;
  final VoidCallback onBook;

  /// Current traveller route passed from HomeScreen after the finalized
  /// SearchBarWidget has completed its route search.
  final LatLng? routeSource;
  final LatLng? routeDestination;
  final List<LatLng> routeCoordinates;
  final List<LatLng> stopCoordinates;

  const ServiceSelector({
    super.key,
    required this.selectedServiceId,
    required this.onServiceSelected,
    required this.onBook,
    this.routeSource,
    this.routeDestination,
    this.routeCoordinates = const [],
    this.stopCoordinates = const [],
  });

  @override
  State<ServiceSelector> createState() => _ServiceSelectorState();
}

class _ServiceSelectorState extends State<ServiceSelector> {
  static const double _minimumRouteMatch = 50;

  List<CommunityRide> _rides = [];
  bool _isLoading = true;
  String? _errorMessage;

  DateTime? _selectedDateTime;
  String? _selectedVehicleCategory;
  bool _womenOnly = false;
  final Set<String> _selectedFeatures = <String>{};
  RideSort _sort = RideSort.none;

  /// Keep this in sync with the vehicle-selection rules used by Module 3.
  ///
  /// 2 Wheeler: no AC/music features.
  /// 3 Wheeler: music is available, AC is not.
  /// 4 Wheeler: AC and music are available.
  static const Map<String, List<String>> _vehicleFeaturesByCategory = {
  '2 Wheeler': [
    'Helmet',
    'Luggage Allowed',
    'Flexible Pickup',
  ],
  '3 Wheeler': [
    'Luggage Allowed',
    'Pets Allowed',
    'Flexible Pickup',
  ],
  '4 Wheeler': [
    'AC',
    'Luggage Allowed',
    'Pets Allowed',
    'Flexible Pickup',
  ],
};

  static const List<String> _vehicleCategories = [
    '2 Wheeler',
    '3 Wheeler',
    '4 Wheeler',
  ];

  bool get _hasActiveFilters =>
      _selectedDateTime != null ||
      _selectedVehicleCategory != null ||
      _womenOnly ||
      _selectedFeatures.isNotEmpty ||
      _sort != RideSort.none;

  RideSearchFilters get _currentFilters {
    return RideSearchFilters(
      departureDateTime: _selectedDateTime,
      vehicleCategory: _selectedVehicleCategory,
      womenOnly: _womenOnly,
      vehicleFeatures: _selectedFeatures.toList(growable: false),
      sort: _sort,
      minimumRouteMatchPercentage: _minimumRouteMatch,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchRides();
  }

  @override
  void didUpdateWidget(covariant ServiceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final routeChanged =
        oldWidget.routeSource != widget.routeSource ||
        oldWidget.routeDestination != widget.routeDestination ||
        oldWidget.routeCoordinates.length != widget.routeCoordinates.length ||
        oldWidget.stopCoordinates.length != widget.stopCoordinates.length;

    if (routeChanged) {
      _searchRides();
    }
  }

  Future<void> _searchRides() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rides = await RideSearchService.searchRides(
        source: widget.routeSource,
        destination: widget.routeDestination,
        routeCoordinates: widget.routeCoordinates,
        stopCoordinates: widget.stopCoordinates,
        filters: _currentFilters,
      );

      if (!mounted) return;

      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ride search error: $e');
      if (!mounted) return;

      setState(() {
        _rides = [];
        _isLoading = false;
        _errorMessage = 'Unable to load rides right now.';
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDateTime ?? now;

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDate: initialDate.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : initialDate,
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDateTime != null
          ? TimeOfDay.fromDateTime(_selectedDateTime!)
          : TimeOfDay.now(),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });

    _searchRides();
  }

  Future<void> _pickVehicleCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vehicle Category',
                    style: AppTextStyles.h3.copyWith(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose the type of vehicle for your ride.',
                    style: AppTextStyles.caption,
                  ),
                ),
                const SizedBox(height: 14),
                ..._vehicleCategories.map(
                  (category) => _categoryTile(
                    category: category,
                    selected: category == _selectedVehicleCategory,
                    icon: _vehicleCategoryIcon(category),
                    subtitle: _vehicleCategorySubtitle(category),
                    onTap: () => Navigator.pop(context, category),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedVehicleCategory = selected;

      // Module 3 rule: changing category immediately removes features that
      // are not supported by the new category.
      final allowedFeatures =
          _vehicleFeaturesByCategory[selected] ?? const <String>[];
      _selectedFeatures.retainAll(allowedFeatures);
    });

    _searchRides();
  }

  IconData _vehicleCategoryIcon(String category) {
    switch (category) {
      case '2 Wheeler':
        return Icons.two_wheeler_rounded;
      case '3 Wheeler':
        return Icons.electric_rickshaw_rounded;
      case '4 Wheeler':
        return Icons.directions_car_filled_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  String _vehicleCategorySubtitle(String category) {
    switch (category) {
      case '2 Wheeler':
        return 'Bike, scooter and similar';
      case '3 Wheeler':
        return 'Auto, toto and e-rickshaw';
      case '4 Wheeler':
        return 'Car, SUV and similar';
      default:
        return '';
    }
  }

  Widget _categoryTile({
    required String category,
    required bool selected,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primaryTealSurface
            : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primaryTeal
                    : AppColors.borderGray,
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryTeal
                        : AppColors.primaryTealSurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryTealDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.midnightBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryTealDark,
                    size: 21,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFeatures() async {
    if (_selectedVehicleCategory == null) {
      await _pickVehicleCategory();
      if (!mounted || _selectedVehicleCategory == null) return;
    }

    final options =
        _vehicleFeaturesByCategory[_selectedVehicleCategory] ?? const <String>[];
    final draft = Set<String>.from(_selectedFeatures);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderGray,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Vehicle Features',
                      style: AppTextStyles.h3.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available for $_selectedVehicleCategory',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 10),
                    if (options.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTealSurface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'No additional selectable features are available for $_selectedVehicleCategory.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.midnightBlue,
                          ),
                        ),
                      ),
                    ...options.map(
                      (feature) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: draft.contains(feature),
                        title: Text(feature),
                        onChanged: (value) {
                          setSheetState(() {
                            if (value == true) {
                              draft.add(feature);
                            } else {
                              draft.remove(feature);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Apply Features'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    setState(() {
      _selectedFeatures
        ..clear()
        ..addAll(draft);
    });

    _searchRides();
  }

  Future<void> _pickSort() async {
    final selected = await showModalBottomSheet<RideSort>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Sort Rides',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.star_rounded),
                title: const Text('Rating: High → Low'),
                trailing: _sort == RideSort.ratingHighToLow
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, RideSort.ratingHighToLow),
              ),
              ListTile(
                leading: const Icon(Icons.currency_rupee_rounded),
                title: const Text('Fare: High → Low'),
                trailing: _sort == RideSort.fareHighToLow
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, RideSort.fareHighToLow),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() => _sort = selected);
    _searchRides();
  }

  void _toggleWomenOnly() {
    setState(() => _womenOnly = !_womenOnly);
    _searchRides();
  }

  void _removeDateTime() {
    setState(() => _selectedDateTime = null);
    _searchRides();
  }

  void _removeVehicleCategory() {
    setState(() {
      _selectedVehicleCategory = null;
      _selectedFeatures.clear();
    });
    _searchRides();
  }

  void _removeFeatures() {
    setState(() => _selectedFeatures.clear());
    _searchRides();
  }

  void _removeWomenOnly() {
    setState(() => _womenOnly = false);
    _searchRides();
  }

  void _removeSort() {
    setState(() => _sort = RideSort.none);
    _searchRides();
  }

  void _removeAllFilters() {
    if (!_hasActiveFilters) return;
    setState(() {
      _selectedDateTime = null;
      _selectedVehicleCategory = null;
      _womenOnly = false;
      _selectedFeatures.clear();
      _sort = RideSort.none;
    });
    _searchRides();
  }

  String _formatDateTime(DateTime value) {
    const months = [
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
    final hour = value.hour == 0 || value.hour == 12 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day} ${months[value.month - 1]} · $hour:$minute $period';
  }

  String _sortLabel() {
    switch (_sort) {
      case RideSort.ratingHighToLow:
        return 'Rating: High → Low';
      case RideSort.fareHighToLow:
        return 'Fare: High → Low';
      case RideSort.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 10),
        _buildFilters(),
        const SizedBox(height: 14),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryTealDark,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_errorMessage != null)
          _buildError()
        else
          RouteDisplay(
            rides: _rides,
            selectedRideId: widget.selectedServiceId,
            onViewDetails: _openRideDetailsAndNavigate,
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Community Rides',
            style: AppTextStyles.h3.copyWith(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryTealSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: AppColors.primaryTealDark,
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                '${_rides.length} matching',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryTealDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            size: 18,
            color: AppColors.midnightBlue,
          ),
          onPressed: _isLoading ? null : _searchRides,
          tooltip: 'Refresh Rides',
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final active = <Widget>[];

    if (_selectedDateTime != null) {
      active.add(_activeFilterChip(
        'Date & Time: ${_formatDateTime(_selectedDateTime!)}',
        _removeDateTime,
        icon: Icons.calendar_month_rounded,
      ));
    }

    if (_selectedVehicleCategory != null) {
      active.add(_activeFilterChip(
        'Category: $_selectedVehicleCategory',
        _removeVehicleCategory,
        icon: Icons.directions_car_rounded,
      ));
    }

    if (_womenOnly) {
      active.add(_activeFilterChip(
        'Women Only',
        _removeWomenOnly,
        icon: Icons.female_rounded,
      ));
    }

    if (_selectedFeatures.isNotEmpty) {
      active.add(_activeFilterChip(
        'Features: ${_selectedFeatures.join(', ')}',
        _removeFeatures,
        icon: Icons.tune_rounded,
      ));
    }

    if (_sort != RideSort.none) {
      active.add(_activeFilterChip(
        _sortLabel(),
        _removeSort,
        icon: _sort == RideSort.ratingHighToLow
            ? Icons.star_rounded
            : Icons.currency_rupee_rounded,
      ));
    }

    final available = <Widget>[
      _filterButton(
        'Date & Time',
        Icons.calendar_month_rounded,
        _pickDateTime,
      ),
      _filterButton(
        'Vehicle Category',
        Icons.directions_car_rounded,
        _pickVehicleCategory,
      ),
      _filterButton(
        'Women Only',
        Icons.female_rounded,
        _toggleWomenOnly,
      ),
      _filterButton(
        'Vehicle Features',
        Icons.tune_rounded,
        _pickFeatures,
      ),
      _filterButton(
        'Sort',
        Icons.swap_vert_rounded,
        _pickSort,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasActiveFilters) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _removeAllFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 17),
              label: const Text('Remove Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.midnightBlue,
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: AppColors.borderGray.withValues(alpha: 0.9),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (active.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: active.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => active[index],
            ),
          ),
        if (active.isNotEmpty) const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: available.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => available[index],
          ),
        ),
      ],
    );
  }

  Widget _filterButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.midnightBlue),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.midnightBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeFilterChip(
    String label,
    VoidCallback onRemove, {
    required IconData icon,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 11, right: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryTealSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryTealDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryTealDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: AppColors.primaryTealDark,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            tooltip: 'Remove filter',
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.borderGray,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 30,
            color: AppColors.mediumGray,
          ),
          const SizedBox(height: 8),
          Text(_errorMessage!, style: AppTextStyles.bodySmall),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _searchRides,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _openRideDetailsAndNavigate(CommunityRide ride) {
    widget.onServiceSelected(ride.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideDetailsScreen(ride: ride),
      ),
    );
  }
}
