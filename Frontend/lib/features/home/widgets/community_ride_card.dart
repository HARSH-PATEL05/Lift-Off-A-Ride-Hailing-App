import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';

/// Presentation-only card for a single community ride.
///
/// This widget does not fetch rides, perform route matching, apply filters,
/// or book a ride. Those responsibilities remain outside the card.
class CommunityRideCard extends StatelessWidget {
  final CommunityRide ride;
  final bool isSelected;
  final VoidCallback onTap;

  const CommunityRideCard({
    required this.ride,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
                          if (ride.isWomenOnly) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.female_rounded,
                              color: AppColors.womenOnlyPink,
                              size: 15,
                            ),
                          ],
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

                // Match Percentage Badge
                // The percentage is supplied by the ride/matching layer.
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

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.midnightBlue,
                  side: BorderSide(
                    color: AppColors.primaryTeal.withAlpha(130),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
