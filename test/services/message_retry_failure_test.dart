import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/contact.dart';
import 'package:meshcore_open/models/message.dart';
import 'package:meshcore_open/services/message_retry_service.dart';

Contact _contact() => Contact(
  publicKey: Uint8List.fromList(List<int>.generate(32, (i) => 0xAA + i)),
  name: 'Test',
  type: 1,
  pathLength: -1,
  path: Uint8List(0),
  lastSeen: DateTime.now(),
);

void main() {
  late MessageRetryService service;
  late Map<String, Message> latest;
  late List<String> sentTexts;
  late List<String> queuedTexts;
  late bool failSends;
  Uint8List? selfKey;

  setUp(() {
    service = MessageRetryService();
    latest = {};
    sentTexts = [];
    queuedTexts = [];
    failSends = false;
    selfKey = Uint8List(32);
    service.initialize(
      RetryServiceConfig(
        sendMessage: (_, text, _, _) async {
          if (failSends) throw StateError('Not connected');
          sentTexts.add(text);
        },
        addMessage: (_, m) => latest[m.messageId] = m,
        updateMessage: (m) => latest[m.messageId] = m,
        queueTransportFailure: (_, message) async {
          queuedTexts.add(message.text);
        },
        getSelfPublicKey: () => selfKey,
      ),
    );
  });

  tearDown(() => service.dispose());

  Message byText(String text) =>
      latest.values.firstWhere((m) => m.text == text);

  test('failed send fails the message and frees the contact slot', () async {
    failSends = true;
    final contact = _contact();
    await service.sendMessageWithRetry(contact: contact, text: 'a');
    await pumpEventQueue();
    expect(byText('a').status, MessageStatus.failed);

    failSends = false;
    await service.sendMessageWithRetry(contact: contact, text: 'b');
    await pumpEventQueue();
    expect(sentTexts, ['b']);
  });

  test('unknown self key fails instead of waiting forever', () async {
    selfKey = null;
    await service.sendMessageWithRetry(contact: _contact(), text: 'a');
    await pumpEventQueue();
    expect(byText('a').status, MessageStatus.failed);
    expect(sentTexts, isEmpty);
    expect(service.hasPendingMessages, isFalse);
  });

  test(
    'recipient confirmation resolves a resend when RESP_CODE_SENT was missed',
    () async {
      final contact = _contact();
      await service.sendMessageWithRetry(contact: contact, text: 'a');
      await pumpEventQueue();

      final pending = byText('a');
      expect(pending.status, MessageStatus.pending);

      final ackHash = MessageRetryService.computeExpectedAckHash(
        pending.timestamp.millisecondsSinceEpoch ~/ 1000,
        pending.retryCount,
        pending.text,
        selfKey!,
      );
      service.handleAckReceived(ackHash, 1200);
      await pumpEventQueue();

      expect(byText('a').status, MessageStatus.delivered);
      expect(byText('a').tripTimeMs, 1200);
    },
  );

  test('transport disconnect queues and removes the private message', () async {
    final contact = _contact();
    await service.sendMessageWithRetry(contact: contact, text: 'a');
    await pumpEventQueue();
    expect(sentTexts, ['a']);

    service.pauseAllPending();
    await pumpEventQueue();
    expect(queuedTexts, ['a']);
    expect(service.hasPendingMessages, isFalse);
  });

  test('failAllPending fails in-flight and queued messages', () async {
    final contact = _contact();
    await service.sendMessageWithRetry(contact: contact, text: 'a');
    await service.sendMessageWithRetry(contact: contact, text: 'b');
    await pumpEventQueue();
    expect(sentTexts, ['a']);

    service.failAllPending();
    await pumpEventQueue();

    expect(byText('a').status, MessageStatus.failed);
    expect(byText('b').status, MessageStatus.failed);
    expect(service.hasPendingMessages, isFalse);
    expect(sentTexts, ['a']);
  });
}
