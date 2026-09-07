import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Location Item representing a searchable node in the Trie
class LocationItem {
  final String id;
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String category; // 'metro', 'hub', 'airport', 'landmark'

  const LocationItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.category = 'landmark',
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// Calculate distance in km from a given reference point (Haversine formula)
  double distanceToKm(double userLat, double userLng) {
    const double r = 6371.0; // Earth's radius in kilometers
    final double dLat = _toRadians(latitude - userLat);
    final double dLng = _toRadians(longitude - userLng);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(userLat)) *
            math.cos(_toRadians(latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180.0;
  }
}

/// Trie Node for prefix matching
class _TrieNode {
  final Map<String, _TrieNode> children = {};
  final Set<LocationItem> locations = {};
  bool isEndOfWord = false;
}

/// High-performance Prefix Trie for instant Rapido-style location search
class LocationTrieService {
  LocationTrieService._() {
    _populateDefaultLocations();
  }

  static final LocationTrieService instance = LocationTrieService._();

  final _TrieNode _root = _TrieNode();
  final List<LocationItem> _allLocations = [];

  // Default User Location (Delhi NCR center)
  static const double defaultUserLat = 28.6315;
  static const double defaultUserLng = 77.2167;

  /// Insert a location item into the Trie by indexing all words and character prefixes
  void insert(LocationItem location) {
    _allLocations.add(location);

    // Index full name, subtitle, and individual tokenized words
    final textToMatch = '${location.name} ${location.subtitle}'.toLowerCase();
    final words = textToMatch.split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.isEmpty) continue;
      _TrieNode curr = _root;
      for (int i = 0; i < word.length; i++) {
        final char = word[i];
        curr.children.putIfAbsent(char, () => _TrieNode());
        curr = curr.children[char]!;
        curr.locations.add(location);
      }
      curr.isEndOfWord = true;
    }
  }

  /// Search locations using Trie prefix matching + 100 km Haversine Geofencing
  List<LocationSearchResult> search({
    required String query,
    double userLat = defaultUserLat,
    double userLng = defaultUserLng,
    double maxRadiusKm = 100.0,
    int limit = 6,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    List<LocationItem> candidateMatches = [];

    if (cleanQuery.isEmpty) {
      // Empty query returns top nearby locations
      candidateMatches = List.from(_allLocations);
    } else {
      // Perform Trie prefix traversal
      _TrieNode? curr = _root;
      for (int i = 0; i < cleanQuery.length; i++) {
        final char = cleanQuery[i];
        if (!curr!.children.containsKey(char)) {
          curr = null;
          break;
        }
        curr = curr.children[char];
      }

      if (curr != null) {
        candidateMatches = curr.locations.toList();
      } else {
        // Fallback fuzzy filter if exact prefix not found
        candidateMatches = _allLocations.where((loc) {
          final haystack = '${loc.name} ${loc.subtitle}'.toLowerCase();
          return haystack.contains(cleanQuery);
        }).toList();
      }
    }

    // Apply Haversine 100km Geofence Filter & sort by distance
    final results = <LocationSearchResult>[];

    for (final item in candidateMatches) {
      final distKm = item.distanceToKm(userLat, userLng);

      // Enforce 100 km maximum radius restriction
      if (distKm <= maxRadiusKm) {
        results.add(LocationSearchResult(
          location: item,
          distanceKm: distKm,
        ));
      }
    }

    // Sort by closest distance first
    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return results.take(limit).toList();
  }

  /// Dynamically index locations from active rides fetched from the backend API
  void populateFromRides(List<dynamic> rides) {
    for (final ride in rides) {
      if (ride.originName != null && ride.originName.toString().isNotEmpty) {
        insert(LocationItem(
          id: 'dynamic_origin_${ride.rideId}',
          name: ride.originName.toString(),
          subtitle: 'Active Pickup Node',
          latitude: (ride.originLat as num?)?.toDouble() ?? defaultUserLat,
          longitude: (ride.originLng as num?)?.toDouble() ?? defaultUserLng,
          category: 'metro',
        ));
      }
      if (ride.destinationName != null && ride.destinationName.toString().isNotEmpty) {
        insert(LocationItem(
          id: 'dynamic_dest_${ride.rideId}',
          name: ride.destinationName.toString(),
          subtitle: 'Active Destination Node',
          latitude: (ride.destinationLat as num?)?.toDouble() ?? defaultUserLat,
          longitude: (ride.destinationLng as num?)?.toDouble() ?? defaultUserLng,
          category: 'hub',
        ));
      }
    }
  }

  /// Populate comprehensive database of Delhi NCR commute hubs
  void _populateDefaultLocations() {
    const locations = [
      LocationItem(
        id: 'loc_1',
        name: 'Rajiv Chowk Metro Gate 2',
        subtitle: 'Connaught Place, New Delhi',
        latitude: 28.6328,
        longitude: 77.2195,
        category: 'metro',
      ),
      LocationItem(
        id: 'loc_2',
        name: 'DLF Cyber City',
        subtitle: 'Phase 2, Gurgaon, Haryana',
        latitude: 28.4950,
        longitude: 77.0890,
        category: 'hub',
      ),
      LocationItem(
        id: 'loc_3',
        name: 'HUDA City Centre Metro',
        subtitle: 'Sector 29, Gurgaon',
        latitude: 28.4595,
        longitude: 77.0725,
        category: 'metro',
      ),
      LocationItem(
        id: 'loc_4',
        name: 'Noida Sector 62 Electronic City',
        subtitle: 'Sector 62, Noida, Uttar Pradesh',
        latitude: 28.6280,
        longitude: 77.3649,
        category: 'hub',
      ),
      LocationItem(
        id: 'loc_5',
        name: 'Indira Gandhi Airport T3',
        subtitle: 'Palam, New Delhi',
        latitude: 28.5562,
        longitude: 77.1000,
        category: 'airport',
      ),
      LocationItem(
        id: 'loc_6',
        name: 'Golf Course Road',
        subtitle: 'Sector 54, Gurgaon',
        latitude: 28.4390,
        longitude: 77.1025,
        category: 'hub',
      ),
      LocationItem(
        id: 'loc_7',
        name: 'Barakhamba Road Petrol Pump',
        subtitle: 'Tolstoy Marg, New Delhi',
        latitude: 28.6295,
        longitude: 77.2270,
        category: 'landmark',
      ),
      LocationItem(
        id: 'loc_8',
        name: 'Udyog Vihar Phase 4',
        subtitle: 'Gurgaon, Haryana',
        latitude: 28.5050,
        longitude: 77.0820,
        category: 'hub',
      ),
      LocationItem(
        id: 'loc_9',
        name: 'Anand Vihar ISBT & Metro',
        subtitle: 'Trans-Yamuna, East Delhi',
        latitude: 28.6469,
        longitude: 77.3160,
        category: 'metro',
      ),
      LocationItem(
        id: 'loc_10',
        name: 'Kashmere Gate Metro Interchange',
        subtitle: 'Mori Gate, Old Delhi',
        latitude: 28.6675,
        longitude: 77.2280,
        category: 'metro',
      ),
    ];

    for (final loc in locations) {
      insert(loc);
    }
  }
}

/// Search result model with distance calculation
class LocationSearchResult {
  final LocationItem location;
  final double distanceKm;

  const LocationSearchResult({
    required this.location,
    required this.distanceKm,
  });

  String get formattedDistance {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
