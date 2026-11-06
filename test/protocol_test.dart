import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshusf/protocol.dart';

void main() {
  group('UF1 codec', () {
    test('encodes exact INFO request vector', () {
      expect(encodeRequest(1, 0x1234), [0x70, 0x55, 0x46, 1, 1, 0x34, 0x12]);
    });

    test('decodes op, little-endian request ID, status and payload', () {
      final response =
          decodeResponse([0x70, 0x55, 0x46, 1, 3, 0x34, 0x12, 0, 0xaa, 0xbb]);
      expect(response.op, 3);
      expect(response.requestId, 0x1234);
      expect(response.status, 0);
      expect(response.payload, [0xaa, 0xbb]);
    });

    test('decodes INFO fixed fields and UTF-8 node name', () {
      final bytes = <int>[
        ...List.filled(16, 0x11),
        1,
        0,
        0,
        0,
        2,
        0,
        0,
        0,
        0x34,
        0x12,
        1,
        ...List.filled(32, 0x22),
        3,
        ...utf8.encode('Mø')
      ];
      final info = NodeInfo.decode(Uint8List.fromList(bytes));
      expect(info.oldestSeq, 1);
      expect(info.newestSeq, 2);
      expect(info.capacity, 0x1234);
      expect(info.publicSlot, 1);
      expect(info.name, 'Mø');
    });

    test('decodes READ field offsets and sequence', () {
      final payload = <int>[
        9,
        0,
        0,
        0,
        1,
        0x78,
        0x56,
        0x34,
        0x12,
        2,
        2,
        0,
        2,
        ...utf8.encode('hi')
      ];
      final c = decodeJournalChunk(Uint8List.fromList(payload));
      expect(c.seq, 9);
      expect(c.kind, 1);
      expect(c.timestamp, 0x12345678);
      expect(c.channel, 2);
      expect(c.totalLength, 2);
      expect(c.offset, 0);
      expect(utf8.decode(c.data), 'hi');
      expect(readRequestPayload(0x01020304, 7), [4, 3, 2, 1, 7]);
    });

    test('assembles a multi-fragment entry and preserves byte boundaries', () {
      final assembler = JournalAssembler(4);
      assembler.add(decodeJournalChunk(Uint8List.fromList(
          [4, 0, 0, 0, 0, 2, 0, 0, 0, 1, 4, 0, 2, 0xc3, 0xa9])));
      expect(assembler.isComplete, isFalse);
      assembler.add(decodeJournalChunk(Uint8List.fromList(
          [4, 0, 0, 0, 0, 2, 0, 0, 0, 1, 4, 2, 2, 0x21, 0x21])));
      expect(assembler.isComplete, isTrue);
      expect(assembler.finish().text, 'é!!');
    });

    test('decodes explicit journal gap bounds', () {
      final gap =
          JournalGap.decode(Uint8List.fromList([5, 0, 0, 0, 8, 0, 0, 0]));
      expect(gap.oldest, 5);
      expect(gap.newest, 8);
      expect(() => JournalGap.decode(Uint8List.fromList([1, 0])),
          throwsA(isA<ProtocolException>()));
    });
  });

  group('UTF-8 byte limits', () {
    test('counts UTF-8 bytes rather than Dart code units', () {
      expect(utf8Length('é' * 8), 16);
      expect(validUsername('é' * 8), isTrue);
      expect(validUsername('é' * 9), isFalse);
      expect(validBody('🙂' * 20), isTrue);
      expect(validBody('🙂' * 21), isFalse);
      expect(validBody(''), isFalse);
      expect(validUsername('name\u0085'), isFalse);
      expect(validBody('line\u2028break'), isFalse);
    });
  });
}
