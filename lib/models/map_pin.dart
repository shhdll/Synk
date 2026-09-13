import 'package:flutter/material.dart';

// A single pin position on the Map screen's placeholder canvas.
class MapPin {
  const MapPin({required this.top, required this.left, required this.color});

  final double top;
  final double left;
  final Color color;
}
