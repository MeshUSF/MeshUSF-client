import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/l10n/app_localizations.dart';
import 'package:meshcore_open/theme/mesh_theme.dart';
import 'package:meshcore_open/widgets/pin_color_dialog.dart';

Future<Completer<Color?>> _pumpDialog(
  WidgetTester tester, {
  Color initialColor = Colors.blue,
  double textScale = 1,
}) async {
  final result = Completer<Color?>();
  await tester.pumpWidget(
    MaterialApp(
      theme: MeshTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result.complete(
                await showDialog<Color>(
                  context: context,
                  builder: (_) => PinColorDialog(initialColor: initialColor),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  return result;
}

Future<void> _chooseCustom(WidgetTester tester) async {
  final choice = find.byTooltip('Custom');
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('custom hex returns the selected RGB color only on Apply', (
    tester,
  ) async {
    final result = await _pumpDialog(tester);
    await _chooseCustom(tester);
    expect(find.byType(Slider), findsNWidgets(3));
    await tester.enterText(find.byType(TextField), '#3366FF');
    await tester.pumpAndSettle();
    expect(result.isCompleted, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(await result.future, const Color(0xFF3366FF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel discards a custom draft', (tester) async {
    final result = await _pumpDialog(tester, initialColor: Colors.orange);
    await _chooseCustom(tester);
    await tester.enterText(find.byType(TextField), '#FF00FF');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(await result.future, isNull);
  });

  testWidgets(
    'invalid hex disables Apply and RGB editing restores a valid value',
    (tester) async {
      final result = await _pumpDialog(
        tester,
        initialColor: const Color(0xFF0000FF),
      );
      await _chooseCustom(tester);
      await tester.enterText(find.byType(TextField), '#12');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      expect(
        find.text('Enter six hexadecimal digits, for example #3366FF.'),
        findsOneWidget,
      );
      final red = find.byType(Slider).first;
      await tester.ensureVisible(red);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(red);
      await tester.tapAt(Offset(bounds.right - 1, bounds.center.dy));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '#FF00FF',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(await result.future, const Color(0xFFFF00FF));
    },
  );

  testWidgets('an existing custom color reopens in its editor', (tester) async {
    const color = Color(0xFF123456);
    final result = await _pumpDialog(tester, initialColor: color);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '#123456',
    );
    expect(find.byType(Slider), findsNWidgets(3));
    final custom = find.ancestor(
      of: find.byTooltip('Custom'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(custom).isSelected, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(await result.future, color);
  });

  testWidgets('choosing a preset clears an invalid custom draft', (
    tester,
  ) async {
    final result = await _pumpDialog(tester);
    await _chooseCustom(tester);
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.pumpAndSettle();
    final richRed = find.byTooltip('Rich red');
    await tester.ensureVisible(richRed);
    await tester.pumpAndSettle();
    await tester.tap(richRed);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(await result.future, MapPalette.pinRichRed);
  });

  testWidgets(
    'two-row palette and custom editor fit a narrow view with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = await _pumpDialog(tester, textScale: 2);
      await _chooseCustom(tester);
      await tester.enterText(find.byType(TextField), '#ABCDEF');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(await result.future, const Color(0xFFABCDEF));
      expect(tester.takeException(), isNull);
    },
  );
}
