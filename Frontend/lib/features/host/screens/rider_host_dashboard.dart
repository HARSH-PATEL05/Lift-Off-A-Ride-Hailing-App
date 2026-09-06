import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/posted_ride.dart';
import '../../auth/screens/trust_vault_screen.dart';

/// Rider / Host Dashboard Surface (Offered Trips, Verification Vault, Fuel Stats)
class RiderHostDashboard extends StatefulWidget {
  const RiderHostDashboard({super.key});

  @override
  State<RiderHostDashboard> createState() => _RiderHostDashboardState();
}

class _RiderHostDashboardState extends State<RiderHostDashboard> {
  List<PostedRide> _myRides = [];
  bool _isLoadingRides = true;

  @override
  void initState() {
    super.initState();
    _fetchMyRides();
  }

  Future<void> _fetchMyRides() async {
    try {
      // Sync fresh profile state from backend
      AuthService.instance.getUserProfile().catchError((_) => AuthService.instance.currentProfile!);

      final response = await ApiClient.instance.get('${ApiEndpoints.rides}/my');
      if (response is List) {
        final parsed = response
            .map((item) => PostedRide.fromJson(item as Map<String, dynamic>))
            .where((r) => r.status == 'active')
            .toList();
        if (mounted) {
          setState(() {
            _myRides = parsed;
            _isLoadingRides = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingRides = false);
      }
    } catch (e) {
      debugPrint('Error fetching my rides: $e');
      if (mounted) setState(() => _isLoadingRides = false);
    }
  }

  void _openPublishModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PublishRideModal(),
    ).then((_) => _fetchMyRides());
  }

  void _openTrustVault() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrustVaultScreen()),
    ).then((_) {
      AuthService.instance.getUserProfile().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = AuthService.instance.currentProfile;
    final mockUser = MockData.currentUser;
    final displayName = profile?.fullName ?? mockUser.name;
    final avatarUrl = profile?.avatarUrl;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final aadhaarVerified = profile?.aadhaarVerified ?? false;
    final dlVerified = profile?.dlVerified ?? false;
    final rcVerified = profile?.vehicleRcVerified ?? false;
    final allVerified = aadhaarVerified && dlVerified && rcVerified;

    // Live Stats
    final fuelRecovered = profile?.fuelRecoveredInr ?? 0.0;
    final sharedCommutes = profile?.sharedCommutesCount ?? 0;
    final co2Saved = profile?.co2SavedKg ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.softGray,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 70,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              decoration: const BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryTeal,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Center(
                                    child: Text(
                                      initial,
                                      style: AppTextStyles.h2.copyWith(
                                        color: AppColors.primaryTeal,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initial,
                                    style: AppTextStyles.h2.copyWith(
                                      color: AppColors.primaryTeal,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              'Host Status • ${mockUser.rating} Stars',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Verification Vault Chips (live from backend, no emojis)
                  Wrap(
                    spacing: 6,
                    children: [
                      _VerifyPill(
                        label: aadhaarVerified ? 'Aadhaar Verified' : 'Aadhaar Pending',
                        isDone: aadhaarVerified,
                      ),
                      _VerifyPill(
                        label: dlVerified ? 'DL Validated' : 'DL Pending',
                        isDone: dlVerified,
                      ),
                      _VerifyPill(
                        label: rcVerified ? 'Vehicle RC Verified' : 'RC Pending',
                        isDone: rcVerified,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Host Quick Analytics Card (Live Fuel Recovered, Shared Commutes, CO2)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderGray),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: 'Fuel Recovered',
                      value: '₹${fuelRecovered.toInt()}',
                      icon: Icons.local_gas_station_rounded,
                      color: AppColors.midnightBlue,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderGray,
                    ),
                    _StatItem(
                      label: 'Shared Commutes',
                      value: '$sharedCommutes',
                      icon: Icons.group_rounded,
                      color: AppColors.primaryTealDark,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderGray,
                    ),
                    _StatItem(
                      label: 'CO2 Saved',
                      value: '${co2Saved.toStringAsFixed(1)} kg',
                      icon: Icons.eco_rounded,
                      color: AppColors.verifiedGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Primary CTA: Verify Documents OR Offer a Commute
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: allVerified ? AppColors.midnightBlue : AppColors.amberPoll,
                  foregroundColor: allVerified ? AppColors.primaryTeal : AppColors.midnightBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: allVerified ? _openPublishModal : _openTrustVault,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      allVerified ? Icons.add_circle_outline_rounded : Icons.verified_user_outlined,
                      color: allVerified ? AppColors.primaryTeal : AppColors.midnightBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      allVerified ? '+ Offer / Publish a Ride Route' : 'Verify All Documents to Offer Rides',
                      style: AppTextStyles.buttonDark.copyWith(
                        color: allVerified ? AppColors.primaryTeal : AppColors.midnightBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active Published Trips Section (Live Backend Data)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your Published Commutes',
                        style: AppTextStyles.h3,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.midnightBlue),
                        onPressed: _fetchMyRides,
                        tooltip: 'Refresh My Rides',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_isLoadingRides)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryTealDark,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (_myRides.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.directions_car_outlined,
                              size: 36,
                              color: AppColors.mediumGray,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No Active Published Commutes',
                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap the button above to post your first commute route.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.mediumGray),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _myRides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ride = _myRides[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderGray),
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
                                      color: AppColors.primaryTealSurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primaryTealDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Departs: ${_formatTime(ride.departureTime)}',
                                    style: AppTextStyles.label.copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
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
                              Row(
                                children: [
                                  const Icon(
                                    Icons.people_rounded,
                                    size: 16,
                                    color: AppColors.primaryTealDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${ride.availableSeats} seats remaining',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.midnightBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _VerifyPill extends StatelessWidget {
  final String label;
  final bool isDone;

  const _VerifyPill({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? AppColors.verifiedGreen.withAlpha(40) : AppColors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? AppColors.verifiedGreen : AppColors.primaryTeal.withAlpha(80),
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }
}

/// Modal Wizard for Hosts to Publish a Commute Route
class _PublishRideModal extends StatefulWidget {
  const _PublishRideModal();

  @override
  State<_PublishRideModal> createState() => _PublishRideModalState();
}

class _PublishRideModalState extends State<_PublishRideModal> {
  int _seats = 3;
  double _fare = 140;
  bool _womenOnly = false;
  bool _strictConsent = true;
  bool _isPublishing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Publish Your Commute Route',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 4),
          Text(
            'Recover fuel costs by sharing your empty seats.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),

          // Route Nodes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.softGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.trip_origin_rounded,
                      size: 16,
                      color: AppColors.primaryTealDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Origin: Connaught Place, New Delhi',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: AppColors.midnightBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Destination: DLF Cyber City, Gurgaon',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Seats Selector
          Row(
            children: [
              Text('Available Empty Seats:', style: AppTextStyles.bodyLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: () {
                  if (_seats > 1) setState(() => _seats--);
                },
              ),
              Text(
                '$_seats',
                style: AppTextStyles.h2.copyWith(fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: () {
                  if (_seats < 6) setState(() => _seats++);
                },
              ),
            ],
          ),

          // Recommended Fuel Share Slider
          Row(
            children: [
              Text(
                'Fuel Recovery: ₹${_fare.toInt()} / seat',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Rec. ₹120–₹160',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryTealDark,
                ),
              ),
            ],
          ),
          Slider(
            value: _fare,
            min: 80,
            max: 250,
            divisions: 17,
            activeColor: AppColors.primaryTealDark,
            onChanged: (val) => setState(() => _fare = val),
          ),

          // Policy Toggles (No Emojis)
          SwitchListTile(
            title: Text(
              'Women-Only Commute',
              style: AppTextStyles.label,
            ),
            subtitle: Text(
              'Restrict seat requests to verified female commuters',
              style: AppTextStyles.caption,
            ),
            value: _womenOnly,
            activeThumbColor: AppColors.womenOnlyPink,
            onChanged: (v) => setState(() => _womenOnly = v),
          ),

          SwitchListTile(
            title: Text(
              'Democratic Passenger Consent',
              style: AppTextStyles.label,
            ),
            subtitle: Text(
              'Allow existing passengers to vote on subsequent joiners',
              style: AppTextStyles.caption,
            ),
            value: _strictConsent,
            activeThumbColor: AppColors.primaryTealDark,
            onChanged: (v) => setState(() => _strictConsent = v),
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: AppColors.midnightBlue,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isPublishing
                ? null
                : () async {
                    setState(() => _isPublishing = true);

                    final navContext = context;
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    try {
                      final departure = DateTime.now()
                          .add(const Duration(hours: 2))
                          .toUtc()
                          .toIso8601String();

                      final response = await ApiClient.instance.post(
                        ApiEndpoints.rides,
                        body: {
                          'origin_name': 'Connaught Place, New Delhi',
                          'origin_lat': 28.6315,
                          'origin_lng': 77.2167,
                          'destination_name': 'DLF Cyber City, Gurgaon',
                          'destination_lat': 28.4595,
                          'destination_lng': 77.0266,
                          'departure_time': departure,
                          'available_seats': _seats,
                          'fare_per_seat': _fare,
                          'vehicle_model': 'Honda City',
                          'vehicle_number': 'DL 3C XX 1234',
                          'is_women_only': _womenOnly,
                          'democratic_consent': _strictConsent,
                        },
                      );

                      if (!mounted) return;
                      Navigator.pop(navContext);

                      final rideId = (response as Map<String, dynamic>)['ride_id'];

                      // Also refresh user profile to update live host stats
                      AuthService.instance.getUserProfile();

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Commute #$rideId published to LiftOff Network!'),
                          backgroundColor: AppColors.midnightBlue,
                        ),
                      );
                    } on ApiException catch (e) {
                      if (!mounted) return;
                      setState(() => _isPublishing = false);

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to publish: ${e.message}'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _isPublishing = false);

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error publishing ride: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
            child: _isPublishing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.midnightBlue,
                    ),
                  )
                : Text(
                    'Publish Commute Route',
                    style: AppTextStyles.buttonPrimary.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
