import 'dart:async';

import 'package:location/location.dart';
import 'package:latlong/latlong.dart';

import 'package:flutter/material.dart';
import 'package:Nowcasting/main.dart' as main;

Location location = new Location();

LatLng lastKnownLocation;
bool notifyLoc = false;
List<LatLng> places = [LatLng(45.504688, -73.574990)];
List<String> placeNames = ['McGill Downtown Campus'];
List<bool> notify = [false];

bool weatherAlert = false;
bool radarOutage = false;
String radarOutageText = 'The nowcasting service is currently experiencing an outage. This may be due to unscheduled outages in Environment Canada\'s radar system. Tap for more info.';
String alertText = 'Severe weather alert at your location. Tap for more info.';
String radarOutageUrl = 'https://www.canada.ca/en/environment-climate-change/services/weather-general-tools-resources/radar-overview/outages-maintenance.html';
String alertUrl = 'url-not-set';

restorePlaces(BuildContext context) async {
  print('location.restorePlaces: Starting restore process');
  List<String> _loadPlaces;
  List<String> _loadNames;
  List<String> _loadNotify;
  try {
    _loadPlaces = main.prefs.getStringList('places');
    _loadNames = main.prefs.getStringList('placeNames');
    _loadNotify = main.prefs.getStringList('notify');
    notifyLoc = main.prefs.getBool('notifyLoc');

  } catch(e) {
    // If the load failed already because the sharedprefs did not exist yet, just set to defaults
    print('location.restorePlaces[e1]: Arrays did not match in length. Reverting to defaults. Error was '+e.toString());
    places = [LatLng(45.504688, -73.574990)];
    placeNames = ['McGill Downtown Campus'];
    notify = [false];
    notifyLoc = false;
    return;
  }
  List<double> _loadPlacesDouble = [];
  List<LatLng> _loadPlacesLatLng = [];
  List<bool> _loadNotifyBool = [];
  if (_loadPlaces != null && _loadPlaces.isNotEmpty) {
    for (String _s in _loadPlaces) {
      _loadPlacesDouble.add(double.parse(_s));
    }
    for (int i = 0; i < _loadPlaces.length; i+=2) {
      _loadPlacesLatLng.add(LatLng(_loadPlacesDouble[i], _loadPlacesDouble[i+1]));
    }
    places = _loadPlacesLatLng;
  } else {
    places = [];
  }
  placeNames = _loadNames;
  if (_loadNotify != null && _loadNotify.isNotEmpty) {
    for (String _s in _loadNotify) {
      _loadNotifyBool.add(bool.fromEnvironment(_s));
    }
    notify = _loadNotifyBool;
  } else {
    notify = [];
  }
  try {
    assert(places.length == placeNames.length && placeNames.length == notify.length);
  } catch(e) {
    // If the load failed somehow based on the above test, reset to defaults
    print('location.restorePlaces[e2]: Arrays did not match in length. Reverting to defaults. Error was '+e.toString());
    places = [LatLng(45.504688, -73.574990)];
    placeNames = ['McGill Downtown Campus'];
    notify = [false];
    notifyLoc = false;
    return;
  }
  print('location.restorePlaces: Successfully restored locations');
}

savePlaces() async {
  print('update.SavePlaces: Starting save process');
  List<String> _savePlaces = [];
  for (LatLng _place in places) {
    String _lat = _place.latitude.toDouble().toString();
    String _lon = _place.longitude.toDouble().toString();
    _savePlaces.add(_lat);
    _savePlaces.add(_lon);
  }
  main.prefs.setStringList('places', _savePlaces);
  main.prefs.setStringList('placeNames', placeNames);
  List<String> _saveNotify = [];
  for (bool _n in notify) {
    _saveNotify.add(_n.toString());
  }
  main.prefs.setStringList('notify', _saveNotify);
  main.prefs.setBool('notifyLoc', notifyLoc);
}

// Save/restore/update functions for last known location using SharedPreferences.
// This lets us provide a "current location" sliver and map marker
// even when the user has subsequently turned off location services.
restoreLastKnownLocation() async {
  double _loadLat = main.prefs.getDouble('lastKnownLatitude');
  double _loadLon = main.prefs.getDouble('lastKnownLongitude');
  if (_loadLat != null && _loadLon != null) {
    lastKnownLocation = LatLng(_loadLat, _loadLon);
  }
}

saveLastKnownLocation() async {
  try {
    await main.prefs.setDouble('lastKnownLatitude', lastKnownLocation.latitude);
    await main.prefs.setDouble('lastKnownLongitude', lastKnownLocation.longitude);
    return true;
  } catch(e) {
    print('loc.saveLastKnownLocation: Could not update: '+e.toString());
    return false;
  }
}

updateLastKnownLocation({bool withRequests = false}) async {
  try {
    LocationData _newLoc = await getUserLocation(withRequests: withRequests);
    if (_newLoc != null) {
      lastKnownLocation = new LatLng(_newLoc.latitude, _newLoc.longitude);
      await saveLastKnownLocation();
      return true;
    } else {
      print('loc.updateLastKnownLocation: Could not update location, update attempt yielded a null.');
      return false;
    }
  } catch(e) {
    print('loc.updateLastKnownLocation: Could not update location, update attempt yielded an error.');
    return false;
  }
}

Future<bool> checkLocService() async {
  bool _serviceEnabled;
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    return false;
  }
  return true;
}

Future<bool> checkLocPerm() async {
  PermissionStatus _permissionGranted;
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted != PermissionStatus.granted) {
    return false;
  }
  return true;
}

requestLocService() async {
  bool _serviceEnabled;
  _serviceEnabled = await location.requestService();
  if (!_serviceEnabled) {
    print('support-location: Could not enable location service, user rejected prompt');
    return false;
  }
  return true;
}

requestLocPerm() async {
  PermissionStatus _permissionGranted;
  _permissionGranted = await location.requestPermission();
  if (_permissionGranted != PermissionStatus.granted) {
    print('support-location: Could not get location permission, user rejected prompt');
    return false;
  }
  return true;
}

getUserLocation({bool withRequests = false}) async {
  LocationData _locationData;
  Timer timeoutTimer = Timer(Duration(seconds: 5), () {
    print('location.getUserLocation: Didn\'t get location within timeout limit, cancelling update');
    return null;
  });
  if (await checkLocService() == false) {
    if (withRequests) {
      await requestLocService();
    } else {
      return null;
    }
    if (await checkLocService() == false) {
      return null;
    }
  }
  if (await checkLocPerm() == false) {
    if (withRequests) {
      await requestLocPerm();
    } else {
      return null;
    }
    if (await checkLocPerm() == false) {
      return null;
    }
  }
  _locationData = await location.getLocation();
  print('support-location: Successfully got location '+_locationData.toString());
  timeoutTimer.cancel();
  return _locationData;
}