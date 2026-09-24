import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

import '../../auth/screens/trust_vault_screen.dart';
import '../widgets/offer_ride_modal.dart';

/// Rider / Host Dashboard Surface
///
/// Displays:
/// - Host profile
/// - Verification status
/// - Host statistics
/// - Offer / Publish Ride action
/// - Active published rides
class RiderHostDashboard extends StatefulWidget {
  const RiderHostDashboard({super.key});

  @override
  State<RiderHostDashboard> createState() =>
      _RiderHostDashboardState();
}

class _RiderHostDashboardState
    extends State<RiderHostDashboard> {
  List<_PublishedRide> _myRides = [];
  bool _rideActionInProgress = false;
  bool _isLoadingRides = true;
  Timer? _rideLifecycleTimer;

  @override
  void initState() {
    super.initState();
    _fetchMyRides();

    // Refresh the lifecycle from the backend every minute so a scheduled
    // ride automatically becomes ACTIVE 5 minutes before departure and a
    // completed ride disappears from this section without requiring a
    // manual refresh.
    _rideLifecycleTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchMyRides(),
    );
  }

  @override
  void dispose() {
    _rideLifecycleTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // FETCH MY RIDES
  // ============================================================

  Future<void> _fetchMyRides() async {
    try {
      // Sync fresh profile state from backend.
      AuthService.instance
          .getUserProfile()
          .catchError(
            (_) => AuthService.instance.currentProfile!,
          );

      final response =
          await ApiClient.instance.get(
        '${ApiEndpoints.rides}/my',
      );

      if (response is List) {
        final parsed = response
            .whereType<Map<String, dynamic>>()
            .map(_PublishedRide.fromJson)
            .where((ride) {
              final lifecycle = ride.status.toLowerCase();
              return lifecycle == 'scheduled' || lifecycle == 'active';
            })
            .toList();

        if (mounted) {
          setState(() {
            _myRides = parsed;
            _isLoadingRides = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingRides = false;
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Error fetching my rides: $e',
      );

      if (mounted) {
        setState(() {
          _isLoadingRides = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN OFFER RIDE MODAL
  // ============================================================

  Future<void> _openPublishModal() async {
    final published = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) {
        return const OfferRideModal();
      },
    );

    // Only refresh the dashboard when the modal
    // reports that a ride was successfully published.
    if (published == true && mounted) {
      await _fetchMyRides();
    }
  }

  // ============================================================
  // TRUST VAULT
  // ============================================================

  void _openTrustVault() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TrustVaultScreen(),
      ),
    ).then((_) {
      AuthService.instance
          .getUserProfile()
          .then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final profile =
        AuthService.instance.currentProfile;

    final mockUser =
        MockData.currentUser;

    final displayName =
        profile?.fullName ?? mockUser.name;

    final avatarUrl =
        profile?.avatarUrl;

    final initial =
        displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : 'U';

    // ----------------------------------------------------------
    // Verification
    // ----------------------------------------------------------

    final aadhaarVerified =
        profile?.aadhaarVerified ?? false;

    final dlVerified =
        profile?.dlVerified ?? false;

    final rcVerified =
        profile?.vehicleRcVerified ?? false;

    final allVerified =
        aadhaarVerified &&
        dlVerified &&
        rcVerified;

    // ----------------------------------------------------------
    // Host Statistics
    // ----------------------------------------------------------

    final fuelRecovered =
        profile?.fuelRecoveredInr ?? 0.0;

    final sharedCommutes =
        profile?.sharedCommutesCount ?? 0;

    final co2Saved =
        profile?.co2SavedKg ?? 0.0;

    return Scaffold(
      backgroundColor:
          AppColors.softGray,

      body: CustomScrollView(
        slivers: [
          // ======================================================
          // HEADER
          // ======================================================

          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.of(context)
                            .padding
                            .top +
                        70,
                left: 20,
                right: 20,
                bottom: 20,
              ),

              decoration:
                  const BoxDecoration(
                gradient:
                    AppColors.navyGradient,
                borderRadius:
                    BorderRadius.only(
                  bottomLeft:
                      Radius.circular(24),
                  bottomRight:
                      Radius.circular(24),
                ),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // Profile Row
                  // ------------------------------------------------

                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                AppColors
                                    .primaryTeal,
                            width: 2,
                          ),
                        ),

                        child: ClipOval(
                          child:
                              avatarUrl != null &&
                                      avatarUrl
                                          .isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          avatarUrl,
                                      fit:
                                          BoxFit.cover,
                                      errorWidget:
                                          (
                                        _,
                                        __,
                                        ___,
                                      ) =>
                                              Center(
                                        child:
                                            Text(
                                          initial,
                                          style:
                                              AppTextStyles.h2.copyWith(
                                            color:
                                                AppColors.primaryTeal,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child:
                                          Text(
                                        initial,
                                        style:
                                            AppTextStyles.h2.copyWith(
                                          color:
                                              AppColors.primaryTeal,
                                        ),
                                      ),
                                    ),
                        ),
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              displayName,
                              style:
                                  AppTextStyles
                                      .h2
                                      .copyWith(
                                color:
                                    AppColors
                                        .white,
                              ),
                            ),

                            Text(
                              'Host Status • ${mockUser.rating} Stars',
                              style:
                                  AppTextStyles
                                      .caption
                                      .copyWith(
                                color:
                                    AppColors
                                        .primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ------------------------------------------------
                  // Verification Chips
                  // ------------------------------------------------

                  Wrap(
                    spacing: 6,
                    children: [
                      _VerifyPill(
                        label:
                            aadhaarVerified
                                ? 'Aadhaar Verified'
                                : 'Aadhaar Pending',
                        isDone:
                            aadhaarVerified,
                      ),

                      _VerifyPill(
                        label:
                            dlVerified
                                ? 'DL Validated'
                                : 'DL Pending',
                        isDone:
                            dlVerified,
                      ),

                      _VerifyPill(
                        label:
                            rcVerified
                                ? 'Vehicle RC Verified'
                                : 'RC Pending',
                        isDone:
                            rcVerified,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // HOST ANALYTICS
          // ======================================================

          SliverPadding(
            padding:
                const EdgeInsets.all(16),

            sliver:
                SliverToBoxAdapter(
              child: Container(
                padding:
                    const EdgeInsets.all(16),

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.white,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  border:
                      Border.all(
                    color:
                        AppColors.borderGray,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color:
                          AppColors.shadowLight,
                      blurRadius: 16,
                      offset:
                          Offset(0, 4),
                    ),
                  ],
                ),

                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,
                  children: [
                    _StatItem(
                      label:
                          'Fuel Recovered',
                      value:
                          '₹${fuelRecovered.toInt()}',
                      icon:
                          Icons
                              .local_gas_station_rounded,
                      color:
                          AppColors
                              .midnightBlue,
                    ),

                    Container(
                      width: 1,
                      height: 36,
                      color:
                          AppColors
                              .borderGray,
                    ),

                    _StatItem(
                      label:
                          'Shared Commutes',
                      value:
                          '$sharedCommutes',
                      icon:
                          Icons
                              .group_rounded,
                      color:
                          AppColors
                              .primaryTealDark,
                    ),

                    Container(
                      width: 1,
                      height: 36,
                      color:
                          AppColors
                              .borderGray,
                    ),

                    _StatItem(
                      label:
                          'CO2 Saved',
                      value:
                          '${co2Saved.toStringAsFixed(1)} kg',
                      icon:
                          Icons.eco_rounded,
                      color:
                          AppColors
                              .verifiedGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================================
          // OFFER RIDE BUTTON
          // ======================================================

          SliverPadding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),

            sliver:
                SliverToBoxAdapter(
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      allVerified
                          ? AppColors
                              .midnightBlue
                          : AppColors
                              .amberPoll,

                  foregroundColor:
                      allVerified
                          ? AppColors
                              .primaryTeal
                          : AppColors
                              .midnightBlue,

                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                  ),
                ),

                onPressed:
                    allVerified
                        ? _openPublishModal
                        : _openTrustVault,

                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      allVerified
                          ? Icons
                              .add_circle_outline_rounded
                          : Icons
                              .verified_user_outlined,
                      color:
                          allVerified
                              ? AppColors
                                  .primaryTeal
                              : AppColors
                                  .midnightBlue,
                      size: 22,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Text(
                      allVerified
                          ? '+ Offer / Publish a Ride Route'
                          : 'Verify All Documents to Offer Rides',
                      style:
                          AppTextStyles
                              .buttonDark
                              .copyWith(
                        color:
                            allVerified
                                ? AppColors
                                    .primaryTeal
                                : AppColors
                                    .midnightBlue,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ======================================================
          // PUBLISHED RIDES
          // ======================================================

          SliverPadding(
            padding:
                const EdgeInsets.all(16),

            sliver:
                SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your Published Commutes',
                        style:
                            AppTextStyles
                                .h3,
                      ),

                      const Spacer(),

                      IconButton(
                        icon:
                            const Icon(
                          Icons
                              .refresh_rounded,
                          size: 18,
                          color:
                              AppColors
                                  .midnightBlue,
                        ),
                        onPressed:
                            _fetchMyRides,
                        tooltip:
                            'Refresh My Rides',
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  // ------------------------------------------------
                  // Loading
                  // ------------------------------------------------

                  if (_isLoadingRides)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        vertical: 24,
                      ),
                      child:
                          Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              AppColors
                                  .primaryTealDark,
                          strokeWidth:
                              2,
                        ),
                      ),
                    )

                  // ------------------------------------------------
                  // Empty
                  // ------------------------------------------------

                  else if (_myRides.isEmpty)
                    Container(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.white,
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
                        ),
                      ),

                      child:
                          Center(
                        child:
                            Column(
                          children: [
                            const Icon(
                              Icons
                                  .directions_car_outlined,
                              size: 36,
                              color:
                                  AppColors
                                      .mediumGray,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            Text(
                              'No Scheduled or Active Published Commutes',
                              style:
                                  AppTextStyles
                                      .bodyLarge
                                      .copyWith(
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              'Tap the button above to post your first commute route.',
                              style:
                                  AppTextStyles
                                      .caption
                                      .copyWith(
                                color:
                                    AppColors
                                        .mediumGray,
                              ),
                              textAlign:
                                  TextAlign
                                      .center,
                            ),
                          ],
                        ),
                      ),
                    )

                  // ------------------------------------------------
                  // Rides
                  // ------------------------------------------------

                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _myRides.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ride = _myRides[index];

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () =>
                              _showRideDetails(ride),
                          child: _buildPublishedRideCard(ride),
                        );
                      },
                    ),                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ============================================================
  // PUBLISHED RIDE CARD
  // ============================================================

  Widget _buildPublishedRideCard(_PublishedRide ride) {
    final departure = ride.departureTime.toLocal();
    final dateLabel = _formatDateShort(departure);
    final timeLabel = _formatTime(departure);
    final stopCount = ride.stops.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
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
                  ride.status.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryTealDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$dateLabel • $timeLabel',
                style: AppTextStyles.label.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _routeLine(
            icon: Icons.radio_button_checked_rounded,
            iconColor: AppColors.primaryTealDark,
            text: ride.originName,
          ),
          if (stopCount > 0) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const SizedBox(width: 2),
                Container(
                  width: 16,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.more_vert_rounded,
                    size: 17,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$stopCount ${stopCount == 1 ? 'stop' : 'stops'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mediumGray,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          _routeLine(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.midnightBlue,
            text: ride.destinationName,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _compactInfo(
                  Icons.directions_car_rounded,
                  ride.vehicleModel?.trim().isNotEmpty == true
                      ? ride.vehicleModel!
                      : 'Vehicle',
                ),
              ),
              const SizedBox(width: 8),
              _compactInfo(
                Icons.people_alt_rounded,
                '${ride.availableSeats} ${ride.availableSeats == 1 ? 'seat' : 'seats'}',
              ),
              const SizedBox(width: 10),
              _compactInfo(
                Icons.currency_rupee_rounded,
                '₹${ride.farePerSeat.toStringAsFixed(0)}/seat',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeLine({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.midnightBlue,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.primaryTealDark,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.midnightBlue,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LONG-PRESS DETAILS MODAL
  // ============================================================

  Future<void> _showRideDetails(_PublishedRide ride) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _RideDetailsSheet(
        ride: ride,
        onEdit: ride.canEdit
            ? () async {
                Navigator.of(context).pop();
                await _openEditRide(ride);
              }
            : null,
        onCancel: _canCancelRide(ride)
            ? () async {
                Navigator.of(context).pop();
                await _cancelRide(ride);
              }
            : null,
      ),
    );
  }

  // ============================================================
  // EDIT RIDE
  // ============================================================

  bool _canCancelRide(_PublishedRide ride) {
    if (ride.status.toLowerCase() != 'scheduled') {
      return false;
    }

    if (ride.hasBooking) {
      return false;
    }

    final now = DateTime.now();
    final departure = ride.departureTime.toLocal();
    final remaining = departure.difference(now);

    // Keep the same 10-minute safety window used by ride editing.
    return remaining > const Duration(minutes: 10);
  }

  Future<void> _cancelRide(_PublishedRide ride) async {
    if (_rideActionInProgress) return;

    if (!_canCancelRide(ride)) {
      _showRideMessage(
        ride.hasBooking
            ? 'This ride cannot be cancelled because a booking exists.'
            : 'This scheduled ride can no longer be cancelled.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final departure = ride.departureTime.toLocal();

        return AlertDialog(
          title: const Text('Cancel Scheduled Ride?'),
          content: Text(
            'Are you sure you want to cancel this ride?\\n\\n'
            '${ride.originName} → ${ride.destinationName}\\n'
            '${_formatDateShort(departure)} • ${_formatTime(departure)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Ride'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Ride'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _rideActionInProgress = true);

    try {
      await ApiClient.instance.patch(
        '${ApiEndpoints.rides}/${ride.rideId}/cancel',
      );

      if (!mounted) return;

      _showRideMessage('Ride cancelled successfully.');
      await _fetchMyRides();
    } catch (e) {
      if (!mounted) return;
      _showRideMessage('Could not cancel ride: $e');
    }  
      finally {
      if (mounted) {
        setState(() => _rideActionInProgress = false);
      }
    }
  }

  Future<void> _openEditRide(_PublishedRide ride) async {
    if (_rideActionInProgress) return;

    if (!ride.canEdit) {
      _showRideMessage(
        ride.editBlockReason ?? 'This ride cannot be edited right now.',
      );
      return;
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _EditRideSheet(ride: ride),
    );

    if (updated != true || !mounted) return;

    await _fetchMyRides();
  }

  void _showRideMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _formatDateShort(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  static String _formatDateLong(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ============================================================
  // TIME FORMATTER
  // ============================================================

  static String _formatTime(
    DateTime dt,
  ) {
    final local =
        dt.toLocal();

    final hour =
        local.hour > 12
            ? local.hour - 12
            : (local.hour == 0
                ? 12
                : local.hour);

    final minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        local.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }
}


// =================================================================
// PUBLISHED RIDE DATA
// =================================================================

class _PublishedRide {
  final int rideId;
  final String originName;
  final double originLat;
  final double originLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final DateTime departureTime;
  final bool rideNow;
  final int availableSeats;
  final int vehicleId;
  final String? vehicleModel;
  final String? vehicleRegistrationNumber;
  final String? vehicleCategory;
  final String? vehicleSubtype;
  final String? vehicleTypeSpecified;
  final int? seatingCapacity;
  final double farePerSeat;
  final double routeDistanceMeters;
  final double routeDurationSeconds;
  final List<Map<String, dynamic>> routeGeometry;
  final List<Map<String, dynamic>> stops;
  final List<Map<String, dynamic>> routeLegs;
  final bool isWomenOnly;
  final bool democraticConsent;
  final bool flexiblePickup;
  final bool allowLuggage;
  final bool allowPets;
  final bool allowMusic;
  final bool isAc;
  final String additionalNotes;
  final String status;
  final bool hasBooking;
  final bool canEdit;
  final String? editBlockReason;

  const _PublishedRide({
    required this.rideId,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.departureTime,
    required this.rideNow,
    required this.availableSeats,
    required this.vehicleId,
    required this.vehicleModel,
    required this.vehicleRegistrationNumber,
    required this.vehicleCategory,
    required this.vehicleSubtype,
    required this.vehicleTypeSpecified,
    required this.seatingCapacity,
    required this.farePerSeat,
    required this.routeDistanceMeters,
    required this.routeDurationSeconds,
    required this.routeGeometry,
    required this.stops,
    required this.routeLegs,
    required this.isWomenOnly,
    required this.democraticConsent,
    required this.flexiblePickup,
    required this.allowLuggage,
    required this.allowPets,
    required this.allowMusic,
    required this.isAc,
    required this.additionalNotes,
    required this.status,
    required this.hasBooking,
    required this.canEdit,
    required this.editBlockReason,
  });

  factory _PublishedRide.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _mapList(dynamic value) {
      if (value is! List) return <Map<String, dynamic>>[];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    double _double(dynamic value) =>
        value == null ? 0.0 : double.tryParse(value.toString()) ?? 0.0;

    int _int(dynamic value) =>
        value == null ? 0 : int.tryParse(value.toString()) ?? 0;

    return _PublishedRide(
      rideId: _int(json['ride_id']),
      originName: json['origin_name']?.toString() ?? '',
      originLat: _double(json['origin_lat']),
      originLng: _double(json['origin_lng']),
      destinationName: json['destination_name']?.toString() ?? '',
      destinationLat: _double(json['destination_lat']),
      destinationLng: _double(json['destination_lng']),
      departureTime: DateTime.tryParse(
            json['departure_time']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      rideNow: json['ride_now'] == true,
      availableSeats: _int(json['available_seats']),
      vehicleId: _int(json['vehicle_id']),
      vehicleModel: json['vehicle_model']?.toString(),
      vehicleRegistrationNumber:
          json['vehicle_registration_number']?.toString(),
      vehicleCategory: json['vehicle_category']?.toString(),
      vehicleSubtype: json['vehicle_subtype']?.toString(),
      vehicleTypeSpecified: json['vehicle_type_specified']?.toString(),
      seatingCapacity: json['seating_capacity'] == null
          ? null
          : _int(json['seating_capacity']),
      farePerSeat: _double(json['fare_per_seat']),
      routeDistanceMeters: _double(json['route_distance_meters']),
      routeDurationSeconds: _double(json['route_duration_seconds']),
      routeGeometry: _mapList(json['route_geometry']),
      stops: _mapList(json['stops']),
      routeLegs: _mapList(json['route_legs']),
      isWomenOnly: json['is_women_only'] == true,
      democraticConsent: json['democratic_consent'] != false,
      flexiblePickup: json['flexible_pickup'] == true,
      allowLuggage: json['allow_luggage'] == true,
      allowPets: json['allow_pets'] == true,
      allowMusic: json['allow_music'] == true,
      isAc: json['is_ac'] == true,
      additionalNotes: json['additional_notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      hasBooking: json['has_booking'] == true,
      canEdit: json['can_edit'] == true,
      editBlockReason: json['edit_block_reason']?.toString(),
    );
  }

  Map<String, dynamic> toUpdateJson({
    required DateTime departureTime,
    required int availableSeats,
    required bool isWomenOnly,
    required bool democraticConsent,
    required bool flexiblePickup,
    required bool allowLuggage,
    required bool allowPets,
    required bool allowMusic,
    required bool isAc,
    required String additionalNotes,
  }) {
    return {
      'origin_name': originName,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_name': destinationName,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'departure_time': departureTime.toUtc().toIso8601String(),
      'ride_now': false,
      'available_seats': availableSeats,
      'vehicle_id': vehicleId,
      'route_distance_meters': routeDistanceMeters,
      'route_duration_seconds': routeDurationSeconds,
      'route_geometry': routeGeometry,
      'stops': stops,
      'route_legs': routeLegs,
      'is_women_only': isWomenOnly,
      'democratic_consent': democraticConsent,
      'flexible_pickup': flexiblePickup,
      'allow_luggage': allowLuggage,
      'allow_pets': allowPets,
      'allow_music': allowMusic,
      'is_ac': isAc,
      'additional_notes': additionalNotes,
    };
  }
}

// =================================================================
// RIDE DETAILS SHEET
// =================================================================

class _RideDetailsSheet extends StatelessWidget {
  final _PublishedRide ride;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const _RideDetailsSheet({
    required this.ride,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final departure = ride.departureTime.toLocal();
    final dateLabel = _RiderHostDashboardState._formatDateLong(departure);
    final timeLabel = _RiderHostDashboardState._formatTime(departure);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderGray,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const Spacer(),
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 17),
                      label: const Text('Edit Ride'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryTealDark,
                      ),
                    ),
                  if (onCancel != null)
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 17,
                      ),
                      label: const Text('Cancel Ride'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    )
                  else if (onEdit == null)
                    const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                children: [
                  Row(
                    children: [
                      _statusPill(ride.status),
                      const Spacer(),
                      if (!ride.canEdit &&
                          ride.editBlockReason != null &&
                          ride.editBlockReason!.isNotEmpty)
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AppColors.mediumGray,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _section(
                    'Journey',
                    Icons.route_rounded,
                    Column(
                      children: [
                        _detailRow('Source', ride.originName),
                        _detailRow(
                          'Stops',
                          ride.stops.isEmpty
                              ? 'No intermediate stops'
                              : ride.stops
                                  .map((stop) =>
                                      '${stop['stop_order'] ?? ''}. ${stop['stop_name'] ?? ''}')
                                  .join('\n'),
                        ),
                        _detailRow('Destination', ride.destinationName),
                        _detailRow('Distance', _formatDistance(ride.routeDistanceMeters)),
                        _detailRow('Duration', _formatDuration(ride.routeDurationSeconds)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    'Schedule',
                    Icons.schedule_rounded,
                    Column(
                      children: [
                        _detailRow('Departure date', dateLabel),
                        _detailRow('Departure time', timeLabel),
                        _detailRow('Ride mode', ride.rideNow ? 'Ride Now' : 'Scheduled'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    'Vehicle & Fare',
                    Icons.directions_car_rounded,
                    Column(
                      children: [
                        _detailRow('Vehicle', ride.vehicleModel ?? 'Vehicle'),
                        _detailRow(
                          'Registration',
                          ride.vehicleRegistrationNumber ?? 'Registered',
                        ),
                        _detailRow('Category', ride.vehicleCategory ?? '—'),
                        _detailRow('Subtype', ride.vehicleSubtype ?? '—'),
                        _detailRow(
                          'Seating capacity',
                          ride.seatingCapacity?.toString() ?? '—',
                        ),
                        _detailRow('Available seats', '${ride.availableSeats}'),
                        _detailRow(
                          'Booking status',
                          ride.hasBooking ? 'Booking exists' : 'No booking',
                        ),
                        _detailRow(
                          'Fare per seat',
                          '₹${ride.farePerSeat.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    'Ride Preferences',
                    Icons.tune_rounded,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _preference('Women only', ride.isWomenOnly),
                        _preference('Flexible pickup', ride.flexiblePickup),
                        _preference('Luggage', ride.allowLuggage),
                        _preference('Pets', ride.allowPets),
                        _preference('Music', ride.allowMusic),
                        _preference('AC', ride.isAc),
                        _preference('Consent', ride.democraticConsent),
                      ],
                    ),
                  ),
                  if (ride.status.toLowerCase() == 'scheduled' &&
                      ride.hasBooking) ...[
                    const SizedBox(height: 12),
                    _actionInfo(
                      Icons.lock_outline_rounded,
                      'Cancellation is unavailable because this ride has a booking.',
                    ),
                  ] else if (ride.status.toLowerCase() == 'scheduled' &&
                      ride.departureTime
                              .toLocal()
                              .difference(DateTime.now()) <=
                          const Duration(minutes: 10)) ...[
                    const SizedBox(height: 12),
                    _actionInfo(
                      Icons.schedule_rounded,
                      'Cancellation is available only more than 10 minutes before departure.',
                    ),
                  ],
                  if (ride.additionalNotes.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _section(
                      'Additional Notes',
                      Icons.notes_rounded,
                      Text(
                        ride.additionalNotes,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  if (onEdit == null &&
                      ride.editBlockReason != null &&
                      ride.editBlockReason!.isNotEmpty &&
                      ride.status.toLowerCase() != 'scheduled') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.mediumGray,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.editBlockReason!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mediumGray,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _actionInfo(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.mediumGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mediumGray,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryTealSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primaryTealDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Widget _section(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 18, color: AppColors.primaryTealDark),
              const SizedBox(width: 7),
              Text(
                title,
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.midnightBlue,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _preference(String label, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primaryTealSurface
            : AppColors.softGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? AppColors.primaryTeal.withAlpha(80)
              : AppColors.borderGray,
        ),
      ),
      child: Text(
        '$label: ${enabled ? 'Yes' : 'No'}',
        style: AppTextStyles.caption.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: enabled
              ? AppColors.primaryTealDark
              : AppColors.mediumGray,
        ),
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters <= 0) return '—';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  static String _formatDuration(double seconds) {
    if (seconds <= 0) return '—';
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${duration.inMinutes} min';
  }
}

// =================================================================
// EDIT RIDE SHEET
// =================================================================

class _EditRideSheet extends StatefulWidget {
  final _PublishedRide ride;

  const _EditRideSheet({required this.ride});

  @override
  State<_EditRideSheet> createState() => _EditRideSheetState();
}

class _EditRideSheetState extends State<_EditRideSheet> {
  late DateTime _departure;
  late int _availableSeats;
  late bool _womenOnly;
  late bool _democraticConsent;
  late bool _flexiblePickup;
  late bool _allowLuggage;
  late bool _allowPets;
  late bool _allowMusic;
  late bool _isAc;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _departure = widget.ride.departureTime.toLocal();
    _availableSeats = widget.ride.availableSeats;
    _womenOnly = widget.ride.isWomenOnly;
    _democraticConsent = widget.ride.democraticConsent;
    _flexiblePickup = widget.ride.flexiblePickup;
    _allowLuggage = widget.ride.allowLuggage;
    _allowPets = widget.ride.allowPets;
    _allowMusic = widget.ride.allowMusic;
    _isAc = widget.ride.isAc;
    _notesController = TextEditingController(
      text: widget.ride.additionalNotes,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _departure,
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departure),
    );

    if (time == null || !mounted) return;

    setState(() {
      _departure = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final minimum = DateTime.now().add(const Duration(minutes: 10));
    if (!_departure.isAfter(minimum)) {
      _showError('Departure must be more than 10 minutes from now.');
      return;
    }

    final ride = widget.ride;
    final payload = ride.toUpdateJson(
      departureTime: _departure,
      availableSeats: _availableSeats,
      isWomenOnly: _womenOnly,
      democraticConsent: _democraticConsent,
      flexiblePickup: _flexiblePickup,
      allowLuggage: _allowLuggage,
      allowPets: _allowPets,
      allowMusic: _allowMusic,
      isAc: _isAc,
      additionalNotes: _notesController.text.trim(),
    );

    try {
      await ApiClient.instance.patch(
        '${ApiEndpoints.rides}/${ride.rideId}',
        body: payload,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError('Could not update ride: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSeats = widget.ride.seatingCapacity == null
        ? widget.ride.availableSeats
        : (widget.ride.seatingCapacity! - 1).clamp(1, 99);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Ride',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                children: [
                  _readOnlyRouteCard(),
                  const SizedBox(height: 12),
                  _editSection(
                    title: 'Departure',
                    icon: Icons.schedule_rounded,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${_RiderHostDashboardState._formatDateLong(_departure)} • ${_RiderHostDashboardState._formatTime(_departure)}',
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text('Change the scheduled departure time.'),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: _pickDeparture,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _editSection(
                    title: 'Available Seats',
                    icon: Icons.people_alt_rounded,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _availableSeats > 1
                              ? () => setState(() => _availableSeats--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '$_availableSeats',
                              style: AppTextStyles.h2.copyWith(fontSize: 22),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _availableSeats < maxSeats
                              ? () => setState(() => _availableSeats++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _editSection(
                    title: 'Ride Preferences',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _switch('Women only', _womenOnly,
                            (v) => setState(() => _womenOnly = v)),
                        _switch('Passenger consent', _democraticConsent,
                            (v) => setState(() => _democraticConsent = v)),
                        _switch('Flexible pickup', _flexiblePickup,
                            (v) => setState(() => _flexiblePickup = v)),
                        _switch('Luggage allowed', _allowLuggage,
                            (v) => setState(() => _allowLuggage = v)),
                        _switch('Pets allowed', _allowPets,
                            (v) => setState(() => _allowPets = v)),
                        _switch('Music allowed', _allowMusic,
                            (v) => setState(() => _allowMusic = v)),
                        _switch('AC', _isAc,
                            (v) => setState(() => _isAc = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _editSection(
                    title: 'Additional Notes',
                    icon: Icons.notes_rounded,
                    child: TextField(
                      controller: _notesController,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: 'Add notes for passengers...',
                        filled: true,
                        fillColor: AppColors.softGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightBlue,
                        foregroundColor: AppColors.primaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

  Widget _readOnlyRouteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.route_rounded,
                  size: 18, color: AppColors.primaryTealDark),
              const SizedBox(width: 7),
              Text(
                'Route',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              const Text(
                'Current route',
                style: TextStyle(fontSize: 10, color: AppColors.mediumGray),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.ride.originName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          if (widget.ride.stops.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              '${widget.ride.stops.length} intermediate ${widget.ride.stops.length == 1 ? 'stop' : 'stops'}',
              style: AppTextStyles.caption.copyWith(color: AppColors.mediumGray),
            ),
          ],
          const SizedBox(height: 5),
          Text(
            widget.ride.destinationName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            'Vehicle changes are not available in this editor yet; the verified vehicle remains attached to this ride.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.mediumGray,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 18, color: AppColors.primaryTealDark),
              const SizedBox(width: 7),
              Text(title,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryTealDark,
    );
  }
}

// =================================================================
// VERIFICATION PILL
// =================================================================

class _VerifyPill
    extends StatelessWidget {
  final String label;
  final bool isDone;

  const _VerifyPill({
    required this.label,
    required this.isDone,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      decoration:
          BoxDecoration(
        color: isDone
            ? AppColors
                .verifiedGreen
                .withAlpha(40)
            : AppColors
                .white
                .withAlpha(25),

        borderRadius:
            BorderRadius.circular(
          8,
        ),

        border:
            Border.all(
          color: isDone
              ? AppColors
                  .verifiedGreen
              : AppColors
                  .primaryTeal
                  .withAlpha(80),
        ),
      ),

      child: Text(
        label,
        style:
            AppTextStyles
                .caption
                .copyWith(
          color:
              AppColors.white,
          fontSize: 10,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }
}

// =================================================================
// STAT ITEM
// =================================================================

class _StatItem
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          value,
          style:
              AppTextStyles.label
                  .copyWith(
            fontWeight:
                FontWeight.w800,
            fontSize: 14,
          ),
        ),

        Text(
          label,
          style:
              AppTextStyles.caption
                  .copyWith(
            fontSize: 10,
            color:
                AppColors
                    .mediumGray,
          ),
        ),
      ],
    );
  }
}