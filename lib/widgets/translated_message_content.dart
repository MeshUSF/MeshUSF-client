import 'package:flutter/material.dart';

import '../helpers/link_handler.dart';
import '../helpers/location_map_link.dart';
import '../l10n/app_localizations.dart';
import 'location_share_button.dart';

class TranslatedMessageContent extends StatelessWidget {
  final String displayText;
  final String? originalText;
  final TextStyle style;
  final TextStyle? originalStyle;
  final bool showOriginalFirst;
  final VoidCallback? onSecondaryTap;
  final double textScale;

  static final _locationLabels = {
    for (final locale in AppLocalizations.supportedLocales) ...[
      lookupAppLocalizations(locale).chat_myLocation,
      lookupAppLocalizations(locale).chat_location,
    ],
  };

  const TranslatedMessageContent({
    super.key,
    required this.displayText,
    required this.style,
    this.originalText,
    this.originalStyle,
    this.showOriginalFirst = true,
    this.onSecondaryTap,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedDisplay = displayText.trim();
    final trimmedOriginal = originalText?.trim();
    final shouldShowOriginal =
        trimmedOriginal != null &&
        trimmedOriginal.isNotEmpty &&
        trimmedOriginal != trimmedDisplay;
    final displayLocation = LocationMapLink.extract(
      trimmedDisplay,
      locationLabels: _locationLabels,
    );
    final originalLocation = shouldShowOriginal
        ? LocationMapLink.extract(
            trimmedOriginal,
            locationLabels: _locationLabels,
          )
        : null;
    final location = displayLocation ?? originalLocation;
    final displayBody =
        displayLocation?.textWithoutLink.trim() ?? trimmedDisplay;
    final originalBody = originalLocation?.position == location?.position
        ? originalLocation?.textWithoutLink.trim() ?? trimmedOriginal
        : trimmedOriginal;
    final originalWidget =
        shouldShowOriginal &&
            originalBody != null &&
            originalBody.isNotEmpty &&
            originalBody != displayBody
        ? LinkHandler.buildLinkifyText(
            context: context,
            text: originalBody,
            style:
                originalStyle ??
                style.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: style.fontSize,
                ),
            onSecondaryTap: onSecondaryTap,
          )
        : null;
    final translatedWidget = displayBody.isEmpty
        ? null
        : LinkHandler.buildLinkifyText(
            context: context,
            text: displayBody,
            style: style,
            onSecondaryTap: onSecondaryTap,
          );

    final textWidgets =
        (showOriginalFirst
                ? [originalWidget, translatedWidget]
                : [translatedWidget, originalWidget])
            .whereType<Widget>()
            .toList();
    final children = <Widget>[
      for (var i = 0; i < textWidgets.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        textWidgets[i],
      ],
      if (location != null)
        LocationShareButton(
          position: location.position,
          textScale: textScale,
          onPressed: () => LinkHandler.handleLinkTap(context, location.link),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.single;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
