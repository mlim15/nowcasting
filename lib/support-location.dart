import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:location/location.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-io.dart' as io;

// Location object used by library
Location location = new Location();

// Storage objects for our locations
CurrentLocation currentLocation = CurrentLocation();
List<SavedLocation> savedPlaces = [SavedLocation(name: "McGill Downtown Campus", coordinates: LatLng(45.504688, -73.574990), notify: false)];
// Bools used to store whether or not things are happening
bool weatherAlert = false;
bool radarOutage = false;

// Locations class definitions
class NowcastingLocation {
  String name;
  LatLng coordinates;
  bool notify;
  DateTime lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);
}

class SavedLocation extends NowcastingLocation {
  String name;
  LatLng coordinates;
  bool notify;
  DateTime lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);

  // Default constructor
  SavedLocation({@required this.name, @required this.coordinates, @required this.notify});

  String toString() {
    return name;
  }

  // Constructor to load from JSON
  SavedLocation.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        coordinates = LatLng(double.parse(json['latitude']), double.parse(json['longitude'])),
        notify = (json['notify'] == "true"),
        lastNotified = DateTime.parse(json['lastNotified']);

  // Export as JSON
  Map<String, dynamic> toJson() =>
    {
      'name': name,
      'latitude': coordinates.latitude.toString(),
      'longitude': coordinates.longitude.toString(),
      'notify' : notify.toString(),
      'lastNotified' : lastNotified.toIso8601String()
    };
}

class CurrentLocation extends NowcastingLocation {
  String name = "Current Location";
  LatLng coordinates;
  bool notify = false;
  DateTime lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);

  // Default constructor
  CurrentLocation();

  // Constructor to load from JSON
  CurrentLocation.fromJson(Map<String, dynamic> json)
      : name = "Current Location",
        coordinates = LatLng(double.parse(json['latitude']), double.parse(json['longitude'])),
        notify = (json['notify'] == "true"),
        lastNotified = DateTime.parse(json['lastNotified']);

  // Export as JSON
  Map<String, dynamic> toJson() =>
    {
      'latitude': coordinates.latitude.toString(),
      'longitude': coordinates.longitude.toString(),
      'notify' : notify.toString(),
      'lastNotified' : lastNotified.toIso8601String()
    };

  update({bool withRequests = false}) async {
    try {
      LocationData _newLoc = await getUserLocation(withRequests: withRequests);
      if (_newLoc != null) {
        this.coordinates = new LatLng(_newLoc.latitude, _newLoc.longitude);
        await io.savePlaceData();
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

}

// Location plugin service related things
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