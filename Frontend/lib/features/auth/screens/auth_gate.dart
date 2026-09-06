import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../app_shell.dart';
import 'sign_in_screen.dart';
import 'aadhaar_verification_screen.dart';

/// LiftOff — Auth Gate
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _AuthPhase {
  loading,
  signIn,
  verifyAadhaar,
  dashboard,
}

class _AuthGateState extends State<AuthGate> {
  _AuthPhase _phase = _AuthPhase.loading;

  UserProfile? _userProfile;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    print('🚀 AuthGate initState() CALLED');

    _authSubscription =
        AuthService.instance.onAuthStateChange.listen(_onAuthStateChanged);

    _checkCurrentSession();
  }

  @override
  void dispose() {
    print('🛑 AuthGate dispose() CALLED');

    _authSubscription?.cancel();

    super.dispose();
  }

  // ─────────────────────────────────────
  // CHECK EXISTING SUPABASE SESSION
  // ─────────────────────────────────────

  Future<void> _checkCurrentSession() async {
    print('');
    print('🔍 CHECKING CURRENT SUPABASE SESSION');

    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    print('Session exists: ${session != null}');
    print('User exists: ${user != null}');

    print(
      'AuthService says signed in: '
      '${AuthService.instance.isSignedIn}',
    );

    if (AuthService.instance.isSignedIn) {
      print('✅ EXISTING SESSION FOUND');

      await _syncAndNavigate();
    } else {
      print('❌ NO EXISTING SESSION');

      if (mounted) {
        setState(() => _phase = _AuthPhase.signIn);
      }
    }
  }

  // ─────────────────────────────────────
  // SUPABASE AUTH STATE EVENTS
  // ─────────────────────────────────────

  void _onAuthStateChanged(AuthState authState) {
    final event = authState.event;

    print('');
    print('🔐 SUPABASE AUTH EVENT RECEIVED');
    print('Event: $event');
    print('Session exists: ${authState.session != null}');

    final eventUser = authState.session?.user;

    print('Event User ID: ${eventUser?.id}');
    print('Event Email: ${eventUser?.email}');

    if (event == AuthChangeEvent.signedIn) {
      print('✅ SIGNED IN EVENT DETECTED');

      _syncAndNavigate();
    } else if (event == AuthChangeEvent.signedOut) {
      print('🚪 SIGNED OUT EVENT DETECTED');

      if (mounted) {
        setState(() {
          _phase = _AuthPhase.signIn;
          _userProfile = null;
        });
      }
    }
  }

  // ─────────────────────────────────────
  // INSPECT SUPABASE DATA + BACKEND SYNC
  // ─────────────────────────────────────

  Future<void> _syncAndNavigate() async {
    print('');
    print('🔥 _syncAndNavigate() CALLED');

    if (mounted) {
      setState(() => _phase = _AuthPhase.loading);
    }

    // Get current Supabase session
    final session = Supabase.instance.client.auth.currentSession;

    // Get current authenticated user
    final user = Supabase.instance.client.auth.currentUser;

    print('');
    print('========== SUPABASE AUTH DATA ==========');

    print('Session exists: ${session != null}');
    print('User exists: ${user != null}');

    print('');
    print('---------- USER INFORMATION ----------');

    print('User ID: ${user?.id}');
    print('Email: ${user?.email}');
    print('Phone: ${user?.phone}');

    print('');
    print('---------- USER METADATA ----------');

    print(user?.userMetadata);

    print('');
    print('---------- APP METADATA ----------');

    print(user?.appMetadata);

    print('');
    print('---------- SESSION INFORMATION ----------');

    print('Expires At: ${session?.expiresAt}');

    // We do NOT print the actual token.
    // Only confirm that it exists.
    print('Access Token Exists: ${session?.accessToken.isNotEmpty}');

    if (session != null) {
      print('Access Token Length: ${session.accessToken.length}');
    }

    print('========================================');

    // ─────────────────────────────────────
    // EXISTING BACKEND SYNC
    // ─────────────────────────────────────

    try {
      print('');
      print('🌐 CALLING BACKEND...');
      print('AuthService.syncWithBackend()');

      final profile =
          await AuthService.instance.syncWithBackend();

      print('✅ BACKEND RESPONSE RECEIVED');

      _userProfile = profile;

      print('Aadhaar Verified: ${profile.aadhaarVerified}');

      if (profile.aadhaarVerified) {
        print('➡️ NAVIGATING TO DASHBOARD');

        if (mounted) {
          setState(() => _phase = _AuthPhase.dashboard);
        }
      } else {
        print('➡️ NAVIGATING TO AADHAAR VERIFICATION');

        if (mounted) {
          setState(() => _phase = _AuthPhase.verifyAadhaar);
        }
      }
    } catch (e) {
      print('');
      print('❌ BACKEND SYNC ERROR');
      print(e);

      debugPrint('AuthGate sync error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() => _phase = _AuthPhase.signIn);
      }
    }
  }

  // ─────────────────────────────────────
  // UI
  // ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildCurrentPhase(),
    );
  }

  Widget _buildCurrentPhase() {
    switch (_phase) {
      case _AuthPhase.loading:
        return _LoadingSplash(
          key: const ValueKey('loading'),
        );

      case _AuthPhase.signIn:
        return const SignInScreen(
          key: ValueKey('sign_in'),
        );

      case _AuthPhase.verifyAadhaar:
        return AadhaarVerificationScreen(
          key: const ValueKey('verify_aadhaar'),
          userProfile: _userProfile!,
          onVerified: (profile) {
            setState(() {
              _userProfile = profile;
              _phase = _AuthPhase.dashboard;
            });
          },
        );

      case _AuthPhase.dashboard:
        return const AppShell(
          key: ValueKey('dashboard'),
        );
    }
  }
}

/// Loading splash shown during session check and backend sync.
class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.tealGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LiftOff',
              style: AppTextStyles.display,
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connecting...',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}