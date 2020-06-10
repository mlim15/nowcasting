import 'package:geolocator/geolocator.dart';

Position position;
Geolocator geolocator = Geolocator()..forceAndroidLocationManager = true;

// Location
getUserLocation() async {
  GeolocationStatus geolocationStatus  = await geolocator.checkGeolocationPermissionStatus();
  if (geolocationStatus != GeolocationStatus.granted) {
    print('support-location: Could not get location, geolocationStatus is '+geolocationStatus.toString());
    return;
  }
  Position position = await geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  print('support-location: Successfully got location '+position.toString());
  return position;
}