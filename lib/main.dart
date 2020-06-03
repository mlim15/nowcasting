import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:Nowcasting/onboarding.dart';
import 'package:Nowcasting/forecast.dart';
import 'package:Nowcasting/map.dart';
import 'package:Nowcasting/info.dart';

// Variables and objects
Directory appDocPath;
DateTime lastRefresh;
var dio = Dio();
Location location = new Location();
bool _serviceEnabled;
PermissionStatus _permissionGranted;
LocationData _locationData;

// Notifications
final noRefreshSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('No new data to fetch!'));
final refreshedSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Done refreshing.'));
final refreshingSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Refreshing...'));

// File helper functions
File localFile(String fileName) {
  return File(localFilePath(fileName));
}

String localFilePath(String fileName) {
  String pathName = p.join(appDocPath.path, fileName);
  return pathName;
}

// Setting/value saver/loader functions
Future<File> saveLastRefresh(DateTime lastRefresh) async {
  final file = localFile('lastRefresh');
  return file.writeAsString('$lastRefresh');
}

DateTime loadLastRefresh() {
  try {
    final file = localFile('lastRefresh');
    // Read the file.
    String contents = file.readAsStringSync();
    return DateTime.parse(contents);
  } catch (e) {
    // If encountering an error, return arbitrary date that allows for refresh.
    return DateTime(1984, DateTime.january, 1);
  }
}

// File downloading and management
Future downloadFile(String url, String savePath, [int retryCount=0, int maxRetries=0]) async {
  try {
    Response response = await dio.get(
      url,
      //onReceiveProgress: showDownloadProgress,
      //Received data with List<int>
      options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          receiveTimeout: 0),
    );
    print(response.headers);
    File file = File(savePath);
    var raf = file.openSync(mode: FileMode.write);
    // response.data is List<int> type
    raf.writeFromSync(response.data);
    await raf.close();
  } catch (e) {
    // Retry up to the retryLimit after waiting 2 seconds
    if (retryCount < maxRetries) {
      int newRetryCount = retryCount+1;
      print('Failed $url - retrying time $newRetryCount');
      Timer(Duration(seconds: 2), () {downloadFile(url, savePath, newRetryCount, maxRetries);});
    } else {
      // When we have reached max retries just return an error
      throw('Failed to download $url with $maxRetries retries.');
    }
  }
}

refreshImages(BuildContext context, bool forceRefresh, bool showSnack) async {
  int diff;
  // Ensure it's been longer than 10 minutes since last refresh.
  // Unless forceRefresh is true, then bypass this check.
  if (forceRefresh) {
    diff = 11;
  } else {
    lastRefresh = loadLastRefresh();
    diff = DateTime.now().difference(lastRefresh).inMinutes;
  }
  if (diff > 10) {
    // We are refreshing. Show a notification telling the user we are refreshing.
    if (showSnack) {
      Scaffold.of(context).showSnackBar(refreshingSnack);
    }
    // Download all the images using our downloadFile method.
    for (int i = 0; i <= 8; i++) {
      await downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', localFilePath('forecast.$i.png'));
      await downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast_legend.$i.png', localFilePath('forecast_legend.$i.png'));
    }
    // Clear the image cache.
    imageCache.clear();
    // Set the time we last refreshed to now and save the variable to disk.
    lastRefresh = DateTime.now();
    saveLastRefresh(lastRefresh);
    // Show a notification saying we successfully refreshed.
    if (showSnack) {
      Scaffold.of(context).showSnackBar(refreshedSnack);
    }
  } else {
    // We aren't refreshing because it was too soon.
    // Show a notification saying so.
    if (showSnack) {
      Scaffold.of(context).showSnackBar(noRefreshSnack);
    }
  }
}

// Images in memory
safeUpdate() async {
  // Clear the array and reload all the images into it
  // Note that the array is a class-level variable in forecast.dart
  forecasts.clear();
  for (int i = 0; i <= 8; i++) {
    forecasts.add(pngDecoder.decodeImage(localFile('forecast.$i.png').readAsBytesSync()));
  }
}

// Location
getUserLocation() async {
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      return;
    }
  }
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      return;
    }
  }
  _locationData = await location.getLocation();
  print(_locationData);
  return _locationData;
}

// App code
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appDocPath = await getExternalStorageDirectory();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const String _title = 'MAPLE Nowcasting';
  @override
  Widget build(BuildContext context) {
    return MaterialApp (
      title: _title,
      home: Splash(),
      theme: ThemeData(
        primaryColor: Color(0xff0075b3), 
        accentColor: Color(0xff0075b3),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xff0075b3),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark, 
        primaryColor: Color(0xff0075b3),
        accentColor: Color(0xff00a3f9),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          foregroundColor: Colors.white,
          backgroundColor: Color(0xff0075b3),
        ),
      ),
    );
  }
}

class Splash extends StatefulWidget {
  @override
  SplashState createState() => new SplashState();
}

class SplashState extends State<Splash> {
  updateOutdatedImages() async {
    lastRefresh = loadLastRefresh();
    // If it's been an hour since the app was last opened, force a refresh.
    if (DateTime.now().difference(lastRefresh).inMinutes > 60) {
      print('Holding on splash to update outdated images');
      try {
        await refreshImages(context, true, false);
        await safeUpdate();
        print('Done attempting to update images');
      } catch (e) {
        print('Error attempting image update');
      }
      print('proceeding past splash');
      return true;
    }
    print('No need to update images, proceeding past splash');
    return false;
  }
  Future checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool _seen = (prefs.getBool('seen') ?? false);

    if (_seen) {
      // Before going off the load screen, try to refresh outdated images.
      await updateOutdatedImages();
      Navigator.of(context).pushReplacement(
          new MaterialPageRoute(builder: (context) => new AppContents()));
    } else {
      Navigator.of(context).pushReplacement(
          new MaterialPageRoute(builder: (context) => new OnboardingScreen()));
    }
  }

  @override
  void initState() {
    super.initState();
    new Timer(new Duration(milliseconds: 200), () {
      checkFirstSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Center(
        child: new SvgPicture.asset("assets/paaatterns-clarence.svg"),
      ),
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
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ForecastScreen(), // In forecast.dart
          MapScreen(), // In map.dart
          InfoScreen(), // In info.dart
        ],
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