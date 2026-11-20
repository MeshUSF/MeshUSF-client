import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/storage/manual_location_store.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Connector extends MeshCoreConnector {
  bool connected = true;
  bool gps = false;
  bool failWrite = false;
  String radioKey = '0123456789abcdef';
  double? latitude;
  double? longitude;
  final locations = <(double, double)>[];
  final waitedForAck = <bool>[];

  @override
  bool get isConnected => connected;
  @override
  bool get hasGps => gps;
  @override
  String get selfPublicKeyHex => radioKey;
  @override
  double? get selfLatitude => latitude;
  @override
  double? get selfLongitude => longitude;

  @override
  Future<void> sendFrame(
    Uint8List data, {
    String? channelSendQueueId,
    bool expectsGenericAck = false,
    bool waitForGenericAck = false,
  }) async {
    if (failWrite) throw StateError('Rejected location');
    if (data.first == cmdSetAdvertLatLon) {
      final reader = BufferReader(data)..skipBytes(1);
      latitude = reader.readInt32LE() / 1000000;
      longitude = reader.readInt32LE() / 1000000;
      locations.add((latitude!, longitude!));
      waitedForAck.add(waitForGenericAck);
    }
  }
}

void main() {
  late _Connector connector;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    connector = _Connector();
  });
  tearDown(() => connector.dispose());

  test(
    'manual location survives a new connector and stays scoped to its radio',
    () async {
      await connector.setNodeLocation(lat: 28, lon: -82);
      expect(connector.manualLocation!.latitude, 28);
      expect(connector.waitedForAck, [true]);
      final reopened = _Connector();
      addTearDown(reopened.dispose);
      expect(reopened.manualLocation!.longitude, -82);
      reopened.radioKey = 'abcdef0123456789';
      expect(reopened.manualLocation, isNull);
      reopened.radioKey = connector.radioKey;
      expect(reopened.manualLocation!.latitude, 28);
    },
  );

  test('repeated manual choices retain the original GPS undo point', () async {
    connector
      ..gps = true
      ..latitude = 42
      ..longitude = -71;
    await connector.setNodeLocation(lat: 28, lon: -82);
    await connector.setNodeLocation(lat: 29, lon: -81);
    await connector.revertManualLocation();
    expect(connector.locations.last, (42, -71));
    expect(connector.manualLocation, isNull);
    expect(ManualLocationStore().load(connector.radioKey), isNull);
  });

  test(
    'revert uses a newer radio fix instead of overwriting it with an old one',
    () async {
      connector
        ..gps = true
        ..latitude = 42
        ..longitude = -71;
      await connector.setNodeLocation(lat: 28, lon: -82);
      connector
        ..latitude = 42.1
        ..longitude = -71.1;
      await connector.revertManualLocation();
      expect(connector.locations.last, (42.1, -71.1));
      expect(connector.manualLocation, isNull);
    },
  );

  test(
    'revert without radio GPS clears stored coordinates for phone fallback',
    () async {
      // Older manually configured firmware coordinates must not become an undo fix.
      connector
        ..latitude = 27
        ..longitude = -83;
      await connector.setNodeLocation(lat: 28, lon: -82);
      await connector.revertManualLocation();
      expect(connector.locations.last, (0, 0));
      expect(connector.manualLocation, isNull);
    },
  );

  test(
    'rejected set does not create a manual source or overwrite its undo point',
    () async {
      connector.failWrite = true;
      await expectLater(
        connector.setNodeLocation(lat: 28, lon: -82),
        throwsStateError,
      );
      expect(connector.manualLocation, isNull);
      expect(ManualLocationStore().load(connector.radioKey), isNull);
    },
  );

  test(
    'rejected revert keeps the manual selection and its persisted undo point',
    () async {
      await connector.setNodeLocation(lat: 28, lon: -82);
      connector.failWrite = true;
      await expectLater(connector.revertManualLocation(), throwsStateError);
      expect(connector.manualLocation!.latitude, 28);
      expect(ManualLocationStore().load(connector.radioKey)!.latitude, 28);
    },
  );

  test('invalid persisted coordinates are ignored', () async {
    await PrefsManager.instance.setStringList('manual_location_0123456789', [
      'NaN',
      '-82',
      '',
      '',
    ]);
    expect(connector.manualLocation, isNull);
  });
}
