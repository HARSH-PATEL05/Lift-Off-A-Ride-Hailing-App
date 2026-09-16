import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

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

  // ─── Driving Licence Verification ───

  Future<UserProfile> verifyDrivingLicence(String licenceNumber) async {
    final clean = licenceNumber.trim();
    if (clean.length < 5) {
      throw const ValidationException(message: 'Please enter a valid Driving Licence number.');
    }

    final response = await _apiClient.post(
      ApiEndpoints.verifyDL,
      body: {'licence_number': clean},
    );

    final data = response as Map<String, dynamic>;
    if (data['verified'] == true) {
      return await AuthService.instance.syncWithBackend();
    } else {
      throw ApiException(
        message: data['message']?.toString() ?? 'Driving Licence verification failed.',
        statusCode: 200,
      );
    }
  }

    // ─── Vehicle RC Verification ───

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
    final cleanSpecified = vehicleTypeSpecified?.trim();

    // ─── Client-side validation ───

    if (cleanRc.length < 5 || cleanRc.length > 20) {
      throw const ValidationException(
        message: 'Please enter a valid Vehicle RC number.',
      );
    }

    if (cleanModel.length < 2) {
      throw const ValidationException(
        message: 'Please enter the vehicle make and model.',
      );
    }

    if (cleanColor != null &&
        cleanColor.isNotEmpty &&
        cleanColor.length > 50) {
      throw const ValidationException(
        message: 'Vehicle color is too long.',
      );
    }

    if (cleanCategory.isEmpty) {
      throw const ValidationException(
        message: 'Please select a vehicle category.',
      );
    }

    if (cleanSubtype.isEmpty) {
      throw const ValidationException(
        message: 'Please select a vehicle type.',
      );
    }

    if (cleanSpecified != null && cleanSpecified.length > 100) {
      throw const ValidationException(
        message: 'Vehicle type specification is too long.',
      );
    }

    if ((cleanCategory.toUpperCase() == 'OTHER' ||
            cleanSubtype.toUpperCase() == 'OTHER') &&
        (cleanSpecified == null || cleanSpecified.isEmpty)) {
      throw const ValidationException(
        message: 'Please specify the vehicle type.',
      );
    }

    if (seatingCapacity < 2 || seatingCapacity > 100) {
      throw const ValidationException(
        message: 'Seating capacity must be between 2 and 100.',
      );
    }

    final response = await _apiClient.post(
      ApiEndpoints.verifyRC,
      body: {
        'rc_number': cleanRc,
        'vehicle_model': cleanModel,
        'vehicle_color':
            cleanColor == null || cleanColor.isEmpty ? null : cleanColor,
        'vehicle_category': cleanCategory,
        'vehicle_subtype': cleanSubtype,
        'vehicle_type_specified':
            cleanSpecified == null || cleanSpecified.isEmpty
                ? null
                : cleanSpecified,
        'seating_capacity': seatingCapacity,
      },
    );

    final data = response as Map<String, dynamic>;

    if (data['verified'] == true) {
      debugPrint(
        'VerificationService: Vehicle RC verified successfully '
        '(capacity=$seatingCapacity, max LiftOff seats=${seatingCapacity - 1})',
      );

      return await AuthService.instance.syncWithBackend();
    }

    throw ApiException(
      message: data['message']?.toString() ??
          'Vehicle RC verification failed. Please check the details and try again.',
      statusCode: 200,
    );
  }}