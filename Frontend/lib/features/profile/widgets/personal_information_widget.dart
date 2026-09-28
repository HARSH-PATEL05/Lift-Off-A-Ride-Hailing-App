import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Displays the user's personal/account information.
///
/// This widget is intentionally responsible only for displaying profile data
/// and presenting the phone-verification UI.
///
/// The actual OTP operations are supplied by the parent through
/// [onSendPhoneOtp] and [onVerifyPhone].
class PersonalInformationWidget extends StatefulWidget {
  final String? name;
  final String? email;
  final String? phoneNumber;
  final bool emailVerified;
  final bool phoneVerified;

  /// Called when the user requests a phone verification OTP.
  ///
  /// In development mode, the parent can bypass SMS delivery.
  ///
  /// In production mode, this will use the real Supabase/Twilio flow.
  final Future<bool> Function()? onSendPhoneOtp;

  /// Called when the user submits a 6-digit phone OTP.
  ///
  /// In development mode, any 6-digit OTP can be accepted.
  ///
  /// In production mode, this will use Supabase OTP verification.
  final Future<bool> Function(String otp)? onVerifyPhone;

  const PersonalInformationWidget({
    super.key,
    this.name,
    this.email,
    this.phoneNumber,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.onSendPhoneOtp,
    this.onVerifyPhone,
  });

  @override
  State<PersonalInformationWidget> createState() =>
      _PersonalInformationWidgetState();
}

class _PersonalInformationWidgetState
    extends State<PersonalInformationWidget> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Name',
        widget.name?.trim().isNotEmpty == true
            ? widget.name!.trim()
            : 'Not available',
        Icons.person_outline_rounded,
      ),
      (
        'Email',
        widget.email?.trim().isNotEmpty == true
            ? widget.email!.trim()
            : 'Not available',
        Icons.email_outlined,
      ),
      (
        'Phone',
        widget.phoneNumber?.trim().isNotEmpty == true
            ? widget.phoneNumber!.trim()
            : 'Not added yet',
        Icons.phone_outlined,
      ),
    ];

    final selected = items[_selectedIndex];

    return Material(
      color: AppColors.white,
      elevation: 3,
      shadowColor: AppColors.shadowLight,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          children: [
            Row(
              children: List.generate(items.length, (index) {
                final active = index == _selectedIndex;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == items.length - 1 ? 0 : 8,
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryTealSurface
                              : const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? AppColors.primaryTeal
                                : AppColors.borderGray,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              items[index].$3,
                              size: 19,
                              color: active
                                  ? AppColors.primaryTealDark
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              items[index].$1,
                              style: AppTextStyles.caption.copyWith(
                                color: active
                                    ? AppColors.primaryTealDark
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 18),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTealSurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    selected.$3,
                    color: AppColors.primaryTealDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.$1,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selected.$2,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.midnightBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      // Email verification
                      if (_selectedIndex == 1 &&
                          widget.emailVerified) ...[
                        const SizedBox(height: 5),
                        const _VerifiedBadge(),
                      ],

                      // Phone verification status
                      if (_selectedIndex == 2) ...[
                        const SizedBox(height: 5),
                        Text(
                          widget.phoneVerified
                              ? 'Verified'
                              : 'Not verified',
                          style: AppTextStyles.caption.copyWith(
                            color: widget.phoneVerified
                                ? AppColors.verifiedGreen
                                : Colors.orange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ─────────────────────────────────────
            // VERIFY PHONE BUTTON
            // ─────────────────────────────────────

            if (_selectedIndex == 2 &&
                !widget.phoneVerified &&
                widget.phoneNumber?.trim().isNotEmpty == true &&
                widget.onSendPhoneOtp != null &&
                widget.onVerifyPhone != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _startPhoneVerification(context),
                  icon: const Icon(
                    Icons.verified_user_outlined,
                  ),
                  label: const Text('Verify Phone'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // START PHONE VERIFICATION
  // ─────────────────────────────────────────────

  Future<void> _startPhoneVerification(
    BuildContext context,
  ) async {
    final sendOtp = widget.onSendPhoneOtp;
    final verifyOtp = widget.onVerifyPhone;

    if (sendOtp == null || verifyOtp == null) {
      return;
    }

    try {
      // ─────────────────────────────────────────
      // SEND OTP
      // ─────────────────────────────────────────

      final sent = await sendOtp();

      if (!context.mounted) {
        return;
      }

      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to send OTP. Please try again.',
            ),
          ),
        );

        return;
      }

      // ─────────────────────────────────────────
      // OPEN OTP DIALOG
      // ─────────────────────────────────────────

      final verified = await _openOtpDialog(
        context,
        verifyOtp,
      );

      if (!context.mounted) {
        return;
      }

      // ─────────────────────────────────────────
      // SUCCESS
      // ─────────────────────────────────────────

      if (verified == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone number verified successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone verification failed: $e',
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // OTP DIALOG
  // ─────────────────────────────────────────────

  Future<bool?> _openOtpDialog(
    BuildContext context,
    Future<bool> Function(String otp) onVerifyPhone,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PhoneOtpDialog(
          phoneNumber: widget.phoneNumber ?? '',
          onVerifyPhone: onVerifyPhone,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// OTP DIALOG
// ═══════════════════════════════════════════════════════════════

class _PhoneOtpDialog extends StatefulWidget {
  final String phoneNumber;
  final Future<bool> Function(String otp) onVerifyPhone;

  const _PhoneOtpDialog({
    required this.phoneNumber,
    required this.onVerifyPhone,
  });

  @override
  State<_PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends State<_PhoneOtpDialog> {
  late final TextEditingController _controller;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
  }

  @override
  void dispose() {
    // The controller belongs to this dialog.
    // It is disposed only when the dialog itself is removed.
    _controller.dispose();

    super.dispose();
  }

  // ─────────────────────────────────────────────
  // VERIFY OTP
  // ─────────────────────────────────────────────

  Future<void> _verify() async {
    if (_submitting) {
      return;
    }

    final otp = _controller.text.trim();

    // ─────────────────────────────────────────────
    // Validate OTP
    // ─────────────────────────────────────────────

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid 6-digit OTP.',
          ),
        ),
      );

      return;
    }

    // ─────────────────────────────────────────────
    // Start verification
    // ─────────────────────────────────────────────

    setState(() {
      _submitting = true;
    });

    try {
      final success = await widget.onVerifyPhone(otp);

      // The dialog may have been removed while awaiting.
      if (!mounted) {
        return;
      }

      if (success) {
        // Return success to the parent.
        //
        // The parent will display the success SnackBar
        // after the dialog has completely closed.
        Navigator.of(context).pop(true);

        return;
      }

      // ─────────────────────────────────────────
      // Verification failed
      // ─────────────────────────────────────────

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid OTP. Please try again.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'OTP verification failed: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Verify Phone',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the 6-digit OTP sent to',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            widget.phoneNumber,
            style: AppTextStyles.label.copyWith(
              color: AppColors.midnightBlue,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '6-digit OTP',
              hintText: '123456',
              counterText: '',
            ),
          ),
        ],
      ),

      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _submitting ? null : _verify,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// VERIFIED BADGE
// ═══════════════════════════════════════════════════════════════

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.verified_rounded,
          size: 15,
          color: AppColors.verifiedGreen,
        ),
        const SizedBox(width: 4),
        Text(
          'Verified',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primaryTealDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}