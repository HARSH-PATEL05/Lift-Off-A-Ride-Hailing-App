import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/vehicle_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/screens/trust_vault_screen.dart';
import '../../auth/screens/vehicle_rc_verification_screen.dart';
import '../widgets/activity_widget.dart';
import '../widgets/personal_information_widget.dart';
import '../widgets/verification_widget.dart';
import '../widgets/notification_page.dart';
import '../widgets/support_page.dart';

/// LiftOff — Profile Screen
///
/// Displays:
/// - User profile information
/// - Personal information
/// - Phone verification
/// - Aadhaar verification
/// - Driving licence verification
/// - Vehicle RC verification
/// - Vehicles
/// - Activity statistics
/// - Settings
/// - Logout
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  bool _isLoadingVehicles = false;

  List<ProfileVehicle> _vehicles = const <ProfileVehicle>[];
  String? _maskedDrivingLicence;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // ─────────────────────────────────────────────
  // INITIAL PROFILE DATA
  // ─────────────────────────────────────────────

  Future<void> _loadProfileData() async {
    await Future.wait<void>([
      _refreshBackendProfile(showError: false),
      _loadVehicles(showError: false),
    ]);
  }

  // ─────────────────────────────────────────────
  // BACKEND PROFILE
  // ─────────────────────────────────────────────

  Future<void> _refreshBackendProfile({
    bool showError = true,
  }) async {
    try {
      await AuthService.instance.getUserProfile();

      // The existing user-profile response already contains the safe,
      // masked driving-licence value. Do not call a second verification
      // endpoint just to fetch the masked value.
      final profile = AuthService.instance.currentProfile;

      if (!mounted) return;

      setState(() {
        _maskedDrivingLicence =
            profile?.maskedDrivingLicence;
      });
    } catch (error) {
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not refresh profile: $error',
            ),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // VEHICLES
  // ─────────────────────────────────────────────

  Future<void> _loadVehicles({
    bool showError = true,
  }) async {
    if (_isLoadingVehicles) return;

    if (mounted) {
      setState(() => _isLoadingVehicles = true);
    }

    try {
      final vehicles =
          await VehicleService.instance.getMyVehicles();

      final mapped = vehicles
          .map(
            (vehicle) => ProfileVehicle(
              id: vehicle.id,
              vehicleModel: vehicle.vehicleModel,
              vehicleColor: vehicle.vehicleColor,
              registrationNumber:
                  vehicle.registrationNumber,

              // Module 3 uses subtype as its displayed vehicle type.
              vehicleType: vehicle.vehicleSubtype,
              vehicleSubtype: vehicle.vehicleSubtype,
              seatingCapacity: vehicle.seatingCapacity,
              verified: vehicle.rcVerified,
              isActive: vehicle.isActive,
            ),
          )
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _vehicles = mapped;
        _isLoadingVehicles = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoadingVehicles = false);

      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load vehicles: $error',
            ),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // REFRESH PROFILE
  // ─────────────────────────────────────────────

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _loadProfileData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile refreshed.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not refresh profile: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // TRUST VAULT
  // ─────────────────────────────────────────────

  Future<void> _openTrustVault() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TrustVaultScreen(),
      ),
    );

    if (!mounted) return;

    await _loadProfileData();
  }

  // ─────────────────────────────────────────────
  // ADD / VERIFY VEHICLE
  // ─────────────────────────────────────────────

  Future<void> _openAddVehicleFlow() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) =>
            const VehicleRcVerificationScreen(),
      ),
    );

    if (!mounted) return;

    // Vehicle verification screen may return a UserProfile
    // in the current implementation. The vehicle list itself
    // is always re-read from DB.
    if (result != null) {
      await _refreshBackendProfile(
        showError: false,
      );
    }

    await _loadVehicles();
  }

  // ─────────────────────────────────────────────
  // PHONE VERIFICATION
  // ─────────────────────────────────────────────

  /// Sends a phone verification OTP through Supabase.
  ///
  /// The actual SMS delivery and OTP generation are handled
  /// by Supabase and its configured SMS provider.
  Future<bool> _sendPhoneOtp() async {
    final profile =
        AuthService.instance.currentProfile;

    final phoneNumber = profile?.phoneNumber;

    if (phoneNumber == null ||
        phoneNumber.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add a phone number before verifying.',
            ),
          ),
        );
      }

      return false;
    }

    try {
      await AuthService.instance
          .sendPhoneVerificationOtp(
        phoneNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'OTP sent to $phoneNumber',
            ),
          ),
        );
      }

      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not send OTP: $error',
            ),
          ),
        );
      }

      return false;
    }
  }

  /// Verifies the OTP and synchronizes the result with
  /// the LiftOff backend.
  ///
  /// DEVELOPMENT MODE:
  /// Any 6-digit OTP is accepted locally, then the
  /// development backend endpoint sets:
  ///
  ///     users.phone_number = <phone>
  ///     users.phone_verified = true
  ///
  /// REAL MODE:
  /// Supabase verifies the OTP first. AuthService then
  /// synchronizes the verified Supabase phone state
  /// with the LiftOff backend.
  Future<bool> _verifyPhoneOtp(String otp) async {
    final profile =
        AuthService.instance.currentProfile;

    final phoneNumber = profile?.phoneNumber;

    if (phoneNumber == null ||
        phoneNumber.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone number is not available.',
            ),
          ),
        );
      }

      return false;
    }

    try {
      debugPrint(
        'Starting complete phone verification flow...',
      );

      // IMPORTANT:
      // Do not call verifyPhoneOtp() directly here.
      //
      // verifyPhoneOtp() only verifies/accepts the OTP.
      // verifyPhoneAndRefreshProfile() also performs the
      // backend synchronization and refreshes the profile.
      final updatedProfile =
          await AuthService.instance
              .verifyPhoneAndRefreshProfile(
        phoneNumber: phoneNumber,
        otp: otp,
      );

      debugPrint(
        'Phone verification backend result: '
        'phone=${updatedProfile.phoneNumber}, '
        'verified=${updatedProfile.phoneVerified}',
      );

      // Refresh the screen from the backend response.
      //
      // This is important because ProfileScreen derives
      // phoneVerified from AuthService.currentProfile.
      await _refreshBackendProfile(
        showError: false,
      );

      if (!mounted) {
        return updatedProfile.phoneVerified;
      }

      if (updatedProfile.phoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone number verified successfully.',
            ),
          ),
        );

        return true;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OTP was accepted, but phone verification '
            'could not be synchronized.',
          ),
        ),
      );

      return false;
    } catch (error) {
      debugPrint(
        '❌ Complete phone verification failed: $error',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid OTP or verification failed: $error',
            ),
          ),
        );
      }

      return false;
    }
  }

  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    if (_isLoggingOut) return;

    final shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out of LiftOff?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() => _isLoggingOut = true);

    try {
      await AuthService.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not log out: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // ABOUT LIFTOFF
  // ─────────────────────────────────────────────

  Future<void> _showAboutLiftOff() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'About LiftOff',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.midnightBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LiftOff is a smart ride-sharing platform '
                'designed to help travellers and hosts '
                'connect for shared journeys.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'The app brings trip planning, route '
                'selection, vehicle verification and ride '
                'management together in one place.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTealSurface,
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color:
                          AppColors.primaryTealDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'LiftOff uses verification and '
                        'profile information to support a '
                        'more trusted ride-sharing experience.',
                        style:
                            AppTextStyles.caption.copyWith(
                          color:
                              AppColors.midnightBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Version 1.0.0',
                style:
                    AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile =
        AuthService.instance.currentProfile;

    final avatarUrl = profile?.avatarUrl;

    final name = profile?.fullName ??
        profile?.email ??
        MockData.currentUser.name;

    final email = profile?.email ?? '';

    final phoneNumber =
        profile?.phoneNumber;

    final isPhoneVerified =
        profile?.phoneVerified ?? false;

    final initial =
        name.isNotEmpty
            ? name[0].toUpperCase()
            : 'U';

    final aadhaarVerified =
        profile?.aadhaarVerified ?? false;

    final dlVerified =
        profile?.dlVerified ?? false;

    final vehicleRcVerified =
        (profile?.vehicleRcVerified ?? false) ||
            _vehicles.any(
              (vehicle) => vehicle.verified,
            );

    final rides =
        profile?.sharedCommutesCount ?? 0;

    final fuelRecovered =
        profile?.fuelRecoveredInr ?? 0.0;

    final co2Saved =
        profile?.co2SavedKg ?? 0.0;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        surfaceTintColor:
            Colors.transparent,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _isRefreshing
                ? null
                : _refreshProfile,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                  ),
          ),
        ],
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
          padding:
              const EdgeInsets.all(16),
          children: [
            // ─────────────────────────────────
            // PROFILE HEADER
            // ─────────────────────────────────

            Container(
              padding:
                  const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                    BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color:
                        AppColors.shadowLight,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration:
                            BoxDecoration(
                          gradient:
                              AppColors.navyGradient,
                          shape:
                              BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: avatarUrl != null &&
                                  avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl:
                                      avatarUrl,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  fadeInDuration:
                                      const Duration(
                                    milliseconds:
                                        150,
                                  ),
                                  placeholder:
                                      (
                                    _,
                                    __,
                                  ) =>
                                          _AvatarFallback(
                                    initial:
                                        initial,
                                  ),
                                  errorWidget:
                                      (
                                    _,
                                    __,
                                    ___,
                                  ) =>
                                          _AvatarFallback(
                                    initial:
                                        initial,
                                  ),
                                )
                              : _AvatarFallback(
                                  initial:
                                      initial,
                                ),
                        ),
                      ),
                      if (aadhaarVerified)
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
                            child:
                                const Icon(
                              Icons
                                  .check_circle_rounded,
                              color: AppColors
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
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style:
                          AppTextStyles.body.copyWith(
                        color:
                            AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (phoneNumber
                          ?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: isPhoneVerified
                              ? AppColors
                                  .verifiedGreen
                              : AppColors
                                  .textSecondary,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          phoneNumber!,
                          style:
                              AppTextStyles
                                  .caption
                                  .copyWith(
                            color: AppColors
                                .textSecondary,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          isPhoneVerified
                              ? 'Verified'
                              : 'Not verified',
                          style:
                              AppTextStyles
                                  .caption
                                  .copyWith(
                            color:
                                isPhoneVerified
                                    ? AppColors
                                        .verifiedGreen
                                    : Colors.orange,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration:
                        BoxDecoration(
                      color: aadhaarVerified
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
                          aadhaarVerified
                              ? Icons
                                  .verified_rounded
                              : Icons
                                  .pending_rounded,
                          size: 16,
                          color: aadhaarVerified
                              ? AppColors
                                  .verifiedGreen
                              : Colors.orange,
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          aadhaarVerified
                              ? 'Verified Account'
                              : 'Verification Pending',
                          style:
                              AppTextStyles
                                  .caption
                                  .copyWith(
                            fontWeight:
                                FontWeight.w700,
                            color:
                                aadhaarVerified
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

            // ─────────────────────────────────
            // PERSONAL INFORMATION
            // ─────────────────────────────────

            const SizedBox(height: 20),

            _buildSectionTitle(
              'Personal Information',
            ),

            PersonalInformationWidget(
              name: name,
              email: email,
              phoneNumber: phoneNumber,
              emailVerified:
                  profile?.email != null,
              phoneVerified:
                  isPhoneVerified,

              // Send OTP through Supabase.
              onSendPhoneOtp:
                  phoneNumber?.isNotEmpty ==
                          true
                      ? _sendPhoneOtp
                      : null,

              // Verify OTP through Supabase.
              onVerifyPhone:
                  phoneNumber?.isNotEmpty ==
                          true
                      ? _verifyPhoneOtp
                      : null,
            ),

            // ─────────────────────────────────
            // VERIFICATION
            // ─────────────────────────────────

            const SizedBox(height: 20),

            _buildSectionTitle(
              'Verification',
            ),

            VerificationWidget(
              aadhaarVerified:
                  aadhaarVerified,
              maskedAadhaar:
                  profile?.maskedAadhaar,
              drivingLicenceVerified:
                  dlVerified,
              maskedDrivingLicence:
                  _maskedDrivingLicence,
              vehicleRcVerified:
                  vehicleRcVerified,
              vehicles: _vehicles,
              isLoadingVehicles:
                  _isLoadingVehicles,
              onRefreshVehicles:
                  _loadVehicles,
              onOpenTrustVault:
                  _openTrustVault,
              onAddVehicle:
                  _openAddVehicleFlow,
            ),

            // ─────────────────────────────────
            // ACTIVITY
            // ─────────────────────────────────

            const SizedBox(height: 20),

            ActivityWidget(
              sharedRides: rides,
              fuelRecovered:
                  fuelRecovered,
              co2Saved: co2Saved,
            ),

            // ─────────────────────────────────
            // SETTINGS
            // ─────────────────────────────────

            const SizedBox(height: 20),

            _buildSectionTitle(
              'Settings',
            ),

            _ProfileCard(
              children: [
                _ProfileTile(
                  icon: Icons
                      .notifications_none_rounded,
                  title: 'Notifications',
                  subtitle:
                      'Manage notification preferences',
                  onTap: () =>
                      NotificationPage.show(
                    context,
                  ),
                ),
                const _ProfileDivider(),
                _ProfileTile(
                  icon: Icons
                      .help_outline_rounded,
                  title: 'Help & Support',
                  subtitle:
                      'Get help with LiftOff',
                  onTap: () =>
                      SupportPage.show(
                    context,
                  ),
                ),
                const _ProfileDivider(),
                _ProfileTile(
                  icon: Icons
                      .info_outline_rounded,
                  title: 'About LiftOff',
                  subtitle:
                      'App information',
                  onTap:
                      _showAboutLiftOff,
                ),
              ],
            ),

            // ─────────────────────────────────
            // LOGOUT
            // ─────────────────────────────────

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _isLoggingOut
                  ? null
                  : _confirmLogout,
              icon: const Icon(
                Icons.logout_rounded,
              ),
              label:
                  const Text('Log Out'),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.red,
                side:
                    const BorderSide(
                  color: Colors.red,
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

  // ─────────────────────────────────────────────
  // SECTION TITLE
  // ─────────────────────────────────────────────

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

// ═══════════════════════════════════════════════════════════════
// AVATAR FALLBACK
// ═══════════════════════════════════════════════════════════════

class _AvatarFallback
    extends StatelessWidget {
  final String initial;

  const _AvatarFallback({
    required this.initial,
  });

  @override
  Widget build(
    BuildContext context,
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
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILE CARD
// ═══════════════════════════════════════════════════════════════

class _ProfileCard
    extends StatelessWidget {
  final List<Widget> children;

  const _ProfileCard({
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor:
          AppColors.shadowLight,
      borderRadius:
          BorderRadius.circular(20),
      clipBehavior:
          Clip.antiAlias,
      child:
          Column(children: children),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILE TILE
// ═══════════════════════════════════════════════════════════════

class _ProfileTile
    extends StatelessWidget {
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
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration:
            BoxDecoration(
          color:
              AppColors.primaryTealSurface,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color:
              AppColors.primaryTealDark,
        ),
      ),
      title: Text(
        title,
        style:
            AppTextStyles.label.copyWith(
          color:
              AppColors.midnightBlue,
          fontWeight:
              FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILE DIVIDER
// ═══════════════════════════════════════════════════════════════

class _ProfileDivider
    extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Divider(
      height: 1,
      indent: 72,
      color:
          AppColors.borderGray,
    );
  }
}