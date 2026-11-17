import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapPin {
  final String id;
  final LatLng position;
  String label;
  Color color;

  MapPin({
    required this.id,
    required this.position,
    required this.label,
    required this.color,
  });
}
