import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/posted_ride.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Frontend module for rides published by the current user.
///
/// Statuses:
/// - Active
/// - Scheduled
/// - Completed
/// - Cancelled
class PublishedRidesModule extends StatefulWidget {
  const PublishedRidesModule({super.key});

  @override
  State<PublishedRidesModule> createState() => PublishedRidesModuleState();
}

class PublishedRidesModuleState extends State<PublishedRidesModule>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<PostedRide> _allRides = [];
  bool _isLoading = true;
  Timer? _rideLifecycleTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchPublishedRides();
    _rideLifecycleTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchPublishedRides(),
    );
  }

  @override
  void dispose() {
    _rideLifecycleTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublishedRides() async {
    try {
      final response =
          await ApiClient.instance.get('${ApiEndpoints.rides}/my');

      if (response is! List) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final parsed = response
          .map((item) => PostedRide.fromJson(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _allRides = parsed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching published rides: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Called by the parent screen's global refresh button.
  Future<void> refresh() async {
    await _fetchPublishedRides();
  }

  bool _canCancelRide(PostedRide ride) {
    if (ride.status.toLowerCase() != 'scheduled') {
      return false;
    }

    // Same 10-minute cutoff used by the host-side ride action rules.
    // The backend remains authoritative for booking-state validation.
    final now = DateTime.now();
    final departure = ride.departureTime.toLocal();

    return departure.difference(now) > const Duration(minutes: 10);
  }

  Future<void> _confirmCancelRide(PostedRide ride) async {
    if (!_canCancelRide(ride)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Ride?'),
          content: const Text(
            'Are you sure you want to cancel this scheduled ride?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Ride'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel Ride'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _cancelRide(ride.rideId);
    }
  }

  Future<void> _cancelRide(int rideId) async {
    try {
      await ApiClient.instance.patch(
        '${ApiEndpoints.rides}/$rideId/cancel',
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride #$rideId has been cancelled.'),
          backgroundColor: AppColors.midnightBlue,
        ),
      );
      await _fetchPublishedRides();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel ride: ${e.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling ride: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<PostedRide> _filterRides(String status) {
    return _allRides
        .where((ride) => ride.status.toLowerCase() == status)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryTealDark,
          strokeWidth: 2,
        ),
      );
    }

    return Column(
      children: [
        Material(
          color: AppColors.midnightBlue,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelPadding: EdgeInsets.zero,
            indicatorColor: AppColors.primaryTeal,
            indicatorWeight: 3,
            labelColor: AppColors.primaryTeal,
            unselectedLabelColor: AppColors.lightGray,
            labelStyle: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Active'))),
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Scheduled'))),
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Completed'))),
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Cancelled'))),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RideListSegment(
                rides: _filterRides('active'),
                emptyMessage: 'No Active Published Rides',
                emptySubtitle:
                    'You currently have no active published rides.',
                onCancel: null,
                showCancelButton: false,
              ),
              _RideListSegment(
                rides: _filterRides('scheduled'),
                emptyMessage: 'No Scheduled Published Rides',
                emptySubtitle:
                    'Future rides that you publish will appear here.',
                onCancel: _confirmCancelRide,
                showCancelButton: true,
              ),
              _RideListSegment(
                rides: _filterRides('completed'),
                emptyMessage: 'No Completed Published Rides',
                emptySubtitle:
                    'Completed rides that you published will be archived here.',
                onCancel: null,
                showCancelButton: false,
              ),
              _RideListSegment(
                rides: _filterRides('cancelled'),
                emptyMessage: 'No Cancelled Published Rides',
                emptySubtitle:
                    'Published rides that were cancelled will appear here.',
                onCancel: null,
                showCancelButton: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideListSegment extends StatelessWidget {
  final List<PostedRide> rides;
  final String emptyMessage;
  final String emptySubtitle;
  final Future<void> Function(PostedRide)? onCancel;
  final bool showCancelButton;

  const _RideListSegment({
    required this.rides,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.onCancel,
    required this.showCancelButton,
  });

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'active':
        return AppColors.primaryTealSurface;
      case 'scheduled':
        return Colors.blue.withAlpha(25);
      case 'completed':
        return AppColors.verifiedGreen.withAlpha(40);
      case 'cancelled':
        return Colors.redAccent.withAlpha(30);
      default:
        return AppColors.primaryTealSurface;
    }
  }

  bool _canCancelRide(PostedRide ride) {
    if (ride.status.toLowerCase() != 'scheduled') {
      return false;
    }

    return ride.departureTime
            .toLocal()
            .difference(DateTime.now()) >
        const Duration(minutes: 10);
  }

  Color _statusForeground(String status) {
    switch (status) {
      case 'active':
        return AppColors.primaryTealDark;
      case 'scheduled':
        return Colors.blue.shade700;
      case 'completed':
        return AppColors.verifiedGreen;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return AppColors.primaryTealDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
      return _EmptyPublishedState(
        message: emptyMessage,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = rides[index];
        final status = ride.status.toLowerCase();
        final isCancelable = showCancelButton && _canCancelRide(ride);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderGray),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBackground(status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: _statusForeground(status),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Departure: ${_formatTime(ride.departureTime)}',
                    style: AppTextStyles.label.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${ride.originName} → ${ride.destinationName}',
                style: AppTextStyles.h3.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '${ride.vehicleModel ?? "Vehicle"} '
                '(${ride.vehicleNumber ?? "Registered"}) '
                '• ₹${ride.farePerSeat.toInt()}/seat',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderGray),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.event_seat_rounded,
                    size: 16,
                    color: AppColors.midnightBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${ride.availableSeats} seats available',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.midnightBlue,
                    ),
                  ),
                  const Spacer(),
                  if (isCancelable)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => onCancel?.call(ride),
                      child: Text(
                        'Cancel Ride',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyPublishedState extends StatelessWidget {
  final String message;
  final String subtitle;

  const _EmptyPublishedState({
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryTealSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: AppColors.primaryTealDark,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.h2.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
