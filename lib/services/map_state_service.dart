import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

// Persists the last map viewport center so the map reopens where the user
// left it instead of jumping to the (often stale) GPS fix.
class MapStateService {
  static const _latKey = 'last_map_center_lat';
  static const _lngKey = 'last_map_center_lng';

  static Future<void> saveCenter(LatLng center) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, center.latitude);
    await prefs.setDouble(_lngKey, center.longitude);
  }

  static Future<LatLng?> loadCenter() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}