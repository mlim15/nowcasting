import 'dart:core';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

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
  // Object properties
  int index;
  File file;
  DateTime legend;
  String shownTime;
  Map<String, dynamic> pixelCache = {};
  update.CompletionStatus status = update.CompletionStatus.inactive;
  DateTime get lastUpdated {
    if (this.file.existsSync()) {
      return this.file.lastModifiedSync();
    } else {
      return null;
    }
  }

  // Default constructor
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

  // Public methods
  Future<bool> refresh(bool forced) async {
    this.status = update.CompletionStatus.inProgress;
    try {
      // First check for remote update for the image and download it if necessary.
      if (await _updateFile(forced)) {
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

  dynamic getCachedValue(_x, _y) {
    if (this.pixelCache.containsKey("$_x,$_y")) {
      return this.pixelCache["$_x,$_y"];
    } else {
      return false;
    }
  }

  void setCachedValue(int _x, int _y, String result) {
    if (this.pixelCache.containsKey('$_x,$_y')) {
      return;
    } else {
      this.pixelCache['$_x,$_y'] = result;
    }
  }

  // Private methods
  Future<bool> _updateFile(bool forced) async {
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
}

// Initial instantiations of the object above
List<Nowcast> nowcasts = [for (int i = 0; i <= 8; i++) new Nowcast(i)];

// Details relevant to nowcasting imagery products - pixel dimensions
// and geographical bbox
final int dimensions = 1808;
final LatLng sw = LatLng(35.0491, -88.7654);
final LatLng ne = LatLng(51.0000, -66.7500);

enum PrecipitationType {
  rain,
  transition,
  snow,
  none
}

class PixelValue {
  final Color colorObj;
  final String hexString;
  final String description;
  final IconData iconData;
  final PrecipitationType type;
  final int level;
  // Constructor
  const PixelValue(final this.level, final this.type, final this.colorObj, final this.hexString, final this.description, final this.iconData);
}

// Imagery legend colors in AARRGGBB hex, string, description, icon forms, plus associated basic info
const PixelValue r1 = const PixelValue(1, PrecipitationType.rain, Color(0xFF00FF00), "FF00FF00", "Light Drizzle",MdiIcons.weatherPartlyRainy);
const PixelValue r2 = const PixelValue(2, PrecipitationType.rain, Color(0xFF00B400), "FF00B400", "Drizzle", MdiIcons.weatherPartlyRainy);
const PixelValue r3 = const PixelValue(3, PrecipitationType.rain, Color(0xFF007300), "FF007300", "Light Rain", MdiIcons.weatherRainy);
const PixelValue r4 = const PixelValue(4, PrecipitationType.rain, Color(0xFF005500), "FF005000", "Light Rain", MdiIcons.weatherRainy);
const PixelValue r5 = const PixelValue(5, PrecipitationType.rain, Color(0xFFFFFF00), "FFFFFF00", "Rain", MdiIcons.weatherRainy);
const PixelValue r6 = const PixelValue(6, PrecipitationType.rain, Color(0xFFFFB400), "FFFFB400", "Rain", MdiIcons.weatherRainy);
const PixelValue r7 = const PixelValue(7, PrecipitationType.rain, Color(0xFFFF6400), "FFFF6400", "Heavy Rain", MdiIcons.weatherPouring);
const PixelValue r8 = const PixelValue(8, PrecipitationType.rain, Color(0xFFC80000), "FFC80000", "Heavy Rain", MdiIcons.weatherPouring);
const PixelValue r9 = const PixelValue(9, PrecipitationType.rain, Color(0xFFFF64FF), "FFFF64FF", "Storm", MdiIcons.weatherLightningRainy);
const PixelValue r10 = const PixelValue(10, PrecipitationType.rain, Color(0xFFB400B4), "FFB400B4", "Storm",  MdiIcons.weatherLightningRainy);
const PixelValue r11 = const PixelValue(11, PrecipitationType.rain, Color(0xFF640064), "FF640064", "Violent Storm",  MdiIcons.weatherHail);
const PixelValue r12 = const PixelValue(12, PrecipitationType.rain, Color(0xFF000000), "FF000000", "Hailstorm",  MdiIcons.weatherHail);
const PixelValue t1 = const PixelValue(1, PrecipitationType.transition, Color(0xFF37F0C8), "FF37F0C8", "Light Sleet", MdiIcons.weatherPartlySnowyRainy);
const PixelValue t2 = const PixelValue(2, PrecipitationType.transition, Color(0xFF00A58C), "FF00A58C", "Light Sleet", MdiIcons.weatherPartlySnowyRainy);
const PixelValue t3 = const PixelValue(3, PrecipitationType.transition, Color(0xFF287D8C), "FF287D8C", "Sleet", MdiIcons.weatherSnowyRainy);
const PixelValue t4 = const PixelValue(4, PrecipitationType.transition, Color(0xFF4B5A6E), "FF4B5A6E", "Sleet", MdiIcons.weatherSnowyRainy);
const PixelValue t5 = const PixelValue(5, PrecipitationType.transition, Color(0xFFFFC382), "FFFFC382", "Heavy Sleet", MdiIcons.weatherSnowyRainy);
const PixelValue s1 = const PixelValue(1, PrecipitationType.snow, Color(0xFFCEFFFF), "FFCEFFFF", "Gentle Snow", MdiIcons.weatherPartlySnowy);
const PixelValue s2 = const PixelValue(2, PrecipitationType.snow, Color(0xFF9CEEFF), "FF9CEEFF", "Light Snow", MdiIcons.weatherPartlySnowy);
const PixelValue s4 = const PixelValue(4, PrecipitationType.snow, Color(0xFF86D9FF), "FF86D9FF", "Light Snow", MdiIcons.weatherPartlySnowy);
const PixelValue s5 = const PixelValue(5, PrecipitationType.snow, Color(0xFF6DC1FF), "FF6DC1FF", "Snow", MdiIcons.weatherSnowy);
const PixelValue s6 = const PixelValue(6, PrecipitationType.snow, Color(0xFF4196FF), "FF4196FF", "Snow", MdiIcons.weatherSnowy);
const PixelValue s7 = const PixelValue(7, PrecipitationType.snow, Color(0xFF2050FF), "FF2050FF", "Heavy Snow", MdiIcons.weatherSnowyHeavy);
const PixelValue s8 = const PixelValue(8, PrecipitationType.snow, Color(0xFF040ED8), "FF040ED8", "Blizzard", MdiIcons.weatherSnowyHeavy);
const PixelValue s9 = const PixelValue(9, PrecipitationType.snow, Color(0xFFFF9898), "FFFF9898", "Wet Blizzard", MdiIcons.weatherSnowyRainy);
const PixelValue none = const PixelValue(0, PrecipitationType.none, Color(0x0000FF00), "0000FF00", "None", Icons.wb_sunny);
List<PixelValue> pixelValues = const [r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, t1, t2, t3, t4, t5, s1, s2, s4, s5, s6, s7, s8, s9, none];

List<Color> rainColors = const [const Color(0xFF00FF00), const Color(0xFF00B400), const Color(0xFF007300), const Color(0xFF005500), const Color(0xFFFFFF00), const Color(0xFFFFB400), const Color(0xFFFF6400), const Color(0xFFC80000), const Color(0xFFFF64FF), const Color(0xFFB400B4), const Color(0xFF640064), const Color(0xFF000000)];
List<Color> transitionColors = const [const Color(0xFF37F0C8), const Color(0xFF00A58C), const Color(0xFF287D8C), const Color(0xFF4B5A6E), const Color(0xFFFFC382)];
List<Color> snowColors = const [const Color(0xFFCEFFFF), const Color(0xFF9CEEFF), const Color(0xFF86D9FF), const Color(0xFF6DC1FF), const Color(0xFF4196FF), const Color(0xFF2050FF), const Color(0xFF040ED8), const Color(0xFFFF9898)];

// Convert by taking hex string of AARRGGBB color and
// and provide the corresponding hex color, icon, or text description
Color hex2color(String _hex) {
  // Assumes 8 character hex.
  return Color(int.parse(_hex, radix: 16));
}

Icon hex2icon(String _pixelColor) {
  return Icon(pixelValues.singleWhere((value) {return value.hexString.compareTo(_pixelColor) == 0;}).iconData);
}

String hex2desc(String _pixelColor) {
  return pixelValues.singleWhere((value) {return value.hexString.compareTo(_pixelColor) == 0;}).description;
}

// Helper functions to resolve relative severity
bool isUnderThreshold(String _pixelColor, int _threshold) {
  int _level = pixelValues.singleWhere((value) {return value.hexString.compareTo(_pixelColor) == 0;}).level;
  if (_level < _threshold) {
    return true;
  } else {
    return false;
  }
}

// Helper functions to get pixel values, check bounds
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
    _nowcast.setCachedValue(_x, _y, _result);
  } catch (e) {
    print(e.toString());
    return null;
  }
  return _result;
}
