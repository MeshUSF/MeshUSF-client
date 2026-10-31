import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../theme/mesh_theme.dart';

class LocationShareButton extends StatelessWidget {
  final LatLng position;
  final VoidCallback onPressed;
  final double textScale;

  const LocationShareButton({
    super.key,
    required this.position,
    required this.onPressed,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12 * textScale,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: MeshPalette.lightInk,
          side: const BorderSide(color: MeshPalette.lightLine),
        ),
        icon: const Icon(Icons.location_on_outlined, color: Color(0xFFD32F2F)),
        onPressed: onPressed,
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.chat_location,
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}',
              style: style,
            ),
            Text(context.l10n.chat_viewOnMap, style: style),
          ],
        ),
      ),
    );
  }
}
