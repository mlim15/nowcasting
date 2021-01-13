import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:location/location.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-imagery.dart' as imagery;

// Location object used by library
Location location = new Location();

// Storage objects for our locations
//List<NowcastingLocation> allLocations = <NowcastingLocation>[currentLocation] + savedPlaces;
CurrentLocation currentLocation = CurrentLocation();
List<SavedLocation> savedPlaces = [SavedLocation(name: "McGill Downtown Campus", coordinates: LatLng(45.504688, -73.574990), notify: false)];
// Bools used to store whether or not things are happening
bool weatherAlert = false;
bool radarOutage = false;

// Locations class definitions
class NowcastingLocation {
  String name;
  bool notify;
  DateTime lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);
  LatLng _coordinates;
  List<int> pixelCoordinates;
  set coordinates(LatLng _newValue) {
    this._coordinates = _newValue;
    updatePixelCoordinates();
  }

  LatLng get coordinates {
    return this._coordinates;
  }

  String toString() {
    return this.name;
  }

  void updatePixelCoordinates() {
    if (this.coordinates == null) {
      return;
    }
    List<int> _newPixelCoordinates;
    try {
      _newPixelCoordinates = imagery.geoToPixel(this.coordinates.latitude, this.coordinates.longitude);
    } catch(e) {
      print(e);
      return;
    }
    this.pixelCoordinates = _newPixelCoordinates;
  }

}

class SavedLocation extends NowcastingLocation {
  SavedLocation({@required String name, @required LatLng coordinates, @required bool notify}) {
    super.name = name;
    super.coordinates = coordinates;
    super.notify = notify;
    super.lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);
  }

  // Constructor to load from JSON
  SavedLocation.fromJson(Map<String, dynamic> json) {
    super.name = json['name'];
    super.coordinates = (json['latitude'] != null) && (json['longitude'] != null) ? LatLng(double.parse(json['latitude']), double.parse(json['longitude'])) : null;
    super.notify = json['notify'];
    super.lastNotified = DateTime.parse(json['lastNotified']);
  }

  // Export as JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': coordinates != null ? coordinates.latitude.toString() : null,
        'longitude': coordinates != null ? coordinates.longitude.toString() : null,
        'notify': notify,
        'lastNotified': lastNotified.toIso8601String(),
      };
}

class CurrentLocation extends NowcastingLocation {
  DateTime lastUpdated;

  CurrentLocation() {
    super.name = "Current Location";
    super.coordinates = null;
    super.notify = false;
    super.lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);
    this.lastUpdated = DateTime.fromMicrosecondsSinceEpoch(0);
  }

  CurrentLocation.fromJson(Map<String, dynamic> json) {
    super.name = "Current Location";
    super.coordinates = (json['latitude'] != null) && (json['longitude'] != null) ? LatLng(double.parse(json['latitude']), double.parse(json['longitude'])) : null;
    super.notify = json['notify'];
    super.lastNotified = DateTime.parse(json['lastNotified']);
    this.lastUpdated = DateTime.parse(json['lastUpdated']);
  }

  // Export as JSON
  Map<String, dynamic> toJson() => {
    'latitude': this.coordinates != null ? this.coordinates.latitude.toString() : null, 
    'longitude': this.coordinates != null ? this.coordinates.longitude.toString() : null, 
    'notify': this.notify, 'lastNotified': this.lastNotified.toIso8601String(), 
    'lastUpdated': this.lastUpdated.toIso8601String()
    };

  update({bool withRequests = false}) async {
    try {
      LocationData _newLoc = await getUserLocation(withRequests: withRequests);
      if (_newLoc != null) {
        super.coordinates = new LatLng(_newLoc.latitude, _newLoc.longitude);
        this.lastUpdated = DateTime.now();
        await io.savePlaceData();
        return true;
      } else {
        print('loc.updateLastKnownLocation: Could not update location, update attempt yielded a null.');
        return false;
      }
    } catch (e) {
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
  print('support-location: Successfully got location ' + _locationData.toString());
  timeoutTimer.cancel();
  return _locationData;
}
