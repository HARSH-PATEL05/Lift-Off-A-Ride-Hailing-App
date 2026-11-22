import 'package:flutter/material.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Frontend-only ride details page.
///
/// Booking behavior is intentionally not implemented yet. The bottom button
/// is the reserved entry point for the booking flow that will be discussed
/// and implemented separately.
class RideDetailsScreen extends StatelessWidget {
  final CommunityRide ride;

  const RideDetailsScreen({
    super.key,
    required this.ride,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.midnightBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                title: 'Host',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.midnightBlue,
                      child: Text(
                        ride.host.name.isEmpty ? '?' : ride.host.name[0],
                        style: AppTextStyles.h3.copyWith(color: AppColors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ride.host.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            '★ ${ride.host.rating}  •  ${ride.host.sharedTripsCount} shared trips',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_rounded, color: AppColors.verifiedGreen),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                title: 'Route Match',
                child: Row(
                  children: [
                    Text(
                      '${ride.routeMatchPercentage}%',
                      style: AppTextStyles.h2.copyWith(color: AppColors.primaryTealDark),
                    ),
                    const SizedBox(width: 10),
                    const Text('matched with your route'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                title: 'Ride Information',
                child: Column(
                  children: [
                    _infoRow(Icons.directions_car_filled_rounded, 'Vehicle', ride.vehicleModel),
                    _infoRow(Icons.access_time_filled_rounded, 'Departure', ride.departureTime),
                    _infoRow(Icons.near_me_rounded, 'Pickup', '${ride.meetingNodeName} (${ride.meetingNodeDistance})'),
                    _infoRow(Icons.airline_seat_recline_normal_rounded, 'Seats', '${ride.availableSeats} available'),
                    _infoRow(Icons.currency_rupee_rounded, 'Fuel share', '₹${ride.fuelSharePerSeat.toInt()} / seat'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                title: 'Ride Preferences',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(ride.isWomenOnly ? 'Women-only' : 'Open ride'),
                    _tag('Consent preference: ${ride.isWomenOnly ? 'Women-only' : 'Standard'}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking flow will be implemented next.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.midnightBlue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Book Ride',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3.copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primaryTealDark),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.caption),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryTealSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primaryTealDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
