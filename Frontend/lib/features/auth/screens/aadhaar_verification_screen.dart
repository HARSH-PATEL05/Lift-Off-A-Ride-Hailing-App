import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/verification_service.dart';
import '../../../core/api/api_exceptions.dart';

/// LiftOff — Aadhaar Verification Screen
/// User enters 12-digit Aadhaar number → calls FastAPI → sandbox verify.
class AadhaarVerificationScreen extends StatefulWidget {
  final UserProfile userProfile;

  /// Called when verification succeeds with updated profile.
  final ValueChanged<UserProfile> onVerified;

  const AadhaarVerificationScreen({
    super.key,
    required this.userProfile,
    required this.onVerified,
  });

  @override
  State<AadhaarVerificationScreen> createState() =>
      _AadhaarVerificationScreenState();
}

class _AadhaarVerificationScreenState extends State<AadhaarVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _aadhaarController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isVerifying = false;
  String? _errorMessage;
  bool _isSuccess = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final updatedProfile = await VerificationService.instance
          .verifyAadhaar(_aadhaarController.text);

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isVerifying = false;
        });

        // Short success animation before navigating
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onVerified(updatedProfile);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Something went wrong. Please try again.';
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // ─── Header ───
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? AppColors.verifiedGreenLight
                        : AppColors.primaryTealSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _isSuccess
                        ? Icons.verified_rounded
                        : Icons.fingerprint_rounded,
                    color: _isSuccess
                        ? AppColors.verifiedGreen
                        : AppColors.primaryTealDark,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  _isSuccess ? 'Aadhaar Verified! ✅' : 'Verify Your Identity',
                  style: AppTextStyles.display.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),

                Text(
                  _isSuccess
                      ? 'Your identity has been confirmed. Redirecting to dashboard...'
                      : 'We need to verify your Aadhaar to ensure community safety. '
                          'Your data is encrypted and never stored in plain text.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.mediumGray,
                    height: 1.6,
                  ),
                ),

                // User info card
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.softGray,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryTealSurface,
                        child: Text(
                          (widget.userProfile.fullName ?? 'U')[0].toUpperCase(),
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.primaryTealDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userProfile.fullName ?? 'User',
                              style: AppTextStyles.label,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.userProfile.email,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Aadhaar Input ───
                const SizedBox(height: 32),
                if (!_isSuccess) ...[
                  Text(
                    'AADHAAR NUMBER',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _aadhaarController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                        _AadhaarInputFormatter(),
                      ],
                      style: AppTextStyles.h1.copyWith(
                        fontSize: 24,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '0000 0000 0000',
                        hintStyle: AppTextStyles.h1.copyWith(
                          fontSize: 24,
                          letterSpacing: 3,
                          color: AppColors.lightGray,
                          fontWeight: FontWeight.w400,
                        ),
                        filled: true,
                        fillColor: AppColors.softGray,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.borderGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primaryTeal, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.errorRed),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 16, right: 8),
                          child: Icon(
                            Icons.badge_rounded,
                            color: AppColors.mediumGray,
                            size: 22,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                      ),
                      validator: (value) {
                        final digits =
                            value?.replaceAll(RegExp(r'\D'), '') ?? '';
                        if (digits.length != 12) {
                          return 'Please enter a valid 12-digit Aadhaar number';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRedLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.errorRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ─── Verify Button ───
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: AppColors.midnightBlue,
                        disabledBackgroundColor: AppColors.lightGray,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.midnightBlue,
                              ),
                            )
                          : Text(
                              'Verify Aadhaar',
                              style: AppTextStyles.buttonPrimary,
                            ),
                    ),
                  ),

                  // Trust note
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded,
                          size: 14, color: AppColors.subtleGray),
                      const SizedBox(width: 6),
                      Text(
                        'End-to-end encrypted • UIDAI sandbox verified',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.subtleGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom input formatter that adds spaces every 4 digits (Aadhaar format).
class _AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 12; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
