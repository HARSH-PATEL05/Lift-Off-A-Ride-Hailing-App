import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastLocationService {
  LastLocationService._();

  static final LastLocationService instance =
      LastLocationService._();

  // Storage keys
  static const String _latitudeKey =
      'liftoff_last_latitude';

  static const String _longitudeKey =
      'liftoff_last_longitude';

  static const String _addressKey =
      'liftoff_last_address';

  static const String _shortAddressKey =
      'liftoff_last_short_address';

  /// Save the user's latest real location.
  ///
  /// This location is saved locally and can be loaded
  /// the next time the app is opened.
  Future<void> saveLocation({
    required LatLng position,
    String? address,
    String? shortAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble(
        _latitudeKey,
        position.latitude,
      );

      await prefs.setDouble(
        _longitudeKey,
        position.longitude,
      );

      if (address != null && address.trim().isNotEmpty) {
        await prefs.setString(
          _addressKey,
          address.trim(),
        );
      }

      if (shortAddress != null &&
          shortAddress.trim().isNotEmpty) {
        await prefs.setString(
          _shortAddressKey,
          shortAddress.trim(),
        );
      }
    } catch (e) {
      // Location storage failure should not crash the app.
      // We can log this later if required.
    }
  }

  /// Get the last saved location.
  ///
  /// Returns null if no location has ever been saved.
  Future<LatLng?> getLastPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final latitude = prefs.getDouble(_latitudeKey);
      final longitude = prefs.getDouble(_longitudeKey);

      if (latitude == null || longitude == null) {
        return null;
      }

      return LatLng(latitude, longitude);
    } catch (e) {
      return null;
    }
  }

  /// Get the last saved full address.
  Future<String?> getLastAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString(_addressKey);
    } catch (e) {
      return null;
    }
  }

  /// Get the last saved short address.
  Future<String?> getLastShortAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString(_shortAddressKey);
    } catch (e) {
      return null;
    }
  }

  /// Get all saved location information together.
  Future<LastLocationData?> getLastLocation() async {
    try {
      final position = await getLastPosition();

      if (position == null) {
        return null;
      }

      final address = await getLastAddress();
      final shortAddress = await getLastShortAddress();

      return LastLocationData(
        position: position,
        address: address,
        shortAddress: shortAddress,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear the saved location.
  ///
  /// Normally this will not be needed during normal app usage.
  /// It can be useful for logout, testing, or account reset.
  Future<void> clearLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_latitudeKey);
      await prefs.remove(_longitudeKey);
      await prefs.remove(_addressKey);
      await prefs.remove(_shortAddressKey);
    } catch (e) {
      // Ignore storage errors.
    }
  }
}

/// Contains all information about the user's
/// last saved location.
class LastLocationData {
  final LatLng position;
  final String? address;
  final String? shortAddress;

  const LastLocationData({
    required this.position,
    this.address,
    this.shortAddress,
  });
}