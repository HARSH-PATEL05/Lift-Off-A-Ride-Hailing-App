import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';

/// Active Ride Hub with 120s Democratic Co-Passenger Polling & Meeting Node Guidance
class LiveRideDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const LiveRideDrawer({super.key, required this.onClose});

  @override
  State<LiveRideDrawer> createState() => _LiveRideDrawerState();
}

class _LiveRideDrawerState extends State<LiveRideDrawer> {
  int _votingCountdown = 108;
  Timer? _pollTimer;
  bool _hasVoted = false;
  String? _voteDecision;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_votingCountdown > 0) {
        setState(() => _votingCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _formattedCountdown {
    final m = _votingCountdown ~/ 60;
    final s = _votingCountdown % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _castVote(bool accept) {
    HapticFeedback.heavyImpact();
    setState(() {
      _hasVoted = true;
      _voteDecision = accept ? 'Accepted ✅' : 'Declined ❌';
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = MockData.communityRides.first;
    final applicant = MockData.activeApplicant;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowHeavy,
            blurRadius: 36,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Status & Start OTP Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTealSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.primaryTealDark,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'En Route to Meeting Node',
                        style: AppTextStyles.label.copyWith(fontSize: 13),
                      ),
                      Text(
                        'ETA: 5 mins • ${ride.meetingNodeName}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // 4-Digit Security Start OTP
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.midnightBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'OTP: ',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '4829',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderGray),

          // ─── Embedded 120s Democratic Co-Passenger Polling Card ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.votingGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.amberPoll.withAlpha(120),
                  width: 1.5,
                ),
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
                          color: AppColors.amberPoll,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.how_to_vote_rounded,
                              color: AppColors.midnightBlue,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DEMOCRATIC CO-PASSENGER VOTE',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.midnightBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 120s Countdown Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.amberPoll),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer_rounded,
                              color: AppColors.amberPoll,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formattedCountdown,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.midnightBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Co-Passenger Details
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.womenOnlyPink.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: AppColors.womenOnlyPink,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  applicant.name,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.verifiedGreen,
                                  size: 14,
                                ),
                              ],
                            ),
                            Text(
                              '${applicant.pickupPoint} ➔ ${applicant.dropPoint} (${applicant.routeOverlapPercent}% corridor overlap)',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.deepSlate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Voting Action Chips
                  if (!_hasVoted)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.verifiedGreen,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _castVote(true),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.thumb_up_rounded, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Accept Passenger',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.subtleGray,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _castVote(false),
                            child: Text(
                              'Decline',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.mediumGray,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Your vote: $_voteDecision (Waiting for host consensus)',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.midnightBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Quick In-App Commute Chat Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ChatChip(label: "I'm at Gate 2 📍", onTap: () {}),
                const SizedBox(width: 6),
                _ChatChip(label: "Stuck 2 mins ⏳", onTap: () {}),
                const SizedBox(width: 6),
                _ChatChip(label: "Standing near post office", onTap: () {}),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _ChatChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChatChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.softGray,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.midnightBlue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
