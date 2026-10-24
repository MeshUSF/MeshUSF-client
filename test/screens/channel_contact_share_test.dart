import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/models/channel.dart';
import 'package:meshcore_open/models/channel_message.dart';
import 'package:meshcore_open/models/contact.dart';
import 'package:meshcore_open/screens/channel_chat_screen.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/services/chat_text_scale_service.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/widgets/translated_message_content.dart';

const _key = 'abababababababababababababababababababababababababababababababab';
const _share = '<$_key:1:Fake name>';

class _Connector extends MeshCoreConnector {
  bool connected = true;
  final saved = <Contact>[];
  final discovered = <Contact>[];
  final messages = <ChannelMessage>[];
  final frames = <Uint8List>[];
  bool waitedForAck = false;
  bool failImport = false;
  int refreshes = 0;
  Completer<void>? ack;
  Uint8List? ownKey = Uint8List(32);
  String? ownName = 'My radio';
  final channelSends =
      <
        ({
          Channel channel,
          String text,
          String? region,
          ChannelMessage? replyTo,
        })
      >[];
  bool failShare = false;

  @override
  bool get isConnected => connected;
  @override
  Uint8List? get selfPublicKey => ownKey;
  @override
  String? get selfName => ownName;
  @override
  List<Contact> get allContactsUnfiltered => [...saved, ...discovered];
  @override
  Contact? getContactByPubKeyHex(String key) =>
      saved.where((c) => c.publicKeyHex == key).firstOrNull;
  @override
  List<ChannelMessage> getChannelMessages(Channel channel) => messages;
  @override
  void acquireRadioStatsPolling() {}
  @override
  void releaseRadioStatsPolling() {}
  @override
  void setActiveChannel(int? index) {}
  @override
  Future<List<ChannelMessage>> loadOlderChannelMessages(
    int index, {
    int count = 50,
  }) async => [];
  @override
  Future<void> sendFrame(
    Uint8List data, {
    String? channelSendQueueId,
    bool expectsGenericAck = false,
    bool waitForGenericAck = false,
  }) async {
    frames.add(data);
    waitedForAck = waitForGenericAck;
    if (failImport) throw StateError('Import failed');
    await ack?.future;
  }

  @override
  Future<void> refreshContacts() async {
    refreshes++;
    saved.add(_contact());
    notifyListeners();
  }

  @override
  Future<void> sendChannelMessage(
    Channel channel,
    String text, {
    String? originalText,
    String? translatedLanguageCode,
    String? translationModelId,
    String? region,
    ChannelMessage? replyTo,
  }) async {
    if (failShare) throw StateError('Share failed');
    channelSends.add((
      channel: channel,
      text: text,
      region: region,
      replyTo: replyTo,
    ));
  }
}

Contact _contact({bool active = true}) => Contact(
  publicKey: hexToPubKey(_key),
  name: 'Discovered name',
  type: advTypeRepeater,
  flags: 3,
  pathLength: 2,
  path: Uint8List.fromList([1, 2]),
  lastSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  isActive: active,
);

Future<void> _show(
  WidgetTester tester,
  _Connector connector, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
        ChangeNotifierProvider(create: (_) => AppSettingsService()),
        ChangeNotifierProvider(create: (_) => ChatTextScaleService()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChannelChatScreen(
          channel: Channel(
            index: 7,
            name: 'Public',
            psk: hex2Uint8List(Channel.publicChannelPsk),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
  });

  testWidgets('adds only on tap and waits for the ACK before refreshing', (
    tester,
  ) async {
    final connector = _Connector();
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: 'hello $_share goodbye',
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    expect(find.text('Fake name'), findsOneWidget);
    expect(find.text('abababab'), findsOneWidget);
    expect(
      tester
          .widgetList<TranslatedMessageContent>(
            find.byType(TranslatedMessageContent),
          )
          .map((content) => content.displayText),
      ['hello ', ' goodbye'],
    );
    expect(connector.frames, isEmpty);
    connector.ack = Completer<void>();
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, hasLength(1));
    expect(connector.waitedForAck, isTrue);
    expect(connector.refreshes, 0);
    expect(connector.frames.single[0], cmdAddUpdateContact);
    expect(connector.frames.single[35], 0xff);
    final timestampOffset = 36 + maxPathSize + maxNameSize;
    expect(
      connector.frames.single.sublist(timestampOffset, timestampOffset + 4),
      [0, 0, 0, 0],
    );
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, hasLength(1));
    connector.ack!.complete();
    await tester.pumpAndSettle();
    expect(connector.refreshes, 1);
    expect(find.text('Already added'), findsOneWidget);
    expect(find.text('Contact has been imported.'), findsOneWidget);
  });

  testWidgets('discovered metadata wins over a fake string name and type', (
    tester,
  ) async {
    final connector = _Connector()..discovered.add(_contact(active: false));
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: _share,
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    final frame = connector.frames.single;
    final nameOffset = 36 + maxPathSize;
    expect(
      utf8.decode(
        frame
            .sublist(nameOffset, nameOffset + maxNameSize)
            .takeWhile((b) => b != 0)
            .toList(),
      ),
      'Discovered name',
    );
    expect(frame[33], advTypeRepeater);
    expect(frame[34], 3);
    expect(frame[35], 2);
    expect(frame.sublist(36, 38), [1, 2]);
    final timestampOffset = nameOffset + maxNameSize;
    expect(
      ByteData.sublistView(
        frame,
        timestampOffset,
        timestampOffset + 4,
      ).getUint32(0, Endian.little),
      1700000000,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('uppercase saved keys cannot rename an existing contact', (
    tester,
  ) async {
    final connector = _Connector()..saved.add(_contact());
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: _share.toUpperCase(),
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    expect(find.text('Already added'), findsOneWidget);
    await tester.tap(find.text('Already added'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, isEmpty);
  });

  testWidgets('an import failure permits retry', (tester) async {
    final connector = _Connector()..failImport = true;
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: _share,
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Failed to import contact.'), findsOneWidget);
    expect(connector.refreshes, 0);
    connector.failImport = false;
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, hasLength(2));
    await tester.pumpAndSettle();
  });

  testWidgets('disconnected controls cannot send an import', (tester) async {
    final connector = _Connector()..connected = false;
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: _share,
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, isEmpty);
  });

  testWidgets('rechecks saved contacts when tapped', (tester) async {
    final connector = _Connector();
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: _share,
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    connector.saved.add(_contact());
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, isEmpty);
  });

  testWidgets(
    'share action sends to the selected channel without touching a draft',
    (tester) async {
      final connector = _Connector()
        ..ownKey = hexToPubKey(_key)
        ..ownName = 'é' * 20;
      addTearDown(connector.dispose);
      await _show(tester, connector);
      await tester.enterText(find.byType(TextField), 'Unsent draft');
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share my contact'));
      await tester.pumpAndSettle();
      final sent = connector.channelSends.single;
      expect(sent.channel.index, 7);
      expect(sent.text, '<$_key:1:${'é' * 15}>');
      expect(
        utf8.encode(sent.text).length,
        lessThanOrEqualTo(maxChannelMessageBytes(connector.selfName)),
      );
      expect(sent.region, isNull);
      expect(sent.replyTo, isNull);
      expect(find.text('Unsent draft'), findsOneWidget);
    },
  );

  testWidgets('sharing requires self-info', (tester) async {
    final connector = _Connector()..ownKey = null;
    addTearDown(connector.dispose);
    await _show(tester, connector);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Share my contact'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(connector.channelSends, isEmpty);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('share failure shows localized feedback', (tester) async {
    final connector = _Connector()..failShare = true;
    addTearDown(connector.dispose);
    await _show(tester, connector);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share my contact'));
    await tester.pumpAndSettle();
    expect(find.text('Could not share your contact.'), findsOneWidget);
  });

  testWidgets('sharing respects the send cooldown', (tester) async {
    final connector = _Connector();
    addTearDown(connector.dispose);
    await _show(tester, connector);
    final menu = tester.widget<PopupMenuButton<String>>(
      find.ancestor(
        of: find.byIcon(Icons.add_circle_outline),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    menu.onSelected!('contact');
    menu.onSelected!('contact');
    await tester.pumpAndSettle();
    expect(connector.channelSends, hasLength(1));
    expect(
      find.text('Please wait a moment before sending again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'multiple bounded contact controls fit a narrow bubble at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final connector = _Connector();
      addTearDown(connector.dispose);
      connector.messages.add(
        ChannelMessage(
          senderName: 'Sender',
          text: '<$_key:1:${'Name:' * 20}> $_share',
          translatedText: 'Translated message',
          timestamp: DateTime.now(),
          isOutgoing: false,
        ),
      );
      await _show(tester, connector, scale: 1.8);
      expect(find.text('Add Contact'), findsNWidgets(2));
      expect(find.text('abababab'), findsNWidgets(2));
      expect(connector.frames, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('translated text cannot introduce an add-contact action', (
    tester,
  ) async {
    final connector = _Connector();
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: 'Plain text',
        translatedText: _share,
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    expect(find.text('Add Contact'), findsNothing);
    expect(connector.frames, isEmpty);
  });

  for (final outgoing in [false, true]) {
    testWidgets(
      'standalone contact renders only a filled button (outgoing: $outgoing)',
      (tester) async {
        final connector = _Connector();
        addTearDown(connector.dispose);
        connector.messages.add(
          ChannelMessage(
            senderName: 'Sender',
            text: _share,
            timestamp: DateTime.now(),
            isOutgoing: outgoing,
            status: ChannelMessageStatus.sent,
          ),
        );
        await _show(tester, connector);
        expect(find.byType(TranslatedMessageContent), findsNothing);
        final buttonFinder = find.widgetWithText(FilledButton, 'Fake name');
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<FilledButton>(buttonFinder);
        final color = button.style!.backgroundColor!.resolve({});
        final scheme = Theme.of(tester.element(buttonFinder)).colorScheme;
        expect(color, isNotNull);
        expect(
          color,
          isNot(outgoing ? MeshPalette.me : scheme.surfaceContainerLow),
        );
        expect(find.text('abababab'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'own contact shows feedback without importing, regardless of key case',
    (tester) async {
      final connector = _Connector()..ownKey = hexToPubKey(_key);
      addTearDown(connector.dispose);
      connector.messages.add(
        ChannelMessage(
          senderName: 'Me',
          text: _share.toUpperCase(),
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: ChannelMessageStatus.sent,
        ),
      );
      await _show(tester, connector);
      expect(find.text('Your contact'), findsOneWidget);
      await tester.tap(find.text('Your contact'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text("You can't add your own contact."), findsOneWidget);
      expect(find.text('Contact has been imported.'), findsNothing);
      expect(connector.frames, isEmpty);
      expect(connector.refreshes, 0);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('own key is checked again when tapping a stale add button', (
    tester,
  ) async {
    final connector = _Connector();
    addTearDown(connector.dispose);
    connector.messages.add(
      ChannelMessage(
        senderName: 'Sender',
        text: _share,
        timestamp: DateTime.now(),
        isOutgoing: false,
      ),
    );
    await _show(tester, connector);
    connector.ownKey = hexToPubKey(_key);
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text("You can't add your own contact."), findsOneWidget);
    expect(connector.frames, isEmpty);
    expect(connector.refreshes, 0);
    await tester.pumpAndSettle();
  });
}
