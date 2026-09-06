import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';

/// Trust Vault & Profile Screen
/// Displays authenticated user profile, avatar, email, and DigiLocker/Government verification badges.
class TrustVaultScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const TrustVaultScreen({
    super.key,
    this.userProfile,
  });

  @override
  State<TrustVaultScreen> createState() => _TrustVaultScreenState();
}

class _TrustVaultScreenState extends State<TrustVaultScreen> {
  late UserProfile? _profile;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.userProfile ?? AuthService.instance.currentProfile;
  }

  Future<void> _refreshProfile() async {
    setState(() => _isRefreshing = true);
    try {
      final updatedProfile = await AuthService.instance.syncWithBackend();
      if (mounted) {
        setState(() {
          _profile = updatedProfile;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile synced with backend successfully'),
            backgroundColor: AppColors.verifiedGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? AuthService.instance.currentProfile;
    final displayName = profile?.fullName ?? profile?.email.split('@').first ?? 'Commuter';
    final email = profile?.email ?? 'Not signed in';
    final avatarUrl = profile?.avatarUrl;
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Verification Vault & Profile',
          style: AppTextStyles.h3.copyWith(color: AppColors.midnightBlue),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryTealDark,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.midnightBlue),
            tooltip: 'Sync Profile',
            onPressed: _isRefreshing ? null : _refreshProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── USER PROFILE HEADER CARD ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowMedium,
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar with border
                  Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.midnightBlue,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => _buildAvatarFallback(initialLetter),
                            )
                          : _buildAvatarFallback(initialLetter),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display Name
                  Text(
                    displayName,
                    style: AppTextStyles.h2.copyWith(color: AppColors.white),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 4),

                  // Email
                  Text(
                    email,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.white.withAlpha(200)),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Trust Status Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: profile?.aadhaarVerified == true
                          ? AppColors.verifiedGreen.withAlpha(50)
                          : AppColors.amberPoll.withAlpha(50),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: profile?.aadhaarVerified == true
                            ? AppColors.verifiedGreen
                            : AppColors.amberPoll,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          profile?.aadhaarVerified == true
                              ? Icons.verified_user_rounded
                              : Icons.gpp_maybe_rounded,
                          size: 16,
                          color: profile?.aadhaarVerified == true
                              ? AppColors.verifiedGreen
                              : AppColors.amberPoll,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          profile?.aadhaarVerified == true
                              ? 'Verified Trust Commuter'
                              : 'Pending Verification',
                          style: AppTextStyles.caption.copyWith(
                            color: profile?.aadhaarVerified == true
                                ? AppColors.verifiedGreen
                                : AppColors.amberPoll,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── VERIFICATION STATUS CARDS ───
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Trust & Identity Vault',
                style: AppTextStyles.h3.copyWith(color: AppColors.midnightBlue),
              ),
            ),
            const SizedBox(height: 12),

            // 1. Aadhaar Card
            _buildDocTile(
              icon: Icons.fingerprint_rounded,
              title: 'DigiLocker Aadhaar',
              subtitle: profile?.maskedAadhaar ?? 'National identity verification',
              isVerified: profile?.aadhaarVerified ?? false,
            ),

            const SizedBox(height: 12),

            // 2. Driving Licence Card
            _buildDocTile(
              icon: Icons.badge_rounded,
              title: 'Driving License',
              subtitle: 'Required for Host / Rider mode',
              isVerified: profile?.dlVerified ?? false,
            ),

            const SizedBox(height: 12),

            // 3. Vehicle RC Card
            _buildDocTile(
              icon: Icons.directions_car_rounded,
              title: 'Vehicle Registration (RC)',
              subtitle: 'Required for offering community rides',
              isVerified: profile?.vehicleRcVerified ?? false,
            ),

            const SizedBox(height: 32),

            // ─── SIGN OUT BUTTON ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.instance.signOut();
                },
                icon: const Icon(Icons.logout_rounded, color: AppColors.errorRed),
                label: Text(
                  'Sign Out',
                  style: AppTextStyles.buttonPrimary.copyWith(color: AppColors.errorRed),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.errorRed, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String letter) {
    return Container(
      color: AppColors.midnightBlue,
      child: Center(
        child: Text(
          letter,
          style: AppTextStyles.display.copyWith(
            color: AppColors.primaryTeal,
            fontSize: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildDocTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isVerified
                  ? AppColors.primaryTealSurface
                  : AppColors.softGray,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isVerified
                  ? AppColors.primaryTealDark
                  : AppColors.mediumGray,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: AppColors.mediumGray),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isVerified
                  ? AppColors.verifiedGreen.withAlpha(30)
                  : AppColors.mediumGray.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
                  size: 14,
                  color: isVerified ? AppColors.verifiedGreen : AppColors.mediumGray,
                ),
                const SizedBox(width: 4),
                Text(
                  isVerified ? 'Verified' : 'Pending',
                  style: AppTextStyles.caption.copyWith(
                    color: isVerified ? AppColors.verifiedGreen : AppColors.mediumGray,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
