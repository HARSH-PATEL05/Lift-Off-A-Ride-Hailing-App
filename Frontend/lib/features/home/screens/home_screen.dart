import 'package:flutter/material.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/map_view.dart';
import '../widgets/booking_bottom_sheet.dart';
import '../../ride/widgets/live_ride_drawer.dart';
import '../../host/screens/rider_host_dashboard.dart';
import '../../../core/data/mock_data.dart';

/// LiftOff Main Home Screen with Dual-Surface Architecture (Traveller Mode ↔ Rider/Host Mode)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRiderMode = false;
  String _selectedServiceId = MockData.communityRides.first.id;
  bool _showRideStatus = false;

  void _onModeChanged(bool isRider) {
    setState(() => _isRiderMode = isRider);
  }

  void _onServiceSelected(String serviceId) {
    setState(() => _selectedServiceId = serviceId);
  }

  void _onBook() {
    setState(() => _showRideStatus = true);
  }

  void _onCloseRideStatus() {
    setState(() => _showRideStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ─── Traveller Mode Surface ───
          if (!_isRiderMode) ...[
            // Layer 1: Interactive Map & Corridor
            const Positioned.fill(
              child: MapView(),
            ),

            // Layer 2: Booking Bottom Sheet (When not in active ride)
            if (!_showRideStatus)
              BookingBottomSheet(
                selectedServiceId: _selectedServiceId,
                onServiceSelected: _onServiceSelected,
                onBook: _onBook,
              ),

            // Layer 3: Active Ride & 120s Democratic Polling Drawer
            if (_showRideStatus)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LiveRideDrawer(
                  onClose: _onCloseRideStatus,
                ),
              ),
          ],

          // ─── Rider / Host Mode Surface ───
          if (_isRiderMode)
            const Positioned.fill(
              child: RiderHostDashboard(),
            ),

          // Floating Top Bar with Mode Switcher & Safe Meeting Node (Always accessible on top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(
              isRiderMode: _isRiderMode,
              onModeChanged: _onModeChanged,
            ),
          ),
        ],
      ),
    );
  }
}
