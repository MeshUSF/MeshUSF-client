import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'protocol.dart';

class StoredMessage {
  const StoredMessage(
      {required this.nodeKey,
      required this.seq,
      required this.kind,
      required this.timestamp,
      required this.channel,
      required this.text,
      required this.gap});
  final String nodeKey, text;
  final int seq, kind, timestamp, channel;
  final bool gap;
}

class JournalStore {
  JournalStore._(this.db);
  final Database db;

  Future<void> close() => db.close();

  static Future<JournalStore> open({String? databasePath}) async {
    final dir = databasePath == null ? await getDatabasesPath() : null;
    final db = await openDatabase(
        databasePath ?? p.join(dir!, 'meshcore_poc.db'),
        version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE messages (node_key TEXT NOT NULL, seq INTEGER NOT NULL, kind INTEGER NOT NULL, timestamp INTEGER NOT NULL, channel INTEGER NOT NULL, text TEXT NOT NULL, is_gap INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(node_key, seq))');
      await db.execute(
          'CREATE TABLE cursors (node_key TEXT PRIMARY KEY, cursor INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE settings (setting_key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    });
    return JournalStore._(db);
  }

  Future<int> cursor(String key) async =>
      (await db.query('cursors',
              columns: ['cursor'],
              where: 'node_key = ?',
              whereArgs: [key],
              limit: 1))
          .firstOrNull?['cursor'] as int? ??
      0;

  Future<String?> setting(String key) async => (await db.query('settings',
          columns: ['value'],
          where: 'setting_key = ?',
          whereArgs: [key],
          limit: 1))
      .firstOrNull?['value'] as String?;
  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {'setting_key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveAndAdvance(
      String key, JournalEntry entry, int cursor) async {
    await db.transaction((txn) async {
      await txn.insert(
          'messages',
          {
            'node_key': key,
            'seq': entry.seq,
            'kind': entry.kind,
            'timestamp': entry.timestamp,
            'channel': entry.channel,
            'text': entry.text,
            'is_gap': 0
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('cursors', {'node_key': key, 'cursor': cursor},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> saveGap(String key, int seq, int oldest, int newest) async {
    await db.transaction((txn) async {
      await txn.insert(
          'messages',
          {
            'node_key': key,
            'seq': seq,
            'kind': 2,
            'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'channel': 0,
            'text':
                'Journal gap: entries $seq–${oldest - 1} are no longer available (journal now $oldest–$newest).',
            'is_gap': 1
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('cursors', {'node_key': key, 'cursor': oldest - 1},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<StoredMessage>> messages(String publicKeyHex) async {
    final rows = await db.query('messages',
        where: 'node_key LIKE ?',
        whereArgs: ['$publicKeyHex:%'],
        orderBy: 'timestamp DESC, seq DESC');
    return rows
        .map((r) => StoredMessage(
            nodeKey: r['node_key'] as String,
            seq: r['seq'] as int,
            kind: r['kind'] as int,
            timestamp: r['timestamp'] as int,
            channel: r['channel'] as int,
            text: r['text'] as String,
            gap: r['is_gap'] == 1))
        .toList();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
