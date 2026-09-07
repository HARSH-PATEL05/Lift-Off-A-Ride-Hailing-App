import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/posted_ride.dart';
import '../data/mock_data.dart';
import '../services/location_trie_service.dart';

class RideService {
  RideService._();
  static final RideService instance = RideService._();

  /// Search active rides from FastAPI backend with query parameters
  Future<List<CommunityRide>> searchRides({
    String? origin,
    String? destination,
    bool? isWomenOnly,
    bool? verifiedOnly,
  }) async {
    final queryParams = <String, String>{};
    if (origin != null && origin.trim().isNotEmpty) {
      queryParams['origin'] = origin.trim();
    }
    if (destination != null && destination.trim().isNotEmpty) {
      queryParams['destination'] = destination.trim();
    }
    if (isWomenOnly == true) {
      queryParams['is_women_only'] = 'true';
    }
    if (verifiedOnly == true) {
      queryParams['verified_only'] = 'true';
    }

    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.rides,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response is List) {
        final postedRides = response
            .map((item) => PostedRide.fromJson(item as Map<String, dynamic>))
            .toList();
        
        LocationTrieService.instance.populateFromRides(postedRides);

        final rides = postedRides.map((r) => r.toCommunityRide()).toList();
        return rides;
      }
      return [];
    } catch (e) {
      // Fallback or empty if backend unfulfilled
      return [];
    }
  }
}
