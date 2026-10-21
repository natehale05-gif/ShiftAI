import 'package:geolocator/geolocator.dart';

/// A coarse fix, worth a metro area's worth of precision and nothing more —
/// see `docs/API.md`'s `/v1/league` for why the server only needs this much.
class GeoFix {
  const GeoFix(this.lat, this.lng);

  /// [lat] and [lng] to two decimal places, about a kilometre: plenty for
  /// a metro area. A low-accuracy fix still came back with every decimal
  /// the device had, and Apple counts three or more as precise location,
  /// which is not what the privacy label says this app collects.
  factory GeoFix.coarse(double lat, double lng) => GeoFix(_two(lat), _two(lng));

  static double _two(double v) => (v * 100).roundToDouble() / 100;

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
      return GeoFix.coarse(position.latitude, position.longitude);
    } on Object {
      return null;
    }
  }
}
