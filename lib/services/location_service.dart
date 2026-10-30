import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static LatLng? last;

  /// Asks for permission if needed. Returns a message when location is not
  /// available, or null when it is.
  static Future<String?> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on location services to find rides near you.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return 'Location permission was denied.';
    }
    if (perm == LocationPermission.deniedForever) {
      return 'Location is blocked. Enable it for TrustRide in your phone settings.';
    }
    return null;
  }

  /// Current position, or null if unavailable.
  static Future<LatLng?> current() async {
    try {
      if (await ensurePermission() != null) return last;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      last = LatLng(p.latitude, p.longitude);
      return last;
    } catch (_) {
      return last;
    }
  }

  /// Continuous updates (used by drivers while online).
  static Stream<LatLng> watch({int distanceFilterMeters = 25}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    ).map((p) {
      last = LatLng(p.latitude, p.longitude);
      return last!;
    });
  }
}
