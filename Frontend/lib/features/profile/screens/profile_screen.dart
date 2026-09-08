import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthService.instance.currentProfile;

    final avatarUrl = profile?.avatarUrl;

    final name = profile?.fullName ??
        profile?.email ??
        MockData.currentUser.name;

    final email = profile?.email ?? '';

    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final isAadhaarVerified =
        profile?.aadhaarVerified ?? false;

    final isDlVerified =
        profile?.dlVerified ?? false;

    final isRcVerified =
        profile?.vehicleRcVerified ?? false;

    final rides =
        profile?.sharedCommutesCount ?? 0;

    final fuelRecovered =
        profile?.fuelRecoveredInr ?? 0.0;

    final co2Saved =
        profile?.co2SavedKg ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Text(
          'My Profile',
          style: AppTextStyles.h3.copyWith(
            color: AppColors.midnightBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // =====================================================
            // PROFILE HEADER
            // =====================================================

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),

              child: Column(
                children: [

                  // =================================================
                  // AVATAR
                  // =================================================

                  Stack(
                    children: [

                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient:
                              AppColors.navyGradient,
                          shape: BoxShape.circle,
                        ),

                        child: ClipOval(
                          child:
                              avatarUrl != null &&
                                      avatarUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          avatarUrl,

                                      width: 96,
                                      height: 96,

                                      fit:
                                          BoxFit.cover,

                                      fadeInDuration:
                                          const Duration(
                                        milliseconds:
                                            150,
                                      ),

                                      placeholder: (
                                        context,
                                        url,
                                      ) {
                                        return Center(
                                          child: Text(
                                            initial,
                                            style:
                                                AppTextStyles.h1.copyWith(
                                              color:
                                                  AppColors.primaryTeal,
                                              fontWeight:
                                                  FontWeight.w800,
                                                  fontSize: 42,
                                            ),
                                          ),
                                        );
                                      },

                                      errorWidget: (
                                        context,
                                        url,
                                        error,
                                      ) {
                                        return Center(
                                          child: Text(
                                            initial,
                                            style:
                                                AppTextStyles.h1.copyWith(
                                              color:
                                                  AppColors.primaryTeal,
                                              fontWeight:
                                                  FontWeight.w800,
                                                  fontSize: 42,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                        initial,
                                        style:
                                            AppTextStyles.h1.copyWith(
                                          color:
                                              AppColors.primaryTeal,
                                          fontWeight:
                                              FontWeight.w800,
                                              fontSize: 42,
                                        ),
                                      ),
                                    ),
                        ),
                      ),

                      // VERIFIED BADGE

                      if (isAadhaarVerified)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding:
                                const EdgeInsets.all(
                              4,
                            ),
                            decoration:
                                const BoxDecoration(
                              color:
                                  AppColors.white,
                              shape:
                                  BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons
                                  .check_circle_rounded,
                              color:
                                  AppColors
                                      .verifiedGreen,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    name,
                    style:
                        AppTextStyles.h2.copyWith(
                      color:
                          AppColors.midnightBlue,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    email,
                    style:
                        AppTextStyles.body.copyWith(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ACCOUNT STATUS

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isAadhaarVerified
                              ? AppColors
                                  .primaryTealSurface
                              : Colors.orange
                                  .withValues(
                                  alpha: 0.12,
                                ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),

                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [

                        Icon(
                          isAadhaarVerified
                              ? Icons
                                  .verified_rounded
                              : Icons
                                  .pending_rounded,
                          size: 16,
                          color:
                              isAadhaarVerified
                                  ? AppColors
                                      .verifiedGreen
                                  : Colors.orange,
                        ),

                        const SizedBox(width: 6),

                        Text(
                          isAadhaarVerified
                              ? 'Verified Account'
                              : 'Verification Pending',
                          style:
                              AppTextStyles.caption.copyWith(
                            fontWeight:
                                FontWeight.w700,
                            color:
                                isAadhaarVerified
                                    ? AppColors
                                        .primaryTealDark
                                    : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // =====================================================
            // ACCOUNT
            // =====================================================

            _buildSectionTitle(
              'Account',
            ),

            _ProfileCard(
              children: [

                _ProfileTile(
                  icon:
                      Icons.person_outline_rounded,
                  title:
                      'Personal Information',
                  subtitle:
                      'Name and account details',
                  onTap: () {},
                ),

                _ProfileDivider(),

                _ProfileTile(
                  icon:
                      Icons.email_outlined,
                  title:
                      'Email',
                  subtitle:
                      email.isNotEmpty
                          ? email
                          : 'No email available',
                  onTap: () {},
                ),

                _ProfileDivider(),

                _ProfileTile(
                  icon:
                      Icons.lock_outline_rounded,
                  title:
                      'Security',
                  subtitle:
                      'Password and account security',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =====================================================
            // VERIFICATION
            // =====================================================

            _buildSectionTitle(
              'Verification',
            ),

            _ProfileCard(
              children: [

                _VerificationTile(
                  icon:
                      Icons.badge_outlined,
                  title:
                      'Aadhaar Verification',
                  verified:
                      isAadhaarVerified,
                  subtitle:
                      profile?.maskedAadhaar ??
                          'Identity verification',
                ),

                _ProfileDivider(),

                _VerificationTile(
                  icon:
                      Icons.credit_card_outlined,
                  title:
                      'Driving Licence',
                  verified:
                      isDlVerified,
                  subtitle:
                      'Driving licence verification',
                ),

                _ProfileDivider(),

                _VerificationTile(
                  icon:
                      Icons.directions_car_outlined,
                  title:
                      'Vehicle RC',
                  verified:
                      isRcVerified,
                  subtitle:
                      'Vehicle registration verification',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =====================================================
            // YOUR ACTIVITY
            // =====================================================

            _buildSectionTitle(
              'Your Activity',
            ),

            Row(
              children: [

                Expanded(
                  child: _StatCard(
                    icon:
                        Icons.route_rounded,
                    value:
                        rides.toString(),
                    label:
                        'Shared Rides',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _StatCard(
                    icon:
                        Icons
                            .currency_rupee_rounded,
                    value:
                        fuelRecovered
                            .toStringAsFixed(0),
                    label:
                        'Fuel Recovered',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _StatCard(
              icon:
                  Icons.eco_rounded,
              value:
                  '${co2Saved.toStringAsFixed(1)} kg',
              label:
                  'CO₂ Saved',
              fullWidth:
                  true,
            ),

            const SizedBox(height: 20),

            // =====================================================
            // SETTINGS
            // =====================================================

            _buildSectionTitle(
              'Settings',
            ),

            _ProfileCard(
              children: [

                _ProfileTile(
                  icon:
                      Icons
                          .notifications_none_rounded,
                  title:
                      'Notifications',
                  subtitle:
                      'Manage notification preferences',
                  onTap: () {},
                ),

                _ProfileDivider(),

                _ProfileTile(
                  icon:
                      Icons.help_outline_rounded,
                  title:
                      'Help & Support',
                  subtitle:
                      'Get help with LiftOff',
                  onTap: () {},
                ),

                _ProfileDivider(),

                _ProfileTile(
                  icon:
                      Icons.info_outline_rounded,
                  title:
                      'About LiftOff',
                  subtitle:
                      'App information',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =====================================================
            // LOGOUT
            // =====================================================

            OutlinedButton.icon(
              onPressed: () async {
                // Connect AuthService logout here.
              },

              icon: const Icon(
                Icons.logout_rounded,
              ),

              label: const Text(
                'Log Out',
              ),

              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.red,
                side:
                    const BorderSide(
                  color:
                      Colors.red,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // SECTION TITLE
  // =============================================================

  Widget _buildSectionTitle(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        left: 4,
        bottom: 10,
      ),
      child: Text(
        title,
        style:
            AppTextStyles.label.copyWith(
          color:
              AppColors.midnightBlue,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }
}


// ===============================================================
// PROFILE CARD
// ===============================================================

class _ProfileCard extends StatelessWidget {
  final List<Widget> children;

  const _ProfileCard({
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          AppColors.white,

      elevation:
          3,

      shadowColor:
          AppColors.shadowLight,

      borderRadius:
          BorderRadius.circular(
        20,
      ),

      clipBehavior:
          Clip.antiAlias,

      child: Column(
        children:
            children,
      ),
    );
  }
}


// ===============================================================
// PROFILE TILE
// ===============================================================

class _ProfileTile extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      onTap:
          onTap,

      leading: Container(
        width:
            42,

        height:
            42,

        decoration:
            BoxDecoration(
          color:
              AppColors
                  .primaryTealSurface,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),

        child: Icon(
          icon,
          color:
              AppColors
                  .primaryTealDark,
        ),
      ),

      title: Text(
        title,
        style:
            AppTextStyles.label.copyWith(
          fontWeight:
              FontWeight.w700,
        ),
      ),

      subtitle: Text(
        subtitle,
        maxLines:
            1,
        overflow:
            TextOverflow.ellipsis,
      ),

      trailing:
          const Icon(
        Icons.chevron_right_rounded,
      ),
    );
  }
}


// ===============================================================
// VERIFICATION TILE
// ===============================================================

class _VerificationTile
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final bool verified;

  const _VerificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.verified,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      leading:
          Container(
        width:
            42,

        height:
            42,

        decoration:
            BoxDecoration(
          color:
              verified
                  ? AppColors
                      .primaryTealSurface
                  : Colors.grey
                      .withValues(
                      alpha: 0.10,
                    ),

          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),

        child:
            Icon(
          icon,
          color:
              verified
                  ? AppColors
                      .primaryTealDark
                  : Colors.grey,
        ),
      ),

      title:
          Text(
        title,
        style:
            AppTextStyles.label.copyWith(
          fontWeight:
              FontWeight.w700,
        ),
      ),

      subtitle:
          Text(
        subtitle,
      ),

      trailing:
          Icon(
        verified
            ? Icons.verified_rounded
            : Icons.pending_outlined,

        color:
            verified
                ? AppColors
                    .verifiedGreen
                : Colors.orange,
      ),
    );
  }
}


// ===============================================================
// DIVIDER
// ===============================================================

class _ProfileDivider
    extends StatelessWidget {
  @override
  Widget build(
    BuildContext context,
  ) {
    return Divider(
      height:
          1,

      indent:
          72,

      color:
          AppColors.borderGray,
    );
  }
}


// ===============================================================
// STAT CARD
// ===============================================================

class _StatCard
    extends StatelessWidget {
  final IconData icon;

  final String value;

  final String label;

  final bool fullWidth;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.fullWidth = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          fullWidth
              ? double.infinity
              : null,

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        boxShadow:
            const [
          BoxShadow(
            color:
                AppColors.shadowLight,
            blurRadius:
                10,
            offset:
                Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          Icon(
            icon,
            color:
                AppColors
                    .primaryTealDark,
          ),

          const SizedBox(
            width:
                10,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Text(
                value,
                style:
                    AppTextStyles.h3.copyWith(
                  fontWeight:
                      FontWeight.w800,
                  color:
                      AppColors
                          .midnightBlue,
                ),
              ),

              Text(
                label,
                style:
                    AppTextStyles.caption.copyWith(
                  color:
                      AppColors
                          .textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}