import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';

/// Floating Top Bar for LiftOff with Dual Mode Switcher (Traveller ↔ Rider Mode)
class FloatingTopBar extends StatelessWidget {
  final bool isRiderMode;
  final ValueChanged<bool> onModeChanged;

  const FloatingTopBar({
    super.key,
    required this.isRiderMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Meeting node / Location pill
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withAlpha(240),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.borderGray,
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowLight,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primaryTealSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.near_me_rounded,
                                color: AppColors.primaryTealDark,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Safe Meeting Spot',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primaryTealDark,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_user_rounded,
                                        size: 11,
                                        color: AppColors.verifiedGreen,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    MockData.safeMeetingNodes.first.name,
                                    style: AppTextStyles.label.copyWith(
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.mediumGray,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // User Avatar with Verified Badge
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.navyGradient,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          MockData.currentUser.name[0],
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.verifiedGreen,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Dual Mode Switcher Pill (Traveller Mode ↔ Rider/Host Mode)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.midnightBlue.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowHeavy,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeButton(
                    label: 'Traveller Mode',
                    icon: Icons.person_pin_circle_rounded,
                    isSelected: !isRiderMode,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onModeChanged(false);
                    },
                  ),
                  const SizedBox(width: 4),
                  _ModeButton(
                    label: 'Host Mode (Offer Ride)',
                    icon: Icons.drive_eta_rounded,
                    isSelected: isRiderMode,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onModeChanged(true);
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
}

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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.midnightBlue
                  : AppColors.white.withAlpha(180),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? AppColors.midnightBlue
                    : AppColors.white.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
