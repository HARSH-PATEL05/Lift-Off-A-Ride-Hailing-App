import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// ------------------------------------------------------------
/// PLACE SUGGESTION MODEL
/// ------------------------------------------------------------

class PlaceSuggestion {
  final String placeId;
  final String description;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
}

/// ------------------------------------------------------------
/// ROUTE RESULT MODEL
/// ------------------------------------------------------------

class RouteResult {
  final List<LatLng> points;

  final String distanceText;
  final String durationText;

  final num distanceMeters;
  final num durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// ------------------------------------------------------------
/// LOCATION ADDRESS MODEL
///
/// Used for reverse geocoding.
///
/// fullAddress:
///   Complete Google Maps address.
///
/// area:
///   Local area / neighborhood.
///
/// city:
///   City name.
///
/// areaAndCity:
///   Used in the top header.
/// ------------------------------------------------------------

class LocationAddress {
  final String fullAddress;

  final String area;

  final String city;

  const LocationAddress({
    required this.fullAddress,
    required this.area,
    required this.city,
  });

  /// Example:
  ///
  /// Amanaka, Raipur
  String get areaAndCity {
    if (area.isNotEmpty &&
        city.isNotEmpty) {
      // Avoid duplicate text.
      if (area.toLowerCase() ==
          city.toLowerCase()) {
        return city;
      }

      return '$area, $city';
    }

    if (city.isNotEmpty) {
      return city;
    }

    if (area.isNotEmpty) {
      return area;
    }

    return fullAddress;
  }
}

/// ------------------------------------------------------------
/// GOOGLE PLACES / ROUTING SERVICE
/// ------------------------------------------------------------

class GooglePlacesService {
  GooglePlacesService._();

  static final GooglePlacesService instance =
      GooglePlacesService._();

  /// IMPORTANT:
  /// For production, move this key to a backend
  /// or environment variable.
  static const String _apiKey =
      'AIzaSyAoVHuAyzxiVUgspUsnM5crVkpgczdLdN0';

  // ============================================================
  // PLACE AUTOCOMPLETE
  // ============================================================

  Future<List<PlaceSuggestion>> autocomplete(
    String input,
  ) async {
    if (input.trim().length < 2) {
      return [];
    }

    final response = await http.post(
      Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      ),
      headers: {
        'Content-Type': 'application/json',

        'X-Goog-Api-Key':
            _apiKey,

        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,'
            'suggestions.placePrediction.text.text',
      },
      body: jsonEncode({
        'input':
            input.trim(),

        'includedRegionCodes': [
          'IN',
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Google Places autocomplete failed: '
        '${response.statusCode} '
        '${response.body}',
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final suggestions =
        data['suggestions']
            as List<dynamic>? ??
            [];

    return suggestions
        .where(
          (item) =>
              item['placePrediction'] != null,
        )
        .map(
          (item) {
            final prediction =
                item['placePrediction']
                    as Map<String, dynamic>;

            final text =
                prediction['text']
                    as Map<String, dynamic>?;

            return PlaceSuggestion(
              placeId:
                  prediction['placeId']
                      as String,

              description:
                  text?['text']
                      as String? ??
                      '',
            );
          },
        )
        .toList();
  }

  // ============================================================
  // GET PLACE LOCATION FROM PLACE ID
  // ============================================================

  Future<LatLng> getPlaceLocation(
    String placeId,
  ) async {
    final response = await http.get(
      Uri.parse(
        'https://places.googleapis.com/v1/places/'
        '$placeId',
      ),
      headers: {
        'X-Goog-Api-Key':
            _apiKey,

        'X-Goog-FieldMask':
            'location',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Google Places details failed: '
        '${response.statusCode} '
        '${response.body}',
      );
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final location =
        data['location']
            as Map<String, dynamic>;

    final lat =
        (location['latitude'] as num)
            .toDouble();

    final lng =
        (location['longitude'] as num)
            .toDouble();

    return LatLng(
      lat,
      lng,
    );
  }

  // ============================================================
  // GET ROAD ROUTE
  // ============================================================

  Future<RouteResult> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    // ----------------------------------------------------------
    // 1. GOOGLE DIRECTIONS API
    // ----------------------------------------------------------

    if (!kIsWeb) {
      try {
        final googleUrl = Uri.parse(
          'https://maps.googleapis.com/maps/api/'
          'directions/json'
          '?origin=${origin.latitude},'
          '${origin.longitude}'
          '&destination=${destination.latitude},'
          '${destination.longitude}'
          '&mode=driving'
          '&key=$_apiKey',
        );

        final response =
            await http.get(
          googleUrl,
        );

        if (response.statusCode == 200) {
          final data =
              jsonDecode(response.body)
                  as Map<String, dynamic>;

          final routes =
              data['routes']
                  as List<dynamic>?;

          if (data['status'] == 'OK' &&
              routes != null &&
              routes.isNotEmpty) {
            final route =
                routes.first
                    as Map<String, dynamic>;

            final overviewPolyline =
                route['overview_polyline']
                    as Map<String, dynamic>?;

            final encodedPoints =
                overviewPolyline?['points']
                    as String?;

            final legs =
                route['legs']
                    as List<dynamic>?;

            final leg =
                legs != null &&
                        legs.isNotEmpty
                    ? legs.first
                        as Map<String, dynamic>
                    : null;

            if (encodedPoints != null &&
                encodedPoints.isNotEmpty) {
              final points =
                  decodePolyline(
                encodedPoints,
              );

              final distance =
                  leg?['distance']
                      as Map<String, dynamic>?;

              final duration =
                  leg?['duration']
                      as Map<String, dynamic>?;

              return RouteResult(
                points:
                    points,

                distanceText:
                    distance?['text']
                        as String? ??
                        '',

                durationText:
                    duration?['text']
                        as String? ??
                        '',

                distanceMeters:
                    distance?['value']
                        as num? ??
                        0,

                durationSeconds:
                    duration?['value']
                        as num? ??
                        0,
              );
            }
          }
        }
      } catch (error) {
        debugPrint(
          'Google Directions API error: '
          '$error',
        );
      }
    }

    // ----------------------------------------------------------
    // 2. OSRM FALLBACK
    //
    // Returns an actual road route.
    // ----------------------------------------------------------

    try {
      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/'
        'route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},'
        '${destination.latitude}'
        '?overview=full'
        '&geometries=geojson',
      );

      final response =
          await http.get(
        osrmUrl,
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body)
                as Map<String, dynamic>;

        final routes =
            data['routes']
                as List<dynamic>?;

        if (data['code'] == 'Ok' &&
            routes != null &&
            routes.isNotEmpty) {
          final route =
              routes.first
                  as Map<String, dynamic>;

          final geometry =
              route['geometry']
                  as Map<String, dynamic>?;

          final coordinates =
              geometry?['coordinates']
                  as List<dynamic>?;

          if (coordinates != null &&
              coordinates.isNotEmpty) {
            final points =
                coordinates.map(
              (coordinate) {
                final coordinateList =
                    coordinate
                        as List<dynamic>;

                final longitude =
                    (coordinateList[0] as num)
                        .toDouble();

                final latitude =
                    (coordinateList[1] as num)
                        .toDouble();

                return LatLng(
                  latitude,
                  longitude,
                );
              },
            ).toList();

            final distanceMeters =
                (route['distance'] as num?)
                    ?.toDouble() ??
                    0.0;

            final durationSeconds =
                (route['duration'] as num?)
                    ?.toDouble() ??
                    0.0;

            final distanceKm =
                distanceMeters / 1000;

            final durationMinutes =
                durationSeconds / 60;

            return RouteResult(
              points:
                  points,

              distanceText:
                  '${distanceKm.toStringAsFixed(1)} km',

              durationText:
                  '${durationMinutes.round()} mins',

              distanceMeters:
                  distanceMeters,

              durationSeconds:
                  durationSeconds,
            );
          }
        }
      }
    } catch (error) {
      debugPrint(
        'OSRM Routing API error: '
        '$error',
      );
    }

    // ----------------------------------------------------------
    // 3. LAST FALLBACK
    // ----------------------------------------------------------

    return RouteResult(
      points: [
        origin,
        destination,
      ],

      distanceText:
          '',

      durationText:
          '',

      distanceMeters:
          0,

      durationSeconds:
          0,
    );
  }

  // ============================================================
  // REVERSE GEOCODING
  //
  // Converts latitude + longitude into:
  //
  // 1. Full address
  // 2. Area
  // 3. City
  // ============================================================

  Future<LocationAddress>
      getLocationAddressFromCoordinates(
    LatLng position,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/'
        'geocode/json'
        '?latlng=${position.latitude},'
        '${position.longitude}'
        '&key=$_apiKey',
      );

      final response =
          await http.get(
        url,
      );

      // --------------------------------------------------------
      // HTTP ERROR
      // --------------------------------------------------------

      if (response.statusCode != 200) {
        debugPrint(
          'Reverse geocoding HTTP error: '
          '${response.statusCode}',
        );

        debugPrint(
          'Response body: '
          '${response.body}',
        );

        return const LocationAddress(
          fullAddress:
              '',

          area:
              '',

          city:
              '',
        );
      }

      final data =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      // --------------------------------------------------------
      // GOOGLE API STATUS ERROR
      // --------------------------------------------------------

      if (data['status'] != 'OK') {
        debugPrint(
          'Reverse geocoding Google status: '
          '${data['status']}',
        );

        debugPrint(
          'Google error message: '
          '${data['error_message']}',
        );

        return const LocationAddress(
          fullAddress:
              '',

          area:
              '',

          city:
              '',
        );
      }

      final results =
          data['results']
              as List<dynamic>?;

      if (results == null ||
          results.isEmpty) {
        return const LocationAddress(
          fullAddress:
              '',

          area:
              '',

          city:
              '',
        );
      }

      // --------------------------------------------------------
      // MOST SPECIFIC RESULT
      //
      // Google generally returns the closest and most specific
      // address first.
      // --------------------------------------------------------

      final firstResult =
          results.first
              as Map<String, dynamic>;

      final fullAddress =
          firstResult['formatted_address']
                  as String? ??
              '';

      final components =
          firstResult['address_components']
                  as List<dynamic>? ??
              [];

      String area =
          '';

      String city =
          '';

      // --------------------------------------------------------
      // EXTRACT AREA + CITY
      //
      // We use address component TYPES instead of parsing
      // formatted_address.
      // --------------------------------------------------------

      for (final component
          in components) {
        final item =
            component
                as Map<String, dynamic>;

        final types =
            (item['types']
                    as List<dynamic>?)
                ?.map(
                  (type) =>
                      type.toString(),
                )
                .toList() ??
                [];

        final longName =
            item['long_name']
                    as String? ??
                '';

        // ------------------------------------------------------
        // CITY
        //
        // locality is normally the city.
        // ------------------------------------------------------

        if (city.isEmpty &&
            types.contains(
              'locality',
            )) {
          city =
              longName;
        }

        // ------------------------------------------------------
        // AREA
        //
        // Priority:
        //
        // neighborhood
        // sublocality_level_1
        // sublocality
        // sublocality_level_2
        // ------------------------------------------------------

        if (area.isEmpty &&
            types.contains(
              'neighborhood',
            )) {
          area =
              longName;
        }

        if (area.isEmpty &&
            types.contains(
              'sublocality_level_1',
            )) {
          area =
              longName;
        }

        if (area.isEmpty &&
            types.contains(
              'sublocality',
            )) {
          area =
              longName;
        }

        if (area.isEmpty &&
            types.contains(
              'sublocality_level_2',
            )) {
          area =
              longName;
        }
      }

      // --------------------------------------------------------
      // CITY FALLBACK
      //
      // Some locations do not return locality.
      // --------------------------------------------------------

      if (city.isEmpty) {
        for (final component
            in components) {
          final item =
              component
                  as Map<String, dynamic>;

          final types =
              (item['types']
                      as List<dynamic>?)
                  ?.map(
                    (type) =>
                        type.toString(),
                  )
                  .toList() ??
                  [];

          final longName =
              item['long_name']
                      as String? ??
                  '';

          if (types.contains(
            'administrative_area_level_2',
          )) {
            city =
                longName;

            break;
          }
        }
      }

      // --------------------------------------------------------
      // AREA FALLBACK
      //
      // Sometimes Google returns no neighborhood/sublocality.
      // In that case, use city rather than showing coordinates.
      // --------------------------------------------------------

      if (area.isEmpty &&
          city.isNotEmpty) {
        area =
            city;
      }

      return LocationAddress(
        fullAddress:
            fullAddress.trim(),

        area:
            area.trim(),

        city:
            city.trim(),
      );
    } catch (error) {
      debugPrint(
        'Reverse geocoding error: '
        '$error',
      );

      return const LocationAddress(
        fullAddress:
            '',

        area:
            '',

        city:
            '',
      );
    }
  }

  // ============================================================
  // GET FULL ADDRESS
  //
  // This method is used by:
  //
  // - Source
  // - Destination
  // - Map selected locations
  //
  // It returns the complete Google formatted address.
  // ============================================================

  Future<String> getAddressFromCoordinates(
    LatLng position,
  ) async {
    final locationAddress =
        await getLocationAddressFromCoordinates(
      position,
    );

    return locationAddress.fullAddress;
  }

  // ============================================================
  // GOOGLE ENCODED POLYLINE DECODER
  // ============================================================

  static List<LatLng> decodePolyline(
    String encoded,
  ) {
    final points =
        <LatLng>[];

    int index =
        0;

    int latitude =
        0;

    int longitude =
        0;

    while (index <
        encoded.length) {
      int result =
          0;

      int shift =
          0;

      int byte;

      // --------------------------------------------------------
      // LATITUDE
      // --------------------------------------------------------

      do {
        byte =
            encoded.codeUnitAt(
                  index++,
                ) -
                63;

        result |=
            (byte & 0x1f)
                << shift;

        shift +=
            5;
      } while (byte >=
          0x20);

      final deltaLatitude =
          (result & 1) != 0
              ? ~(result >> 1)
              : result >> 1;

      latitude +=
          deltaLatitude;

      // --------------------------------------------------------
      // LONGITUDE
      // --------------------------------------------------------

      result =
          0;

      shift =
          0;

      do {
        byte =
            encoded.codeUnitAt(
                  index++,
                ) -
                63;

        result |=
            (byte & 0x1f)
                << shift;

        shift +=
            5;
      } while (byte >=
          0x20);

      final deltaLongitude =
          (result & 1) != 0
              ? ~(result >> 1)
              : result >> 1;

      longitude +=
          deltaLongitude;

      points.add(
        LatLng(
          latitude / 1e5,
          longitude / 1e5,
        ),
      );
    }

    return points;
  }
}