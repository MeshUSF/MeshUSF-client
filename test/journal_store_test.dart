import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meshusf/journal_store.dart';
import 'package:meshusf/protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('phone journals stay independent, idempotent and durable across boots',
      () async {
    const tempPrefix = 'meshcore-poc-store-test-';
    final temp = await Directory.systemTemp.createTemp(tempPrefix);
    final tempRoot =
        p.normalize(await Directory.systemTemp.resolveSymbolicLinks());
    final tempTarget = p.normalize(await temp.resolveSymbolicLinks());
    if (!p.isWithin(tempRoot, tempTarget) ||
        p.dirname(tempTarget) != tempRoot ||
        !p.basename(tempTarget).startsWith(tempPrefix)) {
      throw StateError('Refusing to clean an unvalidated test temp directory');
    }

    JournalStore? phoneA;
    JournalStore? phoneB;
    JournalStore? reopenedA;
    try {
      phoneA = await JournalStore.open(
          databasePath: p.join(temp.path, 'phone-a.db'));
      phoneB = await JournalStore.open(
          databasePath: p.join(temp.path, 'phone-b.db'));
      final publicKey = List.filled(32, 'ab').join();
      final bootOne = '$publicKey:${List.filled(16, '11').join()}';
      final bootTwo = '$publicKey:${List.filled(16, '22').join()}';
      const first = JournalEntry(
          seq: 1,
          kind: 0,
          timestamp: 100,
          channel: 0,
          text: 'shared node entry');

      await phoneA.saveAndAdvance(bootOne, first, 1);
      await phoneA.saveAndAdvance(bootOne, first, 1);
      expect(await phoneA.cursor(bootOne), 1);
      expect(await phoneB.cursor(bootOne), 0,
          reason: 'each phone has its own local cursor for the same boot');
      expect(await phoneA.messages(publicKey), hasLength(1),
          reason: 'duplicate sequence writes are idempotent');

      await phoneA.close();
      phoneA = null;
      reopenedA = await JournalStore.open(
          databasePath: p.join(temp.path, 'phone-a.db'));
      expect(await reopenedA.cursor(bootOne), 1);
      expect((await reopenedA.messages(publicKey)).single.text,
          'shared node entry');
      expect(await reopenedA.cursor(bootTwo), 0,
          reason: 'a new boot nonce starts a fresh cursor');

      await reopenedA.saveAndAdvance(
          bootTwo,
          const JournalEntry(
              seq: 1,
              kind: 1,
              timestamp: 200,
              channel: 0,
              text: 'next boot entry'),
          1);
      final allBoots = await reopenedA.messages(publicKey);
      expect(allBoots, hasLength(2));
      expect(allBoots.map((m) => m.text),
          containsAll(['shared node entry', 'next boot entry']));
      expect(await reopenedA.cursor(bootOne), 1);
      expect(await reopenedA.cursor(bootTwo), 1);
    } finally {
      await phoneA?.close();
      await phoneB?.close();
      await reopenedA?.close();
      // Revalidate the exact system-temp child before recursive test cleanup.
      final cleanupTarget = p.normalize(await temp.resolveSymbolicLinks());
      if (cleanupTarget != tempTarget ||
          p.dirname(cleanupTarget) != tempRoot ||
          !p.basename(cleanupTarget).startsWith(tempPrefix)) {
        throw StateError('Test temp directory changed before cleanup');
      }
      await temp.delete(recursive: true);
    }
  });
}
