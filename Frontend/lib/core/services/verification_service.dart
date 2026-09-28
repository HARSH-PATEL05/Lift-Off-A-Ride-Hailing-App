import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// LiftOff — Verification Service
///
/// Handles Aadhaar, Driving Licence and Vehicle RC verification
/// by calling the FastAPI backend which talks to sandbox APIs.
class VerificationService {
  VerificationService._();

  static final VerificationService instance =
      VerificationService._();

  final _apiClient = ApiClient.instance;

  // ─────────────────────────────────────────────
  // AADHAAR VERIFICATION
  // ─────────────────────────────────────────────

  /// Submit Aadhaar number and phone number for verification.
  ///
  /// Flow:
  /// Flutter
  ///   ↓
  /// FastAPI
  ///   ↓
  /// Aadhaar Sandbox API
  ///   ↓
  /// PostgreSQL
  ///
  /// The phone number is stored in the LiftOff users table
  /// by the backend.
  ///
  /// Phone verification is intentionally separate from
  /// Aadhaar verification. Supplying a phone number does
  /// not automatically mark it as verified.
  ///
  /// Returns updated [UserProfile] on success.
  ///
  /// Throws [ApiException] on failure.
  Future<UserProfile> verifyAadhaar(
    String aadhaarNumber,
    String phoneNumber,
  ) async {
    // ─────────────────────────────────────────────
    // Sanitize Aadhaar
    // ─────────────────────────────────────────────

    final cleanAadhaarNumber =
        aadhaarNumber.replaceAll(RegExp(r'[\s\-]'), '');

    // ─────────────────────────────────────────────
    // Sanitize Phone
    // ─────────────────────────────────────────────

    final cleanPhoneNumber =
        phoneNumber.replaceAll(RegExp(r'\D'), '');

    // ─────────────────────────────────────────────
    // Client-side Aadhaar Validation
    // ─────────────────────────────────────────────

    if (cleanAadhaarNumber.length != 12 ||
        !RegExp(r'^\d{12}$')
            .hasMatch(cleanAadhaarNumber)) {
      throw const ValidationException(
        message:
            'Please enter a valid 12-digit Aadhaar number.',
      );
    }

    // ─────────────────────────────────────────────
    // Client-side Phone Validation
    // ─────────────────────────────────────────────

    if (cleanPhoneNumber.length < 10 ||
        cleanPhoneNumber.length > 15 ||
        !RegExp(r'^\d+$').hasMatch(cleanPhoneNumber)) {
      throw const ValidationException(
        message:
            'Please enter a valid phone number.',
      );
    }

    // ─────────────────────────────────────────────
    // Backend Request
    // ─────────────────────────────────────────────

    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyAadhaar,
        body: {
          'aadhaar_number': cleanAadhaarNumber,
          'phone_number': cleanPhoneNumber,
        },
      );

      final data = response as Map<String, dynamic>;

      // ───────────────────────────────────────────
      // Verification Success
      // ───────────────────────────────────────────

      if (data['verified'] == true &&
          data['user_profile'] != null) {
        final profile = UserProfile.fromJson(
          data['user_profile']
              as Map<String, dynamic>,
        );

        debugPrint(
          'VerificationService: '
          'Aadhaar verified successfully',
        );

        debugPrint(
          'Phone number saved: '
          '${profile.phoneNumber ?? cleanPhoneNumber}',
        );

        debugPrint(
          'Phone verified: '
          '${profile.phoneVerified}',
        );

        return profile;
      }

      // ───────────────────────────────────────────
      // Verification Failed
      // ───────────────────────────────────────────

      throw ApiException(
        message: data['message']?.toString() ??
            'Aadhaar verification failed. '
            'Please check the number and try again.',
        statusCode: 200,
      );
    } on ApiException {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // DRIVING LICENCE VERIFICATION
  // ─────────────────────────────────────────────

  Future<UserProfile> verifyDrivingLicence(
    String licenceNumber,
  ) async {
    final clean = licenceNumber.trim();

    if (clean.length < 5) {
      throw const ValidationException(
        message:
            'Please enter a valid Driving Licence number.',
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.verifyDL,
      body: {
        'licence_number': clean,
      },
    );

    final data = response as Map<String, dynamic>;

    if (data['verified'] == true) {
      return await AuthService.instance
          .syncWithBackend();
    }

    throw ApiException(
      message: data['message']?.toString() ??
          'Driving Licence verification failed.',
      statusCode: 200,
    );
  }

  // ─────────────────────────────────────────────
  // VEHICLE RC VERIFICATION
  // ─────────────────────────────────────────────

  Future<UserProfile> verifyVehicleRc({
    required String rcNumber,
    required String vehicleModel,
    String? vehicleColor,
    required String vehicleCategory,
    required String vehicleSubtype,
    String? vehicleTypeSpecified,
    required int seatingCapacity,
  }) async {
    final cleanRc = rcNumber
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');

    final cleanModel = vehicleModel.trim();
    final cleanColor = vehicleColor?.trim();

    final cleanCategory = vehicleCategory.trim();
    final cleanSubtype = vehicleSubtype.trim();
    final cleanSpecified =
        vehicleTypeSpecified?.trim();

    // ─────────────────────────────────────────────
    // Client-side Validation
    // ─────────────────────────────────────────────

    if (cleanRc.length < 5 ||
        cleanRc.length > 20) {
      throw const ValidationException(
        message:
            'Please enter a valid Vehicle RC number.',
      );
    }

    if (cleanModel.length < 2) {
      throw const ValidationException(
        message:
            'Please enter the vehicle make and model.',
      );
    }

    if (cleanColor != null &&
        cleanColor.isNotEmpty &&
        cleanColor.length > 50) {
      throw const ValidationException(
        message:
            'Vehicle color is too long.',
      );
    }

    if (cleanCategory.isEmpty) {
      throw const ValidationException(
        message:
            'Please select a vehicle category.',
      );
    }

    if (cleanSubtype.isEmpty) {
      throw const ValidationException(
        message:
            'Please select a vehicle type.',
      );
    }

    if (cleanSpecified != null &&
        cleanSpecified.length > 100) {
      throw const ValidationException(
        message:
            'Vehicle type specification is too long.',
      );
    }

    if ((cleanCategory.toUpperCase() == 'OTHER' ||
            cleanSubtype.toUpperCase() == 'OTHER') &&
        (cleanSpecified == null ||
            cleanSpecified.isEmpty)) {
      throw const ValidationException(
        message:
            'Please specify the vehicle type.',
      );
    }

    if (seatingCapacity < 2 ||
        seatingCapacity > 100) {
      throw const ValidationException(
        message:
            'Seating capacity must be between 2 and 100.',
      );
    }

    // ─────────────────────────────────────────────
    // Backend Request
    // ─────────────────────────────────────────────

    final response = await _apiClient.post(
      ApiEndpoints.verifyRC,
      body: {
        'rc_number': cleanRc,
        'vehicle_model': cleanModel,
        'vehicle_color':
            cleanColor == null ||
                    cleanColor.isEmpty
                ? null
                : cleanColor,
        'vehicle_category': cleanCategory,
        'vehicle_subtype': cleanSubtype,
        'vehicle_type_specified':
            cleanSpecified == null ||
                    cleanSpecified.isEmpty
                ? null
                : cleanSpecified,
        'seating_capacity': seatingCapacity,
      },
    );

    final data = response as Map<String, dynamic>;

    // ─────────────────────────────────────────────
    // Verification Success
    // ─────────────────────────────────────────────

    if (data['verified'] == true) {
      debugPrint(
        'VerificationService: '
        'Vehicle RC verified successfully '
        '(capacity=$seatingCapacity, '
        'max LiftOff seats=${seatingCapacity - 1})',
      );

      return await AuthService.instance
          .syncWithBackend();
    }

    // ─────────────────────────────────────────────
    // Verification Failed
    // ─────────────────────────────────────────────

    throw ApiException(
      message: data['message']?.toString() ??
          'Vehicle RC verification failed. '
          'Please check the details and try again.',
      statusCode: 200,
    );
  }
}