import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/utils/contact_qr.dart';

void main() {
  const key =
      '302dc4cd234339c4c1400e7c182a4c4803c9094b3bc15a8e4616a24d80aa7911';
  const first = '<$key:1:john>';
  const second =
      '<3bbc809f4b2f68e02f4c9a7b140f4340aca49ae38e3ebd716a7b3390bea15de5:1:testSubject1>';

  group('parseContactShare', () {
    test('parses both official examples', () {
      expect(parseContactShare(first)!.name, 'john');
      expect(parseContactShare(second)!.name, 'testSubject1');
      expect(parseContactShare(first)!.publicKey, hasLength(32));
      expect(parseContactShare(first)!.type, 1);
    });

    test('trims whitespace, accepts uppercase, and preserves name colons', () {
      final result = parseContactShare(
        ' \n<${key.toUpperCase()}:2: Alice: Bob >\t',
      )!;
      expect(result.publicKey, parseContactShare(first)!.publicKey);
      expect(result.name, 'Alice: Bob');
      expect(result.type, 2);
    });

    test('accepts known types and leaves unknown numeric types unset', () {
      for (var type = 1; type <= 4; type++) {
        expect(parseContactShare('<$key:$type:Name>')!.type, type);
      }
      for (final type in ['-1', '0', '5', '999999999999999999999999999']) {
        expect(parseContactShare('<$key:$type:Name>')!.type, isNull);
      }
    });

    test('rejects malformed strings without throwing', () {
      for (final text in [
        '',
        '<',
        '<>',
        '<${key.substring(1)}:1:john>',
        '<${key}a:1:john>',
        '<${'z' * 64}:1:john>',
        '$key:1:john>',
        '<$key:1:john',
        '<$key:1>',
        '<$key john>',
        '<$key:1:>',
        '<$key:1:  >',
        '<$key:nope:john>',
        '<$key::john>',
        'before $first',
        '$first after',
        '$first$second',
      ]) {
        expect(parseContactShare(text), isNull, reason: text);
      }
    });

    test('caps names at a whole UTF-8 character', () {
      final name = parseContactShare('<$key:1:${'é' * 20}>')!.name;
      expect(name, 'é' * 15);
      expect(utf8.encode(name).length, 30);
      final emojiName = parseContactShare('<$key:1:${'😀' * 8}>')!.name;
      expect(emojiName, '😀' * 7);
      expect(utf8.encode(emojiName).length, 28);
    });
  });

  group('findContactShareSegments', () {
    test('preserves surrounding text and multiple contacts', () {
      const text = 'hello $first and $second goodbye';
      final segments = findContactShareSegments(text);
      expect(segments.map((s) => s.text).join(), text);
      expect(
        segments.where((s) => s.contact != null).map((s) => s.contact!.name),
        ['john', 'testSubject1'],
      );
      expect(segments.where((s) => s.contact == null).map((s) => s.text), [
        'hello ',
        ' and ',
        ' goodbye',
      ]);
    });

    test('supports adjacent contacts', () {
      expect(findContactShareSegments('$first$second'), hasLength(2));
    });

    test('leaves invalid candidates plain and finds later valid strings', () {
      const prefix = '<3 <lol> <$key:nope:Fake> ';
      final segments = findContactShareSegments('$prefix$first');
      expect(segments.first.text, prefix);
      expect(segments.first.contact, isNull);
      expect(segments.last.contact!.name, 'john');
      expect(findContactShareSegments('<lol>').single.contact, isNull);
    });

    test('the first closing bracket ends a name', () {
      final segments = findContactShareSegments('<$key:1:Jo>hn>');
      expect(segments.first.contact!.name, 'Jo');
      expect(segments.last.text, 'hn>');
      expect(segments.last.contact, isNull);
      expect(parseContactShare('<$key:1:Jo>hn>'), isNull);
    });
  });

  group('buildContactShare', () {
    test('uses lowercase hex, companion type, and a bounded name', () {
      final result = buildContactShare(
        Uint8List.fromList(List.filled(32, 0xAB)),
        ' ${'é' * 20} ',
      )!;
      expect(result, '<${'ab' * 32}:1:${'é' * 15}>');
      expect(parseContactShare(result)!.name, 'é' * 15);
    });

    test('requires usable self-info and a representable name', () {
      final bytes = Uint8List(32);
      expect(buildContactShare(null, 'Alice'), isNull);
      expect(buildContactShare(Uint8List(31), 'Alice'), isNull);
      expect(buildContactShare(bytes, null), isNull);
      expect(buildContactShare(bytes, '  '), isNull);
      expect(buildContactShare(bytes, 'Jo>hn'), isNull);
    });
  });
}
