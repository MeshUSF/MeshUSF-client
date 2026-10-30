import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/helpers/cyr2lat.dart';
import 'package:meshcore_open/helpers/smaz.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/models/contact.dart';
import 'dart:typed_data';

class _Connector extends MeshCoreConnector {
  bool smaz = false;
  bool cyr2lat = false;

  @override
  bool isChannelSmazEnabled(int channelIndex) => smaz;

  @override
  bool isChannelCyr2LatEnabled(int channelIndex) => cyr2lat;

  @override
  bool isContactSmazEnabled(String key) => smaz;

  @override
  bool isContactCyr2LatEnabled(String key) => cyr2lat;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only standalone contacts bypass channel text transformations', () {
    final connector = _Connector();
    addTearDown(connector.dispose);
    final share = '<${'ab' * 32}:1:Алиса>';

    connector.smaz = true;
    expect(connector.prepareChannelOutboundText(7, share), share);
    final compressible = '${'the message and the contact ' * 12}$share after';
    final compressed = connector.prepareChannelOutboundText(7, compressible);
    expect(compressed, Smaz.encodeIfSmaller(compressible));
    expect(compressed, isNot(compressible));

    connector.smaz = false;
    connector.cyr2lat = true;
    expect(connector.prepareChannelOutboundText(7, share), share);
    final cyrillic = 'Привет $share пока';
    final transliterated = connector.prepareChannelOutboundText(7, cyrillic);
    expect(transliterated, Cyr2Lat.encode(cyrillic));
    expect(transliterated, isNot(cyrillic));
  });

  test(
    'only standalone contacts bypass DM transformations, including retry preparation',
    () {
      final connector = _Connector();
      addTearDown(connector.dispose);
      final recipient = Contact(
        publicKey: Uint8List(32),
        name: 'Recipient',
        type: advTypeChat,
        pathLength: -1,
        path: Uint8List(0),
        lastSeen: DateTime(2026),
      );
      final share = '<${'ab' * 32}:2:Алиса>';
      connector.smaz = true;
      expect(connector.prepareContactOutboundText(recipient, share), share);
      final compressible = '${'the message and the contact ' * 12}$share after';
      final compressed = connector.prepareContactOutboundText(
        recipient,
        compressible,
      );
      expect(compressed, Smaz.encodeIfSmaller(compressible));
      expect(compressed, isNot(compressible));
      connector.smaz = false;
      connector.cyr2lat = true;
      expect(connector.prepareContactOutboundText(recipient, share), share);
      final mixed = 'Привет $share пока';
      expect(
        connector.prepareContactOutboundText(recipient, mixed),
        Cyr2Lat.encode(mixed),
      );
      expect(
        connector.prepareContactOutboundText(recipient, mixed),
        isNot(mixed),
      );
    },
  );
}
