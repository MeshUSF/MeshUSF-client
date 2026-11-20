import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import 'location_sharing_service.dart';

enum MapLocationSource { phone, radio, manual }

/// Owns location tracking only while the map is active.
class MapLocationService extends ChangeNotifier {
  final MeshCoreConnector _connector;
  Timer? _refreshTimer;
  StreamSubscription<Position>? _phoneSubscription;
  LatLng? _phonePosition;
  LatLng? _publishedPosition;
  MapLocationSource? _publishedSource;
  bool _active = false;
  bool _phoneLookupInFlight = false;
  int _generation = 0;

  MapLocationService(this._connector) {
    _connector.addListener(_onRadioChanged);
  }

  LatLng? get _radioPosition {
    final lat = _connector.selfLatitude;
    final lon = _connector.selfLongitude;
    if (!_connector.isConnected ||
        lat == null ||
        lon == null ||
        !_connector.hasValidLocation(lat, lon)) {
      return null;
    }
    return LatLng(lat, lon);
  }

  LatLng? get position => _publishedPosition;
  MapLocationSource? get source => _publishedSource;

  void start() {
    if (_active) return;
    _active = true;
    _onRadioChanged();
    unawaited(_refresh(refreshRadio: true));
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refresh(refreshRadio: !_connector.hasGps));
    });
  }

  void stop() {
    _active = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    // Keep the last fix visible while foreground tracking starts again.
    _stopPhoneTracking(clearPosition: false);
  }

  Future<void> _refresh({required bool refreshRadio}) async {
    if (!_active || !_connector.isConnected) return;
    if (refreshRadio) {
      try {
        // SELF_INFO refreshes coordinates without reloading contacts/config.
        await _connector.sendFrame(buildAppStartFrame());
      } catch (error) {
        debugPrint('Map radio location refresh failed: $error');
      }
    }
    if (!_active || !_connector.isConnected) return;
    _onRadioChanged();
    await _trackPhone();
  }

  void _onRadioChanged() {
    if (!_connector.isConnected) {
      _stopPhoneTracking();
      _publish();
      return;
    }
    if (!_active) return;
    final wasUsingRadio =
        _publishedSource == MapLocationSource.radio ||
        _publishedSource == MapLocationSource.manual;
    if (_radioPosition != null || _connector.manualLocation != null) {
      _stopPhoneTracking();
    }
    _publish();
    if (wasUsingRadio && _radioPosition == null && _connector.isConnected) {
      unawaited(_trackPhone());
    }
  }

  Future<void> _trackPhone() async {
    if (!_active ||
        !_connector.isConnected ||
        _connector.manualLocation != null ||
        _radioPosition != null ||
        _phoneLookupInFlight ||
        _phoneSubscription != null) {
      return;
    }
    _phoneLookupInFlight = true;
    final generation = _generation;
    try {
      final coordinates = await LocationSharingService.getCurrentCoordinates(
        _connector,
      );
      if (!_active || generation != _generation || !_connector.isConnected) {
        return;
      }
      if (_radioPosition != null || _connector.manualLocation != null) {
        _onRadioChanged();
        return;
      }
      _phonePosition = LatLng(coordinates.latitude, coordinates.longitude);
      _publish();
      _phoneSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen(
            (position) {
              if (!_active || generation != _generation) return;
              if (!position.latitude.isFinite ||
                  !position.longitude.isFinite ||
                  position.latitude.abs() > 90 ||
                  position.longitude.abs() > 180) {
                return;
              }
              _phonePosition = LatLng(position.latitude, position.longitude);
              _publish();
            },
            onError: (Object error) {
              if (generation != _generation) return;
              debugPrint('Map phone location stream failed: $error');
              _stopPhoneTracking();
              _publish();
            },
            onDone: () {
              if (generation != _generation) return;
              _stopPhoneTracking();
              _publish();
            },
          );
    } catch (error) {
      // Permission/service failures leave the map usable; retry next minute.
      debugPrint('Map phone location lookup failed: $error');
    } finally {
      if (generation == _generation) _phoneLookupInFlight = false;
    }
  }

  void _stopPhoneTracking({bool clearPosition = true}) {
    _generation++;
    _phoneLookupInFlight = false;
    unawaited(_phoneSubscription?.cancel());
    _phoneSubscription = null;
    if (clearPosition) _phonePosition = null;
  }

  void _publish() {
    final manual = _active ? _connector.manualLocation : null;
    final radio = _active ? _radioPosition : null;
    final position = _active && _connector.isConnected
        ? manual != null
              ? LatLng(manual.latitude, manual.longitude)
              : radio ?? _phonePosition
        : null;
    final source = position == null
        ? null
        : manual != null
        ? MapLocationSource.manual
        : radio != null
        ? MapLocationSource.radio
        : MapLocationSource.phone;
    if (position == _publishedPosition && source == _publishedSource) return;
    _publishedPosition = position;
    _publishedSource = source;
    notifyListeners();
  }

  @override
  void dispose() {
    _connector.removeListener(_onRadioChanged);
    _refreshTimer?.cancel();
    _active = false;
    _stopPhoneTracking();
    super.dispose();
  }
}
