import 'package:location/location.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/main.dart' as main;

// TODO turning off location services causes message spam and crash
// likely caused by polling from flutter_map plugin
// TODO set current alert/outage data dynamically
// TODO save/load places and names on changes/app open
// TODO adding/removing entries from places/placeNames in forecast interface

Location location = new Location();
bool _serviceEnabled;
PermissionStatus _permissionGranted;
LocationData _locationData;

LatLng lastKnownLocation;
List<LatLng> places = [lastKnownLocation, LatLng(37.5407, -77.4360)];
List<String> placeNames = ['Current Location', 'McGill'];

bool weatherAlert = false;
bool radarOutage = true;
String radarOutageText = 'Some Environment Canada radar sites are currently offline and this may affect update availability. Tap for more info.';
String alertText = 'Severe weather alert at your location. Tap for more info.';
String radarOutageUrl = 'https://www.canada.ca/en/environment-climate-change/services/weather-general-tools-resources/radar-overview/outages-maintenance.html';
String alertUrl = 'https://google.com/not-set';

restorePlaces() async {
  List<String> _loadPlaces = main.prefs.getStringList('places');
  List<String> _loadNames = main.prefs.getStringList('placeNames');
  if (true) {
    List<double> _loadPlacesDouble = [];

  } else {

  }
}

savePlaces() async {
  for (LatLng place in places) {

  }
}

restoreLastKnownLocation() async {
  double _loadLat = main.prefs.getDouble('lastKnownLatitude');
  double _loadLon = main.prefs.getDouble('lastKnownLongitude');
  if (_loadLat != null && _loadLon != null) {
    lastKnownLocation = LatLng(_loadLat, _loadLon);
  } else {
    // set to safe default
    lastKnownLocation = LatLng(45.5088, -73.5878);
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

updateLastKnownLocation() async {
  LocationData _newLoc = await getUserLocation();
  if (_newLoc != null) {
    lastKnownLocation = new LatLng(_newLoc.latitude, _newLoc.longitude);
    saveLastKnownLocation();
  } else {
    throw('loc.updateLastKnownLocation: Could not update location, update attempt yielded a null.');
  }
}

getUserLocation() async {
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      print('support-location: Could not get location, serviceEnabled is '+_serviceEnabled.toString());
      return;
    }
  }
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      print('support-location: Could not get location, permissionGranted is '+_permissionGranted.toString());
      return;
    }
  }
  _locationData = await location.getLocation();
  print('support-location: Successfully got location '+_locationData.toString());
  return _locationData;
}