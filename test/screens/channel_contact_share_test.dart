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
import 'package:meshcore_open/models/message.dart';
import 'package:meshcore_open/screens/channel_chat_screen.dart';
import 'package:meshcore_open/screens/chat_screen.dart';
import 'package:meshcore_open/services/app_settings_service.dart';
import 'package:meshcore_open/services/chat_text_scale_service.dart';
import 'package:meshcore_open/services/path_history_service.dart';
import 'package:meshcore_open/services/storage_service.dart';
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
  final dmMessages = <Message>[];
  final dmSends = <({Contact recipient, String text})>[];
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
  List<Contact> get contacts => saved
      .where(
        (contact) =>
            contact.publicKeyHex != pubKeyToHex(ownKey ?? Uint8List(0)),
      )
      .toList();
  @override
  List<Message> getMessages(Contact contact) => dmMessages;
  @override
  void setActiveContact(String? key) {}
  @override
  Future<List<Message>> loadOlderMessages(String key, {int count = 50}) async =>
      [];
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

  @override
  Future<void> sendMessage(
    Contact contact,
    String text, {
    String? originalText,
    String? translatedLanguageCode,
    String? translationModelId,
  }) async {
    if (failShare) throw StateError('Share failed');
    dmSends.add((recipient: contact, text: text));
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
  bool dm = false,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
        ChangeNotifierProvider(create: (_) => AppSettingsService()),
        ChangeNotifierProvider(create: (_) => ChatTextScaleService()),
        ChangeNotifierProvider(
          create: (_) => PathHistoryService(StorageService()),
        ),
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
        home: dm
            ? ChatScreen(
                contact: _contact().copyWith(
                  publicKey: hexToPubKey('cd' * 32),
                  name: 'Recipient',
                  type: advTypeChat,
                ),
              )
            : ChannelChatScreen(
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

Future<void> _openSharePicker(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_circle_outline));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Share contact'));
  await tester.pumpAndSettle();
}

Message _dmContactMessage({bool cli = false}) => Message(
  senderKey: hexToPubKey('cd' * 32),
  text: _share,
  timestamp: DateTime.now(),
  isOutgoing: false,
  status: MessageStatus.sent,
  isCli: cli,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
  });

  for (final dm in [false, true]) {
    testWidgets(
      'shares a saved contact to the current ${dm ? 'DM' : 'channel'} with its real type',
      (tester) async {
        final connector = _Connector()
          ..saved.add(_contact())
          ..saved.add(
            _contact().copyWith(publicKey: Uint8List(32), name: 'Myself'),
          )
          ..discovered.add(
            _contact(active: false).copyWith(
              publicKey: hexToPubKey('ef' * 32),
              name: 'Discovery only',
            ),
          );
        addTearDown(connector.dispose);
        await _show(tester, connector, dm: dm);
        await tester.enterText(find.byType(TextField), 'Unsent draft');
        await _openSharePicker(tester);
        expect(find.text('Discovery only'), findsNothing);
        expect(find.text('Myself'), findsNothing);
        await tester.enterText(find.byType(TextField).last, 'ABABAB');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discovered name'));
        await tester.pumpAndSettle();
        const expected = '<$_key:2:Discovered name>';
        if (dm) {
          expect(connector.dmSends.single.text, expected);
          expect(connector.dmSends.single.recipient.publicKeyHex, 'cd' * 32);
          expect(connector.channelSends, isEmpty);
        } else {
          expect(connector.channelSends.single.text, expected);
          expect(connector.channelSends.single.channel.index, 7);
          expect(connector.dmSends, isEmpty);
        }
        expect(find.text('Unsent draft'), findsOneWidget);
        expect(connector.frames, isEmpty);
      },
    );

    testWidgets(
      'cancelling the picker sends nothing (${dm ? 'DM' : 'channel'})',
      (tester) async {
        final connector = _Connector()..saved.add(_contact());
        addTearDown(connector.dispose);
        await _show(tester, connector, dm: dm);
        await _openSharePicker(tester);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(connector.channelSends, isEmpty);
        expect(connector.dmSends, isEmpty);
      },
    );

    testWidgets(
      'empty picker and removal before selection do not send (${dm ? 'DM' : 'channel'})',
      (tester) async {
        final connector = _Connector();
        addTearDown(connector.dispose);
        await _show(tester, connector, dm: dm);
        await _openSharePicker(tester);
        expect(find.text('No contacts yet'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        connector.saved.add(_contact());
        await _openSharePicker(tester);
        final select = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Discovered name'),
            )
            .onPressed!;
        connector.saved.clear();
        select();
        await tester.pumpAndSettle();
        expect(connector.channelSends, isEmpty);
        expect(connector.dmSends, isEmpty);
      },
    );

    testWidgets(
      'disconnect while picker is open prevents sending (${dm ? 'DM' : 'channel'})',
      (tester) async {
        final connector = _Connector()..saved.add(_contact());
        addTearDown(connector.dispose);
        await _show(tester, connector, dm: dm);
        await _openSharePicker(tester);
        final select = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Discovered name'),
            )
            .onPressed!;
        connector.connected = false;
        select();
        await tester.pumpAndSettle();
        expect(connector.channelSends, isEmpty);
        expect(connector.dmSends, isEmpty);
      },
    );
  }

  testWidgets(
    'DM contact renders as a button and imports only after a tap and ACK',
    (tester) async {
      final connector = _Connector()..dmMessages.add(_dmContactMessage());
      addTearDown(connector.dispose);
      await _show(tester, connector, dm: true);
      expect(find.byType(TranslatedMessageContent), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Fake name'), findsOneWidget);
      expect(connector.frames, isEmpty);
      connector.ack = Completer<void>();
      await tester.tap(find.text('Add Contact'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(connector.frames.single[0], cmdAddUpdateContact);
      expect(connector.waitedForAck, isTrue);
      expect(connector.refreshes, 0);
      connector.ack!.complete();
      await tester.pumpAndSettle();
      expect(connector.refreshes, 1);
      expect(find.text('Already added'), findsOneWidget);
    },
  );

  testWidgets(
    'picker includes all saved node types and disables unrepresentable names',
    (tester) async {
      final connector = _Connector();
      addTearDown(connector.dispose);
      for (var type = 1; type <= 4; type++) {
        connector.saved.add(
          _contact().copyWith(
            publicKey: Uint8List.fromList(List.filled(32, type)),
            name: 'Type $type',
            type: type,
          ),
        );
      }
      connector.saved.add(_contact().copyWith(name: 'Invalid>name'));
      await _show(tester, connector);
      await _openSharePicker(tester);
      for (var type = 1; type <= 4; type++) {
        expect(find.text('Type $type'), findsOneWidget);
      }
      final invalid = find.widgetWithText(FilledButton, 'Invalid>name');
      expect(tester.widget<FilledButton>(invalid).onPressed, isNull);
      expect(find.text('This contact cannot be shared.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'no matching contact',
      );
      await tester.pumpAndSettle();
      expect(find.text('No contacts match your filter'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('DM import failures allow retry and prevent concurrent imports', (
    tester,
  ) async {
    final connector = _Connector()
      ..dmMessages.add(_dmContactMessage())
      ..failImport = true;
    addTearDown(connector.dispose);
    await _show(tester, connector, dm: true);
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Failed to import contact.'), findsOneWidget);
    connector.failImport = false;
    connector.ack = Completer<void>();
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Add Contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, hasLength(2));
    expect(connector.refreshes, 0);
    connector.ack!.complete();
    await tester.pumpAndSettle();
    expect(connector.refreshes, 1);
  });

  testWidgets('DM shared-contact send failures use localized feedback', (
    tester,
  ) async {
    final connector = _Connector()
      ..saved.add(_contact())
      ..failShare = true;
    addTearDown(connector.dispose);
    await _show(tester, connector, dm: true);
    await _openSharePicker(tester);
    await tester.tap(find.text('Discovered name'));
    await tester.pumpAndSettle();
    expect(find.text('Could not share the contact.'), findsOneWidget);
    expect(connector.channelSends, isEmpty);
  });

  testWidgets(
    'DM discovery metadata is protected against a fake shared name and type',
    (tester) async {
      final connector = _Connector()
        ..dmMessages.add(_dmContactMessage())
        ..discovered.add(_contact(active: false));
      addTearDown(connector.dispose);
      await _show(tester, connector, dm: true);
      await tester.tap(find.text('Add Contact'));
      await tester.pump(const Duration(milliseconds: 350));
      final frame = connector.frames.single;
      expect(frame[33], advTypeRepeater);
      expect(frame[34], 3);
      expect(frame[35], 2);
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
      await tester.pumpAndSettle();
    },
  );

  testWidgets('DM saved contacts cannot be overwritten', (tester) async {
    final connector = _Connector()
      ..dmMessages.add(_dmContactMessage())
      ..saved.add(_contact());
    addTearDown(connector.dispose);
    await _show(tester, connector, dm: true);
    await tester.tap(find.text('Already added'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(connector.frames, isEmpty);
  });

  testWidgets('DM own-contact rejection gives feedback without an import', (
    tester,
  ) async {
    final connector = _Connector()
      ..dmMessages.add(_dmContactMessage())
      ..ownKey = hexToPubKey(_key);
    addTearDown(connector.dispose);
    await _show(tester, connector, dm: true);
    await tester.tap(find.text('Your contact'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text("You can't add your own contact."), findsOneWidget);
    expect(connector.frames, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('CLI output is never interpreted as an add-contact card', (
    tester,
  ) async {
    final connector = _Connector()
      ..dmMessages.add(_dmContactMessage(cli: true));
    addTearDown(connector.dispose);
    await _show(tester, connector, dm: true);
    expect(find.text('Add Contact'), findsNothing);
    expect(connector.frames, isEmpty);
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
