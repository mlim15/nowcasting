import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:user_location/user_location.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/main.dart';

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // Define timer object and speed for later use
  Timer changeImageTimer;
  Duration speed = Duration(milliseconds: 500);
  // Animation controls and current overlay counter
  int _count = 0;
  bool _playing = false;
  Icon _playPauseIcon = Icon(Icons.play_arrow);
  // Key for controlling scaffold (e.g. open drawer)
  GlobalKey<ScaffoldState> _mapScaffoldKey = GlobalKey();
  // flutter_map and user_location variables
  MapController mapController = MapController();
  UserLocationOptions userLocationOptions;
  List<Marker> markers = [];
  TileLayerOptions basemap;
  // Theming management
  @override
  void initState() {
    super.initState();
     WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final Brightness brightness = WidgetsBinding.instance.window.platformBrightness;
    //inform listeners and rebuild widget tree
    setState(() {
      
    });
  }
  // State management functions
  _next() {
    setState(() {
      if (_count < 8)
        _count++;
      else
        _count = 0;
    });
  }
  _previous() {
    setState(() {
      if (_count == 0)
        _count = 8;
      else
        _count--;
    });
  }
  _togglePlaying() {
    setState(() {
      if (_playing) {
        _playing = false;
        _playPauseIcon = Icon(Icons.play_arrow);
        changeImageTimer.cancel();
      } else {
        _playing = true;
        _playPauseIcon = Icon(Icons.pause);
        changeImageTimer = Timer.periodic(speed, (timer) { _next();});
      }
    });
  }
  // Widget overrides
  @override
  Widget build(BuildContext context) {
    userLocationOptions = UserLocationOptions(
      context: context,
      mapController: mapController,
      markers: markers,
      updateMapLocationOnPositionChange: false,
      showMoveToCurrentLocationFloatingActionButton: true,
      zoomToCurrentLocationOnLoad: true,
    );
    var overlayImages = <OverlayImage>[
      OverlayImage(
        bounds: LatLngBounds(
        LatLng(35.0491, -88.7654), LatLng(51.0000, -66.7500)),
        opacity: 0.6,
        imageProvider: FileImage(localFile('forecast.$_count.png')),
        gaplessPlayback: true,
      )];
    if (darkmode(context)) {
      basemap = TileLayerOptions(
        tileProvider: AssetTileProvider(),
        urlTemplate: "assets/jawg-matrix/{z}/{x}/{y}.png",
        maxNativeZoom: 9,
        minNativeZoom: 5,
        maxZoom: 9,
        minZoom: 5,
        backgroundColor: Color(0xFF000000),
      );
    } else {
      basemap = TileLayerOptions(
        //urlTemplate: "http://tiles.meteo.mcgill.ca/tile/{z}/{x}/{y}.png",
        tileProvider: AssetTileProvider(),
        urlTemplate: "assets/jawg-sunny/{z}/{x}/{y}.png",
        maxNativeZoom: 9,
        minNativeZoom: 5,
        maxZoom: 9,
        minZoom: 5,
        keepBuffer: 3,
        tileFadeInDuration: 1,
        backgroundColor: Color(0xFFCCE7FC),
      );
    }
    return Scaffold(
      key: _mapScaffoldKey,
      body: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                center: LatLng(45.5088, -73.5878),
                zoom: 6.0,
                maxZoom: 9,
                minZoom: 5,
                swPanBoundary: LatLng(35.0491, -88.7654),
                nePanBoundary: LatLng(51.0000, -66.7500),
                plugins: [
                  UserLocationPlugin(),
                ],
              ),
              layers: [
                basemap,
                OverlayImageLayerOptions(overlayImages: overlayImages),
                MarkerLayerOptions(markers: markers),
                userLocationOptions,
              ],
              mapController: mapController,
            ),
            SafeArea(child: Image.file(localFile('forecast_legend.$_count.png'), gaplessPlayback: true)),
          ]
      ),
      bottomNavigationBar: BottomAppBar(
          child: Row(
            children: [
              IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () {_mapScaffoldKey.currentState.openDrawer();}
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.navigate_before),
                onPressed: _previous,
              ),
              IconButton(
                icon: _playPauseIcon,
                onPressed: _togglePlaying,
              ),
              IconButton(
                icon: Icon(Icons.navigate_next),
                onPressed: _next,
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {setState(() {if (_playing) {_togglePlaying();} _count = 0; refreshImages(context, false, true);});},
              ),
            ],
          )
      ),
      // TODO Drawer
      drawer: Drawer(
          child: ListView(
            children: <Widget>[
              Container(child: Text("Not implemented yet")),
            ],
          )
      ),
    );
  }
}