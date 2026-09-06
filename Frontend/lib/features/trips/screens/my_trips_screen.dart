import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/posted_ride.dart';

/// My Trips Screen with 3 Tab Segments: Active, Completed, Cancelled
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PostedRide> _allRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Default selected tab is Active (index 0) whenever opened
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _fetchMyRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyRides() async {
    try {
      final response = await ApiClient.instance.get('${ApiEndpoints.rides}/my');
      if (response is List) {
        final parsed = response
            .map((item) => PostedRide.fromJson(item as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _allRides = parsed;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching my trips: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRide(int rideId) async {
    try {
      await ApiClient.instance.patch('${ApiEndpoints.rides}/$rideId/cancel');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ride #$rideId has been cancelled.'),
          backgroundColor: AppColors.midnightBlue,
        ),
      );
      _fetchMyRides();
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
    return _allRides.where((r) => r.status.toLowerCase() == status.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.midnightBlue,
        elevation: 0,
        title: Text(
          'My Commute Trips',
          style: AppTextStyles.h2.copyWith(color: AppColors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryTeal),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchMyRides();
            },
            tooltip: 'Refresh Trips',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryTeal,
          indicatorWeight: 3,
          labelColor: AppColors.primaryTeal,
          unselectedLabelColor: AppColors.lightGray,
          labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryTealDark,
                strokeWidth: 2,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _RideListSegment(
                  rides: _filterRides('active'),
                  emptyMessage: 'No Active Trips',
                  emptySubtitle: 'You currently have no active published rides.',
                  onCancel: _cancelRide,
                  showCancelButton: true,
                ),
                _RideListSegment(
                  rides: _filterRides('completed'),
                  emptyMessage: 'No Completed Trips',
                  emptySubtitle: 'Completed rides will be archived here.',
                  onCancel: null,
                  showCancelButton: false,
                ),
                _RideListSegment(
                  rides: _filterRides('cancelled'),
                  emptyMessage: 'No Cancelled Trips',
                  emptySubtitle: 'Cancelled trips will appear in this section.',
                  onCancel: null,
                  showCancelButton: false,
                ),
              ],
            ),
    );
  }
}

class _RideListSegment extends StatelessWidget {
  final List<PostedRide> rides;
  final String emptyMessage;
  final String emptySubtitle;
  final Function(int)? onCancel;
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
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
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
                emptyMessage,
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: AppTextStyles.caption.copyWith(color: AppColors.mediumGray),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = rides[index];
        final isCancelable = showCancelButton && ride.status == 'active';

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
              // Header Row: Status Badge & Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride.status == 'active'
                          ? AppColors.primaryTealSurface
                          : (ride.status == 'completed'
                              ? AppColors.verifiedGreen.withAlpha(40)
                              : Colors.redAccent.withAlpha(30)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ride.status.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: ride.status == 'active'
                            ? AppColors.primaryTealDark
                            : (ride.status == 'completed'
                                ? AppColors.verifiedGreen
                                : Colors.redAccent),
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

              // Route details
              Text(
                '${ride.originName} -> ${ride.destinationName}',
                style: AppTextStyles.h3.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '${ride.vehicleModel ?? "Vehicle"} (${ride.vehicleNumber ?? "Registered"}) • ₹${ride.farePerSeat.toInt()}/seat',
                style: AppTextStyles.caption,
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderGray),
              const SizedBox(height: 10),

              // Footer: Seats & Action
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => onCancel?.call(ride.rideId),
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
