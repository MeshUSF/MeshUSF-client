import 'dart:async';

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

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationLookupException(
        LocationLookupFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationLookupException(
        LocationLookupFailure.permissionDenied,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (!_isValidCoordinates(position.latitude, position.longitude)) {
        throw const LocationLookupException(LocationLookupFailure.unavailable);
      }
      return SharedCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
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
