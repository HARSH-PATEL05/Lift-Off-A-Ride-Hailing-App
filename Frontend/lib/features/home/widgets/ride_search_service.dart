import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/data/mock_data.dart';

enum RideSort {
  none,
  ratingHighToLow,
  fareHighToLow,
}

/// Filters selected by the traveller while searching for a community ride.
///
/// Vehicle category and vehicle features follow the same conceptual contract
/// used by Module 3. The authoritative route matching/filtering remains a
/// backend responsibility once the real endpoint is connected.
class RideSearchFilters {
  final DateTime? departureDateTime;
  final String? vehicleCategory;
  final bool womenOnly;
  final List<String> vehicleFeatures;
  final RideSort sort;
  final double minimumRouteMatchPercentage;

  const RideSearchFilters({
    this.departureDateTime,
    this.vehicleCategory,
    this.womenOnly = false,
    this.vehicleFeatures = const [],
    this.sort = RideSort.none,
    this.minimumRouteMatchPercentage = 50,
  });

  Map<String, dynamic> toJson() {
    return {
      if (departureDateTime != null)
        'departure_date_time':
            departureDateTime!.toUtc().toIso8601String(),
      if (vehicleCategory != null) 'vehicle_category': vehicleCategory,
      'women_only': womenOnly,
      if (vehicleFeatures.isNotEmpty) 'vehicle_features': vehicleFeatures,
      if (sort != RideSort.none)
        'sort': switch (sort) {
          RideSort.ratingHighToLow => 'rating_desc',
          RideSort.fareHighToLow => 'fare_desc',
          RideSort.none => null,
        },
      'minimum_route_match_percentage': minimumRouteMatchPercentage,
    };
  }
}

/// Result boundary between the frontend and the route-matching API.
///
/// Until the exact backend search endpoint is wired, the existing mock rides
/// keep the UI testable. Women-only and route-match filtering plus sorting are
/// exercised locally where the mock model already exposes the required data.
/// Date/category/feature filtering is represented in [RideSearchFilters] and
/// should be applied authoritatively by the backend.
class RideSearchService {
  const RideSearchService._();

  static Future<List<CommunityRide>> searchRides({
    required LatLng? source,
    required LatLng? destination,
    required List<LatLng> routeCoordinates,
    required List<LatLng> stopCoordinates,
    required RideSearchFilters filters,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    var result = List<CommunityRide>.from(MockData.communityRides);

    if (filters.womenOnly) {
      result = result.where((ride) => ride.isWomenOnly).toList();
    }

    result = result
        .where(
          (ride) =>
              ride.routeMatchPercentage >=
              filters.minimumRouteMatchPercentage,
        )
        .toList();

    switch (filters.sort) {
      case RideSort.ratingHighToLow:
        result.sort((a, b) => b.host.rating.compareTo(a.host.rating));
        break;
      case RideSort.fareHighToLow:
        result.sort(
          (a, b) => b.fuelSharePerSeat.compareTo(a.fuelSharePerSeat),
        );
        break;
      case RideSort.none:
        break;
    }

    return result;
  }
}
