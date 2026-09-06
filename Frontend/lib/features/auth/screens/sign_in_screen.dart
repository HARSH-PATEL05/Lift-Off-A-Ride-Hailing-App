import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../widgets/google_sign_in_button.dart';

/// LiftOff — Sign In Screen
/// Beautiful branded screen with Google OAuth sign-in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      // AuthGate will react to auth state change automatically
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ─── Logo & Branding ───
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.tealGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.tealGlow,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: AppColors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // App name
                  Text(
                    'LiftOff',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Community-Powered Shared Mobility',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 15,
                      color: AppColors.mediumGray,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🌿  Share rides · Save fuel · Build trust',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryTealDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ─── Features Preview ───
                  _FeaturePill(
                    icon: Icons.verified_user_rounded,
                    text: 'Govt ID Verified Commuters',
                    color: AppColors.verifiedGreen,
                    bgColor: AppColors.verifiedGreenLight,
                  ),
                  const SizedBox(height: 10),
                  _FeaturePill(
                    icon: Icons.how_to_vote_rounded,
                    text: 'Democratic Co-Consent Rides',
                    color: const Color(0xFFD97706),
                    bgColor: AppColors.amberPollLight,
                  ),
                  const SizedBox(height: 10),
                  _FeaturePill(
                    icon: Icons.female_rounded,
                    text: 'Women-Only Safe Commute',
                    color: AppColors.womenOnlyPink,
                    bgColor: AppColors.womenOnlyPinkLight,
                  ),

                  const Spacer(flex: 1),

                  // ─── Sign-In Button ───
                  GoogleSignInButton(
                    onPressed: _handleGoogleSignIn,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Terms
                  Text(
                    'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.subtleGray,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color bgColor;

  const _FeaturePill({
    required this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
