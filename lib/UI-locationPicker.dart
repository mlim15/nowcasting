import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/UI-map.dart' as map;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-location.dart' as loc;

class LocationPickerScreen extends StatefulWidget {
  final loc.NowcastingLocation location;

  LocationPickerScreen(this.location);

  @override
  LocationPickerScreenState createState() => new LocationPickerScreenState(this.location);
}

class LocationPickerScreenState extends State<LocationPickerScreen> with WidgetsBindingObserver {
  final loc.NowcastingLocation location;

  LocationPickerScreenState(this.location);

  MapController _mapController = MapController();
  LatLng _markerLoc = LatLng(0,0);

  _donePressed() {
    Navigator.pop(context, _mapController.center);
  }

  _positionChanged(MapPosition _newPosition, bool _hasGesture) {
    // Do not set the state unless the position has actually changed from a 
    // possible starting position. This prevents errors due to calling setState
    // during initial building, because onPositionChanged is for some reason 
    // called even during the intial build.
    // https://github.com/fleaflet/flutter_map/issues/56
    // LatLng cannot be tested with == operator (immutable), test longitude instead
    if (imagery.coordOutOfBounds(this.location.coordinates)) {
      // Then default centre coordinates were used when drawing the map.
      // Test against these defaults
      if (_newPosition.center.longitude == -73.574990) {
        return;
      }
    } else if (_newPosition.center.longitude == this.location.coordinates.longitude) {
      // Otherwise test against the saved location to determine if we really moved
      return;
    }
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
    if (imagery.coordOutOfBounds(this.location.coordinates)) {
      // When out of bounds, simply do not send centerLat/centerLon and the
      // method defaults to McGill.
      _mapOptions = map.getMapOptions(context, positionChanged: _positionChanged);
    } else {
      // Else send them so we can start centered on the current coordinates of the saved location.
      _mapOptions = map.getMapOptions(context, centerLat: this.location.coordinates.latitude, centerLon: this.location.coordinates.longitude, positionChanged: _positionChanged);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(this.location.name),
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
                  Marker(point: this.location.coordinates, builder: (context) {return ux.locMarker(context);})
                ],
              ),
            ], // End of layers
          ),
        ]
      ),
    );
  }
}