import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Activity summary shown on the Profile screen.
///
/// This widget is presentation-only. Values are supplied by ProfileScreen
/// from the current UserProfile.
class ActivityWidget extends StatelessWidget {
  final int sharedRides;
  final double fuelRecovered;
  final double co2Saved;

  const ActivityWidget({
    super.key,
    required this.sharedRides,
    required this.fuelRecovered,
    required this.co2Saved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Your Activity',
            style: AppTextStyles.label.copyWith(
              color: AppColors.midnightBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.route_rounded,
                value: sharedRides.toString(),
                label: 'Shared Rides',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.currency_rupee_rounded,
                value: fuelRecovered.toStringAsFixed(0),
                label: 'Fuel Recovered',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: Icons.eco_rounded,
          value: '${co2Saved.toStringAsFixed(1)} kg',
          label: 'CO₂ Saved',
          fullWidth: true,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: AppColors.shadowLight,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryTealSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryTealDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.midnightBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
