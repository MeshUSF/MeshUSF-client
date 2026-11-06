import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'journal_store.dart';
import 'mesh_connection.dart';
import 'protocol.dart';
import 'theme/mesh_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await JournalStore.open();
  runApp(MeshApp(store: store));
}

class MeshApp extends StatelessWidget {
  const MeshApp({super.key, required this.store, this.transport});
  final JournalStore store;
  final MeshBleTransport? transport;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MeshUSF',
        theme: MeshTheme.light(),
        darkTheme: MeshTheme.dark(),
        home: ChatPage(store: store, transport: transport),
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.store, this.transport});
  final JournalStore store;
  final MeshBleTransport? transport;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final MeshConnection mesh = MeshConnection(
      widget.transport ?? ReactiveBleTransport(FlutterReactiveBle()),
      widget.store);
  final _username = TextEditingController();
  final _body = TextEditingController();
  final _scroll = ScrollController();
  final _preset = TextEditingController();
  int _page = 0;
  bool _savingPreset = false;
  String? _presetStatus;
  List<StoredMessage> _messages = [];
  StreamSubscription<List<StoredMessage>>? _messageSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _stateSub;
  StreamSubscription<DiscoveredDevice>? _scanSub;
  final Map<String, MeshDevice> _devices = {};
  String? _error;
  bool _scanning = false, _connecting = false, _sending = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _messageSub = mesh.messages.listen((m) {
      if (mounted) setState(() => _messages = m);
    });
    _errorSub = mesh.errors.listen((e) {
      if (mounted) setState(() => _error = e);
    });
    _stateSub = mesh.states.listen((_) {
      if (mounted) {
        setState(() {
          _preset.clear();
          _presetStatus = null;
        });
      }
    });
  }

  Future<void> _loadUsername() async {
    _username.text = await widget.store.setting('username') ?? '';
    final publicKey = await widget.store.setting('last_public_key');
    if (publicKey != null) {
      _messages = await widget.store.messages(publicKey);
    }
    if (mounted) setState(() {});
  }

  Future<bool> _permissions() async {
    final statuses =
        await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    if (statuses.values.any((s) => !s.isGranted)) {
      setState(() => _error =
          'Bluetooth permissions are required to find and connect to a radio.');
      return false;
    }
    return true;
  }

  Future<void> _scan() async {
    if (!await _permissions()) return;
    await _scanSub?.cancel();
    setState(() {
      _devices.clear();
      _scanning = true;
      _error = null;
    });
    _scanSub = mesh.scan().listen((d) {
      if (!mounted) return;
      setState(() => _devices[d.id] =
          MeshDevice(d.id, d.name.isEmpty ? 'MeshCore radio' : d.name, d.rssi));
    }, onError: (Object e) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = 'Scan failed: $e';
        });
      }
    });
    await Future<void>.delayed(const Duration(seconds: 8));
    await _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => _scanning = false);
    if (_devices.isEmpty && mounted) {
      setState(() => _error =
          'No MeshCore NUS radios found. Keep the radio nearby and advertising, then scan again.');
    }
  }

  Future<void> _connect(MeshDevice device) async {
    await _scanSub?.cancel();
    _scanSub = null;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await mesh.connect(device.id);
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _chooseDevice() async {
    if (!mesh.connected) await _scan();
    if (!mounted) return;
    if (_devices.isEmpty) return;
    final selected = await showModalBottomSheet<MeshDevice>(
        context: context,
        builder: (context) => SafeArea(
                child: ListView(children: [
              const ListTile(
                  title: Text('Nearby MeshCore radios'),
                  subtitle: Text(
                      'No advertised-name filter; select the correct node.')),
              ..._devices.values.map((d) => ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(d.name),
                  subtitle: Text('${d.id} · RSSI ${d.rssi} dBm'),
                  onTap: () => Navigator.pop(context, d))),
            ])));
    if (selected != null) await _connect(selected);
  }

  Future<void> _saveName(String value) async {
    if (!validUsername(value)) return;
    await widget.store.setSetting('username', value);
    if (mounted) setState(() => _error = null);
  }

  Future<void> _send() async {
    final name = _username.text;
    final body = _body.text;
    if (!validUsername(name) || !validBody(body)) {
      setState(() => _error = !validUsername(name)
          ? 'Username must be 1–16 UTF-8 bytes.'
          : 'Message must be 1–80 UTF-8 bytes.');
      return;
    }
    await _saveName(name);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await mesh.send(name, body);
      if (mounted) {
        _body.clear();
        setState(() => _sending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _messageSub?.cancel();
    _errorSub?.cancel();
    _stateSub?.cancel();
    mesh.dispose();
    _username.dispose();
    _body.dispose();
    _preset.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = mesh.connected;
    return Scaffold(
      appBar: AppBar(title: const Text('MeshUSF'), centerTitle: true, actions: [
        TextButton.icon(
            onPressed: _connecting || _scanning
                ? null
                : (connected
                    ? () async {
                        await mesh.disconnect();
                        setState(() {});
                      }
                    : _chooseDevice),
            icon: Icon(connected ? Icons.link_off : Icons.bluetooth_searching),
            label: Text(connected
                ? 'Disconnect'
                : _scanning
                    ? 'Scanning…'
                    : 'Connect')),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (index) => setState(() => _page = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'Public'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Device'),
        ],
      ),
      body: _page == 0
          ? _dashboard()
          : _page == 2
              ? _map()
              : _page == 3
                  ? _device()
                  : Column(children: [
                      Material(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(children: [
                                Icon(
                                    connected
                                        ? Icons.bluetooth_connected
                                        : Icons.bluetooth_disabled,
                                    color:
                                        connected ? Colors.green : Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        connected
                                            ? '${mesh.info?.name.isNotEmpty == true ? mesh.info!.name : 'MeshCore node'} · Public'
                                            : 'Not connected',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                if (_connecting)
                                  const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                              ]))),
                      if (_error != null)
                        Material(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.info_outline),
                                title: Text(_error!))),
                      Expanded(
                          child: _messages.isEmpty
                              ? Center(
                                  child: Text(
                                      connected
                                          ? 'No Public messages in this radio journal yet.'
                                          : 'Connect to a nearby MeshCore radio to load its Public journal.',
                                      textAlign: TextAlign.center))
                              : ListView.builder(
                                  controller: _scroll,
                                  reverse: true,
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final date =
                                        DateTime.fromMillisecondsSinceEpoch(
                                                message.timestamp * 1000)
                                            .toLocal();
                                    return Card(
                                        color: message.gap
                                            ? Theme.of(context)
                                                .colorScheme
                                                .tertiaryContainer
                                            : null,
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      message.gap
                                                          ? 'History gap'
                                                          : message.kind == 1
                                                              ? 'Node · queued'
                                                              : 'Public',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium),
                                                  const SizedBox(height: 4),
                                                  Text(message.text),
                                                  const SizedBox(height: 4),
                                                  Text('${date.toLocal()}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall),
                                                ])));
                                  })),
                      SafeArea(
                          top: false,
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              child: Column(children: [
                                TextField(
                                    controller: _username,
                                    maxLength: 16,
                                    onChanged: (value) {
                                      setState(() {});
                                      _saveName(value);
                                    },
                                    decoration: InputDecoration(
                                        labelText: 'Local username',
                                        counterText:
                                            '${utf8Length(_username.text)}/16 UTF-8 bytes',
                                        isDense: true)),
                                Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                          child: TextField(
                                              controller: _body,
                                              enabled: connected && !_sending,
                                              maxLength: 80,
                                              minLines: 1,
                                              maxLines: 3,
                                              onChanged: (_) => setState(() {}),
                                              decoration: InputDecoration(
                                                  hintText: connected
                                                      ? 'Public message'
                                                      : 'Connect to send',
                                                  counterText:
                                                      '${utf8Length(_body.text)}/80 UTF-8 bytes'))),
                                      const SizedBox(width: 8),
                                      IconButton.filled(
                                          onPressed: connected && !_sending
                                              ? _send
                                              : null,
                                          icon: _sending
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2))
                                              : const Icon(Icons.send))
                                    ]),
                                if (mesh.submissionUnknown)
                                  const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          'A previous submission is unknown; check history before retrying.',
                                          style: TextStyle(
                                              color: Colors.deepOrange))),
                                const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        'Send acknowledgement means queued by the radio, not delivered.',
                                        style: TextStyle(fontSize: 11))),
                              ]))),
                    ]),
    );
  }

  Widget _dashboard() => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Your shared mesh',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Public communication, without the extra clutter.'),
        Card(
            child: ListTile(
                leading: Icon(mesh.connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled),
                title: Text(mesh.connected
                    ? (mesh.info?.name.isNotEmpty == true
                        ? mesh.info!.name
                        : 'Connected node')
                    : 'Not connected'),
                subtitle: Text(_connecting
                    ? 'Pairing / checking node…'
                    : mesh.connected
                        ? 'Shared Bluetooth link ready'
                        : 'Connect to a nearby node to start'),
                onTap: mesh.connected || _connecting || _scanning
                    ? null
                    : _chooseDevice)),
        if (_error != null)
          Card(
              child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: Text(
                    '${_messages.where((m) => !m.gap).length} saved messages'),
                subtitle: const Text(
                    'Phone history · queued does not mean delivered'),
                onTap: () => setState(() => _page = 1))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.memory),
                title:
                    Text('${mesh.info?.capacity ?? 128} records on the node'),
                subtitle: const Text(
                    'Both phones read copies. Oldest records are replaced when full. Node reboot clears its history.'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Custom button message'),
                subtitle:
                    const Text('Save one message to send without a phone'),
                onTap: () => setState(() => _page = 3))),
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Public is not private. This node supports up to two phones. GPS tracking and Internet bridging are not active.')),
      ]);

  Widget _map() => Column(children: [
        const ListTile(
            leading: Icon(Icons.location_off_outlined),
            title: Text('No live node locations yet'),
            subtitle: Text(
                'Map support is ready. GPS and tracking are not connected; no example positions are shown. Tiles need Internet.')),
        Expanded(
            child: FlutterMap(
                options: const MapOptions(
                    initialCenter: LatLng(0, 0), initialZoom: 2),
                children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.meshusf.unifi_poc'),
              const SimpleAttributionWidget(
                  source: Text('© OpenStreetMap contributors')),
            ])),
      ]);

  Future<void> _presetAction({required bool save}) async {
    final session = mesh.sessionGeneration;
    setState(() {
      _savingPreset = true;
      _presetStatus = null;
    });
    try {
      final saved =
          await (save ? mesh.setPreset(_preset.text) : mesh.getPreset());
      if (!mounted || session != mesh.sessionGeneration) return;
      setState(() {
        _preset.text = saved;
        _presetStatus = save ? 'Saved on the node' : 'Loaded from the node';
      });
    } catch (error) {
      if (mounted && session == mesh.sessionGeneration) {
        setState(() => _presetStatus = '$error');
      }
    } finally {
      if (mounted) setState(() => _savingPreset = false);
    }
  }

  Widget _device() => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Node button message',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'On the node Custom page: double-click sends this saved message. Triple-click keeps the existing check-in. Saving overwrites the previous custom message. Empty text clears it.'),
        const SizedBox(height: 16),
        TextField(
            controller: _preset,
            enabled: mesh.connected && !_savingPreset,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: 'Saved custom message',
                counterText: '${utf8Length(_preset.text)}/80 UTF-8 bytes')),
        Wrap(spacing: 12, children: [
          OutlinedButton(
              onPressed: mesh.connected && !_savingPreset
                  ? () => _presetAction(save: false)
                  : null,
              child: const Text('Load from node')),
          FilledButton(
              onPressed: mesh.connected &&
                      !_savingPreset &&
                      (_preset.text.isEmpty || validBody(_preset.text))
                  ? () => _presetAction(save: true)
                  : null,
              child: const Text('Save to node')),
        ]),
        if (_presetStatus != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_presetStatus!)),
        if (!mesh.connected)
          const Text(
              'Connect before loading or saving. Nothing is saved to a node while disconnected.'),
        const Divider(),
        const Text(
            'Bluetooth pairing uses the PIN on the node. Public messages are shared. GPS, private inboxes and Internet routes are not enabled here.'),
      ]);
}
