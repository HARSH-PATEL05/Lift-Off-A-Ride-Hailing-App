import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Floating Top Bar for LiftOff.
///
/// Features:
/// - Displays the user's real live location address.
/// - Opens the map/current location when location pill is tapped.
/// - Opens the user profile when avatar is tapped.
/// - Switches between Traveller and Host modes.
/// - Shows cached Google profile image when available.
/// - Falls back to the user's first initial when the image fails.
class FloatingTopBar extends StatelessWidget {
  final bool isRiderMode;
  final ValueChanged<bool> onModeChanged;

  /// Human-readable address obtained from GPS + reverse geocoding.
  final String? liveLocationAddress;

  /// Called when the live location card is tapped.
  final VoidCallback? onLiveLocationTap;

  /// Called when the profile avatar is tapped.
  final VoidCallback? onProfileTap;

  const FloatingTopBar({
    super.key,
    required this.isRiderMode,
    required this.onModeChanged,
    this.liveLocationAddress,
    this.onLiveLocationTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile = AuthService.instance.currentProfile;

    final avatarUrl = profile?.avatarUrl?.trim();

    final name =
        profile?.fullName ??
        profile?.email ??
        MockData.currentUser.name;

    final initial =
        name.isNotEmpty
            ? name[0].toUpperCase()
            : 'U';

    final isVerified =
        profile?.aadhaarVerified ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // =========================================================
            // TOP ROW
            // =========================================================

            Row(
              children: [
                // =====================================================
                // LIVE LOCATION CARD
                // =====================================================

                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 12,
                        sigmaY: 12,
                      ),
                      child: Material(
                        color:
                            Colors.transparent,
                        child: InkWell(
                          onTap:
                              onLiveLocationTap,
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  AppColors.white
                                      .withAlpha(
                                240,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppColors
                                        .borderGray,
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color:
                                      AppColors
                                          .shadowLight,
                                  blurRadius:
                                      16,
                                  offset:
                                      Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Location Icon

                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration:
                                      BoxDecoration(
                                    color: AppColors
                                        .primaryTealSurface,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .my_location_rounded,
                                    color:
                                        AppColors
                                            .primaryTealDark,
                                    size: 18,
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                // Location Text

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    mainAxisSize:
                                        MainAxisSize
                                            .min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Your Live Location',
                                            style: AppTextStyles
                                                .caption
                                                .copyWith(
                                              color:
                                                  AppColors
                                                      .primaryTealDark,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                              fontSize:
                                                  10,
                                            ),
                                          ),

                                          const SizedBox(
                                            width: 5,
                                          ),

                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration:
                                                const BoxDecoration(
                                              color:
                                                  AppColors
                                                      .verifiedGreen,
                                              shape:
                                                  BoxShape
                                                      .circle,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(
                                        height: 2,
                                      ),

                                      Text(
                                        _locationText,
                                        style: AppTextStyles
                                            .label
                                            .copyWith(
                                          fontSize:
                                              12,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                const Icon(
                                  Icons
                                      .near_me_rounded,
                                  color:
                                      AppColors
                                          .primaryTeal,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // =====================================================
                // CLICKABLE USER AVATAR
                // =====================================================

                Material(
                  color:
                      Colors.transparent,
                  child: InkWell(
                    onTap:
                        onProfileTap,
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        2,
                      ),
                      child: Stack(
                        clipBehavior:
                            Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration:
                                BoxDecoration(
                              gradient:
                                  AppColors
                                      .navyGradient,
                              shape:
                                  BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color:
                                      AppColors
                                          .shadowLight,
                                  blurRadius:
                                      12,
                                  offset:
                                      Offset(
                                    0,
                                    3,
                                  ),
                                ),
                              ],
                            ),

                            child:
                                ClipOval(
                              child:
                                  avatarUrl != null &&
                                          avatarUrl
                                              .isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl:
                                              avatarUrl,
                                          fit:
                                              BoxFit.cover,

                                          // Show initial while
                                          // the image is loading.
                                          placeholder: (
                                            context,
                                            url,
                                          ) {
                                            return _AvatarInitial(
                                              initial:
                                                  initial,
                                            );
                                          },

                                          // Show initial if Google
                                          // returns 429 or another
                                          // image loading error.
                                          errorWidget: (
                                            context,
                                            url,
                                            error,
                                          ) {
                                            debugPrint(
                                              'Avatar loading failed: '
                                              '$error',
                                            );

                                            return _AvatarInitial(
                                              initial:
                                                  initial,
                                            );
                                          },
                                        )

                                      // No avatar URL available.
                                      : _AvatarInitial(
                                          initial:
                                              initial,
                                        ),
                            ),
                          ),

                          // =================================================
                          // VERIFIED BADGE
                          // =================================================

                          if (isVerified)
                            Positioned(
                              right:
                                  -1,
                              bottom:
                                  -1,
                              child:
                                  Container(
                                padding:
                                    const EdgeInsets
                                        .all(
                                  2,
                                ),
                                decoration:
                                    const BoxDecoration(
                                  color:
                                      AppColors
                                          .white,
                                  shape:
                                      BoxShape
                                          .circle,
                                ),
                                child:
                                    const Icon(
                                  Icons
                                      .check_circle_rounded,
                                  color:
                                      AppColors
                                          .verifiedGreen,
                                  size:
                                      15,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            // =========================================================
            // MODE SWITCHER
            // =========================================================

            Container(
              padding:
                  const EdgeInsets.all(
                4,
              ),
              decoration:
                  BoxDecoration(
                color:
                    AppColors
                        .midnightBlue
                        .withAlpha(
                      230,
                    ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                boxShadow:
                    const [
                  BoxShadow(
                    color:
                        AppColors
                            .shadowHeavy,
                    blurRadius:
                        16,
                    offset:
                        Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _ModeButton(
                    label:
                        'Traveller Mode',
                    icon:
                        Icons
                            .person_pin_circle_rounded,
                    isSelected:
                        !isRiderMode,
                    onTap: () {
                      HapticFeedback
                          .selectionClick();

                      onModeChanged(
                        false,
                      );
                    },
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  _ModeButton(
                    label:
                        'Host Mode (Offer Ride)',
                    icon:
                        Icons
                            .drive_eta_rounded,
                    isSelected:
                        isRiderMode,
                    onTap: () {
                      HapticFeedback
                          .selectionClick();

                      onModeChanged(
                        true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the best available location text.
  String get _locationText {
    final address =
        liveLocationAddress?.trim();

    if (address != null &&
        address.isNotEmpty) {
      return address;
    }

    return 'Fetching your live location...';
  }
}


// ===============================================================
// AVATAR INITIAL FALLBACK
// ===============================================================

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({
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
            AppTextStyles.h3.copyWith(
          color:
              AppColors.primaryTeal,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }
}


// ===============================================================
// MODE BUTTON
// ===============================================================

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          onTap,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),
        decoration:
            BoxDecoration(
          color:
              isSelected
                  ? AppColors
                      .primaryTeal
                  : Colors
                      .transparent,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:
                  15,
              color:
                  isSelected
                      ? AppColors
                          .midnightBlue
                      : AppColors
                          .white
                          .withAlpha(
                        180,
                      ),
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              label,
              style:
                  AppTextStyles
                      .label
                      .copyWith(
                fontSize:
                    12,
                fontWeight:
                    isSelected
                        ? FontWeight
                            .w800
                        : FontWeight
                            .w500,
                color:
                    isSelected
                        ? AppColors
                            .midnightBlue
                        : AppColors
                            .white
                            .withAlpha(
                          200,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}