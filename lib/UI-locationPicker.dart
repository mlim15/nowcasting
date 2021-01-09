import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/UI-map.dart' as map;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-io.dart' as io;

class LocationPickerScreen extends StatefulWidget {
  final LatLng _location;
  final String _locName;

  LocationPickerScreen(this._location, this._locName);

  @override
  LocationPickerScreenState createState() => new LocationPickerScreenState(this._location, this._locName);
}

class LocationPickerScreenState extends State<LocationPickerScreen> with WidgetsBindingObserver {
  final LatLng _location;
  final String _locName;

  LocationPickerScreenState(this._location, this._locName);

  MapController _mapController = MapController();
  LatLng _markerLoc = LatLng(0,0);

  _donePressed() {
    Navigator.pop(context, _mapController.center);
  }

  _positionChanged(MapPosition _newPosition, bool _hasGesture) async {
    // TODO this delay is to prevent it from happening while the
    // screen is building. For some reason flutter_map seems
    // to call the onPositionChanged even while the screen is first rendering.
    // This causes an error. Flutter does not provide the ability to
    // check the widget build state outside of debug mode. (this.context.debugDoingBuild)
    // This solution may reduce stress on low end devices and it's
    // nicely animated so it's not all that bad I guess
    await Future.delayed(Duration(milliseconds: 250));
    setState(() {_markerLoc = _newPosition.center;});
  }

  // Dark mode listening
  @override
  void didChangePlatformBrightness() {
    // Trigger rebuild
    setState(() {});
  }

  // Widget definition
  @override
  Widget build(BuildContext context) {
    // Determine whether or not to send coordinates of center
    // anything out of bounds will result in an unmovable map
    MapOptions _mapOptions;
    if (imagery.coordOutOfBounds(_location)) {
      // When out of bounds, simply do not send centerLat/centerLon and the
      // method defaults to McGill.
      _mapOptions = map.getMapOptions(context, positionChanged: _positionChanged);
    } else {
      // Else send them so we can start centered on the current coordinates of the saved location.
      _mapOptions = map.getMapOptions(context, centerLat: _location.latitude, centerLon: _location.longitude, positionChanged: _positionChanged);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(this._locName),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.done),
            onPressed: () {_donePressed();},
          ), 
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: _mapOptions,
            layers: [
              map.getTileLayerOptions(context),
              OverlayImageLayerOptions(
                overlayImages: <OverlayImage>[
                  OverlayImage(
                    bounds: LatLngBounds(
                      imagery.sw, imagery.ne
                    ),
                    opacity: 0.5,
                    imageProvider: io.localFile('forecast.0.png').existsSync() 
                      ? FileImage(io.localFile('forecast.0.png')) 
                      : AssetImage('assets/launcher/logo.png'),
                    gaplessPlayback: true,
                  )
                ]
              ),
              MarkerLayerOptions(
                markers: [
                  // Center of map (follows view to show new selection)
                  Marker(point: _markerLoc, builder: (context) {return ux.locMarker(context, markerColor: ux.alertColor, borderColor: ux.alertColor);}),
                  // Current saved location (if applicable)
                  Marker(point: _location, builder: (context) {return ux.locMarker(context);})
                ],
              ),
            ], // End of layers
          ),
        ]
      ),
    );
  }
}