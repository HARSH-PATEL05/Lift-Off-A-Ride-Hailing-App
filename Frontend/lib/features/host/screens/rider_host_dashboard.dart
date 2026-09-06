import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';

/// Rider / Host Dashboard Surface (Offered Trips, Verification Vault, Fuel Stats)
class RiderHostDashboard extends StatefulWidget {
  const RiderHostDashboard({super.key});

  @override
  State<RiderHostDashboard> createState() => _RiderHostDashboardState();
}

class _RiderHostDashboardState extends State<RiderHostDashboard> {
  void _openPublishModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PublishRideModal(),
    );
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
                              'Host Status • ${mockUser.rating} ★',
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

                  // Verification Vault Chips (live from backend)
                  Wrap(
                    spacing: 6,
                    children: [
                      _VerifyPill(
                        label: aadhaarVerified ? 'Aadhaar ✅' : 'Aadhaar ⏳',
                        isDone: aadhaarVerified,
                      ),
                      _VerifyPill(
                        label: dlVerified ? 'DL Validated ✅' : 'DL ⏳',
                        isDone: dlVerified,
                      ),
                      _VerifyPill(
                        label: rcVerified ? 'Vehicle RC ✅' : 'RC ⏳',
                        isDone: rcVerified,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Host Quick Analytics Card (Fuel Recovered, CO2, Trips)
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
                      value: '₹4,200',
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
                      value: '${mockUser.sharedTripsCount}',
                      icon: Icons.group_rounded,
                      color: AppColors.primaryTealDark,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: AppColors.borderGray,
                    ),
                    _StatItem(
                      label: 'CO₂ Saved',
                      value: '${mockUser.co2SavedKg} kg 🌿',
                      icon: Icons.eco_rounded,
                      color: AppColors.verifiedGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Primary CTA: Offer / Post a Commute
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightBlue,
                  foregroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _openPublishModal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primaryTeal,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+ Offer / Publish a Ride Route',
                      style: AppTextStyles.buttonDark.copyWith(
                        color: AppColors.primaryTeal,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active Published Trips Section
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Published Commutes',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  Container(
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
                                'ACTIVE TODAY',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryTealDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Departure: 6:00 PM',
                              style: AppTextStyles.label.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Connaught Place ➔ DLF Cyber City',
                          style: AppTextStyles.h3.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Honda City (DL 3C XX 1234) • ₹140/seat',
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
                              '2 / 3 Seats Booked (1 seat remaining)',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.midnightBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        color: AppColors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryTeal.withAlpha(80)),
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
            'Publish Your Commute Route 🚘',
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

          // Policy Toggles
          SwitchListTile(
            title: Text(
              'Women-Only Commute 👩',
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
              'Democratic Passenger Consent 🗳️',
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Commute published to LiftOff Network 🚀'),
                  backgroundColor: AppColors.midnightBlue,
                ),
              );
            },
            child: Text(
              'Publish Commute Route 🚀',
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
