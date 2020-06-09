import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:latlong/latlong.dart';

final LatLng sw = LatLng(35.0491, -88.7654);
final LatLng ne = LatLng(51.0000, -66.7500);
// Imagery legend colors in AARRGGBB hex and equivalent AABBGGRR->raw decimal form
// Get pixel value on decoded png gives the decimal form
final l1hex = Color(0xFF00FF00);
final l1dec = 4278255360;
final l2hex = Color(0xFF00B400); 
final l2dec = 4278236160;
final l3hex = Color(0xFF007300); 
final l3dec = 4278219520;
final l4hex = Color(0xFF005500); 
final l4dec = 4278211840;
final l5hex = Color(0xFFFFFF00); 
final l5dec = 4278255615;
final l6hex = Color(0xFFFFB400); 
final l6dec = 4278236415;
final l7hex = Color(0xFFFF6400); 
final l7dec = 4278215935;
final l8hex = Color(0xFFC80000); 
final l8dec = 4278190280;
final l9hex = Color(0xFFFF64FF); 
final l9dec = 4294927615;
final l10hex = Color(0xFFB400B4); 
final l10dec = 4289986740;
final l11hex = Color(0xFF640064); 
final l11dec = 4284743780;
final l12hex = Color(0xFF000000); 
final l12dec = 4278190080;

List<imglib.Image> forecasts = [];
List<String> legends = [];

// Helper functions
coordinateToPixel(LatLng coordinates) {
  double percEast;
  double percSouth;
  
}

getPixelValue(int x, int y, int index) {
  forecasts[index].getPixel(x, y);
}