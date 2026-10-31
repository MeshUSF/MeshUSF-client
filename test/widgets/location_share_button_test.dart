import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshcore_open/helpers/location_map_link.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/widgets/location_share_button.dart';
import 'package:meshcore_open/widgets/translated_message_content.dart';

Future<void> _show(
  WidgetTester tester,
  String text, {
  String? originalText,
  bool originalFirst = true,
  bool dark = true,
  double width = 300,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? MeshTheme.dark() : MeshTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: TranslatedMessageContent(
              displayText: text,
              originalText: originalText,
              showOriginalFirst: originalFirst,
              textScale: scale,
              style: TextStyle(fontSize: 14 * scale),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final link = LocationMapLink.create(45.5, -122.6);

  for (final heading in [
    'My location',
    'Location',
    'Ma position',
    'Mi ubicación',
    'Ubicación',
  ]) {
    testWidgets('renders a historical $heading share as only a card', (
      tester,
    ) async {
      await _show(tester, '$heading: 45.5,-122.6\n$link');
      expect(find.byType(LocationShareButton), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('45.500000, -122.600000'), findsOneWidget);
      expect(find.text('View on map'), findsOneWidget);
      expect(
        find.textContaining('$heading:', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('https://', findRichText: true), findsNothing);
    });
  }

  testWidgets('keeps text around a location share and mismatched headings', (
    tester,
  ) async {
    await _show(
      tester,
      'Meet me here\nMy location: 46.5,-122.6\n$link\nBring water',
    );
    expect(
      find.textContaining('Meet me here', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('My location: 46.5', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Bring water', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(LocationShareButton), findsOneWidget);
  });

  for (final originalFirst in [false, true]) {
    testWidgets(
      'translated shares show one card (original first: $originalFirst)',
      (tester) async {
        await _show(
          tester,
          'Ma position: 45.5,-122.6\n$link',
          originalText: 'My location: 45.5,-122.6\n$link',
          originalFirst: originalFirst,
        );
        expect(find.byType(LocationShareButton), findsOneWidget);
        expect(
          find.textContaining('position:', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining('location:', findRichText: true),
          findsNothing,
        );

        await _show(
          tester,
          'Rendez-vous ici',
          originalText: 'Meet me here\n$link',
          originalFirst: originalFirst,
        );
        expect(
          find.text('Rendez-vous ici', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Meet me here', findRichText: true), findsOneWidget);
        expect(find.byType(LocationShareButton), findsOneWidget);
      },
    );
  }

  testWidgets(
    'retains an original link whose coordinates differ from translation',
    (tester) async {
      final originalLink = LocationMapLink.create(10, 20);
      await _show(tester, link, originalText: originalLink);
      expect(
        find.textContaining(originalLink, findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(LocationShareButton), findsOneWidget);
    },
  );

  testWidgets('unsupported and invalid links remain text', (tester) async {
    const text =
        '45.5,-122.6 https://maps.app.goo.gl/example https://meshcore.local/map?lat=95&lon=0';
    await _show(tester, text);
    expect(find.byType(LocationShareButton), findsNothing);
    expect(find.text(text, findRichText: true), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'uses a white card with a red pin and fits enlarged narrow cards (dark: $dark)',
      (tester) async {
        await _show(
          tester,
          LocationMapLink.create(-89.999999, -179.999999),
          dark: dark,
          width: 210,
          scale: 1.8,
        );
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.style!.backgroundColor!.resolve({}), Colors.white);
        expect(
          button.style!.foregroundColor!.resolve({}),
          MeshPalette.lightInk,
        );
        expect(button.style!.side!.resolve({})!.color, MeshPalette.lightLine);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.location_on_outlined)).color,
          const Color(0xFFD32F2F),
        );
        expect(find.text('-89.999999, -179.999999'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('location card invokes its action only when tapped', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LocationShareButton(
            position: const LatLng(45.5, -122.6),
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(taps, 0);
    await tester.tap(find.text('View on map'));
    expect(taps, 1);
  });
}
