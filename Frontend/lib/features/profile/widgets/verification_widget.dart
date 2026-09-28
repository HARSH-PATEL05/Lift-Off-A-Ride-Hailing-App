import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Profile verification surface.
///
/// The parent supplies the current backend state and the actual vehicle list.
/// This widget never creates a second vehicle API or invents verification data.
class VerificationWidget extends StatelessWidget {
  final bool aadhaarVerified;
  final String? maskedAadhaar;

  final bool drivingLicenceVerified;
  final String? maskedDrivingLicence;

  final bool vehicleRcVerified;
  final List<ProfileVehicle> vehicles;
  final bool isLoadingVehicles;
  final Future<void> Function()? onRefreshVehicles;

  final VoidCallback? onOpenTrustVault;
  final VoidCallback? onAddVehicle;

  const VerificationWidget({
    super.key,
    required this.aadhaarVerified,
    this.maskedAadhaar,
    required this.drivingLicenceVerified,
    this.maskedDrivingLicence,
    this.vehicleRcVerified = false,
    this.vehicles = const <ProfileVehicle>[],
    this.isLoadingVehicles = false,
    this.onRefreshVehicles,
    this.onOpenTrustVault,
    this.onAddVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final verifiedVehicles =
        vehicles.where((vehicle) => vehicle.verified).toList(growable: false);

    final rcVerified = vehicleRcVerified || verifiedVehicles.isNotEmpty;

    final vehicleSubtitle = isLoadingVehicles
        ? 'Loading vehicles…'
        : vehicles.isEmpty
            ? (rcVerified ? 'RC verified' : 'No vehicle registered')
            : '${vehicles.length} vehicle${vehicles.length == 1 ? '' : 's'} registered';

    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: AppColors.shadowLight,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _VerificationTile(
            icon: Icons.badge_outlined,
            title: 'Aadhaar Verification',
            subtitle: aadhaarVerified
                ? (maskedAadhaar ?? 'Verified')
                : 'Not verified',
            verified: aadhaarVerified,
            onTap: () => _showAadhaarModal(context),
          ),
          const _VerificationDivider(),
          _VerificationTile(
            icon: Icons.credit_card_outlined,
            title: 'Driving Licence',
            subtitle: drivingLicenceVerified
                ? (maskedDrivingLicence ?? 'Verified')
                : 'Not verified',
            verified: drivingLicenceVerified,
            onTap: () => _showDrivingLicenceModal(context),
          ),
          const _VerificationDivider(),
          _VerificationTile(
            icon: Icons.directions_car_outlined,
            title: 'Vehicle RC',
            subtitle: vehicleSubtitle,
            verified: rcVerified,
            onTap: () => _showVehicleRcModal(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showAadhaarModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => _DetailsModal(
        title: 'Aadhaar Details',
        icon: Icons.badge_outlined,
        children: [
          _DetailRow(
            label: 'Aadhaar Number',
            value: maskedAadhaar ?? 'Not available',
          ),
          _DetailStatusRow(label: 'Status', verified: aadhaarVerified),
          if (!aadhaarVerified) ...[
            const SizedBox(height: 8),
            _DetailMessage('Verify Aadhaar from Trust Vault to complete identity verification.'),
          ],
          const SizedBox(height: 18),
          _TrustVaultButton(
            onPressed: onOpenTrustVault == null
                ? null
                : () {
                    Navigator.of(sheetContext).pop();
                    onOpenTrustVault!();
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _showDrivingLicenceModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => _DetailsModal(
        title: 'Driving Licence',
        icon: Icons.credit_card_outlined,
        children: [
          _DetailRow(
            label: 'Licence Number',
            value: maskedDrivingLicence ?? 'Not available',
          ),
          _DetailStatusRow(
            label: 'Status',
            verified: drivingLicenceVerified,
          ),
          if (!drivingLicenceVerified) ...[
            const SizedBox(height: 8),
            _DetailMessage('Your driving licence has not been verified yet.'),
          ],
          const SizedBox(height: 18),
          _TrustVaultButton(
            onPressed: onOpenTrustVault == null
                ? null
                : () {
                    Navigator.of(sheetContext).pop();
                    onOpenTrustVault!();
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleRcModal(BuildContext context) async {
    // Recompute the RC status here because the `rcVerified` variable
    // declared inside build() is only scoped to build().
    final rcVerified =
        vehicleRcVerified || vehicles.any((vehicle) => vehicle.verified);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) {
        final height = MediaQuery.of(sheetContext).size.height * 0.72;

        return SafeArea(
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle RC',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.midnightBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vehicles.isNotEmpty
                        ? 'Your registered vehicles'
                        : rcVerified
                            ? 'Your vehicle RC is verified.'
                            : 'No registered vehicle found.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isLoadingVehicles)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (vehicles.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        itemCount: vehicles.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) =>
                            _VehicleCard(vehicle: vehicles[index]),
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTealSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            rcVerified
                                ? 'The profile confirms an RC-verified vehicle, but the vehicle list returned no rows. Refresh the vehicle list or open the verification flow.'
                                : 'Add and verify a vehicle before using it for ride offers.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.midnightBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (onRefreshVehicles != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoadingVehicles
                            ? null
                            : () async {
                                await onRefreshVehicles!();
                              },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh Vehicles'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddVehicle == null
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              onAddVehicle!();
                            },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Vehicle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryTealDark,
                        side: const BorderSide(
                          color: AppColors.primaryTealDark,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (onOpenTrustVault != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onOpenTrustVault!();
                      },
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Open Trust Vault'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProfileVehicle {
  final int? id;
  final String? vehicleModel;
  final String? vehicleColor;
  final String registrationNumber;
  final String? vehicleType;
  final String? vehicleCategory;
  final String? vehicleSubtype;
  final int? seatingCapacity;
  final bool verified;
  final bool isActive;

  const ProfileVehicle({
    required this.registrationNumber,
    this.id,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleType,
    this.vehicleCategory,
    this.vehicleSubtype,
    this.seatingCapacity,
    this.verified = true,
    this.isActive = true,
  });
}

class _VerificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool verified;
  final VoidCallback onTap;

  const _VerificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.verified,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: verified
              ? AppColors.primaryTealSurface
              : Colors.orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: verified ? AppColors.primaryTealDark : Colors.orange,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.label.copyWith(
          color: AppColors.midnightBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _StatusBadge(verified: verified),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool verified;

  const _StatusBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: verified
            ? AppColors.primaryTealSurface
            : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.pending_outlined,
            size: 15,
            color: verified ? AppColors.verifiedGreen : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Verify',
            style: AppTextStyles.caption.copyWith(
              color: verified ? AppColors.primaryTealDark : Colors.orange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationDivider extends StatelessWidget {
  const _VerificationDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 70,
      color: AppColors.borderGray,
    );
  }
}

class _DetailsModal extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailsModal({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealSurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.primaryTealDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.midnightBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.label.copyWith(
                color: AppColors.midnightBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStatusRow extends StatelessWidget {
  final String label;
  final bool verified;

  const _DetailStatusRow({required this.label, required this.verified});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        _StatusBadge(verified: verified),
      ],
    );
  }
}

class _DetailMessage extends StatelessWidget {
  final String message;

  const _DetailMessage(this.message);

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _TrustVaultButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _TrustVaultButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Open Trust Vault'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryTealDark,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final ProfileVehicle vehicle;

  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final vehicleName = [
      vehicle.vehicleModel,
      vehicle.vehicleSubtype,
    ]
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .join(' • ');

    final capacityText = vehicle.seatingCapacity != null
        ? '${vehicle.seatingCapacity} seats • '
            'LiftOff max ${vehicle.seatingCapacity! > 1 ? vehicle.seatingCapacity! - 1 : 1}'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryTealSurface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _vehicleIcon(vehicle),
              color: AppColors.primaryTealDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicleName.isNotEmpty ? vehicleName : 'Vehicle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.midnightBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vehicle.registrationNumber,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vehicle.vehicleColor?.trim().isNotEmpty == true)
                  Text(
                    vehicle.vehicleColor!.trim(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (capacityText != null)
                  Text(
                    capacityText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 5),
                _StatusBadge(verified: vehicle.verified),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _vehicleIcon(ProfileVehicle vehicle) {
    final type = [
      vehicle.vehicleType,
      vehicle.vehicleCategory,
      vehicle.vehicleSubtype,
    ].whereType<String>().join(' ').toUpperCase();

    if (type.contains('BIKE') ||
        type.contains('SCOOTY') ||
        type.contains('SCOOTER') ||
        type.contains('2 WHEELER')) {
      return Icons.two_wheeler_rounded;
    }

    if (type.contains('AUTO') ||
        type.contains('RICKSHAW') ||
        type.contains('TOTO') ||
        type.contains('3 WHEELER')) {
      return Icons.electric_rickshaw_rounded;
    }

    return Icons.directions_car_filled_rounded;
  }
}
