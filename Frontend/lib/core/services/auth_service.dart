import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/user_profile.dart';

/// LiftOff — Auth Service
/// Manages Supabase Google OAuth + Phone Verification
/// + FastAPI backend synchronization.
///
/// This is the single source of truth for authentication state.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final _apiClient = ApiClient.instance;
  final _supabase = Supabase.instance.client;

  /// ============================================================
  /// TEMPORARY DEVELOPMENT PHONE VERIFICATION
  /// ============================================================
  ///
  /// true:
  ///   - Supabase/Twilio SMS is bypassed.
  ///   - Any 6-digit OTP is accepted.
  ///   - Backend development endpoint marks the phone verified.
  ///
  /// false:
  ///   - Real Supabase phone verification is used.
  ///   - Supabase sends OTP through the configured SMS provider.
  ///
  /// IMPORTANT:
  /// Set this to false before production.
  static const bool useDevelopmentPhoneVerification = true;

  /// Cached user profile from backend.
  UserProfile? _cachedProfile;

  UserProfile? get currentProfile => _cachedProfile;

  // ─────────────────────────────────────────────
  // GOOGLE OAUTH SIGN-IN
  // ─────────────────────────────────────────────

  /// Trigger Supabase Google OAuth flow.
  ///
  /// Returns true if the OAuth flow was successfully launched.
  Future<bool> signInWithGoogle() async {
    try {
      final String redirectUrl;

      if (kIsWeb) {
        // Flutter Web / Chrome
        redirectUrl = 'http://localhost:8080';
      } else {
        // Windows/Desktop
        redirectUrl = 'io.supabase.liftoff://login-callback/';
      }

      debugPrint('');
      debugPrint('========== GOOGLE SIGN-IN STARTED ==========');
      debugPrint('Provider: Google');
      debugPrint('Running on Web: $kIsWeb');
      debugPrint('Redirect URL: $redirectUrl');
      debugPrint('============================================');

      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      debugPrint('OAuth browser launched: $response');

      return response;
    } catch (e) {
      debugPrint('');
      debugPrint('❌ AuthService.signInWithGoogle ERROR');
      debugPrint(e.toString());

      return false;
    }
  }

  // ─────────────────────────────────────────────
  // PHONE VERIFICATION
  // ─────────────────────────────────────────────

  /// Send a phone verification OTP.
  ///
  /// DEVELOPMENT MODE:
  /// No SMS is sent. The OTP screen is still shown,
  /// and any 6-digit OTP will be accepted.
  ///
  /// PRODUCTION MODE:
  /// Supabase sends the OTP through the configured
  /// SMS provider such as Twilio.
  Future<void> sendPhoneVerificationOtp(
    String phoneNumber,
  ) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'You must be signed in to verify a phone number.',
        );
      }

      final normalizedPhone = phoneNumber.trim();

      if (normalizedPhone.isEmpty) {
        throw Exception(
          'Please enter a valid phone number.',
        );
      }

      // ========================================================
      // TEMPORARY DEVELOPMENT MODE
      // ========================================================

      if (useDevelopmentPhoneVerification) {
        debugPrint('');
        debugPrint(
          '========== DEVELOPMENT PHONE VERIFICATION ==========',
        );
        debugPrint('User ID: ${user.id}');
        debugPrint('Phone: $normalizedPhone');
        debugPrint(
          '⚠️ SMS sending bypassed.',
        );
        debugPrint(
          '⚠️ Any 6-digit OTP will be accepted.',
        );
        debugPrint(
          '====================================================',
        );

        return;
      }

      // ========================================================
      // REAL SUPABASE + TWILIO FLOW
      // ========================================================

      debugPrint('');
      debugPrint('========== PHONE VERIFICATION ==========');
      debugPrint('User ID: ${user.id}');
      debugPrint('Sending OTP to: $normalizedPhone');

      await _supabase.auth.updateUser(
        UserAttributes(
          phone: normalizedPhone,
        ),
      );

      debugPrint('✅ Phone verification OTP sent');
      debugPrint('========================================');
    } on AuthException catch (e) {
      debugPrint(
        '❌ Supabase phone OTP error: ${e.message}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ AuthService.sendPhoneVerificationOtp error: $e',
      );

      rethrow;
    }
  }

  /// Verify the OTP sent to the user's phone.
  ///
  /// DEVELOPMENT MODE:
  /// Any 6-digit numeric OTP is accepted.
  ///
  /// REAL MODE:
  /// Supabase verifies the OTP using
  /// [OtpType.phoneChange].
  Future<User?> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final normalizedPhone = phoneNumber.trim();
      final normalizedOtp = otp.trim();

      if (normalizedPhone.isEmpty) {
        throw Exception(
          'Phone number is required.',
        );
      }

      if (normalizedOtp.isEmpty) {
        throw Exception(
          'OTP is required.',
        );
      }

      if (!RegExp(r'^\d{6}$').hasMatch(normalizedOtp)) {
        throw Exception(
          'OTP must contain exactly 6 digits.',
        );
      }

      // ========================================================
      // TEMPORARY DEVELOPMENT MODE
      // ========================================================

      if (useDevelopmentPhoneVerification) {
        final user = _supabase.auth.currentUser;

        if (user == null) {
          throw Exception(
            'You must be signed in to verify a phone number.',
          );
        }

        debugPrint('');
        debugPrint(
          '========== DEVELOPMENT OTP VERIFICATION ==========',
        );
        debugPrint('Phone: $normalizedPhone');
        debugPrint('OTP: $normalizedOtp');
        debugPrint(
          '✅ Any 6-digit OTP accepted.',
        );
        debugPrint(
          '==================================================',
        );

        return user;
      }

      // ========================================================
      // REAL SUPABASE + TWILIO FLOW
      // ========================================================

      debugPrint('');
      debugPrint('========== VERIFY PHONE OTP ==========');
      debugPrint('Phone: $normalizedPhone');

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.phoneChange,
        token: normalizedOtp,
        phone: normalizedPhone,
      );

      final updatedUser = response.user;

      debugPrint(
        '✅ Phone OTP verified successfully',
      );

      debugPrint(
        'Verified phone: ${updatedUser?.phone}',
      );

      debugPrint(
        'Phone confirmed at: '
        '${updatedUser?.phoneConfirmedAt}',
      );

      debugPrint(
        '======================================',
      );

      return updatedUser;
    } on AuthException catch (e) {
      debugPrint(
        '❌ Supabase OTP verification error: ${e.message}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ AuthService.verifyPhoneOtp error: $e',
      );

      rethrow;
    }
  }

  /// Verify the phone OTP and synchronize the verified
  /// phone number with the LiftOff backend.
  ///
  /// DEVELOPMENT MODE:
  ///
  /// Flutter
  ///   ↓
  /// Any 6-digit OTP
  ///   ↓
  /// /auth/dev/verify-phone/{phone}
  ///   ↓
  /// PostgreSQL
  ///   ↓
  /// phone_verified = true
  ///
  /// REAL MODE:
  ///
  /// Flutter
  ///   ↓
  /// Supabase verifyOTP()
  ///   ↓
  /// /auth/sync
  ///   ↓
  /// PostgreSQL
  Future<UserProfile> verifyPhoneAndRefreshProfile({
    required String phoneNumber,
    required String otp,
  }) async {
    await verifyPhoneOtp(
      phoneNumber: phoneNumber,
      otp: otp,
    );

    final normalizedPhone = phoneNumber.trim();

    // ========================================================
    // TEMPORARY DEVELOPMENT BACKEND FLOW
    // ========================================================

    if (useDevelopmentPhoneVerification) {
      debugPrint(
        'Using development phone verification backend...',
      );

      final encodedPhone = Uri.encodeComponent(
        normalizedPhone,
      );

      final response = await _apiClient.post(
        '/auth/dev/verify-phone/$encodedPhone',
      );

      final profile = UserProfile.fromJson(
        response as Map<String, dynamic>,
      );

      _cachedProfile = profile;

      debugPrint(
        '✅ Development phone verification completed.',
      );

      debugPrint(
        'Phone: ${profile.phoneNumber}',
      );

      debugPrint(
        'Phone verified: ${profile.phoneVerified}',
      );

      return profile;
    }

    // ========================================================
    // REAL SUPABASE + BACKEND FLOW
    // ========================================================

    debugPrint(
      'Phone verified in Supabase.',
    );

    debugPrint(
      'Synchronizing verified phone with '
      'LiftOff backend...',
    );

    final profile = await syncWithBackend();

    debugPrint(
      'LiftOff backend profile synchronized.',
    );

    return profile;
  }

  // ─────────────────────────────────────────────
  // BACKEND SYNC
  // ─────────────────────────────────────────────

  /// Send the Supabase JWT to FastAPI backend.
  ///
  /// Backend will create the user if they don't exist,
  /// synchronize verified Supabase phone information,
  /// or return the existing user profile.
  Future<UserProfile> syncWithBackend() async {
    try {
      debugPrint('');
      debugPrint('========== BACKEND SYNC ==========');

      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      debugPrint(
        'Session exists: ${session != null}',
      );

      debugPrint(
        'User ID: ${user?.id}',
      );

      debugPrint(
        'User Email: ${user?.email}',
      );

      debugPrint(
        'Supabase phone: ${user?.phone}',
      );

      debugPrint(
        'Supabase phone confirmed at: '
        '${user?.phoneConfirmedAt}',
      );

      if (session == null) {
        throw Exception(
          'No Supabase session available',
        );
      }

      debugPrint(
        'JWT exists: ${session.accessToken.isNotEmpty}',
      );

      debugPrint(
        'Sending authenticated request to backend...',
      );

      final response = await _apiClient.post(
        ApiEndpoints.authSync,
      );

      debugPrint(
        'Backend response received',
      );

      final profile = UserProfile.fromJson(
        response as Map<String, dynamic>,
      );

      _cachedProfile = profile;

      debugPrint(
        'Aadhaar verified: '
        '${profile.aadhaarVerified}',
      );

      debugPrint(
        'Phone number: '
        '${profile.phoneNumber ?? 'Not provided'}',
      );

      debugPrint(
        'Phone verified: '
        '${profile.phoneVerified}',
      );

      debugPrint(
        '================================',
      );

      return profile;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint(
        '❌ Backend sync error: $e',
      );

      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────

  /// Fetch fresh user profile from backend.
  Future<UserProfile> getUserProfile() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.userProfile,
      );

      final profile = UserProfile.fromJson(
        response as Map<String, dynamic>,
      );

      _cachedProfile = profile;

      // debugPrint(
      //   'AuthService: Profile refreshed '
      //   '(phone=${profile.phoneNumber ?? 'not provided'}, '
      //   'phoneVerified=${profile.phoneVerified})',
      // );

      return profile;
    } on ApiException {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // SESSION CHECK
  // ─────────────────────────────────────────────

  /// Check if there's an active Supabase session.
  bool get isSignedIn =>
      _supabase.auth.currentSession != null;

  /// Get the current Supabase session.
  Session? get currentSession =>
      _supabase.auth.currentSession;

  /// Get the current Supabase user.
  User? get currentUser =>
      _supabase.auth.currentUser;

  /// Listen to authentication state changes.
  Stream<AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;

  // ─────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────

  /// Sign out from Supabase and clear cached data.
  Future<void> signOut() async {
    debugPrint('🚪 Signing out user...');

    await _supabase.auth.signOut();

    _cachedProfile = null;

    debugPrint('✅ User signed out');
  }
}