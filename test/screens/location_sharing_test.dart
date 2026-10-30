import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meshcore_open/connector/meshcore_connector.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/models/app_settings.dart';
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
import 'package:meshcore_open/services/translation_service.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:provider/provider.dart';

class _ChatSettings extends AppSettingsService {
  @override
  final settings = AppSettings(imageMessagesEnabled: false);
}

class _ChatConnector extends MeshCoreConnector {
  bool connected = true;
  final directMessages = <Message>[];
  final channelMessages = <ChannelMessage>[];

  @override
  bool get isConnected => connected;
  @override
  String get selfName => 'Me';
  @override
  bool get hasGps => false;
  @override
  void acquireRadioStatsPolling() {}
  @override
  void releaseRadioStatsPolling() {}
  @override
  void setActiveContact(String? contactKeyHex) {}
  @override
  void setActiveChannel(int? channelIndex) {}
  @override
  List<Message> getMessages(Contact contact) => directMessages;
  @override
  List<ChannelMessage> getChannelMessages(Channel channel) => channelMessages;

  @override
  Future<void> sendMessage(
    Contact contact,
    String text, {
    String? originalText,
    String? translatedLanguageCode,
    String? translationModelId,
  }) async {
    directMessages.add(
      Message(
        senderKey: contact.publicKey,
        text: text,
        timestamp: DateTime(2026, 10, 29, 12),
        isOutgoing: true,
        status: MessageStatus.sent,
      ),
    );
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
    channelMessages.add(
      ChannelMessage(
        senderName: selfName,
        text: text,
        timestamp: DateTime(2026, 10, 29, 12),
        isOutgoing: true,
        status: ChannelMessageStatus.sent,
        channelIndex: channel.index,
        region: region,
      ),
    );
    notifyListeners();
  }
}

class _ChatLocationPlatform extends GeolocatorPlatform {
  int lookups = 0;
  Future<Position> Function()? locate;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    lookups++;
    return locate == null ? _position() : await locate!();
  }
}

Position _position() => Position(
  longitude: -122.6,
  latitude: 45.5,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Future<void> _pumpChat(
  WidgetTester tester,
  _ChatConnector connector, {
  required bool channel,
  String language = 'en',
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MeshCoreConnector>.value(value: connector),
        ChangeNotifierProvider<AppSettingsService>(
          create: (_) => _ChatSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => PathHistoryService(StorageService()),
        ),
        ChangeNotifierProvider(create: (_) => ChatTextScaleService()),
        ChangeNotifierProvider(
          create: (context) =>
              TranslationService(context.read<AppSettingsService>()),
        ),
      ],
      child: RepaintBoundary(
        key: const ValueKey('location-sharing-screenshot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MeshTheme.dark(),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: channel
              ? ChannelChatScreen(
                  channel: Channel(
                    index: 1,
                    name: '#local',
                    psk: Uint8List(16),
                  ),
                )
              : ChatScreen(
                  contact: Contact(
                    publicKey: Uint8List(32),
                    name: 'Alex',
                    type: 1,
                    pathLength: -1,
                    path: Uint8List(0),
                    lastSeen: DateTime(2026, 10, 29),
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _tapLocation(
  WidgetTester tester, {
  required bool channel,
  String label = 'Send location',
}) async {
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    ScaffoldMessenger.of(
      tester.element(find.byType(TextField)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  }
  if (channel) {
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.tap(find.byTooltip(label));
    await tester.pump();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!autoUpdateGoldenFiles) return;
  await expectLater(
    find.byKey(const ValueKey('location-sharing-screenshot')),
    matchesGoldenFile('../../docs/screenshots/$name.png'),
  );
}

void main() {
  late GeolocatorPlatform originalPlatform;
  late _ChatLocationPlatform platform;
  late _ChatConnector connector;

  setUpAll(() async {
    for (final font in {
      'Inter': 'assets/fonts/Inter.ttf',
      'JetBrains Mono': 'assets/fonts/JetBrainsMono.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final fontLoader = FontLoader(font.key);
      fontLoader.addFont(rootBundle.load(font.value));
      await fontLoader.load();
    }
  });
  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    platform = _ChatLocationPlatform();
    GeolocatorPlatform.instance = platform;
    connector = _ChatConnector();
  });
  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
    connector.dispose();
  });

  for (final channel in [false, true]) {
    final kind = channel ? 'channel' : 'direct';

    testWidgets('$kind shows progress and blocks duplicate location actions', (
      tester,
    ) async {
      final pending = Completer<Position>();
      platform.locate = () => pending.future;
      await _pumpChat(tester, connector, channel: channel);
      await tester.enterText(find.byType(TextField), 'Unsent draft');
      await _tapLocation(tester, channel: channel);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(platform.lookups, 1);
      await tester.pump(const Duration(milliseconds: 250));
      await _capture(tester, '$kind-location-sharing-loading');

      if (channel) {
        await tester.tap(find.byTooltip('Getting location…'));
        await tester.pump(const Duration(milliseconds: 300));
        final item = tester.widget<PopupMenuItem<String>>(
          find.ancestor(
            of: find.text('Send location'),
            matching: find.byType(PopupMenuItem<String>),
          ),
        );
        expect(item.enabled, isFalse);
        expect(find.text('Send GIF'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 300));
      } else {
        final button = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Getting location…'),
            matching: find.byType(IconButton),
          ),
        );
        expect(button.onPressed, isNull);
        await tester.tap(find.byTooltip('Getting location…'));
      }
      expect(platform.lookups, 1);
      pending.complete(_position());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final messages = channel
          ? connector.channelMessages.map((message) => message.text)
          : connector.directMessages.map((message) => message.text);
      expect(messages, hasLength(1));
      expect(
        messages.single,
        startsWith('My location: 45.500000,-122.600000\n'),
      );
      expect(find.text('View on map'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Unsent draft',
      );
      await _capture(tester, '$kind-location-sharing-message');
    });

    for (final entry in {
      'en': ('Send location', 'My location'),
      'es': ('Enviar ubicación', 'Mi ubicación'),
      'fr': ('Envoyer la position', 'Ma position'),
    }.entries) {
      testWidgets('$kind uses the ${entry.key} outgoing location label', (
        tester,
      ) async {
        await _pumpChat(
          tester,
          connector,
          channel: channel,
          language: entry.key,
        );
        await _tapLocation(tester, channel: channel, label: entry.value.$1);
        await tester.pumpAndSettle();
        final text = channel
            ? connector.channelMessages.single.text
            : connector.directMessages.single.text;
        expect(text, startsWith('${entry.value.$2}: '));
        expect(
          text,
          contains('https://meshcore.local/map?lat=45.500000&lon=-122.600000'),
        );
      });
    }

    testWidgets('$kind times out, permits retry, and ignores a late fix', (
      tester,
    ) async {
      final pending = Completer<Position>();
      platform.locate = () => pending.future;
      await _pumpChat(tester, connector, channel: channel);
      await _tapLocation(tester, channel: channel);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text(
          "Couldn't determine this device's location. Check its location settings and try again.",
        ),
        findsOneWidget,
      );
      platform.locate = () async => _position();
      await _tapLocation(tester, channel: channel);
      await tester.pumpAndSettle();
      pending.complete(_position());
      await tester.pumpAndSettle();
      expect(
        channel ? connector.channelMessages : connector.directMessages,
        hasLength(1),
      );
    });

    testWidgets('$kind clears progress on a location error and allows retry', (
      tester,
    ) async {
      platform.locate = () async =>
          throw const PositionUpdateException('unavailable');
      await _pumpChat(tester, connector, channel: channel);
      await _tapLocation(tester, channel: channel);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      platform.locate = () async => _position();
      await _tapLocation(tester, channel: channel);
      await tester.pumpAndSettle();
      expect(
        channel ? connector.channelMessages : connector.directMessages,
        hasLength(1),
      );
    });

    for (final leaveScreen in [false, true]) {
      testWidgets(
        '$kind discards lookup after ${leaveScreen ? 'leaving chat' : 'disconnecting'}',
        (tester) async {
          final pending = Completer<Position>();
          platform.locate = () => pending.future;
          await _pumpChat(tester, connector, channel: channel);
          await _tapLocation(tester, channel: channel);
          if (leaveScreen) {
            await tester.pumpWidget(const SizedBox.shrink());
          } else {
            connector.connected = false;
            connector.notifyListeners();
          }
          pending.complete(_position());
          await tester.pumpAndSettle();
          expect(connector.directMessages, isEmpty);
          expect(connector.channelMessages, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
