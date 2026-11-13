import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
import 'package:meshcore_open/services/map_tile_cache_service.dart';
import 'package:meshcore_open/services/path_history_service.dart';
import 'package:meshcore_open/services/storage_service.dart';
import 'package:meshcore_open/services/translation_service.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/screens/map_screen.dart';
import 'package:meshcore_open/storage/prefs_manager.dart';
import 'package:meshcore_open/widgets/contact_share_button.dart';
import 'package:meshcore_open/widgets/location_share_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ChatSettings extends AppSettingsService {
  @override
  final settings = AppSettings(
    imageMessagesEnabled: false,
    mapShowGuessedLocations: false,
  );
}

class _MapTiles extends ChangeNotifier implements MapTileCacheService {
  @override
  Widget buildTileLayer(BuildContext context, {double opacity = 1}) =>
      const SizedBox.shrink();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatConnector extends MeshCoreConnector {
  bool connected = true;
  final mapContacts = <Contact>[];
  final directMessages = <Message>[];
  final channelMessages = <ChannelMessage>[];
  ChannelMessage? sentReplyTo;

  @override
  bool get isConnected => connected;
  @override
  String get selfName => 'Me';
  @override
  bool get hasGps => false;
  @override
  List<Contact> get allContacts => mapContacts;
  @override
  Future<void> getChannels({int? maxChannels, bool force = false}) async {}
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
    sentReplyTo = replyTo;
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
  bool dark = true,
  Widget? home,
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
        ChangeNotifierProvider<MapTileCacheService>(create: (_) => _MapTiles()),
        ChangeNotifierProvider(
          create: (context) =>
              TranslationService(context.read<AppSettingsService>()),
        ),
      ],
      child: RepaintBoundary(
        key: const ValueKey('location-sharing-screenshot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? MeshTheme.dark() : MeshTheme.light(),
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home:
              home ??
              (channel
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
                    )),
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
  await tester.tap(find.byIcon(Icons.add_circle_outline));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!autoUpdateGoldenFiles) return;
  await expectLater(
    find.byKey(const ValueKey('location-sharing-screenshot')),
    matchesGoldenFile('../../docs/screenshots/$name.png'),
  );
}

Color _highlightPinFill(WidgetTester tester) {
  final layer = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).first;
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byWidget(layer.markers.first.child),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    ),
  );
  return (container.decoration! as BoxDecoration).color!;
}

double _highlightPinScale(WidgetTester tester) {
  final layer = tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).first;
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byWidget(layer.markers.first.child),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.storage[0];
}

Finder _highlightPinCard() => find.byWidgetPredicate(
  (widget) => widget is Card && widget.shape is RoundedRectangleBorder,
);

IconButton _pinColorButton(WidgetTester tester, String label) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(label),
        matching: find.byType(IconButton),
      ),
    );

Future<void> _openPinColorDialog(
  WidgetTester tester, {
  String label = 'Pin color',
}) async {
  final button = find.byTooltip(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _applyPinColor(
  WidgetTester tester,
  String label, {
  String applyLabel = 'Apply',
}) async {
  final choice = find.byTooltip(label);
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, applyLabel));
  await tester.pumpAndSettle();
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    originalPlatform = GeolocatorPlatform.instance;
    platform = _ChatLocationPlatform();
    GeolocatorPlatform.instance = platform;
    connector = _ChatConnector();
  });
  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
    connector.dispose();
  });

  final paletteLabels = {
    'en': [
      'Light red',
      'Orange',
      'Rich red',
      'Yellow',
      'Lime',
      'Green',
      'Teal',
      'Cyan',
      'Blue',
      'Indigo',
      'Purple',
      'Pink',
      'Brown',
      'Gray',
      'Black',
      'Custom',
    ],
    'es': [
      'Rojo claro',
      'Naranja',
      'Rojo intenso',
      'Amarillo',
      'Verde lima',
      'Verde',
      'Verde azulado',
      'Cian',
      'Azul',
      'Índigo',
      'Morado',
      'Rosa',
      'Marrón',
      'Gris',
      'Negro',
      'Personalizado',
    ],
    'fr': [
      'Rouge clair',
      'Orange',
      'Rouge intense',
      'Jaune',
      'Vert citron',
      'Vert',
      'Bleu sarcelle',
      'Cyan',
      'Bleu',
      'Indigo',
      'Violet',
      'Rose',
      'Marron',
      'Gris',
      'Noir',
      'Personnalisé',
    ],
  };

  for (final entry in paletteLabels.entries) {
    for (final dark in [false, true]) {
      testWidgets(
        'pin palette ${entry.key} ${dark ? 'dark' : 'light'} updates the pin and outline',
        (tester) async {
          await _pumpChat(
            tester,
            connector,
            channel: false,
            language: entry.key,
            dark: dark,
            home: const MapScreen(highlightPosition: LatLng(45.5, -122.6)),
          );
          await tester.tap(find.byIcon(Icons.location_on));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(GridView), findsNothing);
          final l10n = lookupAppLocalizations(Locale(entry.key));
          expect(
            tester
                .widget<Text>(find.text(l10n.chat_location))
                .style!
                .fontWeight,
            FontWeight.bold,
          );
          if (entry.key == 'en' && dark) {
            await _capture(tester, 'map-pin-info-card');
          }
          await _openPinColorDialog(tester, label: l10n.map_pinColor);
          expect(find.byType(AlertDialog), findsOneWidget);
          final buttons = find.descendant(
            of: find.byType(GridView),
            matching: find.byType(IconButton),
          );
          expect(buttons, findsNWidgets(16));
          for (final label in entry.value) {
            expect(find.byTooltip(label), findsOneWidget);
          }
          expect(
            tester.widget<IconButton>(buttons.last).tooltip,
            entry.value.last,
          );
          final customPosition = tester.getCenter(
            find.byTooltip(entry.value.last),
          );
          final firstRowY = tester
              .getCenter(find.byTooltip(entry.value.first))
              .dy;
          final secondRowY = tester
              .getCenter(find.byTooltip(entry.value[8]))
              .dy;
          for (final label in entry.value.take(8)) {
            expect(
              tester.getCenter(find.byTooltip(label)).dy,
              closeTo(firstRowY, 0.1),
            );
          }
          for (final label in entry.value.skip(8)) {
            expect(
              tester.getCenter(find.byTooltip(label)).dy,
              closeTo(secondRowY, 0.1),
            );
          }
          final firstRowEnd = tester.getCenter(find.byTooltip(entry.value[7]));
          expect(customPosition.dx, closeTo(firstRowEnd.dx, 0.1));
          expect(customPosition.dy, greaterThan(firstRowEnd.dy));

          final blue = find.byTooltip(entry.value[8]);
          await tester.ensureVisible(blue);
          await tester.pumpAndSettle();
          await tester.tap(blue);
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), MapPalette.pinLightRed);
          expect(_pinColorButton(tester, entry.value[8]).isSelected, isTrue);
          expect(
            tester
                .widgetList<IconButton>(buttons)
                .where((button) => button.isSelected == true),
            hasLength(1),
          );
          await tester.tap(find.widgetWithText(TextButton, l10n.common_cancel));
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), MapPalette.pinLightRed);

          await _openPinColorDialog(tester, label: l10n.map_pinColor);
          await _applyPinColor(
            tester,
            entry.value[8],
            applyLabel: l10n.common_apply,
          );
          expect(_highlightPinFill(tester), Colors.blue);
          final infoCard = tester
              .widgetList<Card>(find.byType(Card))
              .singleWhere((card) => card.shape is RoundedRectangleBorder);
          expect(
            (infoCard.shape! as RoundedRectangleBorder).side.color,
            Colors.blue.withValues(alpha: 0.6),
          );

          await _openPinColorDialog(tester, label: l10n.map_pinColor);
          expect(_pinColorButton(tester, entry.value[8]).isSelected, isTrue);
          if (entry.key == 'en' && dark) {
            await _capture(tester, 'map-pin-colors');
          }

          final custom = find.byTooltip(entry.value.last);
          await tester.ensureVisible(custom);
          await tester.pumpAndSettle();
          await tester.tap(custom);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            ),
            '#3366FF',
          );
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), Colors.blue);
          if (entry.key == 'en' && dark) {
            await _capture(tester, 'map-pin-custom-color');
          }
          await tester.tap(find.widgetWithText(TextButton, l10n.common_cancel));
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), Colors.blue);
          await _openPinColorDialog(tester, label: l10n.map_pinColor);

          final black = find.byTooltip(entry.value[14]);
          await tester.ensureVisible(black);
          await tester.pumpAndSettle();
          await tester.tap(black);
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), Colors.blue);
          final blackCheck = tester.widget<Icon>(
            find.descendant(of: black, matching: find.byIcon(Icons.check)),
          );
          expect(blackCheck.color, Colors.white);
          await tester.tap(
            find.widgetWithText(FilledButton, l10n.common_apply),
          );
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), Colors.black);

          await _openPinColorDialog(tester, label: l10n.map_pinColor);
          final yellow = find.byTooltip(entry.value[3]);
          await tester.ensureVisible(yellow);
          await tester.pumpAndSettle();
          await tester.tap(yellow);
          await tester.pumpAndSettle();
          final yellowCheck = tester.widget<Icon>(
            find.descendant(of: yellow, matching: find.byIcon(Icons.check)),
          );
          expect(yellowCheck.color, Colors.black);
          await tester.tap(
            find.widgetWithText(FilledButton, l10n.common_apply),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.location_on));
          await tester.pumpAndSettle();
          expect(find.byTooltip(l10n.map_pinColor), findsNothing);
          await tester.tap(find.byIcon(Icons.location_on));
          await tester.pumpAndSettle();
          expect(_highlightPinFill(tester), Colors.yellow);
          await _openPinColorDialog(tester, label: l10n.map_pinColor);
          expect(_pinColorButton(tester, entry.value[3]).isSelected, isTrue);
          await tester.tap(find.widgetWithText(TextButton, l10n.common_cancel));
          await tester.pumpAndSettle();
          await tester.drag(find.byType(FlutterMap), const Offset(-40, 30));
          await tester.pumpAndSettle();
          expect(find.byTooltip(l10n.map_pinColor), findsOneWidget);
          expect(_highlightPinFill(tester), Colors.yellow);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('pin card and its contents scale together with fractional zoom', (
    tester,
  ) async {
    const label = 'Command post';
    await _pumpChat(
      tester,
      connector,
      channel: false,
      home: const MapScreen(
        highlightPosition: LatLng(45.5, -122.6),
        highlightLabel: label,
        highlightZoom: 6,
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_location_alt));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();
    final compactSize = tester.getRect(_highlightPinCard()).size;
    final titleSize = tester.getRect(find.text(label)).size;
    final coordinates = find.text('45.500000, -122.600000');
    final coordinatesSize = tester.getRect(coordinates).size;
    final closeSize = tester.getRect(find.byTooltip('Close')).size;
    final colorButtonSize = tester.getRect(find.byTooltip('Pin color')).size;
    await _capture(tester, 'map-pin-card-compact');

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(controller.camera.center, 5.5);
    await tester.pumpAndSettle();
    expect(tester.getRect(_highlightPinCard()).size, compactSize);

    controller.move(controller.camera.center, 12.1);
    await tester.pumpAndSettle();
    final sizeAt12Point1 = tester.getRect(_highlightPinCard()).size;
    expect(sizeAt12Point1.width, greaterThan(compactSize.width));
    expect(sizeAt12Point1.height, greaterThan(compactSize.height));

    controller.move(controller.camera.center, 12.2);
    await tester.pumpAndSettle();
    final sizeAt12Point2 = tester.getRect(_highlightPinCard()).size;
    expect(sizeAt12Point2.width, greaterThan(sizeAt12Point1.width));
    expect(sizeAt12Point2.height, greaterThan(sizeAt12Point1.height));

    controller.move(controller.camera.center, 18);
    await tester.pumpAndSettle();
    final expandedSize = tester.getRect(_highlightPinCard()).size;
    expect(expandedSize.width, greaterThan(sizeAt12Point2.width));
    expect(expandedSize.height, greaterThan(sizeAt12Point2.height));
    final scaleRatio = expandedSize.width / compactSize.width;
    final expandedTitle = tester.getRect(find.text(label)).size;
    final expandedCoordinates = tester.getRect(coordinates).size;
    final expandedClose = tester.getRect(find.byTooltip('Close')).size;
    final expandedColor = tester.getRect(find.byTooltip('Pin color')).size;
    expect(scaleRatio, greaterThan(1));
    expect(
      expandedTitle.height / titleSize.height,
      closeTo(scaleRatio, 0.000001),
    );
    expect(
      expandedCoordinates.height / coordinatesSize.height,
      closeTo(scaleRatio, 0.000001),
    );
    expect(
      expandedClose.width / closeSize.width,
      closeTo(scaleRatio, 0.000001),
    );
    expect(
      expandedClose.height / closeSize.height,
      closeTo(scaleRatio, 0.000001),
    );
    expect(
      expandedColor.width / colorButtonSize.width,
      closeTo(scaleRatio, 0.000001),
    );
    expect(
      expandedColor.height / colorButtonSize.height,
      closeTo(scaleRatio, 0.000001),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(_highlightPinCard(), findsNothing);
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();
    await _capture(tester, 'map-pin-card-expanded');
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'es', 'fr']) {
    testWidgets('compact pin card supports large text in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const label =
          'Command post — secteur nord — rendez-vous et coordination des équipes';
      connector.mapContacts.add(
        Contact(
          publicKey: Uint8List(32),
          name: 'Map fixture',
          type: 1,
          pathLength: -1,
          path: Uint8List(0),
          lastSeen: DateTime.now(),
          latitude: 44,
          longitude: -120,
        ),
      );
      await _pumpChat(
        tester,
        connector,
        channel: false,
        language: language,
        home: const MapScreen(
          highlightPosition: LatLng(45.5, -122.6),
          highlightLabel: label,
          highlightZoom: 6,
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_location_alt));
      await tester.pumpAndSettle();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final camera = controller.camera;
      // Keep this layout test independent of the upcoming edge-placement step.
      controller.move(
        camera.screenOffsetToLatLng(
          Offset(
            camera.nonRotatedSize.width / 2 + 110,
            camera.nonRotatedSize.height / 2 - 40,
          ),
        ),
        6,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.location_on));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(Locale(language));
      final card = _highlightPinCard();
      final cardScrollable = find.descendant(
        of: card,
        matching: find.byType(Scrollable),
      );
      expect(tester.getRect(card).right, lessThanOrEqualTo(360));
      expect(
        MediaQuery.textScalerOf(tester.element(find.text(label))).scale(14),
        28,
      );
      final colorAction = find.byTooltip(l10n.map_pinColor);
      await tester.scrollUntilVisible(
        colorAction,
        40,
        scrollable: cardScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(colorAction);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l10n.common_cancel));
      await tester.pumpAndSettle();
      final closeAction = find.byTooltip(l10n.common_close);
      await tester.scrollUntilVisible(
        closeAction,
        -40,
        scrollable: cardScrollable,
      );
      tester.state<ScrollableState>(cardScrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      if (language == 'en') await _capture(tester, 'map-pin-card-large-en');
      await tester.tap(closeAction);
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pin size follows fractional zoom within one bucket', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      connector,
      channel: false,
      home: const MapScreen(
        highlightPosition: LatLng(45.5, -122.6),
        highlightZoom: 18,
      ),
    );
    expect(_highlightPinScale(tester), closeTo(0.60, 0.000001));

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(controller.camera.center, 12);
    await tester.pumpAndSettle();
    final scaleAt12 = _highlightPinScale(tester);

    controller.move(controller.camera.center, 12.1);
    await tester.pumpAndSettle();
    final scaleAt12Point1 = _highlightPinScale(tester);
    expect(scaleAt12Point1, greaterThan(scaleAt12));

    controller.move(controller.camera.center, 12.2);
    await tester.pumpAndSettle();
    final scaleAt12Point2 = _highlightPinScale(tester);
    expect(scaleAt12Point2, greaterThan(scaleAt12Point1));

    controller.move(const LatLng(45.51, -122.6), 12.2);
    await tester.pumpAndSettle();
    expect(_highlightPinScale(tester), closeTo(scaleAt12Point2, 0.000001));

    controller.move(controller.camera.center, 6);
    await tester.pumpAndSettle();
    final minimumScale = _highlightPinScale(tester);
    controller.move(controller.camera.center, 5.5);
    await tester.pumpAndSettle();
    expect(_highlightPinScale(tester), closeTo(minimumScale, 0.000001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected pin and card hide and return together with zoom', (
    tester,
  ) async {
    await _pumpChat(
      tester,
      connector,
      channel: false,
      home: const MapScreen(highlightPosition: LatLng(45.5, -122.6)),
    );
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();
    await _openPinColorDialog(tester);
    await _applyPinColor(tester, 'Blue');
    expect(find.byTooltip('Pin color'), findsOneWidget);

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    controller.move(controller.camera.center, 5);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.location_on), findsNothing);
    expect(find.byTooltip('Pin color'), findsNothing);

    controller.move(controller.camera.center, 5.5);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.byTooltip('Pin color'), findsOneWidget);
    expect(_highlightPinFill(tester), Colors.blue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separate pin views retain independent colors', (tester) async {
    await _pumpChat(
      tester,
      connector,
      channel: false,
      home: const MapScreen(highlightPosition: LatLng(45.5, -122.6)),
    );
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();
    await _openPinColorDialog(tester);
    await _applyPinColor(tester, 'Blue');

    unawaited(
      Navigator.of(tester.element(find.byType(MapScreen))).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const MapScreen(
            highlightPosition: LatLng(46, -123),
            allowPop: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_highlightPinFill(tester), MapPalette.pinLightRed);
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pumpAndSettle();
    await _openPinColorDialog(tester);
    await _applyPinColor(tester, 'Green');
    expect(_highlightPinFill(tester), Colors.green);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(_highlightPinFill(tester), Colors.blue);
    await _openPinColorDialog(tester);
    expect(_pinColorButton(tester, 'Blue').isSelected, isTrue);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final channel in [false, true]) {
    final kind = channel ? 'channel' : 'direct';

    for (final outgoing in [false, true]) {
      testWidgets(
        '$kind shows contact and location cards with surrounding text (outgoing: $outgoing)',
        (tester) async {
          final text =
              'Meet me here\nMy location: 45.5,-122.6\n'
              'https://meshcore.local/map?lat=45.500000&lon=-122.600000\n'
              '<${'ab' * 32}:1:Alex>\nBring water';
          if (channel) {
            connector.channelMessages.add(
              ChannelMessage(
                senderName: 'Alex',
                text: text,
                timestamp: DateTime(2026, 10, 29),
                isOutgoing: outgoing,
                status: ChannelMessageStatus.sent,
                channelIndex: 1,
              ),
            );
          } else {
            connector.directMessages.add(
              Message(
                senderKey: Uint8List(32),
                text: text,
                timestamp: DateTime(2026, 10, 29),
                isOutgoing: outgoing,
                status: MessageStatus.sent,
              ),
            );
          }
          await _pumpChat(tester, connector, channel: channel);
          expect(find.byType(ContactShareButton), findsOneWidget);
          expect(find.byType(LocationShareButton), findsOneWidget);
          expect(
            find.textContaining('Meet me here', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('Bring water', findRichText: true),
            findsOneWidget,
          );
          expect(
            find.textContaining('My location:', findRichText: true),
            findsNothing,
          );
          expect(
            find.textContaining('https://meshcore.local', findRichText: true),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final link in [
      'https://meshcore.local/map?lat=45.500000&lon=-122.600000',
      'https://maps.google.com/?q=45.5,-122.6',
    ]) {
      testWidgets('$kind opens $link in the internal map and returns to chat', (
        tester,
      ) async {
        if (channel) {
          connector.channelMessages.add(
            ChannelMessage(
              senderName: 'Alex',
              text: link,
              timestamp: DateTime(2026, 10, 29),
              isOutgoing: false,
              status: ChannelMessageStatus.sent,
              channelIndex: 1,
            ),
          );
        } else {
          connector.directMessages.add(
            Message(
              senderKey: Uint8List(32),
              text: link,
              timestamp: DateTime(2026, 10, 29),
              isOutgoing: false,
              status: MessageStatus.sent,
            ),
          );
        }
        await _pumpChat(tester, connector, channel: channel);
        await tester.tap(find.text('View on map'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        final map = tester.widget<MapScreen>(find.byType(MapScreen));
        expect(map.highlightPosition!.latitude, 45.5);
        expect(map.highlightPosition!.longitude, -122.6);
        expect(map.allowPop, isTrue);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.byType(MapScreen), findsNothing);
        expect(find.text('View on map'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$kind shows progress and blocks duplicate location actions', (
      tester,
    ) async {
      final pending = Completer<Position>();
      platform.locate = () => pending.future;
      await _pumpChat(tester, connector, channel: channel);
      await tester.enterText(find.byType(TextField), 'Unsent draft');
      expect(find.byTooltip('Send location'), findsNothing);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('Send location'), findsOneWidget);
      expect(find.text('Share contact'), findsOneWidget);
      await _capture(tester, '$kind-location-sharing-menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await _tapLocation(tester, channel: channel);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(platform.lookups, 1);
      await tester.pump(const Duration(milliseconds: 250));
      await _capture(tester, '$kind-location-sharing-loading');

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
      expect(find.text('Share contact'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
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
      expect(find.text('45.500000, -122.600000'), findsOneWidget);
      expect(find.textContaining('My location:'), findsNothing);
      expect(find.textContaining('https://meshcore.local'), findsNothing);
      if (channel) {
        expect(connector.channelMessages.single.channelIndex, 1);
      } else {
        expect(connector.directMessages.single.senderKey, Uint8List(32));
      }
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

  testWidgets('channel location sharing retains the reply, region and draft', (
    tester,
  ) async {
    final reply = ChannelMessage(
      senderName: 'Alex',
      text: 'Where are you?',
      timestamp: DateTime(2026, 10, 29),
      isOutgoing: false,
      status: ChannelMessageStatus.sent,
      channelIndex: 1,
      region: '#north',
    );
    connector.channelMessages.add(reply);
    await _pumpChat(tester, connector, channel: true);
    await tester.tap(
      find.text('Where are you?', findRichText: true),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsent reply');
    await _tapLocation(tester, channel: true);
    await tester.pumpAndSettle();
    expect(connector.channelMessages.last.region, '#north');
    expect(connector.sentReplyTo, same(reply));
    expect(
      connector.channelMessages.last.text,
      startsWith('@[Alex] My location:'),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Unsent reply',
    );
    expect(find.byTooltip('Cancel reply'), findsOneWidget);
  });
}
