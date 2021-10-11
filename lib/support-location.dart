import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:location/location.dart';
import 'package:latlong/latlong.dart';

import 'package:nowcasting/support-io.dart' as io;
import 'package:nowcasting/support-imagery.dart' as imagery;

// Location object used by library
Location location = new Location();

// Storage objects for our locations
//List<nowcastingLocation> allLocations = <nowcastingLocation>[currentLocation] + savedPlaces;
CurrentLocation currentLocation = CurrentLocation();
List<SavedLocation> savedPlaces = [
  SavedLocation(
      name: "McGill Downtown Campus",
      coordinates: LatLng(45.504688, -73.574990),
      notify: false)
];
// Bools used to store whether or not things are happening
bool weatherAlert = false;
bool radarOutage = false;

// Locations class definitions
class nowcastingLocation {
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
    try {
      if (this.coordinates == null) {
        throw ('location.nowcastingLocation.updatePixelCoordinates: Cannot update, coordinates are null');
      }
      double lat = this.coordinates.latitude;
      double lon = this.coordinates.longitude;
      if (imagery.coordOutOfBounds(LatLng(lat, lon))) {
        throw ('location.nowcastingLocation.updatePixelCoordinates: Cannot update, coordinates are out of bounds');
      }
      // If not, then calculate the pixel.
      int mapWidth = imagery.dimensions;
      int mapHeight = imagery.dimensions;

      var mapLonLeft = imagery.sw.longitude;
      var mapLonRight = imagery.ne.longitude;
      var mapLonDelta = mapLonRight - mapLonLeft;

      var mapLatBottom = imagery.sw.latitude;
      var mapLatBottomDegree = mapLatBottom * pi / 180;

      int x = ((lon - mapLonLeft) * (mapWidth / mapLonDelta)).toInt();
      lat = lat * pi / 180;
      var worldMapWidth = ((mapWidth / mapLonDelta) * 360) / (2 * pi);
      var mapOffsetY = (worldMapWidth /
          2 *
          log((1 + sin(mapLatBottomDegree)) / (1 - sin(mapLatBottomDegree))));
      int y = mapHeight -
          ((worldMapWidth / 2 * log((1 + sin(lat)) / (1 - sin(lat)))) -
                  mapOffsetY)
              .toInt();

      this.pixelCoordinates = [x, y];
      return;
    } catch (e) {
      print(e);
      return;
    }
  }
}

class SavedLocation extends nowcastingLocation {
  SavedLocation(
      {@required String name,
      @required LatLng coordinates,
      @required bool notify}) {
    super.name = name;
    super.coordinates = coordinates;
    super.notify = notify;
    super.lastNotified = DateTime.fromMicrosecondsSinceEpoch(0);
  }

  // Constructor to load from JSON
  SavedLocation.fromJson(Map<String, dynamic> json) {
    super.name = json['name'];
    super.coordinates =
        (json['latitude'] != null) && (json['longitude'] != null)
            ? LatLng(
                double.parse(json['latitude']), double.parse(json['longitude']))
            : null;
    super.notify = json['notify'];
    super.lastNotified = DateTime.parse(json['lastNotified']);
  }

  // Export as JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude':
            coordinates != null ? coordinates.latitude.toString() : null,
        'longitude':
            coordinates != null ? coordinates.longitude.toString() : null,
        'notify': notify,
        'lastNotified': lastNotified.toIso8601String(),
      };
}

class CurrentLocation extends nowcastingLocation {
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
    super.coordinates =
        (json['latitude'] != null) && (json['longitude'] != null)
            ? LatLng(
                double.parse(json['latitude']), double.parse(json['longitude']))
            : null;
    super.notify = json['notify'];
    super.lastNotified = DateTime.parse(json['lastNotified']);
    this.lastUpdated = DateTime.parse(json['lastUpdated']);
  }

  // Export as JSON
  Map<String, dynamic> toJson() => {
        'latitude': this.coordinates != null
            ? this.coordinates.latitude.toString()
            : null,
        'longitude': this.coordinates != null
            ? this.coordinates.longitude.toString()
            : null,
        'notify': this.notify,
        'lastNotified': this.lastNotified.toIso8601String(),
        'lastUpdated': this.lastUpdated.toIso8601String()
      };

  update({bool withRequests = false}) async {
    try {
      LocationData _newLoc = await _getUserLocation(withRequests: withRequests);
      if (_newLoc != null) {
        super.coordinates = new LatLng(_newLoc.latitude, _newLoc.longitude);
        this.lastUpdated = DateTime.now();
        await io.savePlaceData();
        return true;
      } else {
        print(
            'loc.updateLastKnownLocation: Could not update location, update attempt yielded a null.');
        return false;
      }
    } catch (e) {
      print(
          'loc.updateLastKnownLocation: Could not update location, update attempt yielded an error.');
      return false;
    }
  }

  // Private helper method for location updating
  _getUserLocation({bool withRequests = false}) async {
    LocationData _locationData;
    if (await location.serviceEnabled() == false) {
      if (withRequests) {
        await location.requestService();
      } else {
        return null;
      }
    }
    if (await location.hasPermission() == PermissionStatus.denied) {
      if (withRequests) {
        await location.requestPermission();
      } else {
        return null;
      }
    }
    try {
      _locationData = await location.getLocation();
      print(
          'location.CurrentLocation._getUserLocation: Successfully got location ' +
              _locationData.toString());
      return _locationData;
    } catch (e) {
      print(
          'location.CurrentLocation._getUserLocation: Could not get location due to service or permission error: ' +
              e.toString());
    }
  }
}
