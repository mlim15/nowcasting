import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info/device_info.dart';
import 'package:package_info/package_info.dart';

import 'package:nowcasting/UI-onboarding.dart' as onboarding;
import 'package:nowcasting/UI-map.dart' as map;
import 'package:nowcasting/UI-forecast.dart' as forecast;
import 'package:nowcasting/UI-info.dart' as info;
import 'package:nowcasting/support-ux.dart' as ux;
import 'package:nowcasting/support-io.dart' as io;
import 'package:nowcasting/support-update.dart' as update;
import 'package:nowcasting/support-notifications.dart' as notifications;

// TODO animate splash screen
// TODO localization including map images... maybe generate/redownload with localized per-region names?

PackageInfo packageInfo;
SharedPreferences prefs;
DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
AndroidDeviceInfo androidInfo;
IosDeviceInfo iosInfo;
const platform = const MethodChannel("com.github.the_salami.nowcasting/pngj");

// App code
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Initialize critical filepath information immediately
  io.updateAppDocPath();
  prefs = await SharedPreferences.getInstance();
  packageInfo = await PackageInfo.fromPlatform();
  if (Platform.isAndroid) {
    androidInfo = await deviceInfo.androidInfo;
  }
  if (Platform.isIOS) {
    iosInfo = await deviceInfo.iosInfo;
  }
  await notifications.initialize();

  // FOR DEBUG PURPOSES
  // Shows normal error boxes in profile and release modes
  //ErrorWidget.builder = (FlutterErrorDetails details) {
  //  bool inDebug = false;
  //  assert(() { inDebug = true; return true; }());
  //  // In debug mode, use the normal error widget which shows
  //  // the error message:
  //  if (inDebug)
  //    return ErrorWidget(details.exception);
  //  // In release builds, you can build an alternative instead:
  //  return Container(
  //    alignment: Alignment.center,
  //    child: Text(
  //     'Error! ${details.exception}',
  //      style: TextStyle(color: Colors.red),
  //      textDirection: TextDirection.ltr,
  //    ),
  //  );
  //};
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const String _title = 'MAPLE nowcasting';
  @override
  Widget build(BuildContext context) {
    return MaterialApp (
      title: _title,
      home: Splash(), // In main.dart, see below
      theme: ux.lightTheme,
      darkTheme: ux.darkTheme,
    );
  }
}

// Splash UI
class Splash extends StatefulWidget {
  @override
  SplashState createState() => new SplashState();
}

class SplashState extends State<Splash> {
  String _splashText = "";
  bool _logoVisible = false;
  bool _textVisible = false;
  _changeSplashText(String newText) {
    setState(() {
      _textVisible = false;
    });
    Timer(Duration(milliseconds: 300), () {setState(() {
      _splashText = newText;
      _logoVisible = true;
      _textVisible = true;
    });});
  }
  _setTextVisible(bool visibility) {
    setState(() {
      _textVisible = visibility;
    });
  }
  _setLogoVisible(bool visibility) {
    setState(() {
      _logoVisible = visibility;
    });
  }
  Future _checkFirstSeen() async {
    // Test the 'seen' SharedPreference which says whether
    // onboarding has been completed or not.
    if (prefs.getBool('obComplete') ?? false) {
      _setTextVisible(false);
      _setLogoVisible(false);
      _changeSplashText("Loading...");
      // Onboarding is not necessary.
      // Instead we do some housekeeping before getting to the main app UI.
      // Try to refresh outdated images:
      print('SplashState: Staying on splash for now to attempt to update images');
      await io.loadPlaceData();
      await io.loadNowcastData();
      await io.loadNotificationPreferences();
      print('SplashState: Done restoring places');
      try {
        _changeSplashText('Checking for Updates...');
        if (await update.completeUpdate(false, true) != update.CompletionStatus.failure) {
          _setTextVisible(false);
        }
        print('SplashState: Done attempting to update images');
      } catch (e) {
        print('SplashState: Error attempting image update');
      }
      print('SplashState: Proceeding past splash');
      // Once we have reloaded images if necessary, proceed to main app UI.
      Navigator.of(context).pushReplacement(
        new MaterialPageRoute(builder: (context) => new AppContents())); // also in main.dart, see below
    } else {
      // If the onboarding process hasn't been completed (tracked by 'seen' sharedpreference above)
      // then just immediately go to the onboarding process.
      Navigator.of(context).pushReplacement(
        new MaterialPageRoute(builder: (context) => new onboarding.OnboardingScreen()));
    }
  }
  // On creation, wait 200ms so transition is not jarring and then check if onboarding is needed
  @override
  void initState() {
    super.initState();
    new Timer(new Duration(milliseconds: 200), () {
      _checkFirstSeen();
    });
  }
  // Widget definition
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light, statusBarColor: Colors.transparent));
    return new Scaffold(
      backgroundColor: ux.nowcastingColor,
      body: new Stack(
        children: <Widget>[
          AnimatedOpacity(opacity: _logoVisible ? 1.0 : 0.0, duration: Duration(milliseconds: 300), child: Center(child: Image.asset("assets/launcher/logo.png", width: 320, height: 320))),
          AnimatedOpacity(opacity: _textVisible ? 1.0 : 0.0, duration: Duration(milliseconds: 300), child: Container(alignment: Alignment.center, margin: EdgeInsets.only(top: 256), child: Text(_splashText, style: ux.latoWhite))),
        ],
      ),
    );
  }
}

// Post-splash UI
class AppContents extends StatefulWidget {
  const AppContents({Key key}) : super(key: key);
  @override
  AppState createState() => AppState();
}

class AppState extends State<AppContents> {
  // A variable that tracks the current page of the app
  int _selectedIndex = 0;
  // Function called when we tap a nav bar icon, triggering a page change
  void _onItemTapped(int passedIndex) {
    setState(() {
      // Close drawers on subpages if they are open,
      // otherwise appbars get unsightly back arrows
      // after changing screens
      try {
        if (map.mapScaffoldKey.currentState.isDrawerOpen) {
          Navigator.pop(map.mapScaffoldKey.currentContext);
        }
      } catch(e) {
        print('AppState: could not check status of mapScreen drawer. Likely the MapScreen did not initialize properly.');
      }
      // Update status bar brightness
      if (_selectedIndex == 1 && passedIndex != 1) {
        // changing from map to something else
        ux.updateStatusBarBrightness(context);
      } else if (passedIndex == 1) {
        // going to map
        ux.updateStatusBarBrightness(context, true, true);
      }
      // Finally, change the page by setting current index to passed index
      _selectedIndex = passedIndex;
    });
  }
  // Widget definition
  @override
  Widget build(BuildContext context) {
    ux.updateStatusBarBrightness(context);
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          forecast.ForecastScreen(),
          map.MapScreen(),
          info.InfoScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny),
            label: 'Forecast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'About',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: ux.nowcastingColor,
        onTap: _onItemTapped,
      ),
    );
  }
}