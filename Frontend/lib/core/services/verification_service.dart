import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/user_profile.dart';

/// LiftOff — Verification Service
/// Handles Aadhaar (and future DL / Vehicle RC) verification
/// by calling the FastAPI backend which talks to sandbox APIs.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  final _apiClient = ApiClient.instance;

  // ─── Aadhaar Verification ───

  /// Submit a 12-digit Aadhaar number for sandbox verification.
  ///
  /// Flow: Flutter → FastAPI → Aadhaar Sandbox API → DB update.
  /// Returns updated [UserProfile] with `aadhaarVerified: true` on success.
  ///
  /// Throws [ApiException] on failure (invalid number, sandbox error, etc.)
  Future<UserProfile> verifyAadhaar(String aadhaarNumber) async {
    // Sanitize: remove spaces and dashes
    final cleanNumber = aadhaarNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // Client-side validation
    if (cleanNumber.length != 12 || !RegExp(r'^\d{12}$').hasMatch(cleanNumber)) {
      throw const ValidationException(
        message: 'Please enter a valid 12-digit Aadhaar number.',
      );
    }

    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyAadhaar,
        body: {'aadhaar_number': cleanNumber},
      );

      final data = response as Map<String, dynamic>;

      // Check if verification was successful
      if (data['verified'] == true && data['user_profile'] != null) {
        final profile =
            UserProfile.fromJson(data['user_profile'] as Map<String, dynamic>);
        debugPrint('VerificationService: Aadhaar verified successfully');
        return profile;
      } else {
        throw ApiException(
          message: data['message']?.toString() ??
              'Aadhaar verification failed. Please check the number and try again.',
          statusCode: 200,
        );
      }
    } on ApiException {
      rethrow;
    }
  }
}
