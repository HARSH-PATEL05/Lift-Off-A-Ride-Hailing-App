import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/posted_ride.dart';

/// Horizontal & vertical feed of Matching Community Shared Rides (Hosts)
class ServiceSelector extends StatefulWidget {
  final String selectedServiceId;
  final ValueChanged<String> onServiceSelected;
  final VoidCallback onBook;

  const ServiceSelector({
    super.key,
    required this.selectedServiceId,
    required this.onServiceSelected,
    required this.onBook,
  });

  @override
  State<ServiceSelector> createState() => _ServiceSelectorState();
}

class _ServiceSelectorState extends State<ServiceSelector> {
  List<CommunityRide> _liveRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveRides();
  }

  Future<void> _fetchLiveRides() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.rides);
      if (response is List) {
        final parsed = response
            .map((item) => PostedRide.fromJson(item as Map<String, dynamic>).toCommunityRide())
            .toList();
        if (mounted) {
          setState(() {
            _liveRides = parsed;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching live rides: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine live backend rides + mock data fallback
    final allRides = [..._liveRides, ...MockData.communityRides];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Departing Community Rides',
                style: AppTextStyles.h3.copyWith(fontSize: 15),
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
                    '${allRides.length} matching',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryTealDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.midnightBlue),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchLiveRides();
              },
              tooltip: 'Refresh Rides',
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoading && _liveRides.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryTealDark,
                strokeWidth: 2,
              ),
            ),
          )
        else
          // List of Community Ride Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allRides.length,
            separatorBuilder: (_, a) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ride = allRides[index];
              final isSelected = ride.id == widget.selectedServiceId;
              return _CommunityRideCard(
                ride: ride,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onServiceSelected(ride.id);
                  widget.onBook();
                },
              );
            },
          ),
      ],
    );
  }
}


class _CommunityRideCard extends StatelessWidget {
  final CommunityRide ride;
  final bool isSelected;
  final VoidCallback onTap;

  const _CommunityRideCard({
    required this.ride,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryTeal : AppColors.borderGray,
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.tealGlow : AppColors.shadowLight,
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Host Avatar, Name, Verification Badge & Match %
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Host Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.navyGradient,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ride.isWomenOnly
                          ? AppColors.womenOnlyPink
                          : AppColors.primaryTeal,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      ride.host.name[0],
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Host details & trust
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ride.host.name,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.verifiedGreen,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.amberPoll,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ride.host.rating.toString(),
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.midnightBlue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${ride.host.sharedTripsCount} shared trips',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Match Percentage Badge (Glowing Teal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryTeal.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${ride.routeMatchPercentage}%',
                        style: AppTextStyles.matchBadge.copyWith(fontSize: 14),
                      ),
                      Text(
                        'Route Match',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderGray),
            const SizedBox(height: 10),

            // Middle Section: Vehicle Model, Departure Time, Meeting Node Distance
            Row(
              children: [
                const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 15,
                  color: AppColors.mediumGray,
                ),
                const SizedBox(width: 5),
                Text(
                  ride.vehicleModel,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.midnightBlue,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.access_time_filled_rounded,
                  size: 15,
                  color: AppColors.primaryTealDark,
                ),
                const SizedBox(width: 4),
                Text(
                  ride.departureTime,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.midnightBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Safe Meeting Node Info Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.softGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    size: 13,
                    color: AppColors.primaryTealDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pickup: ${ride.meetingNodeName} (${ride.meetingNodeDistance})',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.midnightBlue,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Bottom Row: Fuel Split Price + Seats Left Badge + Action indicator
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${ride.fuelSharePerSeat.toInt()}',
                          style: AppTextStyles.fareAmount,
                        ),
                        Text(
                          ' / seat',
                          style: AppTextStyles.fareUnit,
                        ),
                      ],
                    ),
                    Text(
                      'Fuel expense share',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Available Seats Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.midnightBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.airline_seat_recline_normal_rounded,
                        color: AppColors.primaryTeal,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${ride.availableSeats} seats left',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
