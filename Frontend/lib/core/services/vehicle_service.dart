import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exceptions.dart';
import '../models/vehicle.dart';

class VehicleService {
  VehicleService._();

  static final VehicleService instance =
      VehicleService._();

  final _apiClient = ApiClient.instance;

  // ─────────────────────────────────────────────
  // GET MY VEHICLES
  // ─────────────────────────────────────────────

  Future<List<Vehicle>> getMyVehicles() async {
    final response = await _apiClient.get(
      ApiEndpoints.vehicles,
    );

    final data = response as Map<String, dynamic>;

    final vehiclesData =
        data['vehicles'] as List<dynamic>? ?? [];

    return vehiclesData
        .map(
          (item) => Vehicle.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ─────────────────────────────────────────────
  // GET SINGLE VEHICLE
  // ─────────────────────────────────────────────

  Future<Vehicle> getVehicle(int vehicleId) async {
    final response = await _apiClient.get(
      ApiEndpoints.vehicle(vehicleId),
    );

    final data = response as Map<String, dynamic>;

    return Vehicle.fromJson(data);
  }

  // ─────────────────────────────────────────────
  // UPDATE VEHICLE
  // ─────────────────────────────────────────────

  Future<Vehicle> updateVehicle({
    required int vehicleId,
    String? vehicleModel,
    String? vehicleColor,
  }) async {
    final body = <String, dynamic>{};

    if (vehicleModel != null) {
      body['vehicle_model'] = vehicleModel;
    }

    if (vehicleColor != null) {
      body['vehicle_color'] = vehicleColor;
    }

    if (body.isEmpty) {
      throw const ValidationException(
        message: 'No vehicle changes were provided.',
      );
    }

    final response = await _apiClient.patch(
      ApiEndpoints.updateVehicle(vehicleId),
      body: body,
    );

    final data = response as Map<String, dynamic>;

    return Vehicle.fromJson(data);
  }

  // ─────────────────────────────────────────────
  // UPDATE VEHICLE STATUS
  // ─────────────────────────────────────────────

  Future<Vehicle> updateVehicleStatus({
    required int vehicleId,
    required bool isActive,
  }) async {
    final response = await _apiClient.patch(
      ApiEndpoints.vehicleStatus(vehicleId),
      body: {
        'is_active': isActive,
      },
    );

    final data = response as Map<String, dynamic>;

    return Vehicle.fromJson(data);
  }
}