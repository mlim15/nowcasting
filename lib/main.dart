import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:user_location/user_location.dart';
import 'package:latlong/latlong.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const String _title = 'Storm Seer';
  @override
  Widget build(BuildContext context) {
    return MaterialApp (
      title: _title,
      home: const AppContents(),
    );
  }
}

class AppContents extends StatefulWidget {
  const AppContents({Key key}) : super(key: key);

  @override
  AppState createState() => AppState();
}

class AppState extends State<AppContents> {
  int _selectedIndex = 0;
  static List<Widget> _widgetOptions = <Widget>[
    ForecastScreen(),
    MapScreen(),
    InfoScreen(),
  ];
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.wb_sunny),
              title: Text('Forecast'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map),
              title: Text('Map'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info),
              title: Text('About'),
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blueAccent[800],
          onTap: _onItemTapped,
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  Timer timer;
  MapController mapController = MapController();
  UserLocationOptions userLocationOptions;
  List<Marker> markers = [];
  int _count = 0;
  bool _playing = true;
  Icon _playPauseIcon = Icon(Icons.pause);
  next() {
    setState(() {
      if (_count < 8)
        _count++;
      else
        _count = 0;
    });
  }
  previous() {
    setState(() {
      if (_count >= 0)
        _count = 8;
      else
        _count--;
    });
  }
  togglePlaying() {
    setState(() {
      if (_playing) {
        _playing = false;
        _playPauseIcon = Icon(Icons.play_arrow);
      } else {
        _playing = true;
        _playPauseIcon = Icon(Icons.pause);
      }
    });
  }
  locate() {

  }
  @override
  Widget build(BuildContext context) {
    userLocationOptions = UserLocationOptions(
      context: context,
      mapController: mapController,
      markers: markers,
      updateMapLocationOnPositionChange: false,
      fabRight: 100,
      showMoveToCurrentLocationFloatingActionButton: true,
      zoomToCurrentLocationOnLoad: true,
    );
    var overlayImages = <OverlayImage>[
      OverlayImage(
          bounds: LatLngBounds(
              LatLng(35.0491, -88.7654), LatLng(51.0000, -66.7500)),
          opacity: 0.6,
          imageProvider: NetworkImage(
              'https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.${_count}.png')),
    ];
    return Scaffold(
        body: Scaffold(
          body: FlutterMap(
            options: MapOptions(
              center: LatLng(45.5088, -73.5878),
              zoom: 6.0,
              maxZoom: 12,
              minZoom: 4,
              swPanBoundary: LatLng(35.0491, -88.7654),
              nePanBoundary: LatLng(51.0000, -66.7500),
              plugins: [
                // ADD THIS
                UserLocationPlugin(),
              ],
            ),
            layers: [
              TileLayerOptions(
                urlTemplate: "http://tiles.meteo.mcgill.ca/tile/{z}/{x}/{y}.png",
                maxZoom: 12,
              ),
              OverlayImageLayerOptions(overlayImages: overlayImages),
              MarkerLayerOptions(markers: markers),
              userLocationOptions,
            ],
            mapController: mapController,
          ),
          floatingActionButton: userLocationOptions.moveToCurrentLocationFloatingActionButton,
        ),
        bottomNavigationBar: BottomAppBar(
          child: new ButtonBar(
              children: <Widget>[
                RaisedButton(
                  child: Icon(Icons.navigate_before),
                  color: Colors.blueAccent,
                  onPressed: previous(),
                ),
                RaisedButton(
                  child: _playPauseIcon,
                  color: Colors.blueAccent,
                  onPressed: togglePlaying(),
                ),
                RaisedButton(
                  child: Icon(Icons.navigate_next),
                  color: Colors.blueAccent,
                  onPressed: next(),
                ),
              ],
            )
        ),
      drawer: Drawer(
        child: ListView(

        )
      ),
    );
  }
}

class ForecastScreen extends StatelessWidget  {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast'),
      ),
        body: Container(
            child: Text('Forecast')
        )
    );
  }
}

class InfoScreen extends StatelessWidget  {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('About StormSeer'),
        ),
        body: Container(
          child: Text('Information')
        )
    );
  }
}