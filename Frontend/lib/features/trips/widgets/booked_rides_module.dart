import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Frontend module for rides booked/joined by the current user.
///
/// Real booking API integration will be added later when the booking/matching
/// flow is ready.
class BookedRidesModule extends StatefulWidget {
  const BookedRidesModule({super.key});

  @override
  State<BookedRidesModule> createState() => BookedRidesModuleState();
}

class BookedRidesModuleState extends State<BookedRidesModule>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );
  }

  /// Parent refresh hook.
  ///
  /// The real booking API will be connected here when
  /// booking/matching is implemented.
  Future<void> refresh() async {
    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppColors.midnightBlue,
          child: TabBar(
            controller: _tabController,

            // IMPORTANT:
            // Keep the four tabs distributed across the complete width.
            isScrollable: false,

            // Remove Flutter's default horizontal label padding so
            // the four tabs get equal usable space.
            labelPadding: EdgeInsets.zero,

            indicatorColor: AppColors.primaryTeal,
            indicatorWeight: 3,

            labelColor: AppColors.primaryTeal,
            unselectedLabelColor: AppColors.lightGray,

            labelStyle: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
            ),

            tabs: const [
              Tab(
                text: 'Booked',
              ),
              Tab(
                text: 'Active',
              ),
              Tab(
                text: 'Completed',
              ),
              Tab(
                text: 'Cancelled',
              ),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _EmptyState(
                title: 'No Booked Rides',
                subtitle:
                    'Rides you book or join will appear here.',
              ),

              _EmptyState(
                title: 'No Active Booked Rides',
                subtitle:
                    'Your currently travelling booked rides will appear here.',
              ),

              _EmptyState(
                title: 'No Completed Booked Rides',
                subtitle:
                    'Your completed booked rides will be archived here.',
              ),

              _EmptyState(
                title: 'No Cancelled Booked Rides',
                subtitle:
                    'Cancelled bookings will appear here.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.title,
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
                Icons.directions_car_filled_rounded,
                color: AppColors.primaryTealDark,
                size: 36,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              title,
              style: AppTextStyles.h2.copyWith(
                fontSize: 18,
              ),
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