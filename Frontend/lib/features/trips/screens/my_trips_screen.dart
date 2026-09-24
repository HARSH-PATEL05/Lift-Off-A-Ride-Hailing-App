import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/booked_rides_module.dart';
import '../widgets/published_rides_module.dart';

/// Parent screen for the user's commute trips.
///
/// The page is split into two independent child modules:
/// - Published Rides: rides created by the current user.
/// - Booked Rides: rides booked/joined by the current user.
class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final GlobalKey<PublishedRidesModuleState> _publishedRidesKey =
      GlobalKey<PublishedRidesModuleState>();
  final GlobalKey<BookedRidesModuleState> _bookedRidesKey =
      GlobalKey<BookedRidesModuleState>();

  bool _isRefreshing = false;

  Future<void> _refreshEverything() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await Future.wait([
        _publishedRidesKey.currentState?.refresh() ?? Future<void>.value(),
        _bookedRidesKey.currentState?.refresh() ?? Future<void>.value(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
              tooltip: 'Refresh all trips',
              onPressed: _isRefreshing ? null : _refreshEverything,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryTeal,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.white,
                    ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primaryTeal,
            indicatorWeight: 3,
            labelColor: AppColors.primaryTeal,
            unselectedLabelColor: AppColors.lightGray,
            labelStyle: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(text: 'Published Rides'),
              Tab(text: 'Booked Rides'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PublishedRidesModule(key: _publishedRidesKey),
            BookedRidesModule(key: _bookedRidesKey),
          ],
        ),
      ),
    );
  }
}
