import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-notifications.dart' as notifications;

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
  print('location.savePlaceData: Successfully saved locations: '+loc.savedPlaces.toString());
}

saveNotificationPreferences() async {
  main.prefs.setBool('notificationsEnabled', notifications.notificationsEnabled);
  main.prefs.setInt('severityThreshold', notifications.severityThreshold);
  main.prefs.setInt('minNotifDelay', notifications.minimumTimeBetween.inMinutes);
  main.prefs.setInt('maxLookahead', notifications.maxLookahead);
  main.prefs.setInt('maxFrequency', notifications.checkIntervalMinutes);
}

loadNotificationPreferences() async {
  bool _loadNotificationsEnabled = main.prefs.getBool('notificationsEnabled');
  if (_loadNotificationsEnabled != null) {
    notifications.notificationsEnabled = _loadNotificationsEnabled;
  }
  int _loadSeverityThreshold = main.prefs.getInt('severityThreshold');
  if (_loadSeverityThreshold != null) {
    notifications.severityThreshold = _loadSeverityThreshold;
  }
  int _loadMinNotifDelay = main.prefs.getInt('minNotifDelay');
  if (_loadMinNotifDelay != null) {
    notifications.minimumTimeBetween = Duration(minutes: _loadMinNotifDelay);
  }
  int _loadMaxLookahead = main.prefs.getInt('maxLookahead');
  if (_loadMaxLookahead != null) {
    notifications.maxLookahead = _loadMaxLookahead;
  }
  int _loadCheckIntervalMinutes = main.prefs.getInt('maxFrequency');
  if (_loadCheckIntervalMinutes != null) {
    notifications.checkIntervalMinutes = _loadCheckIntervalMinutes;
  }
}

loadNowcastData() async {
  List<String> _loadNowcasts = main.prefs.getStringList('nowcastData');
  if (_loadNowcasts != null) {
    imagery.nowcasts = [];
    for (String _json in _loadNowcasts) {
      imagery.nowcasts.add(imagery.Nowcast.fromJson(json.decode(_json)));
    }
  }
  print('location.loadNowcastData: Successfully restored lastUpdated information for image products.');
}

saveNowcastData() async {
  List<String> _saveNowcasts = [];
  for (imagery.Nowcast _nowcast in imagery.nowcasts) {
    _saveNowcasts.add(json.encode(_nowcast.toJson()));
  }
  main.prefs.setStringList('nowcastData', _saveNowcasts);
  print('location.saveNowcastData: Successfully saved lastUpdated information for image products.');
}