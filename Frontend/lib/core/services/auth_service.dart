import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/user_profile.dart';

/// LiftOff — Auth Service
/// Manages Supabase Google OAuth + FastAPI backend synchronization.
/// This is the single source of truth for authentication state.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final _apiClient = ApiClient.instance;
  final _supabase = Supabase.instance.client;

  /// Cached user profile from backend.
  UserProfile? _cachedProfile;

  UserProfile? get currentProfile => _cachedProfile;

  // ─────────────────────────────────────────────
  // GOOGLE OAUTH SIGN-IN
  // ─────────────────────────────────────────────

  /// Trigger Supabase Google OAuth flow.
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
  // BACKEND SYNC
  // ─────────────────────────────────────────────

  /// Send the Supabase JWT to FastAPI backend.
  /// Backend will create the user if they don't exist,
  /// or return the existing user profile.
  Future<UserProfile> syncWithBackend() async {
    try {
      debugPrint('');
      debugPrint('========== BACKEND SYNC ==========');

      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      debugPrint('Session exists: ${session != null}');
      debugPrint('User ID: ${user?.id}');
      debugPrint('User Email: ${user?.email}');

      if (session == null) {
        throw Exception('No Supabase session available');
      }

      debugPrint(
        'JWT exists: ${session.accessToken.isNotEmpty}',
      );

      debugPrint('Sending authenticated request to backend...');

      final response =
          await _apiClient.post(ApiEndpoints.authSync);

      debugPrint('Backend response received');

      final profile =
          UserProfile.fromJson(response as Map<String, dynamic>);

      _cachedProfile = profile;

      debugPrint(
        'Aadhaar verified: ${profile.aadhaarVerified}',
      );

      debugPrint('================================');

      return profile;
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Backend sync error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────

  /// Fetch fresh user profile from backend.
  Future<UserProfile> getUserProfile() async {
    try {
      final response =
          await _apiClient.get(ApiEndpoints.userProfile);

      final profile =
          UserProfile.fromJson(response as Map<String, dynamic>);

      _cachedProfile = profile;

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