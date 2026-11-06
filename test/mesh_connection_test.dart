import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meshusf/journal_store.dart';
import 'package:meshusf/mesh_connection.dart';
import 'package:meshusf/protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('custom preset saves, reads, overwrites and clears through UF1',
      () async {
    final transport = FakeTransport();
    final mesh = MeshConnection(transport, await _store());
    await mesh.connect('node');
    expect(await mesh.getPreset(), '');
    expect(await mesh.setPreset('Meet at gate'), 'Meet at gate');
    expect(await mesh.getPreset(), 'Meet at gate');
    expect(await mesh.setPreset('Need help'), 'Need help');
    expect(await mesh.setPreset(''), '');
    expect(await mesh.getPreset(), '');
    expect(() => mesh.setPreset('🙂' * 21), throwsA(isA<ProtocolException>()));
    expect(transport.writes.where((w) => w[4] == 3), isEmpty,
        reason: 'Saving a preset must not transmit a Public message');
    await mesh.dispose();
    await transport.close();
  });

  test('connect times out cleanly when the INFO handshake never responds',
      () async {
    final transport = FakeTransport(silentInfo: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(milliseconds: 20));
    await expectLater(mesh.connect('node'), throwsA(isA<TimeoutException>()));
    expect(transport.writes.where((w) => w[4] == 1).length, 2,
        reason: 'INFO gets one safe retry with a fresh request ID');
    await mesh.dispose();
    await transport.close();
  });

  test('legacy ERR response rejects old firmware immediately', () async {
    final transport = FakeTransport(legacyInfoError: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(seconds: 10));
    await expectLater(
        mesh.connect('node'), throwsA(isA<UnsupportedFirmwareException>()));
    expect(transport.writes.where((w) => w[4] == 1), hasLength(1));
    await mesh.dispose();
    await transport.close();
  });

  test('unrelated asynchronous push is ignored while INFO response is matched',
      () async {
    final transport = FakeTransport(asyncPushBeforeInfo: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(milliseconds: 200));
    await mesh.connect('node');
    expect(mesh.connected, isTrue);
    await mesh.dispose();
    await transport.close();
  });

  test('disconnect completes an outstanding connect probe promptly', () async {
    final transport = FakeTransport(silentInfo: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(seconds: 5));
    final connecting = mesh.connect('node');
    await transport.writeSeen.stream.first.timeout(const Duration(seconds: 2));
    transport.disconnect();
    await expectLater(connecting, throwsA(anything));
    await mesh.dispose();
    await transport.close();
  });

  test('disconnect during MTU negotiation prevents stale initialization',
      () async {
    final transport = FakeTransport(deferMtu: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(milliseconds: 200));
    final connecting = mesh.connect('node');
    await transport.mtuRequested.stream.first
        .timeout(const Duration(seconds: 2));
    transport.disconnect();
    await expectLater(connecting, throwsA(anything));
    transport.mtu.complete(185);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(mesh.connected, isFalse);
    expect(transport.subscriptions, 0);
    expect(transport.writes, isEmpty);
    await mesh.dispose();
    await transport.close();
  });

  test('notification subscription error aborts handshake without INFO retries',
      () async {
    final transport = FakeTransport(notificationError: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(seconds: 5));
    await expectLater(mesh.connect('node'), throwsA(anything));
    expect(transport.writes, isEmpty);
    expect(mesh.connected, isFalse);
    await mesh.dispose();
    await transport.close();
  });

  test('disconnect during a pending BLE write settles the request promptly',
      () async {
    final transport = FakeTransport(deferWrite: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(seconds: 5));
    final connecting = mesh.connect('node');
    await transport.writeSeen.stream.first.timeout(const Duration(seconds: 2));
    transport.disconnect();
    await expectLater(connecting, throwsA(anything));
    transport.writeGate.complete();
    await mesh.dispose();
    await transport.close();
  });

  test('queued SEND from a disconnected session is not sent to the reconnect',
      () async {
    final transport = FakeTransport();
    final store = BlockingCursorStore();
    final mesh = MeshConnection(transport, store,
        initialHandshakeTimeout: const Duration(milliseconds: 200));
    final firstConnect = mesh.connect('node');
    await store.cursorStarted.future.timeout(const Duration(seconds: 2));
    final queuedSend = mesh.send('Phone', 'must not cross sessions');

    transport.disconnect();
    await expectLater(firstConnect, throwsA(anything));
    final reconnectInfo =
        transport.writeSeen.stream.where((packet) => packet[4] == 1).first;
    final reconnect = mesh.connect('node-2');
    await reconnectInfo.timeout(const Duration(seconds: 2));
    store.releaseCursor.complete(0);

    await expectLater(queuedSend, throwsA(isA<StateError>()));
    await reconnect;
    expect(transport.writes.where((packet) => packet[4] == 3), isEmpty);
    await mesh.dispose();
    await transport.close();
  });

  test('SEND timeout is submission-unknown and is never automatically retried',
      () async {
    final transport = FakeTransport(silentSend: true);
    final mesh = MeshConnection(transport, await _store(),
        initialHandshakeTimeout: const Duration(milliseconds: 200),
        sendResponseTimeout: const Duration(milliseconds: 30));
    await mesh.connect('node');
    await expectLater(
        mesh.send('Phone', 'hello'), throwsA(isA<TimeoutException>()));
    expect(mesh.submissionUnknown, isTrue);
    expect(transport.writes.where((w) => w[4] == 3).length, 1);
    await mesh.dispose();
    await transport.close();
  });

  test('initial and READ-reported gaps advance the cursor without looping',
      () async {
    final transport = FakeTransport(
      oldest: 3,
      newest: 4,
      gapAt: 3,
      gapOldest: 4,
      gapNewest: 4,
    );
    final store = await _store();
    final mesh = MeshConnection(transport, store,
        initialHandshakeTimeout: const Duration(milliseconds: 200));
    await mesh.connect('node');
    final records = await store.messages(transport.publicKeyHex);
    expect(records.where((r) => r.gap), hasLength(2));
    expect(records.singleWhere((r) => !r.gap).seq, 4);
    expect(transport.readSequences, [3, 4]);
    expect(await store.cursor(mesh.nodeKey!), 4);
    await mesh.dispose();
    await transport.close();
  });
}

Future<JournalStore> _store() =>
    JournalStore.open(databasePath: inMemoryDatabasePath);

class BlockingCursorStore implements JournalStore {
  final cursorStarted = Completer<void>();
  final releaseCursor = Completer<int>();
  bool _blockCursor = true;

  @override
  Future<int> cursor(String key) {
    if (_blockCursor) {
      _blockCursor = false;
      cursorStarted.complete();
      return releaseCursor.future;
    }
    return Future.value(0);
  }

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<List<StoredMessage>> messages(String publicKeyHex) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTransport implements MeshBleTransport {
  FakeTransport({
    this.silentInfo = false,
    this.silentSend = false,
    this.legacyInfoError = false,
    this.asyncPushBeforeInfo = false,
    this.deferMtu = false,
    this.notificationError = false,
    this.deferWrite = false,
    this.oldest = 0,
    this.newest = 0,
    this.gapAt,
    this.gapOldest = 0,
    this.gapNewest = 0,
  });

  final bool silentInfo, silentSend;
  final bool legacyInfoError, asyncPushBeforeInfo;
  final bool deferMtu;
  final bool notificationError, deferWrite;
  final int oldest, newest;
  final int? gapAt;
  final int gapOldest, gapNewest;
  final _connections = StreamController<ConnectionStateUpdate>.broadcast();
  final _notifications = StreamController<List<int>>.broadcast();
  final writeSeen = StreamController<List<int>>.broadcast();
  final mtuRequested = StreamController<void>.broadcast();
  final mtu = Completer<int>();
  final writeGate = Completer<void>();
  int subscriptions = 0;
  final writes = <List<int>>[];
  final readSequences = <int>[];
  List<int> preset = [];
  final int publicKeyByte = _keyCounter++;
  static int _keyCounter = 1;
  String get publicKeyHex => List.filled(32, publicKeyByte)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  @override
  Stream<DiscoveredDevice> scan() => const Stream.empty();

  @override
  Stream<ConnectionStateUpdate> connect(String deviceId, Duration timeout) {
    scheduleMicrotask(() => _connections.add(ConnectionStateUpdate(
        deviceId: deviceId,
        connectionState: DeviceConnectionState.connected,
        failure: null)));
    return _connections.stream;
  }

  void disconnect() => _connections.add(ConnectionStateUpdate(
      deviceId: 'node',
      connectionState: DeviceConnectionState.disconnected,
      failure: null));

  @override
  Future<int> requestMtu(String deviceId, int mtu) {
    if (!deferMtu) return Future.value(185);
    mtuRequested.add(null);
    return this.mtu.future;
  }

  @override
  Future<void> discoverServices(String deviceId) async {}

  @override
  Stream<List<int>> subscribe(QualifiedCharacteristic characteristic) => () {
        subscriptions++;
        if (notificationError) {
          scheduleMicrotask(() =>
              _notifications.addError(StateError('simulated CCCD failure')));
        }
        return _notifications.stream;
      }();

  @override
  Future<void> write(
      QualifiedCharacteristic characteristic, List<int> value) async {
    final packet = List<int>.from(value);
    writes.add(packet);
    writeSeen.add(packet);
    if (deferWrite) return writeGate.future;
    final op = packet[4], id = packet[5] | packet[6] << 8;
    if (op == 1 && legacyInfoError) {
      scheduleMicrotask(() => _notifications.add([0x01, 0x00]));
    } else if (op == 1 && !silentInfo) {
      if (asyncPushBeforeInfo) {
        scheduleMicrotask(() => _notifications.add([0x80, 0x01, 0x02]));
      }
      _reply(op, id, _info());
    } else if (op == 2) {
      final seq =
          packet[7] | packet[8] << 8 | packet[9] << 16 | packet[10] << 24;
      readSequences.add(seq);
      if (seq == gapAt) {
        _reply(op, id, [..._u32(gapOldest), ..._u32(gapNewest)], status: 3);
      } else {
        _reply(op, id, _read(seq, 'entry-$seq'));
      }
    } else if (op == 3 && !silentSend) {
      _reply(op, id, [1, 0, 0, 0]);
    } else if (op == 4) {
      _reply(op, id, [preset.length, ...preset]);
    } else if (op == 5) {
      preset = utf8.encode(utf8.decode(packet.sublist(7)));
      _reply(op, id, [preset.length, ...preset]);
    }
  }

  void _reply(int op, int id, List<int> payload, {int status = 0}) {
    scheduleMicrotask(() => _notifications.add([
          0x70,
          0x55,
          0x46,
          1,
          op,
          id & 255,
          id >> 8 & 255,
          status,
          ...payload
        ]));
  }

  List<int> _info() => [
        ...List.filled(16, 0x44),
        ..._u32(oldest),
        ..._u32(newest),
        32,
        0,
        0,
        ...List.filled(32, publicKeyByte),
        4,
        ...'Node'.codeUnits,
      ];

  List<int> _read(int seq, String text) {
    final bytes = text.codeUnits;
    return [
      ..._u32(seq),
      0,
      0x10,
      0,
      0,
      0,
      1,
      bytes.length,
      0,
      bytes.length,
      ...bytes,
    ];
  }

  Future<void> close() async {
    await _connections.close();
    await _notifications.close();
    await writeSeen.close();
    await mtuRequested.close();
  }
}

List<int> _u32(int v) => [v & 255, v >> 8 & 255, v >> 16 & 255, v >> 24 & 255];
