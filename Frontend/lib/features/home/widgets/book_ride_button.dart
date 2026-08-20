import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/data/mock_data.dart';

/// Primary Call-to-Action for Requesting a Seat on a Host's Commute
class BookRideButton extends StatefulWidget {
  final String selectedServiceId;
  final VoidCallback onBook;

  const BookRideButton({
    super.key,
    required this.selectedServiceId,
    required this.onBook,
  });

  @override
  State<BookRideButton> createState() => _BookRideButtonState();
}

class _BookRideButtonState extends State<BookRideButton> {
  bool _isPressed = false;
  bool _isLoading = false;

  CommunityRide get _selectedRide {
    return MockData.communityRides.firstWhere(
      (r) => r.id == widget.selectedServiceId,
      orElse: () => MockData.communityRides.first,
    );
  }

  void _handleTap() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onBook();
  }

  @override
  Widget build(BuildContext context) {
    final ride = _selectedRide;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _isLoading ? null : _handleTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: AppColors.tealGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.tealGlow,
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.midnightBlue,
                        ),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.airline_seat_recline_extra_rounded,
                        color: AppColors.midnightBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Request Seat with ${ride.host.name.split(' ').first}',
                        style: AppTextStyles.buttonPrimary.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.midnightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${ride.fuelSharePerSeat.toInt()}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
