import 'package:geolocator/geolocator.dart';

Position locationData;
Geolocator geolocator = Geolocator();

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