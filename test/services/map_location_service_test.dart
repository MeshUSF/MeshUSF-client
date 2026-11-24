import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshusf/connector/meshcore_connector.dart';
import 'package:meshusf/connector/meshcore_protocol.dart';
import 'package:meshusf/services/map_location_service.dart';
import 'package:meshusf/storage/manual_location_store.dart';

class _MapConnector extends MeshCoreConnector {
  bool connected = true;
  bool gps = false;
  double? latitude;
  double? longitude;
  bool failSend = false;
  ManualLocation? selectedLocation;
  final frames = <Uint8List>[];

  @override
  bool get isConnected => connected;
  @override
  bool get hasGps => gps;
  @override
  double? get selfLatitude => latitude;
  @override
  double? get selfLongitude => longitude;
  @override
  ManualLocation? get manualLocation => selectedLocation;

  @override
  Future<void> sendFrame(
    Uint8List data, {
    String? channelSendQueueId,
    bool expectsGenericAck = false,
    bool waitForGenericAck = false,
  }) async {
    frames.add(data);
    if (failSend) throw StateError('Radio unavailable');
  }

  void updateLocation(double? lat, double? lon) {
    latitude = lat;
    longitude = lon;
    notifyListeners();
  }
}

class _PhoneLocation extends GeolocatorPlatform {
  final updates = StreamController<Position>.broadcast();
  bool enabled = true;
  bool denied = false;
  int lookups = 0;
  int cancellations = 0;
  Future<Position> Function()? locate;

  _PhoneLocation() {
    updates.onCancel = () => cancellations++;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async =>
      denied ? LocationPermission.deniedForever : LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    lookups++;
    return locate == null ? _position(28, -82) : await locate!();
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      updates.stream;
}

Position _position(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late GeolocatorPlatform originalPlatform;
  late _PhoneLocation phone;
  late _MapConnector connector;
  late MapLocationService location;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    phone = _PhoneLocation();
    GeolocatorPlatform.instance = phone;
    connector = _MapConnector();
    location = MapLocationService(connector);
  });

  tearDown(() async {
    location.dispose();
    connector.dispose();
    await phone.updates.close();
    GeolocatorPlatform.instance = originalPlatform;
  });

  testWidgets('valid radio position wins even without a GPS custom variable', (
    tester,
  ) async {
    connector.updateLocation(29, -81);
    phone.enabled = false;
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.position, const LatLng(29, -81));
    expect(location.source, MapLocationSource.radio);
    expect(phone.lookups, 0);
    expect(connector.frames.single.first, cmdAppStart);
    location.stop();
  });

  for (final coordinates in <(double?, double?)>[
    (null, null),
    (0, 0),
    (91, -82),
    (28, 181),
    (double.nan, -82),
    (28, null),
  ]) {
    testWidgets('invalid radio $coordinates falls back to live phone updates', (
      tester,
    ) async {
      connector.updateLocation(coordinates.$1, coordinates.$2);
      location.start();
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.position, const LatLng(28, -82));
      expect(location.source, MapLocationSource.phone);
      phone.updates.add(_position(28.1, -82.1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.position, const LatLng(28.1, -82.1));
      phone.updates.add(_position(double.nan, -82));
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.position, const LatLng(28.1, -82.1));
      location.stop();
    });
  }

  testWidgets('radio fixes take over immediately and stop phone tracking', (
    tester,
  ) async {
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    connector.updateLocation(29, -81);
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.position, const LatLng(29, -81));
    expect(location.source, MapLocationSource.radio);
    expect(phone.cancellations, 1);
    phone.updates.add(_position(28.2, -82.2));
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.position, const LatLng(29, -81));

    connector.updateLocation(0, 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.source, MapLocationSource.phone);
    expect(phone.lookups, 2);
    location.stop();
  });

  for (final stopDuringLookup in [false, true]) {
    testWidgets(
      'late phone lookup cannot replace ${stopDuringLookup ? 'a stopped session' : 'radio coordinates'}',
      (tester) async {
        final pending = Completer<Position>();
        phone.locate = () => pending.future;
        location.start();
        await tester.pump(const Duration(milliseconds: 50));
        if (stopDuringLookup) {
          location.stop();
        } else {
          connector.updateLocation(29, -81);
        }
        pending.complete(_position(28, -82));
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          location.source,
          stopDuringLookup ? null : MapLocationSource.radio,
        );
        expect(phone.updates.hasListener, isFalse);
        location.stop();
      },
    );
  }

  testWidgets(
    'minute checks discover radio coordinates without GPS detection',
    (tester) async {
      location.start();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 59));
      expect(connector.frames, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(connector.frames, hasLength(2));
      expect(connector.frames.last.first, cmdAppStart);
      connector.updateLocation(29, -81);
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.source, MapLocationSource.radio);
      location.stop();
    },
  );

  testWidgets('GPS-enabled radios reuse connector polling', (tester) async {
    connector.gps = true;
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(minutes: 1));
    expect(connector.frames, hasLength(1));
    location.stop();
  });

  for (final failure in ['permission', 'disabled', 'stream']) {
    testWidgets('$failure failure recovers on the next minute check', (
      tester,
    ) async {
      phone.denied = failure == 'permission';
      phone.enabled = failure != 'disabled';
      location.start();
      await tester.pump(const Duration(milliseconds: 50));
      if (failure == 'stream') {
        phone.updates.addError(const PositionUpdateException('lost fix'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(location.position, isNull);
      phone.denied = false;
      phone.enabled = true;
      await tester.pump(const Duration(minutes: 1));
      expect(location.source, MapLocationSource.phone);
      location.stop();
    });
  }

  testWidgets('radio send failure still allows phone fallback', (tester) async {
    connector.failSend = true;
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.source, MapLocationSource.phone);
    location.stop();
  });

  testWidgets(
    'stop cancels polling and tracking; resume refreshes immediately',
    (tester) async {
      location.start();
      await tester.pump(const Duration(milliseconds: 50));
      location.stop();
      expect(phone.cancellations, 1);
      await tester.pump(const Duration(minutes: 2));
      expect(connector.frames, hasLength(1));
      expect(location.position, const LatLng(28, -82));
      expect(location.source, MapLocationSource.phone);
      location.start();
      await tester.pump(const Duration(milliseconds: 50));
      expect(connector.frames, hasLength(2));
      expect(phone.lookups, 2);
      location.stop();
    },
  );

  testWidgets('last phone fix survives stop and a slow foreground refresh', (
    tester,
  ) async {
    final published = <LatLng?>[];
    location.addListener(() => published.add(location.position));
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    final pending = Completer<Position>();
    phone.locate = () => pending.future;
    location.stop();
    expect(phone.updates.hasListener, isFalse);
    expect(location.position, const LatLng(28, -82));
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.position, const LatLng(28, -82));
    await tester.pump(const Duration(seconds: 2));
    expect(location.position, const LatLng(28, -82));
    pending.complete(_position(28.1, -82.1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.position, const LatLng(28.1, -82.1));
    expect(published, everyElement(isNotNull));
    location.stop();
  });

  testWidgets('disconnect also clears a retained background location', (
    tester,
  ) async {
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    location.stop();
    connector.connected = false;
    connector.notifyListeners();
    await tester.pump(const Duration(milliseconds: 50));
    expect(location.position, isNull);
    expect(location.source, isNull);
  });

  testWidgets('disconnect clears location and cancels phone updates', (
    tester,
  ) async {
    location.start();
    await tester.pump(const Duration(milliseconds: 50));
    connector.connected = false;
    connector.notifyListeners();
    await tester.pump(const Duration(minutes: 1));
    expect(location.position, isNull);
    expect(phone.cancellations, 1);
    expect(connector.frames, hasLength(1));
    location.stop();
  });

  testWidgets(
    'manual location outranks changing radio fixes and phone updates',
    (tester) async {
      location.start();
      await tester.pump(const Duration(milliseconds: 50));
      connector.selectedLocation = const ManualLocation(
        latitude: 30,
        longitude: -80,
      );
      connector.updateLocation(29, -81);
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.source, MapLocationSource.manual);
      expect(location.position, const LatLng(30, -80));
      expect(phone.updates.hasListener, isFalse);
      connector.updateLocation(29.1, -81.1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.position, const LatLng(30, -80));
      connector.selectedLocation = null;
      connector.updateLocation(0, 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(location.source, MapLocationSource.phone);
      location.stop();
    },
  );
}
