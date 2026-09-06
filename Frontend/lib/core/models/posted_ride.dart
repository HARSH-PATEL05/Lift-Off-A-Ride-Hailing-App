import '../data/mock_data.dart';

class PostedRide {
  final int rideId;
  final String hostId;
  final String? hostName;
  final String? hostAvatar;
  final String originName;
  final double? originLat;
  final double? originLng;
  final String destinationName;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime departureTime;
  final int availableSeats;
  final double farePerSeat;
  final String? vehicleModel;
  final String? vehicleNumber;
  final bool isWomenOnly;
  final bool democraticConsent;
  final String status;
  final DateTime createdAt;

  PostedRide({
    required this.rideId,
    required this.hostId,
    this.hostName,
    this.hostAvatar,
    required this.originName,
    this.originLat,
    this.originLng,
    required this.destinationName,
    this.destinationLat,
    this.destinationLng,
    required this.departureTime,
    required this.availableSeats,
    required this.farePerSeat,
    this.vehicleModel,
    this.vehicleNumber,
    required this.isWomenOnly,
    required this.democraticConsent,
    required this.status,
    required this.createdAt,
  });

  factory PostedRide.fromJson(Map<String, dynamic> json) {
    return PostedRide(
      rideId: json['ride_id'] as int,
      hostId: json['host_id'] as String,
      hostName: json['host_name'] as String?,
      hostAvatar: json['host_avatar'] as String?,
      originName: json['origin_name'] as String? ?? 'Origin',
      originLat: (json['origin_lat'] as num?)?.toDouble(),
      originLng: (json['origin_lng'] as num?)?.toDouble(),
      destinationName: json['destination_name'] as String? ?? 'Destination',
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      departureTime: DateTime.parse(json['departure_time'] as String),
      availableSeats: json['available_seats'] as int? ?? 3,
      farePerSeat: (json['fare_per_seat'] as num?)?.toDouble() ?? 140.0,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      isWomenOnly: json['is_women_only'] as bool? ?? false,
      democraticConsent: json['democratic_consent'] as bool? ?? true,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts backend PostedRide into a CommunityRide object for UI display
  CommunityRide toCommunityRide() {
    final displayName = (hostName != null && hostName!.isNotEmpty) ? hostName! : 'Host Commuter';

    return CommunityRide(
      id: rideId.toString(),
      host: CommuterProfile(
        id: hostId,
        name: displayName,
        avatarUrl: hostAvatar ?? '',
        rating: 4.9,
        sharedTripsCount: 12,
        co2SavedKg: 45,
        verification: const VerificationStatus(
          aadhaarVerified: true,
          dlVerified: false,
          vehicleRcVerified: false,
        ),
        workPlace: destinationName,
      ),
      origin: originName,
      destination: destinationName,
      departureTime: 'Today • ${_formatTime(departureTime)}',
      vehicleModel: vehicleModel ?? 'Sedan',
      vehicleNumber: vehicleNumber ?? 'DL 3C XX 1234',
      totalSeats: availableSeats,
      availableSeats: availableSeats,
      routeMatchPercentage: 95,
      meetingNodeName: originName,
      meetingNodeDistance: 'Near pickup',
      fuelSharePerSeat: farePerSeat,
      isWomenOnly: isWomenOnly,
      strictPassengerConsent: democraticConsent,
      preferences: [
        if (isWomenOnly) 'Women Only',
        'AC Ride',
        'Strict Consent',
      ],
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
