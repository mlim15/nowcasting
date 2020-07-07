import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// Key for controlling scaffold (e.g. open drawer)
GlobalKey<ScaffoldState> mapScaffoldKey = GlobalKey();

// API Keys (aren't committed for obvious reasons, if you want to build the app yourself you'll
// need to fill these in with your own)
String lightKey = '**REMOVED**';
String darkKey = '**REMOVED**';

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
  double _nowcastOpacity = 0.6;

  // flutter_map and user_location variables
  MapController mapController = MapController();
  List<Marker> markerList = [Marker(point: loc.lastKnownLocation, builder: ux.locMarker)];

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
    await update.radarOutages();
    if (await update.remoteImagery(context, false, true)) {
      await update.legends();
      setState( () {
        if (_playing) {
          _togglePlaying();
        }
        _count = 0;
        imageCache.clear();
        imageCache.clearLiveImages();
      });
      update.forecasts();
    }
  }
  _locatePressed() async {
    if (await loc.checkLocPerm() == false || await loc.checkLocService() == false) {
      ux.showSnackBarIf(true, ux.locationOffSnack, context, 'map.MapScreenState._locatePressed: Could not update location');
    } else {
      await loc.updateLastKnownLocation(withRequests: true); 
      setState(() {markerList = [Marker(point: loc.lastKnownLocation, builder: ux.locMarker)]; mapController.move(loc.lastKnownLocation, 9);});
    }
  }
  Widget _returnSpacer() {
    return Text('      ');
  }

  Widget _returnDrawerItems() {
    return Align(
      alignment: Alignment(0,0), 
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Column(
          children: [
            // Legend
            Align(alignment: Alignment.center, child: Text("Legend", style: ux.latoWhite.copyWith(fontSize: 16, color: Theme.of(context).textTheme.bodyText1.color))),
            Container(child: Row(children: [Text("Rain", style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color)), Spacer(), Text('Hail', style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color))]), margin: EdgeInsets.all(8),), 
            Row(children: [ 
              for (int _i=0; _i<1; _i++) 
                _returnSpacer(),
              for (Color _color in imagery.colorsHex.sublist(0,12))
                Container(color: _color, child: _returnSpacer())
            ]),
            Container(child: Align(alignment: Alignment.centerLeft, child: Text("Transition", style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color))), margin: EdgeInsets.all(8),),
            Row(children: [ 
              for (int _i=0; _i<1; _i++) 
                _returnSpacer(),
              for (Color _color in imagery.colorsHex.sublist(12,17))
                Container(color: _color, child: _returnSpacer())
            ]),
            Container(child: Row(children: [Text("Snow", style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color)), _returnSpacer(), _returnSpacer(), _returnSpacer(), Text('Wet Snow', style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color))]), margin: EdgeInsets.all(8),),
            Row(children: [ 
              for (Color _color in imagery.colorsHex.sublist(18))
                Container(color: _color, child: _returnSpacer())
            ]),
            Align(alignment: Alignment.center, child: Container(margin: EdgeInsets.only(top: 32, bottom: 16, right: 8, left: 8), child: Text("Overlay Settings", style: ux.latoWhite.copyWith(fontSize: 16, color: Theme.of(context).textTheme.bodyText1.color)))),
            // Speed control
            Container(
              alignment: Alignment.bottomCenter,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Column(children: <Widget>[
                Align(alignment: Alignment.center, child: Text("Animation Speed", style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color))),
                Slider.adaptive(
                  // possibly the dumbest way to implement this but it works.
                  // maybe come back and clean up later without having to hard-code values in.
                  value: speed.inMilliseconds.toInt() == 800
                    ? 4
                    : speed.inMilliseconds.toInt() == 1000
                      ? 3
                      : speed.inMilliseconds.toInt() == 1200
                        ? 2
                        : speed.inMilliseconds.toInt() == 1400
                          ? 1
                          : speed.inMilliseconds.toInt() == 1600
                            ? 0
                            : 0,
                  min: 0,
                  max: 4,
                  divisions: 4,
                  onChanged: (newSpeed) {
                    setState(() {
                      switch(newSpeed.toInt()) {
                        case 0: {speed = Duration(milliseconds: 1600);} break;
                        case 1: {speed = Duration(milliseconds: 1400);} break;
                        case 2: {speed = Duration(milliseconds: 1200);} break;
                        case 3: {speed = Duration(milliseconds: 1000);} break;
                        case 4: {speed = Duration(milliseconds: 800);} break;
                      }
                      if (_playing) {
                        // stop and start so speed change occurs
                        _togglePlaying();_togglePlaying();
                      }
                    });
                  },
                )
              ])
            ),
            // Opacity control
            Container(
              alignment: Alignment.bottomCenter,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Column(children: <Widget>[
                Align(alignment: Alignment.center, child: Text("Nowcast Opacity", style: ux.latoWhite.copyWith(color: Theme.of(context).textTheme.bodyText1.color))),
                Slider.adaptive(
                  value: _nowcastOpacity,
                  min: 0.1,
                  max: 0.9,
                  onChanged: (newOpacity) {
                    setState(() {
                      _nowcastOpacity = newOpacity;
                    });
                  },
                )
              ])
            ),
          ]
        )
      ),
    );
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
            ),
            layers: [
              TileLayerOptions(
                tileProvider: AssetTileProvider(), //CachedNetworkTileProvider(),
                urlTemplate: ux.darkMode(context) 
                  ? "assets/jawg-dark/{z}/{x}/{y}.png" //"https://tile.jawg.io/5c69b784-52bc-408b-8d03-66e426232e15/{z}/{x}/{y}.png?access-token=$darkKey"
                  : "assets/jawg-sunny/{z}/{x}/{y}.png", //"https://tile.jawg.io/jawg-sunny/{z}/{x}/{y}.png?access-token=$lightKey", 
                minNativeZoom: 5,
                maxNativeZoom: 9,
                backgroundColor: ux.darkMode(context) 
                  ? Color(0xFF000000) 
                  : Color(0xFFCCE7FC),
                overrideTilesWhenUrlChanges: true, 
                tileFadeInDuration: 0, 
                tileFadeInStartWhenOverride: 1.0,
                retinaMode: ux.retinaMode(context), // Set retinamode based on device DPI
              ),
              OverlayImageLayerOptions(
                overlayImages: <OverlayImage>[
                  OverlayImage(
                    bounds: LatLngBounds(
                      imagery.sw, imagery.ne
                    ),
                    opacity: _nowcastOpacity,
                    imageProvider: io.localFile('forecast.$_count.png').existsSync() 
                      ? MemoryImage(io.localFile('forecast.$_count.png').readAsBytesSync()) 
                      : AssetImage('assets/launcher/logo.png'),
                    gaplessPlayback: true,
                  )
                ]
              ),
              MarkerLayerOptions(
                markers: markerList,
              ),
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
                  BoxShadow(color: Colors.black54.withOpacity(0.4), blurRadius: 7.0, offset: const Offset(1, 2.5))
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
                center: imagery.legends.length == 9 
                  ? Text(imagery.legends[_count].substring(imagery.legends[_count].length - 12, imagery.legends[_count].length - 7), style: ux.latoWhite.merge(TextStyle(color: Theme.of(context).textTheme.bodyText1.color))) 
                  : Text("...", style: ux.latoWhite),
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
      // TODO possibly other layers e.g. barbs and temperature
      drawer: Platform.isIOS 
        ? SizedBox(
          width: 342, 
          child: Drawer(
            child: ListView(
              children: [_returnDrawerItems()]
            )
          ),
        ) 
        : Drawer(
          child: ListView(
            children: [_returnDrawerItems()]
          )
        ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.my_location),
        onPressed: () {_locatePressed();},
      ),
    );
  }
}