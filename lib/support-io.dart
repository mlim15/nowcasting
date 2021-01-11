import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-imagery.dart' as imagery;
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
  loc.savedPlaces = [loc.SavedLocation(name: "McGill Downtown Campus", coordinates: LatLng(45.504688, -73.574990), notify: false)];
}

// Save/restore/update functions for last known location, saved locations, 
// and notification preferences using SharedPreferences.
loadPlaceData() async {
  String _loadCurrentLoc = main.prefs.getString('currentLocation');
  if (_loadCurrentLoc != null) {
    loc.currentLocation = loc.CurrentLocation.fromJson(json.decode(_loadCurrentLoc));
  }
  List<String> _loadPlacesJSON = main.prefs.getStringList('savedLocations');
  if (_loadPlacesJSON != null) {
    loc.savedPlaces = [];
    for (String _json in _loadPlacesJSON) {
      loc.savedPlaces.add(loc.SavedLocation.fromJson(json.decode(_json)));
    }
  }

  print('location.loadPlaceData: Successfully restored locations: '+loc.savedPlaces.toString());
}

savePlaceData() async {
  main.prefs.setString('currentLocation', json.encode(loc.currentLocation));
  List<String> _savedPlacesJSON = [];
  for (loc.SavedLocation _place in loc.savedPlaces) {
    _savedPlacesJSON.add(json.encode(_place.toJson()));
  }
  main.prefs.setStringList('savedLocations', _savedPlacesJSON);
  print('location.loadPlaceData: Successfully saved locations: '+loc.savedPlaces.toString());
}

loadNotificationPreferences() {

  
}

saveNotificationPreferences() {
  //int maxLookahead = 2; // Index 2 is 60 minutes ahead
  //Duration minimumTimeBetweenNotifications = Duration(minutes: 180);
  //int severityThreshold = 2; // First two items of each type (t1, t2, s1, s2, etc) will be ignored

}