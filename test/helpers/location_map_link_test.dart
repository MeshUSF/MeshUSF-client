import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshcore_open/helpers/location_map_link.dart';

void main() {
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
