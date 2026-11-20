import 'prefs_manager.dart';

class ManualLocation {
  final double latitude;
  final double longitude;
  final double? previousRadioLatitude;
  final double? previousRadioLongitude;

  const ManualLocation({
    required this.latitude,
    required this.longitude,
    this.previousRadioLatitude,
    this.previousRadioLongitude,
  });
}

/// Remembers the explicit override and its undo point for each radio.
class ManualLocationStore {
  String _key(String radioKey) =>
      'manual_location_${radioKey.substring(0, 10)}';

  ManualLocation? load(String radioKey) {
    if (radioKey.length < 10) return null;
    try {
      final values = PrefsManager.instance.getStringList(_key(radioKey));
      if (values == null || values.length != 4) return null;
      final lat = double.tryParse(values[0]);
      final lon = double.tryParse(values[1]);
      final previousLat = double.tryParse(values[2]);
      final previousLon = double.tryParse(values[3]);
      if (!_valid(lat, lon) ||
          ((values[2].isNotEmpty || values[3].isNotEmpty) &&
              !_valid(previousLat, previousLon))) {
        return null;
      }
      return ManualLocation(
        latitude: lat!,
        longitude: lon!,
        previousRadioLatitude: previousLat,
        previousRadioLongitude: previousLon,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String radioKey, ManualLocation? location) async {
    if (radioKey.length < 10) return;
    final prefs = PrefsManager.instance;
    if (location == null) {
      await prefs.remove(_key(radioKey));
      return;
    }
    await prefs.setStringList(_key(radioKey), [
      '${location.latitude}',
      '${location.longitude}',
      location.previousRadioLatitude?.toString() ?? '',
      location.previousRadioLongitude?.toString() ?? '',
    ]);
  }

  bool _valid(double? lat, double? lon) =>
      lat != null &&
      lon != null &&
      lat.isFinite &&
      lon.isFinite &&
      lat.abs() <= 90 &&
      lon.abs() <= 180;
}
