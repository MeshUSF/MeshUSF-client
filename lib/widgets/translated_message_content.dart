import 'package:flutter/material.dart';

import '../helpers/link_handler.dart';
import '../helpers/location_map_link.dart';
import '../l10n/l10n.dart';

class TranslatedMessageContent extends StatelessWidget {
  final String displayText;
  final String? originalText;
  final TextStyle style;
  final TextStyle? originalStyle;
  final bool showOriginalFirst;
  final VoidCallback? onSecondaryTap;

  const TranslatedMessageContent({
    super.key,
    required this.displayText,
    required this.style,
    this.originalText,
    this.originalStyle,
    this.showOriginalFirst = true,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedDisplay = displayText.trim();
    final trimmedOriginal = originalText?.trim();
    final shouldShowOriginal =
        trimmedOriginal != null &&
        trimmedOriginal.isNotEmpty &&
        trimmedOriginal != trimmedDisplay;
    final displayLocation = LocationMapLink.extract(trimmedDisplay);
    final originalLocation = shouldShowOriginal
        ? LocationMapLink.extract(trimmedOriginal)
        : null;
    final location = displayLocation ?? originalLocation;
    final originalWidget = shouldShowOriginal
        ? LinkHandler.buildLinkifyText(
            context: context,
            text: originalLocation?.textWithoutLink ?? trimmedOriginal,
            style:
                originalStyle ??
                style.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: style.fontSize,
                ),
            onSecondaryTap: onSecondaryTap,
          )
        : null;
    final translatedWidget = LinkHandler.buildLinkifyText(
      context: context,
      text: displayLocation?.textWithoutLink ?? trimmedDisplay,
      style: style,
      onSecondaryTap: onSecondaryTap,
    );

    final Widget messageContent;
    if (!shouldShowOriginal) {
      messageContent = translatedWidget;
    } else {
      final children = showOriginalFirst
          ? [originalWidget!, const SizedBox(height: 6), translatedWidget]
          : [translatedWidget, const SizedBox(height: 6), originalWidget!];
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    if (location == null) return messageContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        messageContent,
        TextButton.icon(
          onPressed: () => LinkHandler.handleLinkTap(context, location.link),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(context.l10n.chat_viewOnMap),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(40, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
