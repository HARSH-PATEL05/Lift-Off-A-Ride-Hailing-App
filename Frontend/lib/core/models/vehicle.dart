class Vehicle {
  final int id;

  final String registrationNumber;
  final String vehicleModel;
  final String? vehicleColor;

  final String vehicleCategory;
  final String vehicleSubtype;
  final String? vehicleTypeSpecified;
  final int seatingCapacity;

  final bool isActive;
  final bool rcVerified;

  const Vehicle({
    required this.id,
    required this.registrationNumber,
    required this.vehicleModel,
    this.vehicleColor,
    required this.vehicleCategory,
    required this.vehicleSubtype,
    this.vehicleTypeSpecified,
    required this.seatingCapacity,
    required this.isActive,
    required this.rcVerified,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      registrationNumber:
          json['registration_number'] as String,
      vehicleModel:
          json['vehicle_model'] as String,
      vehicleColor:
          json['vehicle_color'] as String?,

      vehicleCategory:
          json['vehicle_category'] as String,
      vehicleSubtype:
          json['vehicle_subtype'] as String,
      vehicleTypeSpecified:
          json['vehicle_type_specified'] as String?,
      seatingCapacity:
          json['seating_capacity'] as int,

      isActive:
          json['is_active'] as bool? ?? false,
      rcVerified:
          json['rc_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'registration_number': registrationNumber,
      'vehicle_model': vehicleModel,
      'vehicle_color': vehicleColor,

      'vehicle_category': vehicleCategory,
      'vehicle_subtype': vehicleSubtype,
      'vehicle_type_specified': vehicleTypeSpecified,
      'seating_capacity': seatingCapacity,

      'is_active': isActive,
      'rc_verified': rcVerified,
    };
  }

  Vehicle copyWith({
    int? id,
    String? registrationNumber,
    String? vehicleModel,
    String? vehicleColor,

    String? vehicleCategory,
    String? vehicleSubtype,
    String? vehicleTypeSpecified,
    int? seatingCapacity,

    bool? isActive,
    bool? rcVerified,
  }) {
    return Vehicle(
      id: id ?? this.id,
      registrationNumber:
          registrationNumber ?? this.registrationNumber,
      vehicleModel:
          vehicleModel ?? this.vehicleModel,
      vehicleColor:
          vehicleColor ?? this.vehicleColor,

      vehicleCategory:
          vehicleCategory ?? this.vehicleCategory,
      vehicleSubtype:
          vehicleSubtype ?? this.vehicleSubtype,
      vehicleTypeSpecified:
          vehicleTypeSpecified ?? this.vehicleTypeSpecified,
      seatingCapacity:
          seatingCapacity ?? this.seatingCapacity,

      isActive:
          isActive ?? this.isActive,
      rcVerified:
          rcVerified ?? this.rcVerified,
    );
  }
}