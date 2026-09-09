import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Floating Top Bar for LiftOff.
///
/// Traveller Mode:
/// - Live location card
/// - Profile avatar
/// - Traveller / Host mode switcher
///
/// Host Mode:
/// - Live location card hidden
/// - Profile avatar hidden
/// - Mode switcher moved to the top
///
/// Platform behavior:
/// - Web / Windows keep the original Traveller sizing.
/// - Android uses a more compact layout.
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
    final profile =
        AuthService.instance.currentProfile;

    final avatarUrl =
        profile?.avatarUrl?.trim();

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

    // ============================================================
    // PLATFORM
    // ============================================================

    final isAndroid =
        defaultTargetPlatform ==
            TargetPlatform.android;

    // ============================================================
    // HOST MODE
    // ============================================================
    //
    // In Host Mode we ONLY show the mode switcher.
    //
    // Live Location + Avatar are completely removed from
    // the widget tree, so they do not occupy any space.
    // ============================================================

    if (isRiderMode) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                isAndroid ? 12 : 16,
            vertical:
                isAndroid ? 4 : 8,
          ),
          child: Align(
            alignment:
                Alignment.topCenter,
            child:
                _buildModeSwitcher(
              isAndroid:
                  isAndroid,
            ),
          ),
        ),
      );
    }

    // ============================================================
    // TRAVELLER MODE
    // ============================================================
    //
    // This is the existing normal layout.
    //
    // Live Location + Avatar
    //          ↓
    //      Mode Switcher
    //
    // Nothing is removed or changed here.
    // ============================================================

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              isAndroid ? 12 : 16,
          vertical:
              isAndroid ? 4 : 8,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            // =======================================================
            // TOP ROW
            // =======================================================

            Row(
              children: [
                // ===================================================
                // LIVE LOCATION CARD
                // ===================================================

                Expanded(
                  child:
                      ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                    child:
                        BackdropFilter(
                      filter:
                          ImageFilter.blur(
                        sigmaX: 12,
                        sigmaY: 12,
                      ),
                      child:
                          Material(
                        color:
                            Colors.transparent,
                        child:
                            InkWell(
                          onTap:
                              onLiveLocationTap,
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          child:
                              Container(
                            padding:
                                EdgeInsets.symmetric(
                              horizontal:
                                  isAndroid
                                      ? 10
                                      : 14,
                              vertical:
                                  isAndroid
                                      ? 8
                                      : 10,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  AppColors
                                      .white
                                      .withAlpha(
                                240,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppColors
                                        .borderGray,
                                width:
                                    1,
                              ),
                              boxShadow:
                                  const [
                                BoxShadow(
                                  color:
                                      AppColors
                                          .shadowLight,
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
                            child:
                                Row(
                              children: [
                                // =================================
                                // LOCATION ICON
                                // =================================

                                Container(
                                  width:
                                      isAndroid
                                          ? 30
                                          : 32,
                                  height:
                                      isAndroid
                                          ? 30
                                          : 32,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        AppColors
                                            .primaryTealSurface,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                  ),
                                  child:
                                      Icon(
                                    Icons
                                        .my_location_rounded,
                                    color:
                                        AppColors
                                            .primaryTealDark,
                                    size:
                                        isAndroid
                                            ? 17
                                            : 18,
                                  ),
                                ),

                                SizedBox(
                                  width:
                                      isAndroid
                                          ? 8
                                          : 10,
                                ),

                                // =================================
                                // LOCATION TEXT
                                // =================================

                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    mainAxisSize:
                                        MainAxisSize
                                            .min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child:
                                                Text(
                                              'Your Live Location',
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                              style:
                                                  AppTextStyles
                                                      .caption
                                                      .copyWith(
                                                color:
                                                    AppColors
                                                        .primaryTealDark,
                                                fontWeight:
                                                    FontWeight
                                                        .w700,
                                                fontSize:
                                                    isAndroid
                                                        ? 9
                                                        : 10,
                                              ),
                                            ),
                                          ),

                                          SizedBox(
                                            width:
                                                isAndroid
                                                    ? 4
                                                    : 5,
                                          ),

                                          Container(
                                            width:
                                                6,
                                            height:
                                                6,
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
                                        height:
                                            2,
                                      ),

                                      Text(
                                        _locationText,
                                        style:
                                            AppTextStyles
                                                .label
                                                .copyWith(
                                          fontSize:
                                              isAndroid
                                                  ? 11
                                                  : 12,
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

                                SizedBox(
                                  width:
                                      isAndroid
                                          ? 4
                                          : 6,
                                ),

                                // =================================
                                // NAVIGATION ICON
                                // =================================

                                Icon(
                                  Icons
                                      .near_me_rounded,
                                  color:
                                      AppColors
                                          .primaryTeal,
                                  size:
                                      isAndroid
                                          ? 15
                                          : 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  width:
                      isAndroid ? 8 : 10,
                ),

                // =================================================
                // CLICKABLE USER AVATAR
                // =================================================

                Material(
                  color:
                      Colors.transparent,
                  child:
                      InkWell(
                    onTap:
                        onProfileTap,
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                    child:
                        Padding(
                      padding:
                          const EdgeInsets.all(
                        2,
                      ),
                      child:
                          Stack(
                        clipBehavior:
                            Clip.none,
                        children: [
                          Container(
                            width:
                                isAndroid
                                    ? 42
                                    : 44,
                            height:
                                isAndroid
                                    ? 42
                                    : 44,
                            decoration:
                                BoxDecoration(
                              gradient:
                                  AppColors
                                      .navyGradient,
                              shape:
                                  BoxShape
                                      .circle,
                              boxShadow:
                                  const [
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
                                              BoxFit
                                                  .cover,

                                          placeholder:
                                              (
                                            context,
                                            url,
                                          ) {
                                            return _AvatarInitial(
                                              initial:
                                                  initial,
                                            );
                                          },

                                          errorWidget:
                                              (
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
                                      : _AvatarInitial(
                                          initial:
                                              initial,
                                        ),
                            ),
                          ),

                          // =========================================
                          // VERIFIED BADGE
                          // =========================================

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

            // =======================================================
            // GAP
            // =======================================================

            SizedBox(
              height:
                  isAndroid ? 5 : 8,
            ),

            // =======================================================
            // MODE SWITCHER
            // =======================================================

            _buildModeSwitcher(
              isAndroid:
                  isAndroid,
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // MODE SWITCHER
  // ===============================================================

  Widget _buildModeSwitcher({
    required bool isAndroid,
  }) {
    return Container(
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
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          // =======================================================
          // TRAVELLER MODE
          // =======================================================

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

              // false = Traveller
              onModeChanged(
                false,
              );
            },
            isAndroid:
                isAndroid,
          ),

          SizedBox(
            width:
                isAndroid ? 2 : 4,
          ),

          // =======================================================
          // HOST MODE
          // =======================================================

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

              // true = Host
              onModeChanged(
                true,
              );
            },
            isAndroid:
                isAndroid,
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // LOCATION TEXT
  // ===============================================================

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

class _AvatarInitial
    extends StatelessWidget {
  final String initial;

  const _AvatarInitial({
    required this.initial,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Text(
        initial,
        style:
            AppTextStyles.h3.copyWith(
          color:
              AppColors
                  .primaryTeal,
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

class _ModeButton
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAndroid;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isAndroid,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      behavior:
          HitTestBehavior.opaque,
      onTap:
          onTap,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        curve:
            Curves.easeOut,
        padding:
            EdgeInsets.symmetric(
          horizontal:
              isAndroid ? 10 : 14,
          vertical:
              isAndroid ? 6 : 7,
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
        child:
            Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:
                  isAndroid ? 14 : 15,
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

            SizedBox(
              width:
                  isAndroid ? 5 : 6,
            ),

            Text(
              label,
              style:
                  AppTextStyles
                      .label
                      .copyWith(
                fontSize:
                    isAndroid ? 11 : 12,
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