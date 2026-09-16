/// LiftOff — FastAPI Backend Endpoint Paths
/// Central registry of all API routes used by the Flutter client.
class ApiEndpoints {
  ApiEndpoints._();

  // ─── Base URL ───
  // Android emulator → localhost mapping.
  // For physical device, use your PC's local IP (e.g., 192.168.x.x:8000).
  // For production, replace with deployed URL.
  static const String baseUrl = 'http://127.0.0.1:8000';
  // static const String baseUrl = 'http://10.34.101.231:8000';

  // ─── Auth ───
  /// POST: Send Supabase JWT → Backend creates/returns user profile.
  /// Headers: Authorization: Bearer <jwt>
  /// Response: { user_id, email, full_name, aadhaar_verified, ... }
  static const String authSync = '/auth/sync';

  // ─── User Profile ───
  /// GET: Fetch current user's profile & verification status.
  /// Headers: Authorization: Bearer <jwt>
  /// Response: { user_id, email, full_name, aadhaar_verified, dl_verified, ... }
  static const String userProfile = '/api/user/profile';

  // ─── Verification ───
  /// POST: Submit Aadhaar number for sandbox verification.
  /// Headers: Authorization: Bearer <jwt>
  /// Body: { "aadhaar_number": "123456789012" }
  /// Response: { verified: true/false, message: "...", user_profile: {...} }
  static const String verifyAadhaar = '/verification/aadhaar';
  static const String verifyDL = '/verification/driving-licence';
  static const String verifyRC = '/verification/vehicle-rc';
  
  // ─── Vehicles ───

  /// GET: Get all vehicles belonging to the
  /// authenticated user.
  static const String vehicles = '/vehicles';

  /// GET: Get one vehicle belonging to the
  /// authenticated user.
  static String vehicle(int vehicleId) =>
      '/vehicles/$vehicleId';

  /// PATCH: Update vehicle model/color.
  static String updateVehicle(int vehicleId) =>
      '/vehicles/$vehicleId';

  /// PATCH: Activate/deactivate user's vehicle.
  static String vehicleStatus(int vehicleId) =>
      '/vehicles/$vehicleId/status';


  // ─── Rides ───
  /// POST: Publish a new commute route.
  /// GET: List active rides.
  static const String rides = '/rides';
}
