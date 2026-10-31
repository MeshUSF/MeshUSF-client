import 'package:flutter/material.dart';

class ContactShareButton extends StatelessWidget {
  final String name;
  final String publicKeyHex;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double textScale;

  const ContactShareButton({
    super.key,
    required this.name,
    required this.publicKeyHex,
    required this.label,
    required this.icon,
    this.onPressed,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prefix = publicKeyHex.length > 8
        ? publicKeyHex.substring(0, 8)
        : publicKeyHex;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
        ),
        icon: Icon(icon),
        onPressed: onPressed,
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12 * textScale),
            ),
            Text(
              prefix,
              maxLines: 1,
              style: TextStyle(fontSize: 12 * textScale),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12 * textScale),
            ),
          ],
        ),
      ),
    );
  }
}
