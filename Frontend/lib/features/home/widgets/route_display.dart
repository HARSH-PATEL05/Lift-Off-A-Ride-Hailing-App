import 'package:flutter/material.dart';

import '../../../core/data/mock_data.dart';
import 'community_ride_card.dart';

/// Displays rides returned by ServiceSelector.
///
/// This widget intentionally contains no API calls, filtering logic, or route
/// matching. It is only responsible for turning the returned rides into the
/// existing CommunityRideCard presentation and opening the ride details page.
class RouteDisplay extends StatelessWidget {
  final List<CommunityRide> rides;
  final String selectedRideId;
  final ValueChanged<CommunityRide> onViewDetails;

  const RouteDisplay({
    super.key,
    required this.rides,
    required this.selectedRideId,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E6EA)),
        ),
        child: const Column(
          children: [
            Icon(Icons.alt_route_rounded, size: 32, color: Color(0xFF7A8794)),
            SizedBox(height: 8),
            Text(
              'No matching rides found',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Try changing your filters or route.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A8794)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = rides[index];
        return CommunityRideCard(
          ride: ride,
          isSelected: ride.id == selectedRideId,
          onTap: () => onViewDetails(ride),
        );
      },
    );
  }
}
