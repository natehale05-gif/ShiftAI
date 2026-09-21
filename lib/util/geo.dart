import 'package:geolocator/geolocator.dart';

/// A coarse fix, worth a metro area's worth of precision and nothing more —
/// see `docs/API.md`'s `/v1/league` for why the server only needs this much.
class GeoFix {
  const GeoFix(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// The device's own idea of where it is, or null if that is unavailable for
/// any reason — permission refused, the OS setting is off, no hardware to
/// ask. Every one of those is the same "cannot place you locally" to the
/// caller, which is why this never throws.
abstract final class Geo {
  static Future<GeoFix?> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      return GeoFix(position.latitude, position.longitude);
    } on Object {
      return null;
    }
  }
}
