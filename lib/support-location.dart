import 'dart:async';

import 'package:location/location.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-io.dart' as io;

Location location = new Location();

LatLng lastKnownLocation;
List<LatLng> places = [LatLng(45.504688, -73.574990)];
List<String> placeNames = ['McGill Downtown Campus'];

bool weatherAlert = false;
bool radarOutage = false;

updateLastKnownLocation({bool withRequests = false}) async {
  try {
    LocationData _newLoc = await getUserLocation(withRequests: withRequests);
    if (_newLoc != null) {
      lastKnownLocation = new LatLng(_newLoc.latitude, _newLoc.longitude);
      await io.saveLastKnownLocation();
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