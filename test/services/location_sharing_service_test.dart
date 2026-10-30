import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/services/location_sharing_service.dart';

class _LocationConnector extends MeshCoreConnector {
  bool connected = true;
  bool gpsEnabled = false;
  double? latitude;
  double? longitude;

  @override
  bool get isConnected => connected;
  @override
  bool get hasGps => gpsEnabled;
  @override
  double? get selfLatitude => latitude;
  @override
  double? get selfLongitude => longitude;
}

class _LocationPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  final settings = <LocationSettings?>[];
  Future<bool> Function()? checkService;
  Future<Position> Function()? locate;

  @override
  Future<bool> isLocationServiceEnabled() async {
    serviceChecks++;
    return checkService == null ? serviceEnabled : await checkService!();
  }

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settings.add(locationSettings);
    return locate == null ? _position() : await locate!();
  }
}

Position _position({
  DateTime? timestamp,
  double latitude = 45.5,
  double longitude = -122.6,
  double accuracy = 10,
}) => Position(
  longitude: longitude,
  latitude: latitude,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Matcher _failure(LocationLookupFailure failure) =>
    isA<LocationLookupException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

void main() {
  late GeolocatorPlatform originalPlatform;
  late _LocationPlatform platform;
  late _LocationConnector connector;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    platform = _LocationPlatform();
    GeolocatorPlatform.instance = platform;
    connector = _LocationConnector();
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
    connector.dispose();
  });

  test(
    'node GPS wins without consulting device location or permissions',
    () async {
      connector
        ..gpsEnabled = true
        ..latitude = 42
        ..longitude = -71;
      platform.serviceEnabled = false;

      final result = await LocationSharingService.getCurrentCoordinates(
        connector,
      );

      expect(result.latitude, 42);
      expect(result.longitude, -71);
      expect(platform.serviceChecks, 0);
      expect(platform.settings, isEmpty);
    },
  );

  for (final reason in [
    'disabled GPS',
    'invalid coordinates',
    'disconnected',
  ]) {
    test('$reason falls back to device coordinates', () async {
      connector
        ..gpsEnabled = reason != 'disabled GPS'
        ..connected = reason != 'disconnected'
        ..latitude = reason == 'invalid coordinates' ? 91 : 42
        ..longitude = -71;

      final result = await LocationSharingService.getCurrentCoordinates(
        connector,
      );

      expect(result.latitude, 45.5);
      expect(result.longitude, -122.6);
      expect(platform.settings, hasLength(1));
      expect(platform.settings.single!.timeLimit, const Duration(seconds: 10));
    });
  }

  test('disabled location services report a service error', () async {
    platform.serviceEnabled = false;
    await expectLater(
      LocationSharingService.getCurrentCoordinates(connector),
      throwsA(_failure(LocationLookupFailure.serviceDisabled)),
    );
    expect(platform.settings, isEmpty);
  });

  for (final entry in <Object, LocationLookupFailure>{
    const LocationServiceDisabledException():
        LocationLookupFailure.serviceDisabled,
    const PermissionDeniedException('denied'):
        LocationLookupFailure.permissionDenied,
    const PositionUpdateException('unavailable'):
        LocationLookupFailure.unavailable,
    TimeoutException('timeout'): LocationLookupFailure.unavailable,
    PlatformException(code: 'unavailable'): LocationLookupFailure.unavailable,
  }.entries) {
    test(
      '${entry.key.runtimeType} becomes the corresponding location error',
      () async {
        platform.locate = () async => throw entry.key;
        await expectLater(
          LocationSharingService.getCurrentCoordinates(connector),
          throwsA(_failure(entry.value)),
        );
      },
    );
  }

  for (final latitude in [double.nan, double.infinity, 91.0]) {
    test('invalid fresh latitude $latitude is rejected', () async {
      platform.locate = () async => _position(latitude: latitude);
      await expectLater(
        LocationSharingService.getCurrentCoordinates(connector),
        throwsA(_failure(LocationLookupFailure.unavailable)),
      );
    });
  }

  testWidgets(
    'stalled lookup expires after ten seconds and ignores a late fix',
    (tester) async {
      final pending = Completer<Position>();
      platform.locate = () => pending.future;
      var completed = false;
      final result = expectLater(
        LocationSharingService.getCurrentCoordinates(connector),
        throwsA(_failure(LocationLookupFailure.unavailable)),
      ).then((_) => completed = true);

      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      expect(completed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      await result;
      pending.complete(_position());
      await tester.pump();
      expect(platform.settings, hasLength(1));
    },
  );

  testWidgets('a late service check cannot start another location request', (
    tester,
  ) async {
    final pending = Completer<bool>();
    platform.checkService = () => pending.future;
    final result = expectLater(
      LocationSharingService.getCurrentCoordinates(connector),
      throwsA(_failure(LocationLookupFailure.unavailable)),
    );

    await tester.pump(const Duration(seconds: 10));
    await result;
    pending.complete(true);
    await tester.pump();
    expect(platform.permissionChecks, 0);
    expect(platform.settings, isEmpty);
  });

  if (kIsWeb) {
    test('browser prompts through a single coordinate request', () async {
      platform.permission = LocationPermission.denied;
      await LocationSharingService.getCurrentCoordinates(connector);
      expect(platform.permissionChecks, 0);
      expect(platform.permissionRequests, 0);
      expect(platform.settings, hasLength(1));
      expect(
        (platform.settings.single! as WebSettings).maximumAge,
        const Duration(seconds: 60),
      );
    });

    for (final accuracy in [49.0, 50.0]) {
      test(
        'reuses a recent browser fix with $accuracy meter accuracy',
        () async {
          platform.locate = () async => _position(
            timestamp: DateTime.now().subtract(const Duration(seconds: 59)),
            accuracy: accuracy,
          );
          await LocationSharingService.getCurrentCoordinates(connector);
          expect(platform.settings, hasLength(1));
        },
      );
    }

    for (final reason in [
      'older than sixty seconds',
      'future timestamp',
      'accuracy above fifty meters',
      'unreported accuracy',
      'nonfinite accuracy',
      'invalid coordinates',
    ]) {
      test('requests a fresh fix for cached position with $reason', () async {
        platform.locate = () async {
          if (platform.settings.length > 1) return _position(accuracy: 500);
          return _position(
            timestamp: reason == 'future timestamp'
                ? DateTime.now().add(const Duration(minutes: 1))
                : DateTime.now().subtract(
                    Duration(
                      seconds: reason == 'older than sixty seconds' ? 61 : 10,
                    ),
                  ),
            accuracy: switch (reason) {
              'accuracy above fifty meters' => 50.1,
              'unreported accuracy' => 0,
              'nonfinite accuracy' => double.nan,
              _ => 10,
            },
            latitude: reason == 'invalid coordinates' ? 91 : 45.5,
          );
        };
        final result = await LocationSharingService.getCurrentCoordinates(
          connector,
        );
        expect(result.latitude, 45.5);
        expect(platform.settings, hasLength(2));
        expect(
          (platform.settings.last! as WebSettings).maximumAge,
          Duration.zero,
        );
      });
    }

    test('fresh fixes may have accuracy above fifty meters', () async {
      platform.locate = () async => _position(accuracy: 500);
      await LocationSharingService.getCurrentCoordinates(connector);
      expect(platform.settings, hasLength(1));
    });

    testWidgets('a cache retry shares the original ten-second deadline', (
      tester,
    ) async {
      final first = Completer<Position>();
      final second = Completer<Position>();
      platform.locate = () =>
          platform.settings.length == 1 ? first.future : second.future;
      final result = expectLater(
        LocationSharingService.getCurrentCoordinates(connector),
        throwsA(_failure(LocationLookupFailure.unavailable)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      first.complete(
        _position(
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      );
      await tester.pump();
      expect(platform.settings, hasLength(2));
      await tester.pump(const Duration(seconds: 2));
      await result;
      second.complete(_position());
      await tester.pump();
    });
  } else {
    test('native location retains its permission request', () async {
      platform.permission = LocationPermission.denied;
      await LocationSharingService.getCurrentCoordinates(connector);
      expect(platform.permissionRequests, 1);
      expect(platform.settings, hasLength(1));
      expect(platform.settings.single, isNot(isA<WebSettings>()));
    });

    for (final permission in [
      LocationPermission.denied,
      LocationPermission.deniedForever,
    ]) {
      test(
        'native denied permission $permission does not request coordinates',
        () async {
          platform
            ..permission = permission
            ..requestedPermission = permission;
          await expectLater(
            LocationSharingService.getCurrentCoordinates(connector),
            throwsA(_failure(LocationLookupFailure.permissionDenied)),
          );
          expect(platform.settings, isEmpty);
        },
      );
    }
  }
}
