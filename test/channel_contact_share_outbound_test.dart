import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/helpers/cyr2lat.dart';
import 'package:meshcore_open/helpers/smaz.dart';

class _Connector extends MeshCoreConnector {
  bool smaz = false;
  bool cyr2lat = false;

  @override
  bool isChannelSmazEnabled(int channelIndex) => smaz;

  @override
  bool isChannelCyr2LatEnabled(int channelIndex) => cyr2lat;
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
}
