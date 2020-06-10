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
final l4dec = 4278210560;
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
// snow 2 and 3 don't seem to be actually in imagery
final t1hex = Color(0xFF37F0C8);
final t1dec = 4291358775;  
final t2hex = Color(0xFF00A58C);
final t2dec = 4287407360; 
final t3hex = Color(0xFF287D8C);
final t3dec = 4287397160; 
final t4hex = Color(0xFF4B5A6E);
final t4dec = 4285422155; 
final t5hex = Color(0xFFFFC382);
final t5dec = 4286759935; 
final s1hex = Color(0xFFCEFFFF);
final s1dec = 4294967246; 
final s4hex = Color(0xFF86D9FF);
final s4dec = 4294957446; 
final s5hex = Color(0xFF6DC1FF);
final s5dec = 4294951277; 
final s6hex = Color(0xFF4196FF);
final s6dec = 4294940225; 
final s7hex = Color(0xFF2050FF);
final s7dec = 4294922272; 
final s8hex = Color(0xFF040ED8);
final s8dec = 4292349444; 
final s9hex = Color(0xFFFF9898);
final s9dec = 4288190719; 

final colorsDec = [l1dec, l2dec, l3dec, l4dec, l5dec, l6dec, l7dec, l8dec, l9dec, l10dec, l11dec, l12dec, t1dec, t2dec, t3dec, t4dec, t5dec, s1dec, s4dec, s5dec, s6dec, s7dec, s8dec, s9dec];
final descriptors = ["Light Drizzle", "Drizzle", "Light Rain", "Light Rain", "Rain", "Rain", "Heavy Rain", "Heavy Rain", "Storm", "Storm", "Violent Storm", "Hailstorm", "Light Sleet", "Light Sleet", "Sleet", "Sleet", "Heavy Sleet", "Gentle Snow", "Light Snow", "Snow", "Heavy Snow", "Heavy Snow", "Snowstorm", "Wet Snowstorm"];

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