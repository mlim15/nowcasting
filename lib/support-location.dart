import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';

Position locationData;
Geolocator geolocator = Geolocator();
List<LatLng> places = [***REMOVED***, LatLng(37.5407, -77.4360), ***REMOVED***, ***REMOVED***];

//TODO Does not request permission on first access

// Location
getUserLocation() async {
  GeolocationStatus geolocationStatus  = await geolocator.checkGeolocationPermissionStatus();
  if (geolocationStatus != GeolocationStatus.granted) {
    print('support-location: Could not get location, geolocationStatus is '+geolocationStatus.toString());
    return;
  }
  Position locationData = await geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  print('support-location: Successfully got location '+locationData.toString());
  return locationData;
}