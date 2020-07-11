import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

// Details relevant to nowcasting imagery products - pixel dimensions
// and geographical bbox
final int imageryDimensions = 1808;
final LatLng sw = LatLng(35.0491, -88.7654);
final LatLng ne = LatLng(51.0000, -66.7500);

// Imagery legend colors in AARRGGBB hex and equivalent hex AABBGGRR -> decimal AABBGGRR form
// Getting a pixel value from a decoded png returns the value in the decimal AABBGGRR form
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

// Arrays storing data about possible values in a pixel from the nowcasting data products.
// Indices match between the arrays for easy conversion between them.
final colorsHex = [l1hex, l2hex, l3hex, l4hex, l5hex, l6hex, l7hex, l8hex, l9hex, l10hex, l11hex, l12hex, t1hex, t2hex, t3hex, t4hex, t5hex, s1hex, s4hex, s5hex, s6hex, s7hex, s8hex, s9hex];
final colorsDec = [l1dec, l2dec, l3dec, l4dec, l5dec, l6dec, l7dec, l8dec, l9dec, l10dec, l11dec, l12dec, t1dec, t2dec, t3dec, t4dec, t5dec, s1dec, s4dec, s5dec, s6dec, s7dec, s8dec, s9dec];
final descriptors = ["Light Drizzle", "Drizzle", "Light Rain", "Light Rain", "Rain", "Rain", "Heavy Rain", "Heavy Rain", "Storm", "Storm", "Violent Storm", "Hailstorm", "Light Sleet", "Light Sleet", "Sleet", "Sleet", "Heavy Sleet", "Gentle Snow", "Light Snow", "Snow", "Snow", "Heavy Snow", "Blizzard", "Wet Blizzard"];
final icons = [MdiIcons.weatherPartlyRainy, MdiIcons.weatherPartlyRainy, MdiIcons.weatherRainy, MdiIcons.weatherRainy, MdiIcons.weatherRainy, MdiIcons.weatherRainy, MdiIcons.weatherPouring, MdiIcons.weatherPouring, MdiIcons.weatherLightningRainy, MdiIcons.weatherLightningRainy, MdiIcons.weatherHail, MdiIcons.weatherPartlySnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherPartlySnowy, MdiIcons.weatherPartlySnowy, MdiIcons.weatherSnowy, MdiIcons.weatherSnowy, MdiIcons.weatherSnowyHeavy, MdiIcons.weatherSnowyRainy];

// Arrays storing local products derived from nowcasting data
List<imglib.Image> decodedForecasts = [];
// TODO add separate legends array for forecast screen that is updated only as images are decoded to prevent mismatched legend/data on forecast screen
List<String> legends = [];

// Functions that take decimal AABBGGRR values queried from the data products
// and provide the corresponding hex color, icon, or text description
String dec2desc(int _dec) {
  int _index = colorsDec.indexWhere((element) => element == _dec);
  if (_index == -1) {
    return "None";
  }
  return descriptors[_index];
}

Icon dec2icon(int _dec) {
  int _index = colorsDec.indexWhere((element) => element == _dec);
  if (_index == -1) {
    return Icon(Icons.wb_sunny, color: Colors.white);
  }
  return Icon(icons[_index], color: Colors.white);
}

Color dec2hex(int _dec) {
  // TODO probably not safe. Some checks are in order before doing this and blindly returning it
  String _aabbggrr = _dec.toRadixString(16);
  _aabbggrr = _aabbggrr.padRight(8,'0');
  String _aarrggbb = _aabbggrr.substring(0,2)+_aabbggrr.substring(6,8)+_aabbggrr.substring(4,6)+_aabbggrr.substring(2,4);
  return Color(int.parse(_aarrggbb, radix: 16));
}

// Saving and loading raw decoded AABBGGRR images to/from disk.
// Decompressing and decoding AARRGGBB png to uncompressed AABBGGRR is computationally expensive,
// taking up to a minute on slower devices. This saves loading time and battery when compared
// with decoding the png on every launch, in exchange for eating up what is probably 
// an unreasonable amount of disk space.
saveDecodedForecasts(List<imglib.Image> _decodedForecasts) async {
  for (int i = 0; i <= 8; i++) {
    print('imagery.saveDecodedForecasts: Saving decoded image $i (9 total)');
    File _file = io.localFile('decodedForecast.$i.raw');
    _file.writeAsBytes(_decodedForecasts[i].getBytes());
  }
  print('imagery.saveDecodedForecasts: Finished saving decoded images');
}

loadDecodedForecasts() async {
  List<imglib.Image> _decodedForecasts = [];
  try {
    // First check to make sure none of the local images are newer than the local
    // decoded images. This could happen if the user closes the app while the images are decoding,
    // or while the decoded images are being saved.
    for (int i = 0; i <= 8; i++) {
      DateTime _forecastLastMod = io.localFile('forecast.$i.png').lastModifiedSync();
      DateTime _decodedLastMod = io.localFile('decodedForecast.$i.raw').lastModifiedSync();
      if (_decodedLastMod.isBefore(_forecastLastMod)) {
        throw('imagery.loadDecodedForecasts: locally cached decoded images are outdated compared to local pngs');
      }
    }
    // If none of them are outdated, load them from disk
    for (int i = 0; i <= 8; i++) {
      print('imagery.loadDecodedForecasts: Loading previously decoded image $i (9 total)');
      File _file = io.localFile('decodedForecast.$i.raw');
      _decodedForecasts.add(imglib.Image.fromBytes(imageryDimensions, imageryDimensions, _file.readAsBytesSync()));
    }
    decodedForecasts = _decodedForecasts;
  } catch (e) {
    print('imagery.loadDecodedForecasts: Error loading previously decoded images, triggering full refresh: '+e.toString());
    // If encountering an error, trigger the decoding of the pngs all over again.
    update.forecasts();
    return;
  }
  print('imagery.loadDecodedForecasts: Finished loading previously decoded images');
}

// Helper functions to get pixel values, convert geographic coordinates to pixel coordinates
geoToPixel(double lat, double lon) {
  if (coordOutOfBounds(LatLng(lat, lon))) {
    throw('imagery.geoToPixel: Error, passed coordinates were out of bounds');
  }
  // If not, then calculate the pixel.
  int mapWidth = imageryDimensions;
  int mapHeight = imageryDimensions;

  var mapLonLeft = sw.longitude;
  var mapLonRight = ne.longitude;
  var mapLonDelta = mapLonRight - mapLonLeft;

  var mapLatBottom = sw.latitude;
  var mapLatBottomDegree = mapLatBottom * pi / 180;

  int x = ((lon - mapLonLeft) * (mapWidth / mapLonDelta)).toInt();
  lat = lat * pi / 180;
  var worldMapWidth = ((mapWidth/mapLonDelta)*360)/(2*pi);
  var mapOffsetY = (worldMapWidth / 2 * log((1 + sin(mapLatBottomDegree)) / (1 - sin(mapLatBottomDegree))));
  int y = mapHeight - ((worldMapWidth / 2 * log((1 + sin(lat)) / (1 - sin(lat)))) - mapOffsetY).toInt();
  return [x,y];
}

bool coordOutOfBounds(LatLng coord) {
  // Check to see if the coordinates are out of bounds.
  double eastBound = ne.longitude;
  double westBound = sw.longitude;
  double northBound = ne.latitude;
  double southBound = sw.latitude;
  try {
    if (!(westBound <= coord.longitude && coord.longitude <= eastBound)) {
      throw('imagery.coordinateToPixel: Error, coordinates out of bounds');
    } else if (!(southBound <= coord.latitude && coord.latitude <= northBound)) {
      throw('imagery.coordinateToPixel: Error, coordinates out of bounds');
    }
  } catch(e) {
    return true;
  }
  return false;
}

getPixelValue(int x, int y, int index) {
  return decodedForecasts[index].getPixelSafe(x, y);
}
