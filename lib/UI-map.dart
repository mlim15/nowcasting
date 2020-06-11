import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:user_location/user_location.dart';
import 'package:latlong/latlong.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// Key for controlling scaffold (e.g. open drawer)
GlobalKey<ScaffoldState> mapScaffoldKey = GlobalKey();

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // Define timer object and speed for later use
  Timer changeImageTimer;
  Duration speed = Duration(milliseconds: 800);

  // Animation controls and current overlay counter
  int _count = 0;
  bool _playing = false;
  Icon _playPauseIcon = Icon(Icons.play_arrow);

  // flutter_map and user_location variables
  MapController mapController = MapController();
  List<Marker> markers = [];

  // Dark mode listening
  @override
  void didChangePlatformBrightness() {
    // Trigger rebuild
    setState(() {});
  }

  // State management helper functions
  _nextPressed() {
    setState(() {
      if (_count < 8)
        _count++;
      else
        _count = 0;
    });
  }
  _previousPressed() {
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
        changeImageTimer = Timer.periodic(speed, (timer) { _nextPressed();});
      }
    });
  }
  _refreshPressed() async {
    if (await update.remoteImagery(context, false, true)) {
      await update.legends();
      await loc.getUserLocation();
      setState( () {
        if (_playing) {
          _togglePlaying();
        }
        _count = 0;
        imageCache.clear();
        imageCache.clearLiveImages();
      });
      await update.forecasts();
    }
  }

  // Widget definition
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mapScaffoldKey,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: LatLng(45.5088, -73.5878),
              zoom: 6.0,
              maxZoom: ux.retinaMode(context) ? 8.4 : 9, // Dynamically determined because retina mode doesn't work with overzooming+limited native z, requires lower threshold
              minZoom: 5,
              swPanBoundary: imagery.sw,
              nePanBoundary: imagery.ne,
              plugins: [
                UserLocationPlugin(),
              ],
            ),
            layers: [
              TileLayerOptions(
                tileProvider: AssetTileProvider(),
                urlTemplate: ux.darkMode(context) ? "assets/jawg-matrix/{z}/{x}/{y}.png" : "assets/jawg-sunny/{z}/{x}/{y}.png",
                minNativeZoom: 5,
                maxNativeZoom: 9,
                backgroundColor: ux.darkMode(context) ? Color(0xFF000000) : Color(0xFFCCE7FC),
                overrideTilesWhenUrlChanges: true, 
                tileFadeInDuration: 0, 
                tileFadeInStartWhenOverride: 1.0,
                retinaMode: ux.retinaMode(context), // Set retinamode based on device DPI
              ),
              OverlayImageLayerOptions(overlayImages: <OverlayImage>[
                OverlayImage(
                  bounds: LatLngBounds(
                    imagery.sw, imagery.ne
                  ),
                  opacity: 0.6,
                  imageProvider: io.localFile('forecast.$_count.png').existsSync() ? MemoryImage(io.localFile('forecast.$_count.png').readAsBytesSync()) : AssetImage('assets/launcher/logo.png'),
                  gaplessPlayback: true,
                )
              ]),
              MarkerLayerOptions(
                markers: markers
              ),
              UserLocationOptions(
                context: context,
                mapController: mapController,
                markers: markers,
                updateMapLocationOnPositionChange: false,
                showMoveToCurrentLocationFloatingActionButton: true,
                zoomToCurrentLocationOnLoad: true,
                moveToCurrentLocationFloatingActionButton: Container(
                  decoration: BoxDecoration(
                  color: Theme.of(context).floatingActionButtonTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black54.withOpacity(0.4), blurRadius: 7.0, offset: const Offset(1, 2.5),)
                    ]),
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).floatingActionButtonTheme.foregroundColor,
                  ),
                )
              )
            ], // End of layers
          ),
          Container (
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: EdgeInsets.all(12), 
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).canvasColor,
                boxShadow: [
                  BoxShadow(color: Colors.black54.withOpacity(0.4), blurRadius: 7.0, offset: const Offset(1, 2.5),)
                ],
              ),
              child: CircularPercentIndicator(
                animationDuration: speed.inMilliseconds,
                restartAnimation: false,
                animation: true,
                animateFromLastPercent: true,
                radius: 56.0,
                lineWidth: 4.0,
                circularStrokeCap: CircularStrokeCap.round,
                percent: _count/8,
                center: imagery.legends.length == 9 ? Text(imagery.legends[_count].substring(imagery.legends[_count].length-12,imagery.legends[_count].length-7), style: GoogleFonts.lato(fontWeight: FontWeight.w600)) : Text("...", style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
                progressColor: Theme.of(context).accentColor,
                backgroundColor: Theme.of(context).backgroundColor,
              )
            ),
          )
        ]
      ),
      bottomNavigationBar: BottomAppBar(
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {mapScaffoldKey.currentState.openDrawer();}
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.navigate_before),
                onPressed: _previousPressed,
              ),
              IconButton(
                icon: _playPauseIcon,
                onPressed: _togglePlaying,
              ),
              IconButton(
                icon: Icon(Icons.navigate_next),
                onPressed: _nextPressed,
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {_refreshPressed();},
              ),
            ],
          )
      ),
      // TODO Rest of drawer: speed and opacity settings, possibly other layers e.g. barbs and composite, make proper legend with hex colors in support-imagery
      drawer: Drawer(
          child: ListView(
            children: <Widget>[
              Align(
                alignment: Alignment(0,0), 
                child: Column(
                  children: [
                    Image.asset('assets/pal_prec_nowcasting.png'),
                    Text(''),
                    Icon(Icons.warning), 
                    Text("Under Construction")
                  ]
                )
              ),
            ],
          )
      ),
    );
  }
}