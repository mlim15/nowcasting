import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:location/location.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as imglib;
import 'package:intl/intl.dart';

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
String headerFormat = "EEE, dd MMM yyyy HH:mm:ss zzz";

// Notifications
final checkingSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Checking for updates...'));
final noRefreshSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('No new data to fetch!'));
final errorRefreshSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error refreshing.'));
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

// File downloading and management
Future<bool> updateAvailable(String url, File file) async {
  var urlLastModHeader;
  DateTime fileLastModified = (await file.lastModified()).toUtc();
  try {
    Response header = await dio.head(url);
    urlLastModHeader = header.headers.value(HttpHeaders.lastModifiedHeader);
  } catch(e) {
    print('updateAvailable: Failed to get header for $url');
    // return true by default on failure
    return true;
  }
  DateTime urlLastModified = DateFormat(headerFormat).parse(urlLastModHeader, true);
  bool updateAvailable = fileLastModified.isBefore(urlLastModified);
  // Debug info
  print('updateAvailable: Local $file modified '+fileLastModified.toString());
  print('updateAvailable: Remote URL $file modified '+urlLastModified.toString());
  if (updateAvailable) {
    print('updateAvailable: Updating $file, remote version is newer');
  } else {
    print('updateAvailable: Not updating $file, remote version not newer');
  }
  return updateAvailable;
}

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
    // Debug info
    //print(response.headers);
    File file = File(savePath);
    var raf = file.openSync(mode: FileMode.write);
    // response.data is List<int> type
    raf.writeFromSync(response.data);
    await raf.close();
  } catch (e) {
    // Retry up to the retryLimit after waiting 2 seconds
    if (retryCount < maxRetries) {
      int newRetryCount = retryCount+1;
      print('downloadFile: Failed $url - retrying time $newRetryCount');
      Timer(Duration(seconds: 2), () {downloadFile(url, savePath, newRetryCount, maxRetries);});
    } else {
      // When we have reached max retries just return an error
      throw('downloadFile: Failed to download $url with $maxRetries retries.');
    }
  }
}

refreshImages(BuildContext context, bool forceRefresh, bool notSilent) async {
  showSnackBarIf(notSilent, context, checkingSnack, 'refreshImages: Starting image update process');
  if (forceRefresh) {
    print('refreshImages: This refresh will be forced, ignoring last modified headers');
  }
  bool notYetShownStartSnack = true;
  // Download all the images using our downloadFile method.
  // The HTTP last modified header is individually checked for each file before downloading.
  for (int i = 0; i <= 8; i++) {
    if (forceRefresh || await updateAvailable('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', localFile('forecast.$i.png'))) {
      if (notYetShownStartSnack) {showSnackBarIf(notSilent, context, refreshingSnack, 'refreshImages: An image was found that needs updating. Starting update');notYetShownStartSnack=false;}
      try {
        downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', localFilePath('forecast.$i.png'));
      } catch(e) {
        showSnackBarIf(notSilent, context, errorRefreshSnack, 'refreshImages: Error updating image number $i, stopping');
        return false;
      }
    }
    if (forceRefresh || await updateAvailable('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast_legend.$i.png', localFile('forecast_legend.$i.png'))) {
      if (notYetShownStartSnack) {showSnackBarIf(notSilent, context, refreshingSnack, 'refreshImages: An image was found that needs updating. Starting update');notYetShownStartSnack=false;}
      try {
        downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast_legend.$i.png', localFilePath('forecast_legend.$i.png'));
      } catch(e) {
        showSnackBarIf(notSilent, context, errorRefreshSnack, 'refreshImages: Error updating image legend $i, stopping');
        return false;
      }
    }
  }
  if (notYetShownStartSnack) {
    // If no files needed updating, the start snack will never have been shown.
    // We aren't refreshing because no files needed refreshing.
    // Show a notification saying so and return.
    showSnackBarIf(notSilent, context, noRefreshSnack, 'refreshImages: No images needed updating');
    return false;
  } else {
    // Clear the image cache.
    await updateImageArray();
    // Show a notification saying we successfully refreshed.
    showSnackBarIf(notSilent, context, refreshedSnack, 'refreshImages: Image update successful');
    return true;
  }
}

showSnackBarIf(bool showControl, BuildContext context, SnackBar passedSnack, [String debugMessage = '']) {
  if (showControl) {
    Scaffold.of(context).removeCurrentSnackBar();
    Scaffold.of(context).showSnackBar(passedSnack);
    print(debugMessage);
  } else {
    print("showSnackBarIf: Skipping snack bar for: "+debugMessage);
  }
}

// Images in memory
updateImageArray() async {
  // Clear the array and reload all the images into it
  // Note that the array is a class-level variable in forecast.dart
  try {
    if (forecasts.isNotEmpty) {
      forecasts.clear();
    }
  } catch(e) {
    print(e);
    print("updateImageArray: Could not clear image array.");
  }
  for (int i = 0; i <= 8; i++) {
    if(await localFile('forecast.$i.png').exists()) {
      forecasts.add(pngDecoder.decodeImage(await localFile('forecast.$i.png').readAsBytes()));
    }
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

// Theming
bool darkMode(BuildContext context) {
  final Brightness brightnessValue = MediaQuery.of(context).platformBrightness;
  bool isDark = brightnessValue == Brightness.dark;
  return isDark;
}

// App code
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appDocPath = await getApplicationSupportDirectory();
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
          foregroundColor: Colors.white,
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
    print('SplashState: Staying on splash for now to attempt to update images');
    try {
      await refreshImages(context, false, false);
      print('SplashState: Done attempting to update images');
    } catch (e) {
      print('SplashState: Error attempting image update');
    }
    print('SplashState: Proceeding past splash');
    return true;
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
      backgroundColor: Color(0xFF0075b3),
      body: new Center(
        child: Image.asset("assets/launcher/logo.png"),
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
  _updateStatusBarBrightness(BuildContext context, [index = 1]) {
    // check current index
    // if changing to/from map screen, manage status bar legiblity
    if (_selectedIndex == 1 && index != 1) {
      // changing from map to something else
      if (darkMode(context)) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    } else {
      if (index == 1) {
        // going to map
        if (darkMode(context)) {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light, statusBarColor: Colors.transparent));
        } else {
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.transparent));
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _updateStatusBarBrightness(context, index);
      // set current index to passed index
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateStatusBarBrightness(context);
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