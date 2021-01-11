import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-notifications.dart' as notifications;
import 'package:Nowcasting/support-location.dart' as loc;

Directory appDocPath;

// Initialization
updateAppDocPath() async {
  appDocPath = await getApplicationSupportDirectory();
}

// File helper functions
File localFile(String fileName) {
  return File(localFilePath(fileName));
}

String localFilePath(String fileName) {
  String pathName = join(appDocPath.path, fileName);
  return pathName;
}

// This functionality is only useful if the app is opened within 10 minutes
// and it has also been killed in the background before the user opens it again,
// or the user has no internet when opening the second time.
// Frankly it's of very limited use, but it will certainly improve the experience
// on very low end devices if the app is frequently opened and closed.
saveForecastCache(int _index) async {
  File _file = localFile('forecast.$_index.cache');
  _file.writeAsStringSync(json.encode(imagery.forecastCache[_index]));
  print('imagery.saveForecastCache: Finished saving decoded values for image $_index');
}

loadForecastCaches() async {
  Map<String, dynamic> _json;
  for (int i = 0; i <= 8; i++) {
    File _file = localFile('forecast.$i.cache');
    if (_file.existsSync()) {
      _json = json.decode(_file.readAsStringSync());
      if(_json != null && _json.isNotEmpty) {
        imagery.forecastCache[i] = _json;
      } 
    }
  }
  print('imagery.loadForecastCache: Finished loading cached image values');
}

restoreDefaultPlaceData([String errorMessage, Error e]) {
  if (errorMessage != null && e != null) {print(errorMessage+' Reverting to defaults. Error was '+e.toString());}
  else if (errorMessage != null) {print(errorMessage+' Reverting to defaults.');}
  loc.places = [LatLng(45.504688, -73.574990)];
  loc.placeNames = ['McGill Downtown Campus'];
  notifications.enabledSavedLoc = [false];
  notifications.enabledCurrentLoc = false;
}

// Save/restore/update functions for last known location, saved locations, 
// and notification preferences using SharedPreferences.
loadPlaceData() async {
  print('location.restorePlaces: Starting restore process');
  List<String> _loadPlaces;
  List<String> _loadNames;
  List<String> _loadNotifySaved;
  bool _loadNotifyCurrentBool;
  try {
    _loadPlaces = main.prefs.getStringList('places');
    _loadNames = main.prefs.getStringList('placeNames');
    _loadNotifySaved = main.prefs.getStringList('notify');
    _loadNotifyCurrentBool = main.prefs.getBool('notifyLoc');
  } catch(e) {
    // If the load failed somehow already, use defaults.
    print('location.restorePlaces: Error loading SharedPreference stored values. Default values from initialization kept.');
    return;
  }
  // Check for nulls first in the retrieved data and just return in that case
  if (_loadPlaces == null || _loadNames == null || _loadNotifySaved == null || _loadNotifyCurrentBool == null) {
    print('location.restorePlaces: Tried to restore but SharedPreferences were null. Default values from initialization kept.');
    return;
  }
  List<double> _loadPlacesDouble = [];
  List<LatLng> _loadPlacesLatLng = [];
  List<bool> _loadNotifySavedBool = [];
  // Load saved place coordinates
  if (_loadPlaces.isNotEmpty) {
    for (String _s in _loadPlaces) {
      _loadPlacesDouble.add(double.parse(_s));
    }
    for (int i = 0; i < _loadPlaces.length; i+=2) {
      _loadPlacesLatLng.add(LatLng(_loadPlacesDouble[i], _loadPlacesDouble[i+1]));
    }
    if (_loadPlacesLatLng != null) {
      loc.places = _loadPlacesLatLng;
    }
  } else {
    loc.places = [];
  }
  // Load place names
  if (_loadNames.isNotEmpty) {
    loc.placeNames = _loadNames;
  } else {
    loc.placeNames = [];
  }
  // Load whether notifications are enabled for each saved location
  if (_loadNotifySaved.isNotEmpty) {
    for (String _s in _loadNotifySaved) {
      bool _parsedBool = false;
      if (_s == "true") {
        _parsedBool = true;
      } 
      _loadNotifySavedBool.add(_parsedBool);
    }
    if (_loadNotifySavedBool != null) {
      notifications.enabledSavedLoc = _loadNotifySavedBool;
    }
  } else {
    notifications.enabledSavedLoc = [];
  }
  // Load whether notifications are enabled for the saved location
  if (_loadNotifyCurrentBool != null) {
    notifications.enabledCurrentLoc = _loadNotifyCurrentBool;
  }
  try {
    // Flutter does not evaluate assertions in profile or release mode.
    if (!(loc.places != null && loc.placeNames != null && notifications.enabledSavedLoc != null)) {
      throw('location.restorePlaces: Loaded arrays generated null results.');
    } else if (!(loc.places.length == loc.placeNames.length && loc.placeNames.length == notifications.enabledSavedLoc.length)) {
      throw('location.restorePlaces: Loaded arrays were not equal in length.');
    } 
  } catch(e) {
    // If the load failed somehow based on the above test, reset to defaults
    restoreDefaultPlaceData('location.restorePlaces: Restored values failed sanity check.', e);
    return;
  }
  print('location.restorePlaces: Successfully restored locations: '+loc.placeNames.toString());
}

savePlaceData() async {
  print('update.SavePlaces: Starting save process');
  List<String> _savePlaces = [];
  for (LatLng _place in loc.places) {
    String _lat = _place.latitude.toDouble().toString();
    String _lon = _place.longitude.toDouble().toString();
    _savePlaces.add(_lat);
    _savePlaces.add(_lon);
  }
  main.prefs.setStringList('places', _savePlaces);
  main.prefs.setStringList('placeNames', loc.placeNames);
  List<String> _saveNotify = [];
  for (bool _n in notifications.enabledSavedLoc) {
    _saveNotify.add(_n.toString());
  }
  main.prefs.setStringList('notify', _saveNotify);
  main.prefs.setBool('notifyLoc', notifications.enabledCurrentLoc);
}

loadLastKnownLocation() async {
  double _loadLat = main.prefs.getDouble('lastKnownLatitude');
  double _loadLon = main.prefs.getDouble('lastKnownLongitude');
  if (_loadLat != null && _loadLon != null) {
    loc.lastKnownLocation = LatLng(_loadLat, _loadLon);
  }
}

saveLastKnownLocation() async {
  // There's no need to call this in most circumstances
  // because loc.updateLastKnownLocation will automatically save it.
  try {
    await main.prefs.setDouble('lastKnownLatitude', loc.lastKnownLocation.latitude);
    await main.prefs.setDouble('lastKnownLongitude', loc.lastKnownLocation.longitude);
    return true;
  } catch(e) {
    print('loc.saveLastKnownLocation: Could not update: '+e.toString());
    return false;
  }
}

loadNotificationPreferences() {
  //DateTime lastShownNotificationCurrentLoc = DateTime.fromMillisecondsSinceEpoch(0);
  //List<DateTime> lastShownNotificationSavedLoc = [DateTime.fromMillisecondsSinceEpoch(0)];
  //int maxLookahead = 2; // Index 2 is 60 minutes ahead
  //Duration minimumTimeBetweenNotifications = Duration(minutes: 180);
  //bool doNotNotifyUnderThreshold = true;
  //int severityThreshold = 2; // First two items of each type (t1, t2, s1, s2, etc) will be ignored
  
}

saveNotificationPreferences() {

}