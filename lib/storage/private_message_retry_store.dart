import 'dart:convert';
import '../models/message.dart';
import 'prefs_manager.dart';

class PrivateMessageRetryRecord {
  final String contactKeyHex;
  final String text;
  final DateTime timestamp;
  final String? originalText;
  final String? translatedLanguageCode;
  final String? translationModelId;
  final DateTime failedAt;

  const PrivateMessageRetryRecord({
    required this.contactKeyHex,
    required this.text,
    required this.timestamp,
    this.originalText,
    this.translatedLanguageCode,
    this.translationModelId,
    required this.failedAt,
  });

  factory PrivateMessageRetryRecord.fromMessage(
    Message message, {
    required DateTime failedAt,
  }) {
    return PrivateMessageRetryRecord(
      contactKeyHex: message.senderKeyHex,
      text: message.text,
      timestamp: message.timestamp,
      originalText: message.originalText,
      translatedLanguageCode: message.translatedLanguageCode,
      translationModelId: message.translationModelId,
      failedAt: failedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'contactKeyHex': contactKeyHex,
    'text': text,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'originalText': originalText,
    'translatedLanguageCode': translatedLanguageCode,
    'translationModelId': translationModelId,
    'failedAt': failedAt.millisecondsSinceEpoch,
  };

  static PrivateMessageRetryRecord? fromJson(Map<String, dynamic> json) {
    final contactKeyHex = json['contactKeyHex'] as String?;
    final text = json['text'] as String?;
    final timestamp = json['timestamp'] as int?;
    final failedAt = json['failedAt'] as int?;
    if (contactKeyHex == null ||
        text == null ||
        timestamp == null ||
        failedAt == null) {
      return null;
    }
    return PrivateMessageRetryRecord(
      contactKeyHex: contactKeyHex,
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      originalText: json['originalText'] as String?,
      translatedLanguageCode: json['translatedLanguageCode'] as String?,
      translationModelId: json['translationModelId'] as String?,
      failedAt: DateTime.fromMillisecondsSinceEpoch(failedAt),
    );
  }
}

class PrivateMessageRetryStore {
  static const _keyPrefix = 'private_message_retry_';
  String _publicKeyHex = '';

  set setPublicKeyHex(String value) {
    _publicKeyHex = value.length > 10 ? value.substring(0, 10) : '';
  }

  String get _key => '$_keyPrefix$_publicKeyHex';

  Future<List<PrivateMessageRetryRecord>> load() async {
    if (_publicKeyHex.isEmpty) return [];
    final raw = PrefsManager.instance.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PrivateMessageRetryRecord.fromJson)
          .whereType<PrivateMessageRetryRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<PrivateMessageRetryRecord> records) async {
    if (_publicKeyHex.isEmpty) return;
    await PrefsManager.instance.setString(
      _key,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  Future<void> add(PrivateMessageRetryRecord record) async {
    final records = await load();
    records.removeWhere(
      (existing) =>
          existing.contactKeyHex == record.contactKeyHex &&
          existing.timestamp == record.timestamp &&
          existing.text == record.text,
    );
    records.add(record);
    await save(records);
  }

  Future<void> remove(PrivateMessageRetryRecord record) async {
    final records = await load();
    records.removeWhere(
      (existing) =>
          existing.contactKeyHex == record.contactKeyHex &&
          existing.timestamp == record.timestamp &&
          existing.text == record.text,
    );
    await save(records);
  }
}
