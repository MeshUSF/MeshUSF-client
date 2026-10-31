import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../connector/meshcore_connector.dart';

enum LocationLookupFailure { permissionDenied, serviceDisabled, unavailable }

class LocationLookupException implements Exception {
  final LocationLookupFailure failure;

  const LocationLookupException(this.failure);
}

class SharedCoordinates {
  final double latitude;
  final double longitude;

  const SharedCoordinates({required this.latitude, required this.longitude});
}

class LocationSharingService {
  const LocationSharingService._();

  static const _maxCachedPositionAge = Duration(seconds: 60);
  static const _maxCachedAccuracyMeters = 50.0;
  static const _lookupTimeout = Duration(seconds: 10);

  static Future<SharedCoordinates> getCurrentCoordinates(
    MeshCoreConnector connector,
  ) async {
    final radioLatitude = connector.selfLatitude;
    final radioLongitude = connector.selfLongitude;
    if (connector.isConnected &&
        connector.hasGps &&
        connector.hasValidLocation(radioLatitude, radioLongitude)) {
      return SharedCoordinates(
        latitude: radioLatitude!,
        longitude: radioLongitude!,
      );
    }

    var lookupExpired = false;
    try {
      // Bound the whole operation independently of the browser plugin's timeout.
      return await (() async {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw const LocationLookupException(
            LocationLookupFailure.serviceDisabled,
          );
        }
        if (lookupExpired) throw TimeoutException('Location lookup expired');

        if (!kIsWeb) {
          var permission = await Geolocator.checkPermission();
          if (lookupExpired) throw TimeoutException('Location lookup expired');
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            throw const LocationLookupException(
              LocationLookupFailure.permissionDenied,
            );
          }
        }

        if (lookupExpired) throw TimeoutException('Location lookup expired');
        final requestStartedAt = DateTime.now();
        var position = await Geolocator.getCurrentPosition(
          locationSettings: kIsWeb
              ? WebSettings(
                  accuracy: LocationAccuracy.high,
                  maximumAge: _maxCachedPositionAge,
                  timeLimit: _lookupTimeout,
                )
              : const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: _lookupTimeout,
                ),
        );
        if (lookupExpired) throw TimeoutException('Location lookup expired');

        if (kIsWeb) {
          final cacheAge = DateTime.now().difference(position.timestamp);
          final isFresh =
              !position.timestamp.isBefore(requestStartedAt) &&
              !cacheAge.isNegative;
          final isReusable =
              !cacheAge.isNegative &&
              cacheAge <= _maxCachedPositionAge &&
              position.accuracy.isFinite &&
              position.accuracy > 0 &&
              position.accuracy <= _maxCachedAccuracyMeters &&
              _isValidCoordinates(position.latitude, position.longitude);
          if (!isFresh && !isReusable) {
            position = await Geolocator.getCurrentPosition(
              locationSettings: WebSettings(
                accuracy: LocationAccuracy.high,
                maximumAge: Duration.zero,
                timeLimit: _lookupTimeout,
              ),
            );
          }
        }

        if (!_isValidCoordinates(position.latitude, position.longitude)) {
          throw const LocationLookupException(
            LocationLookupFailure.unavailable,
          );
        }
        return SharedCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      })().timeout(
        _lookupTimeout,
        onTimeout: () {
          lookupExpired = true;
          throw TimeoutException('Location lookup expired');
        },
      );
    } on LocationServiceDisabledException {
      throw const LocationLookupException(
        LocationLookupFailure.serviceDisabled,
      );
    } on PermissionDeniedException {
      throw const LocationLookupException(
        LocationLookupFailure.permissionDenied,
      );
    } on TimeoutException {
      throw const LocationLookupException(LocationLookupFailure.unavailable);
    } on PositionUpdateException {
      throw const LocationLookupException(LocationLookupFailure.unavailable);
    } on PlatformException {
      throw const LocationLookupException(LocationLookupFailure.unavailable);
    }
  }

  static bool _isValidCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
