/// LiftOff — User Profile Model
///
/// Represents the authenticated user's profile and verification status
/// as returned by the FastAPI backend.
class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;

  // ─── Verification Status ───

  final bool aadhaarVerified;
  final bool dlVerified;
  final bool vehicleRcVerified;

  // ─── Aadhaar Display ───

  // Example: XXXX-XXXX-1234
  final String? maskedAadhaar;

  // ─── Host Performance Stats ───
  final double fuelRecoveredInr;
  final int sharedCommutesCount;
  final double co2SavedKg;

  // ─── Timestamp ───

  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.aadhaarVerified = false,
    this.dlVerified = false,
    this.vehicleRcVerified = false,
    this.maskedAadhaar,
    this.fuelRecoveredInr = 0.0,
    this.sharedCommutesCount = 0,
    this.co2SavedKg = 0.0,
    required this.createdAt,
  });

  /// Parse from FastAPI JSON response.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      // Supabase user UUID
      id: json['user_id'] as String,

      email: json['email'] as String,

      fullName: json['full_name'] as String?,

      avatarUrl: json['avatar_url'] as String?,

      // Verification flags
      aadhaarVerified:
          json['aadhaar_verified'] as bool? ?? false,

      dlVerified: (json['driving_licence_verified'] as bool?) ??
          (json['dl_verified'] as bool?) ??
          false,

      vehicleRcVerified: (json['rc_verified'] as bool?) ??
          (json['vehicle_rc_verified'] as bool?) ??
          false,

      // Aadhaar masked value
      maskedAadhaar:
          json['masked_aadhaar'] as String?,

      // Host Stats
      fuelRecoveredInr: (json['fuel_recovered_inr'] as num?)?.toDouble() ?? 0.0,
      sharedCommutesCount: (json['shared_commutes_count'] as int?) ?? 0,
      co2SavedKg: (json['co2_saved_kg'] as num?)?.toDouble() ?? 0.0,

      // Backend timestamp
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,

      'aadhaar_verified': aadhaarVerified,
      'driving_licence_verified': dlVerified,
      'rc_verified': vehicleRcVerified,

      'masked_aadhaar': maskedAadhaar,

      'fuel_recovered_inr': fuelRecoveredInr,
      'shared_commutes_count': sharedCommutesCount,
      'co2_saved_kg': co2SavedKg,

      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Immutable update helper.
  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,

    bool? aadhaarVerified,
    bool? dlVerified,
    bool? vehicleRcVerified,

    String? maskedAadhaar,

    double? fuelRecoveredInr,
    int? sharedCommutesCount,
    double? co2SavedKg,

    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,

      aadhaarVerified:
          aadhaarVerified ?? this.aadhaarVerified,

      dlVerified:
          dlVerified ?? this.dlVerified,

      vehicleRcVerified:
          vehicleRcVerified ?? this.vehicleRcVerified,

      maskedAadhaar:
          maskedAadhaar ?? this.maskedAadhaar,

      fuelRecoveredInr:
          fuelRecoveredInr ?? this.fuelRecoveredInr,

      sharedCommutesCount:
          sharedCommutesCount ?? this.sharedCommutesCount,

      co2SavedKg:
          co2SavedKg ?? this.co2SavedKg,

      createdAt:
          createdAt ?? this.createdAt,
    );
  }
}