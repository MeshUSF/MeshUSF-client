import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:meshusf/journal_store.dart';
import 'package:meshusf/main.dart';
import 'package:meshusf/mesh_connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('shows the Public chat surface before connecting',
      (tester) async {
    final store = (await tester.runAsync(
        () => JournalStore.open(databasePath: inMemoryDatabasePath)))!;
    await tester.pumpWidget(MeshApp(store: store, transport: _EmptyBle()));
    expect(find.text('MeshUSF'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    await tester.tap(find.text('Public'));
    await tester.pump();
    expect(find.text('Local username'), findsOneWidget);
  });
}

class _EmptyBle implements MeshBleTransport {
  @override
  Stream<DiscoveredDevice> scan() => const Stream.empty();
  @override
  Stream<ConnectionStateUpdate> connect(String deviceId, Duration timeout) =>
      const Stream.empty();
  @override
  Future<int> requestMtu(String deviceId, int mtu) async => 185;
  @override
  Future<void> discoverServices(String deviceId) async {}
  @override
  Stream<List<int>> subscribe(QualifiedCharacteristic characteristic) =>
      const Stream.empty();
  @override
  Future<void> write(
      QualifiedCharacteristic characteristic, List<int> value) async {}
}
