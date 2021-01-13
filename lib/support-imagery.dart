import 'dart:core';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import 'package:latlong/latlong.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-location.dart' as loc;

// Extensions for manipulating DateTime
extension on DateTime {
  DateTime roundDown([Duration delta = const Duration(minutes: 10)]) {
    return DateTime.fromMillisecondsSinceEpoch(this.millisecondsSinceEpoch - this.millisecondsSinceEpoch % delta.inMilliseconds);
  }

  DateTime roundUp([Duration delta = const Duration(minutes: 10)]) {
    return DateTime.fromMillisecondsSinceEpoch(
        // add the duration then follow the round down procedure
        this.millisecondsSinceEpoch + delta.inMilliseconds - this.millisecondsSinceEpoch % delta.inMilliseconds);
  }
}

class Nowcast {
  DateTime get lastUpdated {
    if (this.file.existsSync()) {
      return this.file.lastModifiedSync();
    } else {
      return null;
    }
  }

  int index;
  File file;
  DateTime legend;
  String shownTime;
  Map<String, dynamic> pixelCache = {};
  update.CompletionStatus status = update.CompletionStatus.inactive;

  Nowcast(int i) {
    this.index = i;
    this.file = io.localFile('forecast.$i.png');
    if (this.file.existsSync()) {
      this.legend = this.file.lastModifiedSync().toUtc().roundUp(Duration(minutes: 10)).add(Duration(minutes: 20 * this.index));
      this.shownTime = DateFormat('kk:mm').format(this.legend);
    }
  }

  // Constructor to load from JSON
  Nowcast.fromJson(Map<String, dynamic> _loadjson) {
    this.index = _loadjson['index'];
    this.file = io.localFile('forecast.${this.index}.png');
    this.pixelCache = json.decode(_loadjson['pixelCache']);
    if (this.file.existsSync()) {
      this.legend = this.file.lastModifiedSync().toUtc().roundUp(Duration(minutes: 10)).add(Duration(minutes: 20 * this.index));
      this.shownTime = DateFormat('kk:mm').format(this.legend);
    }
  }

  // Export as JSON
  Map<String, dynamic> toJson() => {
        'index': index,
        'pixelCache': json.encode(this.pixelCache),
      };

  Future<bool> refresh(bool forced) async {
    this.status = update.CompletionStatus.inProgress;
    try {
      // First check for remote update for the image and download it if necessary.
      if (await updateFile(forced)) {
        // If an update occurred, its legend etc will be updated
        // Its cache will also be cleared, and the image will be evicted
        // from flutter's internal cache to force FileImages with it to reload.
        this.legend = this.file.lastModifiedSync().toUtc().roundUp(Duration(minutes: 10)).add(Duration(minutes: 20 * this.index));
        this.shownTime = DateFormat('kk:mm').format(this.legend);
        this.pixelCache.clear();
        FileImage(this.file).evict();
        this.status = update.CompletionStatus.success;
        return true;
      } else {
        // No update was needed for the image.
        this.status = update.CompletionStatus.unnecessary;
        return false;
      }
    } catch (e) {
      print('imagery.Nowcast.update: Error updating image $index: ' + e.toString());
      this.status = update.CompletionStatus.failure;
      return false;
    }
  }

  Future<bool> updateFile(bool forced) async {
    try {
      if (forced || await update.checkUpdateAvailable('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$index.png', this.file)) {
        await update.downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$index.png', this.file.path);
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
    return true;
  }

  dynamic getCachedValue(_x, _y) {
    if (this.pixelCache.containsKey("$_x,$_y")) {
      return this.pixelCache["$_x,$_y"];
    } else {
      return false;
    }
  }

  void cachePixel(int _x, int _y, String result) {
    if (this.pixelCache.containsKey('$_x,$_y')) {
      return;
    } else {
      this.pixelCache['$_x,$_y'] = result;
    }
  }
}

List<Nowcast> nowcasts = [for (int i = 0; i <= 8; i++) new Nowcast(i)];

// Details relevant to nowcasting imagery products - pixel dimensions
// and geographical bbox
final int dimensions = 1808;
final LatLng sw = LatLng(35.0491, -88.7654);
final LatLng ne = LatLng(51.0000, -66.7500);

// Imagery legend colors in AARRGGBB hex and equivalent hex AABBGGRR -> decimal AABBGGRR form
// Getting a pixel value from a decoded png returns the value in the decimal AABBGGRR form

final l1hex = Color(0xFF00FF00);
final l2hex = Color(0xFF00B400);
final l3hex = Color(0xFF007300);
final l4hex = Color(0xFF005500);
final l5hex = Color(0xFFFFFF00);
final l6hex = Color(0xFFFFB400);
final l7hex = Color(0xFFFF6400);
final l8hex = Color(0xFFC80000);
final l9hex = Color(0xFFFF64FF);
final l10hex = Color(0xFFB400B4);
final l11hex = Color(0xFF640064);
final l12hex = Color(0xFF000000);
// snow 3 doesn't seem to be actually in imagery
final t1hex = Color(0xFF37F0C8);
final t2hex = Color(0xFF00A58C);
final t3hex = Color(0xFF287D8C);
final t4hex = Color(0xFF4B5A6E);
final t5hex = Color(0xFFFFC382);
final s1hex = Color(0xFFCEFFFF);
final s2hex = Color(0xFF9CEEFF);
final s4hex = Color(0xFF86D9FF);
final s5hex = Color(0xFF6DC1FF);
final s6hex = Color(0xFF4196FF);
final s7hex = Color(0xFF2050FF);
final s8hex = Color(0xFF040ED8);
final s9hex = Color(0xFFFF9898);
final String l1str = "FF00FF00";
final String l2str = "FF00B400";
final String l3str = "FF007300";
final String l4str = "FF005000";
final String l5str = "FFFFFF00";
final String l6str = "FFFFB400";
final String l7str = "FFFF6400";
final String l8str = "FFC80000";
final String l9str = "FFFF64FF";
final String l10str = "FFB400B4";
final String l11str = "FF640064";
final String l12str = "FF000000";
final String t1str = "FF37F0C8";
final String t2str = "FF00A58C";
final String t3str = "FF287D8C";
final String t4str = "FF4B5A6E";
final String t5str = "FFFFC382";
final String s1str = "FFCEFFFF";
final String s2str = "FF9CEEFF";
final String s4str = "FF86D9FF";
final String s5str = "FF6DC1FF";
final String s6str = "FF4196FF";
final String s7str = "FF2050FF";
final String s8str = "FF040ED8";
final String s9str = "FFFF9898";

// Arrays storing data about possible values in a pixel from the nowcasting data products.
// Indices match between the arrays for easy conversion between them.
final colorsStr = [l1str, l2str, l3str, l4str, l5str, l6str, l7str, l8str, l9str, l10str, l11str, l12str, t1str, t2str, t3str, t4str, t5str, s1str, s2str, s4str, s5str, s6str, s7str, s8str, s9str];
final colorsObj = [l1hex, l2hex, l3hex, l4hex, l5hex, l6hex, l7hex, l8hex, l9hex, l10hex, l11hex, l12hex, t1hex, t2hex, t3hex, t4hex, t5hex, s1hex, s2hex, s4hex, s5hex, s6hex, s7hex, s8hex, s9hex];
final descriptors = ["Light Drizzle", "Drizzle", "Light Rain", "Light Rain", "Rain", "Rain", "Heavy Rain", "Heavy Rain", "Storm", "Storm", "Violent Storm", "Hailstorm", "Light Sleet", "Light Sleet", "Sleet", "Sleet", "Heavy Sleet", "Gentle Snow", "Light Snow", "Light Snow", "Snow", "Snow", "Heavy Snow", "Blizzard", "Wet Blizzard"];
final icons = [MdiIcons.weatherPartlyRainy, MdiIcons.weatherPartlyRainy, MdiIcons.weatherRainy, MdiIcons.weatherRainy, MdiIcons.weatherRainy, MdiIcons.weatherRainy, MdiIcons.weatherPouring, MdiIcons.weatherPouring, MdiIcons.weatherLightningRainy, MdiIcons.weatherLightningRainy, MdiIcons.weatherHail, MdiIcons.weatherPartlySnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherSnowyRainy, MdiIcons.weatherPartlySnowy, MdiIcons.weatherPartlySnowy, MdiIcons.weatherPartlySnowy, MdiIcons.weatherSnowy, MdiIcons.weatherSnowy, MdiIcons.weatherSnowyHeavy, MdiIcons.weatherSnowyHeavy, MdiIcons.weatherSnowyRainy];

final rainStr = [l1str, l2str, l3str, l4str, l5str, l6str, l7str, l8str, l9str, l10str, l11str, l12str];
final transitionStr = [t1str, t2str, t3str, t4str, t5str];
final snowStr = [s1str, s2str, s4str, s5str, s6str, s7str, s8str, s9str];

// Functions that take decimal AABBGGRR values queried from the data products
// and provide the corresponding hex color, icon, or text description
Color hex2color(String _hex) {
  // Assumes 8 character hex.
  return Color(int.parse(_hex, radix: 16));
}

Icon hex2icon(String _hex) {
  int _index = colorsStr.indexWhere((element) => element == _hex);
  if (_index != -1) {
    return Icon(icons[_index], color: Colors.white);
  } else {
    return Icon(Icons.wb_sunny, color: Colors.white);
  }
}

String hex2desc(String _hex) {
  int _index = colorsStr.indexWhere((element) => element == _hex);
  if (_index != -1) {
    return descriptors[_index];
  } else {
    return "None";
  }
}

// Helper functions to resolve relative severity
bool isUnderThreshold(String _pixelColor, int _threshold) {
  if (rainStr.contains(_pixelColor)) {
    if (rainStr.indexOf(_pixelColor) > _threshold-1) {
      return true;
    } else {
      return false;
    }
  }
  if (transitionStr.contains(_pixelColor)) {
    if (transitionStr.indexOf(_pixelColor) > _threshold-1) {
      return true;
    } else {
      return false;
    }
  }
  if (snowStr.contains(_pixelColor)) {
    if (snowStr.indexOf(_pixelColor) > _threshold-1) {
      return true;
    } else {
      return false;
    }
  }
  return false;
}

// Helper functions to get pixel values, convert geographic coordinates to pixel coordinates
List<int> geoToPixel(double lat, double lon) {
    // Check to see if the coordinates are out of bounds.
    if (coordOutOfBounds(LatLng(lat, lon))) {
      throw ('imagery.geoToPixel: Error, passed coordinates were out of bounds');
    }
    // If not, then calculate the pixel.
    int mapWidth = dimensions;
    int mapHeight = dimensions;

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


Future<String> getPixel(Nowcast _nowcast, loc.NowcastingLocation _location) async {
  String _result;
  int _x = _location.pixelCoordinates.first;
  int _y = _location.pixelCoordinates.last;
  // First check to see if the result is in the cache
  // and return that if we can. This is less expensive.
  if (_nowcast.getCachedValue(_x, _y) != false) {
    return _nowcast.getCachedValue(_x, _y);
  }
  // If not then run the platform code to decode the image and
  // retrieve the pixel value.
  try {
    _result = await main.platform.invokeMethod('getPixel', <String, dynamic>{
      "filePath": _nowcast.file.path.toString(),
      "xCoord": _x,
      "yCoord": _y,
    });
    // Cache the result.
    _nowcast.cachePixel(_x, _y, _result);
  } catch (e) {
    print(e);
    return null;
  }
  return _result;
}
