import 'package:latlong2/latlong.dart';

class LocationMapLinkMatch {
  final LatLng position;
  final String link;
  final String textWithoutLink;

  const LocationMapLinkMatch({
    required this.position,
    required this.link,
    required this.textWithoutLink,
  });
}

class LocationMapLink {
  static const _internalHost = 'meshcore.local';
  static final _urlPattern = RegExp(r'https://\S+');
  static const _trailingPunctuation = '.,;:!?)]}';

  static String create(double latitude, double longitude) => Uri.https(
    _internalHost,
    '/map',
    {'lat': latitude.toStringAsFixed(6), 'lon': longitude.toStringAsFixed(6)},
  ).toString();

  static LatLng? parse(String link) {
    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return null;

      double? latitude;
      double? longitude;
      if (uri.scheme == 'https' &&
          uri.host == _internalHost &&
          uri.path == '/map') {
        latitude = double.tryParse(uri.queryParameters['lat'] ?? '');
        longitude = double.tryParse(uri.queryParameters['lon'] ?? '');
      } else if (uri.scheme == 'https' &&
          (uri.host == 'maps.google.com' || uri.host == 'www.google.com')) {
        final coordinates = uri.queryParameters['q']?.split(',');
        if (coordinates?.length == 2) {
          latitude = double.tryParse(coordinates![0].trim());
          longitude = double.tryParse(coordinates[1].trim());
        }
      }

      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        return null;
      }
      return LatLng(latitude, longitude);
    } on FormatException {
      return null;
    }
  }

  static LocationMapLinkMatch? extract(
    String text, {
    Iterable<String> locationLabels = const [],
  }) {
    for (final match in _urlPattern.allMatches(text)) {
      var link = match.group(0)!;
      while (link.isNotEmpty &&
          _trailingPunctuation.contains(link[link.length - 1])) {
        link = link.substring(0, link.length - 1);
      }
      final position = parse(link);
      if (position == null) continue;

      var prefix = text.substring(0, match.start);
      final beforeLink = prefix.trimRight();
      final lineStart = beforeLink.lastIndexOf('\n') + 1;
      final heading = beforeLink.substring(lineStart).trim();
      for (final label in locationLabels) {
        if (!heading.startsWith('$label:')) continue;
        final coordinates = heading
            .substring(label.length + 1)
            .trim()
            .split(',');
        if (coordinates.length != 2) continue;
        final latitude = double.tryParse(coordinates[0].trim());
        final longitude = double.tryParse(coordinates[1].trim());
        if (latitude != null &&
            longitude != null &&
            latitude.isFinite &&
            longitude.isFinite &&
            latitude.toStringAsFixed(6) ==
                position.latitude.toStringAsFixed(6) &&
            longitude.toStringAsFixed(6) ==
                position.longitude.toStringAsFixed(6)) {
          prefix = prefix.substring(0, lineStart);
          break;
        }
      }
      return LocationMapLinkMatch(
        position: position,
        link: link,
        textWithoutLink:
            '$prefix'
                    '${text.substring(match.start + link.length)}'
                .trimRight(),
      );
    }
    return null;
  }
}
