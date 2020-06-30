import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info/device_info.dart';

import 'package:Nowcasting/UI-onboarding.dart' as onboarding;
import 'package:Nowcasting/UI-map.dart' as map;
import 'package:Nowcasting/UI-forecast.dart' as forecast;
import 'package:Nowcasting/UI-info.dart' as info;
import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// TODO animate splash screen

SharedPreferences prefs;
DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
AndroidDeviceInfo androidInfo;
IosDeviceInfo iosInfo;

// App code
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Initialize critical filepath information immediately
  io.updateAppDocPath();
  prefs = await SharedPreferences.getInstance();
  if (Platform.isAndroid) {
    androidInfo = await deviceInfo.androidInfo;
  }
  if (Platform.isIOS) {
    iosInfo = await deviceInfo.iosInfo;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const String _title = 'MAPLE Nowcasting';
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
  Future _checkFirstSeen() async {
    // Test the 'seen' SharedPreference which says whether
    // onboarding has been completed or not.
    if (prefs.getBool('obComplete') ?? false) {
      // Onboarding is not necessary.
      // Instead we do some housekeeping before getting to the main app UI.
      // Try to refresh outdated images:
      print('SplashState: Staying on splash for now to attempt to update images');
      // TODO ensure hangup caused by dio connection timeout error on update.radarOutages is gone for good
      await loc.restoreLastKnownLocation();
      await loc.restorePlaces(context);
      await loc.updateLastKnownLocation();
      await update.radarOutages();
      try {
        if (await update.remoteImagery(context, false, false)) {
          update.forecasts();
        } else {
          await imagery.loadDecodedForecasts();
        }
        await update.legends();
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
      body: new Center(
        child: Image.asset("assets/launcher/logo.png"),
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
        selectedItemColor: ux.nowcastingColor,
        onTap: _onItemTapped,
      ),
    );
  }
}