import 'dart:async';
import 'dart:convert';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'journal_store.dart';
import 'protocol.dart';

const nusService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const nusRx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const nusTx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

abstract interface class MeshBleTransport {
  Stream<DiscoveredDevice> scan();
  Stream<ConnectionStateUpdate> connect(String deviceId, Duration timeout);
  Future<int> requestMtu(String deviceId, int mtu);
  Future<void> discoverServices(String deviceId);
  Stream<List<int>> subscribe(QualifiedCharacteristic characteristic);
  Future<void> write(QualifiedCharacteristic characteristic, List<int> value);
}

class ReactiveBleTransport implements MeshBleTransport {
  ReactiveBleTransport(this.ble);
  final FlutterReactiveBle ble;
  @override
  Stream<DiscoveredDevice> scan() => ble.scanForDevices(
      withServices: [Uuid.parse(nusService)], scanMode: ScanMode.lowLatency);
  @override
  Stream<ConnectionStateUpdate> connect(String deviceId, Duration timeout) =>
      ble.connectToDevice(id: deviceId, connectionTimeout: timeout);
  @override
  Future<int> requestMtu(String deviceId, int mtu) =>
      ble.requestMtu(deviceId: deviceId, mtu: mtu);
  @override
  Future<void> discoverServices(String deviceId) =>
      ble.discoverAllServices(deviceId);
  @override
  Stream<List<int>> subscribe(QualifiedCharacteristic characteristic) =>
      ble.subscribeToCharacteristic(characteristic);
  @override
  Future<void> write(QualifiedCharacteristic characteristic, List<int> value) =>
      ble.writeCharacteristicWithResponse(characteristic, value: value);
}

class MeshDevice {
  const MeshDevice(this.id, this.name, this.rssi);
  final String id, name;
  final int rssi;
}

class MeshConnection {
  MeshConnection(this.ble, this.store,
      {this.initialHandshakeTimeout = const Duration(seconds: 60),
      this.sendResponseTimeout = const Duration(seconds: 6)});
  final MeshBleTransport ble;
  final JournalStore store;
  final Duration initialHandshakeTimeout;
  final Duration sendResponseTimeout;
  final _messages = StreamController<List<StoredMessage>>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _states = StreamController<bool>.broadcast();
  Stream<List<StoredMessage>> get messages => _messages.stream;
  Stream<String> get errors => _errors.stream;
  Stream<bool> get states => _states.stream;
  StreamSubscription<List<int>>? _rxSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  Completer<Object>? _notificationFailure;
  QualifiedCharacteristic? _tx, _rx;
  Completer<ExtensionResponse>? _pending;
  int _nextRequestId = 1;
  Future<void> _serial = Future.value();
  Timer? _poller;
  NodeInfo? info;
  String? nodeKey;
  bool connected = false;
  bool _initializing = false;
  bool _pollQueued = false;
  int _session = 0;
  int get sessionGeneration => _session;
  bool submissionUnknown = false;
  String? get publicKeyHex => info == null ? null : _hex(info!.publicKey);

  Stream<DiscoveredDevice> scan() => ble.scan();

  Future<void> connect(String deviceId) async {
    if (_connectionSub != null || _initializing || connected) {
      throw StateError('A BLE connection attempt is already active.');
    }
    final session = ++_session;
    final done = Completer<void>();
    _connectionSub = ble.connect(deviceId, const Duration(seconds: 15)).listen(
        (update) async {
      if (session != _session) return;
      if (update.connectionState == DeviceConnectionState.connected &&
          !_initializing &&
          !connected) {
        _initializing = true;
        try {
          final mtu = await ble.requestMtu(deviceId, 185);
          _checkSession(session);
          if (mtu < 176) {
            throw StateError(
                'Radio negotiated MTU $mtu; this build requires at least 176.');
          }
          await ble.discoverServices(deviceId);
          _checkSession(session);
          _rx = QualifiedCharacteristic(
              serviceId: Uuid.parse(nusService),
              characteristicId: Uuid.parse(nusRx),
              deviceId: deviceId);
          _tx = QualifiedCharacteristic(
              serviceId: Uuid.parse(nusService),
              characteristicId: Uuid.parse(nusTx),
              deviceId: deviceId);
          final notificationFailure = Completer<Object>();
          _notificationFailure = notificationFailure;
          // Install TX notifications before probing the extension: this avoids losing a fast response.
          _rxSub = ble.subscribe(_tx!).listen((value) {
            if (session == _session) _onNotification(value);
          }, onError: (Object e) {
            if (session != _session) return;
            _reportError('BLE notifications: $e');
            if (!notificationFailure.isCompleted) {
              notificationFailure.complete(e);
            }
          });
          connected = true;
          await Future<void>.delayed(const Duration(milliseconds: 400));
          _checkSession(session);
          final infoResponse = await _initialInfo();
          _checkSession(session);
          if (infoResponse.status != 0) {
            throw StateError(
                'INFO request failed with status ${infoResponse.status}');
          }
          info = NodeInfo.decode(infoResponse.payload);
          nodeKey = '${_hex(info!.publicKey)}:${_hex(info!.bootNonce)}';
          await store.setSetting('last_public_key', _hex(info!.publicKey));
          _checkSession(session);
          if (info!.publicSlot == 255) {
            throw StateError('This node has no Public channel.');
          }
          await _serialized(() => _refreshMessages(session));
          _checkSession(session);
          _startPolling();
          _states.add(true);
          if (!done.isCompleted) done.complete();
        } catch (e) {
          if (session == _session) {
            _reportError('$e');
            await disconnect();
            if (!done.isCompleted) done.completeError(e);
          }
        } finally {
          if (session == _session) _initializing = false;
        }
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        ++_session;
        _initializing = false;
        connected = false;
        _states.add(false);
        _poller?.cancel();
        if (_pending != null && !_pending!.isCompleted) {
          _pending!.completeError(StateError('Disconnected before response'));
        }
        if (!done.isCompleted) done.completeError(StateError('Disconnected'));
        final subscription = _connectionSub;
        _connectionSub = null;
        unawaited(subscription?.cancel());
        final rxSubscription = _rxSub;
        _rxSub = null;
        _rx = null;
        _tx = null;
        info = null;
        nodeKey = null;
        _notificationFailure = null;
        unawaited(rxSubscription?.cancel());
      }
    }, onError: (Object e) {
      if (!done.isCompleted) done.completeError(e);
      if (session == _session) {
        unawaited(disconnect());
      }
    });
    return done.future;
  }

  Future<ExtensionResponse> _initialInfo() async {
    try {
      return await request(1, [], initialHandshakeTimeout);
    } on TimeoutException {
      // INFO is read-only and safe to retry if OS pairing or notification setup raced the probe.
      return request(1, [], initialHandshakeTimeout);
    }
  }

  void _onNotification(List<int> value) {
    try {
      if (value.length < 4 ||
          value[0] != extensionOpcode ||
          value[1] != 0x55 ||
          value[2] != 0x46 ||
          value[3] != 1) {
        final pending = _pending;
        if (pending != null &&
            !pending.isCompleted &&
            _pendingOp == 1 &&
            value.isNotEmpty &&
            (value[0] == 0x01 || value[0] == 0x70)) {
          pending.completeError(const UnsupportedFirmwareException(
              'Unsupported MeshCore firmware. Flash the shared Uni-Fi PoC firmware target, then reconnect.'));
        }
        return; // Ignore unrelated legacy responses and asynchronous pushes.
      }
      final response = decodeResponse(value);
      final pending = _pending;
      if (pending != null &&
          !pending.isCompleted &&
          response.op == _pendingOp &&
          response.requestId == _pendingId) {
        pending.complete(response);
      }
    } catch (e) {
      _reportError('$e');
    }
  }

  int? _pendingOp, _pendingId;

  Future<ExtensionResponse> request(int op,
      [List<int> payload = const [],
      Duration timeout = const Duration(seconds: 4)]) async {
    final completer = Completer<ExtensionResponse>();
    final id = _nextRequestId++ & 0xffff;
    _pending = completer;
    _pendingId = id;
    _pendingOp = op;
    try {
      final failure = _notificationFailure;
      if (failure?.isCompleted ?? false) {
        throw StateError('BLE notification subscription failed.');
      }
      final response = failure == null
          ? completer.future
          : Future.any<ExtensionResponse>([
              completer.future,
              failure.future.then((e) =>
                  throw StateError('BLE notification subscription failed: $e')),
            ]);
      final write = ble.write(_rx!, encodeRequest(op, id, payload));
      final results =
          await Future.wait<Object?>([write, response], eagerError: true)
              .timeout(timeout);
      return results[1] as ExtensionResponse;
    } on TimeoutException catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
      rethrow;
    } finally {
      if (identical(_pending, completer)) {
        _pending = null;
        _pendingId = null;
        _pendingOp = null;
      }
    }
  }

  Future<T> _serialized<T>(Future<T> Function() task) {
    final next = _serial.then((_) => task());
    _serial = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pollQueued) return;
      _pollQueued = true;
      _serialized(_pollOnce)
          .catchError((Object e) => _reportError('$e'))
          .whenComplete(() => _pollQueued = false);
    });
  }

  Future<void> _pollOnce() async {
    if (!connected || nodeKey == null) return;
    final session = _session;
    final response = await request(1);
    _checkSession(session);
    if (response.status != 0) {
      throw StateError('INFO request failed with status ${response.status}');
    }
    final latest = NodeInfo.decode(response.payload);
    if (_hex(latest.bootNonce) != _hex(info!.bootNonce) ||
        _hex(latest.publicKey) != _hex(info!.publicKey)) {
      info = latest;
      nodeKey = '${_hex(latest.publicKey)}:${_hex(latest.bootNonce)}';
      await _refreshMessages(session);
      return;
    }
    info = latest;
    await _refreshMessages(session);
  }

  Future<void> _refreshMessages([int? expectedSession]) async {
    final session = expectedSession ?? _session;
    final i = info, key = nodeKey;
    if (i == null || key == null) return;
    var cursor = await store.cursor(key);
    _checkSession(session);
    if (i.oldestSeq > 1 && cursor < i.oldestSeq - 1) {
      await store.saveGap(key, cursor + 1, i.oldestSeq, i.newestSeq);
      cursor = i.oldestSeq - 1;
    }
    final goal = i.newestSeq;
    var readCount = 0;
    while (
        cursor < goal && connected && session == _session && readCount < 16) {
      final seq = cursor + 1;
      final assembler = JournalAssembler(seq);
      while (!assembler.isComplete) {
        _checkSession(session);
        final r = await request(
            2, readRequestPayload(seq, _assemblerOffset(assembler)));
        _checkSession(session);
        if (r.status == 2) break;
        if (r.status == 3) {
          final gap = JournalGap.decode(r.payload);
          if (gap.oldest <= seq) {
            throw const ProtocolException(
                'READ reported a non-advancing journal gap');
          }
          await store.saveGap(key, seq, gap.oldest, gap.newest);
          cursor = gap.oldest - 1;
          break;
        }
        if (r.status != 0) {
          throw StateError('READ $seq failed with status ${r.status}');
        }
        assembler.add(decodeJournalChunk(r.payload));
      }
      if (cursor != seq - 1) continue;
      if (!assembler.isComplete) break;
      final entry = assembler.finish();
      _checkSession(session);
      await store.saveAndAdvance(key, entry, seq);
      cursor = seq;
      readCount++;
    }
    _checkSession(session);
    final messages = await store.messages(key.split(':').first);
    _checkSession(session);
    if (!_messages.isClosed) _messages.add(messages);
  }

  Future<void> send(String username, String body) {
    final session = _session;
    return _serialized(() async {
      _checkSession(session);
      if (!connected || _rx == null) {
        throw StateError('Not connected to a MeshCore node.');
      }
      if (!validUsername(username)) {
        throw const ProtocolException(
            'Local username must be 1–16 UTF-8 bytes.');
      }
      if (!validBody(body)) {
        throw const ProtocolException('Message must be 1–80 UTF-8 bytes.');
      }
      final label = utf8.encode(username), text = utf8.encode(body);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = <int>[
        now & 255,
        now >> 8 & 255,
        now >> 16 & 255,
        now >> 24 & 255,
        label.length,
        ...label,
        ...text
      ];
      var gotResponse = false;
      try {
        final response = await request(3, payload, sendResponseTimeout);
        _checkSession(session);
        gotResponse = true;
        if (response.status != 0) {
          throw StateError('SEND was rejected with status ${response.status}');
        }
        // ACK means queued only. The journal poll will later confirm a local journal record.
        await _refreshMessages(session);
        submissionUnknown = false;
      } catch (e) {
        submissionUnknown = !gotResponse;
        _reportError(gotResponse
            ? '$e'
            : 'Submission unknown; do not retry automatically. $e');
        rethrow;
      }
    });
  }

  void _reportError(String message) {
    if (!_errors.isClosed) _errors.add(message);
  }

  Future<String> getPreset() => _presetRequest(4, const []);

  Future<String> setPreset(String text) {
    if (text.isNotEmpty && !validBody(text)) {
      throw const ProtocolException(
          'Preset must be at most 80 UTF-8 bytes, without control characters.');
    }
    return _presetRequest(5, utf8.encode(text));
  }

  Future<String> _presetRequest(int operation, List<int> payload) {
    final session = _session;
    return _serialized(() async {
      _checkSession(session);
      if (!connected) throw StateError('Connect to a node first.');
      final response = await request(operation, payload, sendResponseTimeout);
      _checkSession(session);
      if (response.status != 0) {
        throw StateError(
            'Preset command rejected (${response.status}). Update to preset-capable firmware.');
      }
      final data = response.payload;
      if (data.isEmpty || data[0] > 80 || data.length != data[0] + 1) {
        throw const ProtocolException('Invalid saved preset reply.');
      }
      final text = utf8.decode(data.sublist(1), allowMalformed: false);
      if (text.isNotEmpty && !validBody(text)) {
        throw const ProtocolException('Invalid preset text.');
      }
      return text;
    });
  }

  Future<void> disconnect() async {
    ++_session;
    _initializing = false;
    _poller?.cancel();
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(StateError('Disconnected before response'));
    }
    await _rxSub?.cancel();
    _rxSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    connected = false;
    _states.add(false);
    _initializing = false;
    _rx = null;
    _tx = null;
    _notificationFailure = null;
    info = null;
    nodeKey = null;
    _connectionSub = null;
  }

  void _checkSession(int session) {
    if (session != _session) {
      throw StateError('BLE connection changed during initialization.');
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _errors.close();
    await _states.close();
  }
}

int _assemblerOffset(JournalAssembler assembler) => assembler.receivedBytes;

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
bool listEquals(List<int> a, List<int> b) =>
    a.length == b.length && a.asMap().entries.every((e) => b[e.key] == e.value);
