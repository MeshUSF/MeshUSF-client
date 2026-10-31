import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshcore_open/helpers/location_map_link.dart';

void main() {
  const labels = [
    'My location',
    'Location',
    'Ma position',
    'Mi ubicación',
    'Ubicación',
  ];
  final link = LocationMapLink.create(45.5, -122.6);

  for (final label in labels) {
    test('removes the matching $label heading and preserves other text', () {
      final match = LocationMapLink.extract(
        'Meet me here\n$label: 45.500000, -122.600000\n$link\nBring water',
        locationLabels: labels,
      );
      expect(match!.position, const LatLng(45.5, -122.6));
      expect(match.textWithoutLink, 'Meet me here\n\nBring water');
      expect(
        LocationMapLink.extract(
          '$label: 45.5,-122.6\n$link',
          locationLabels: labels,
        )!.textWithoutLink,
        isEmpty,
      );
    });
  }

  test('preserves mismatched, unrelated and nonadjacent headings', () {
    for (final prefix in [
      'My location: 46.5,-122.6',
      'My location: 45.5,-122.6 extra text',
      'My location: NaN,-122.6',
      'Meet me: 45.5,-122.6',
      'My location: 45.5,-122.6\nMeet me here',
    ]) {
      expect(
        LocationMapLink.extract(
          '$prefix\n$link',
          locationLabels: labels,
        )!.textWithoutLink,
        prefix,
      );
    }
  });

  test('extracts only the first valid location and preserves punctuation', () {
    final second = LocationMapLink.create(10, 20);
    final match = LocationMapLink.extract(
      'https://example.com ($link). $second',
    );
    expect(match!.link, link);
    expect(match.textWithoutLink, 'https://example.com (). $second');
  });

  test('supports legacy Google coordinate links and matching headings', () {
    for (final googleLink in [
      'https://maps.google.com/?q=45.5,-122.6',
      'https://www.google.com/maps?q=45.5%2C-122.6',
    ]) {
      final match = LocationMapLink.extract(
        'Location: 45.5,-122.6\n$googleLink',
        locationLabels: labels,
      );
      expect(match!.position, const LatLng(45.5, -122.6));
      expect(match.textWithoutLink, isEmpty);
    }
  });

  test('ignores bare coordinates, unsupported URLs and malformed input', () {
    for (final text in [
      '45.5,-122.6',
      'https://maps.app.goo.gl/abcdef',
      'https://maps.google.com/?q=London',
      'https://meshcore.local/map?lat=NaN&lon=0',
      'https://meshcore.local/map?lat=0&lon=Infinity',
      'https://meshcore.local/map?lat=-91&lon=0',
      'https://meshcore.local/map?lat=0&lon=181',
      'https://meshcore.local/map?lat=%FF&lon=0',
      'https://meshcore.local/map?lat=45&lon=%',
      'https://meshcore.local.evil/map?lat=45&lon=0',
    ]) {
      expect(LocationMapLink.parse(text), isNull, reason: text);
      expect(LocationMapLink.extract(text), isNull, reason: text);
    }
  });

  test('creates and parses internal map links', () {
    final link = LocationMapLink.create(45.1234567, -122.7654321);

    expect(link, 'https://meshcore.local/map?lat=45.123457&lon=-122.765432');
    expect(LocationMapLink.parse(link), const LatLng(45.123457, -122.765432));

    final elements = const UrlLinkifier().parse([
      TextElement(link),
    ], const LinkifyOptions(humanize: false, defaultToHttps: false));
    expect(elements.whereType<UrlElement>().single.url, link);
  });

  test('extracts internal map links from message content for a map button', () {
    const prefix = 'Location: 45.5,-122.6\n';
    final link = LocationMapLink.create(45.5, -122.6);
    final extracted = LocationMapLink.extract('$prefix$link');

    expect(extracted, isNotNull);
    expect(extracted!.link, link);
    expect(extracted.position, const LatLng(45.5, -122.6));
    expect(extracted.textWithoutLink, 'Location: 45.5,-122.6');
  });

  test(
    'extracts My location messages without changing the map coordinates',
    () {
      final link = LocationMapLink.create(45.5, -122.6);
      final extracted = LocationMapLink.extract(
        'My location: 45.5,-122.6\n$link',
      );
      expect(extracted!.position, const LatLng(45.5, -122.6));
      expect(extracted.textWithoutLink, 'My location: 45.5,-122.6');
    },
  );

  test(
    'opens coordinates from previously sent Google Maps links internally',
    () {
      expect(
        LocationMapLink.parse('https://maps.google.com/?q=45.5,-122.6'),
        const LatLng(45.5, -122.6),
      );
    },
  );

  test('rejects unrecognized links and invalid coordinates', () {
    expect(
      LocationMapLink.parse('https://example.com/map?lat=45&lon=-122'),
      isNull,
    );
    expect(
      LocationMapLink.parse('https://meshcore.local/map?lat=91&lon=-122'),
      isNull,
    );
    expect(
      LocationMapLink.parse(
        'https://meshcore.local/map?lat=45&lon=not-a-coordinate',
      ),
      isNull,
    );
  });
}
