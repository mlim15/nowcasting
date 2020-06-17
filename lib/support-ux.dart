import 'package:introduction_screen/introduction_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Snack bars
final checkingSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Checking for updates...'));
final noRefreshSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('No new data to fetch!'));
final errorRefreshSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error refreshing.'));
final refreshedSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Done refreshing.'));
final refreshingSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Refreshing...'));
// Snack bars for onboarding
final onboardErrorSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Couldn\'t download data! Try again later.'));
final onboardCannotContinueSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Can\'t proceed without map data! Go back and download it.'));

// Theme definitions
final nowcastingColor = const Color(0xFF0075b3);
final nowcastingColorLighter = const Color(0xff00a3f9);
final grey850 = const Color(0xFF303030);
final grey250 = const Color(0xFFFAFAFA);
final lightTheme = ThemeData(
  primaryColor: nowcastingColor, 
  accentColor: nowcastingColor,
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    foregroundColor: Colors.white,
    backgroundColor: nowcastingColor,
  ),
);
final darkTheme = ThemeData(
  brightness: Brightness.dark, 
  primaryColor: nowcastingColor,
  accentColor: nowcastingColorLighter,
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    foregroundColor: Colors.white,
    backgroundColor: nowcastingColor,
  ),
);
// This number*160 is the actual DPI threshold.
// At 2 we are treating devices above 320dpi as high DPI (smaller maps, etc)
final dpiThreshold = 2;

// Onboarding object theme definitions
final pageDecorationDark = PageDecoration(
  titleTextStyle: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: Colors.white),
  bodyTextStyle: TextStyle(fontSize: 14.0, color: Colors.white),
  descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
  pageColor: grey850,
  //boxDecoration: BoxDecoration(gradient: Gradient()),
  imagePadding: EdgeInsets.zero,
);
final pageDecorationLight = PageDecoration(
  titleTextStyle: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700),
  bodyTextStyle: TextStyle(fontSize: 14.0),
  descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
  pageColor: grey250,
  imagePadding: EdgeInsets.zero,
);
final dotsDecorator = DotsDecorator(
  size: Size(10.0, 10.0),
  color: Color(0xFFBDBDBD),
  activeColor: nowcastingColor,
  activeSize: Size(22.0, 10.0),
  activeShape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(25.0)),
  ),
);
// Onboarding progress button themes
final double progressButtonWidth = 196;
final double progressButtonHeight = 48;
final double progressButtonBorderRadius = 24;
final progressButtonColor = nowcastingColor;
final progressButtonTextStyle = const TextStyle(color: Colors.white);
final progressButtonWidget = const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white));

// Helper functions to get info about device theming and properties
bool darkMode(BuildContext context) {
  final Brightness brightnessValue = MediaQuery.of(context).platformBrightness;
  bool isDark = brightnessValue == Brightness.dark;
  return isDark;
}
bool retinaMode(BuildContext context) { 
  if (MediaQuery.of(context).devicePixelRatio > dpiThreshold) {
    return true;
  } else {
    return false;
  }
}

// Helper functions to show or update UI elements
showSnackBarIf(bool showControl, SnackBar passedSnack, BuildContext context, [String debugMessage = '']) {
  if (showControl) {
    Scaffold.of(context).removeCurrentSnackBar();
    Scaffold.of(context).showSnackBar(passedSnack);
    print(debugMessage);
  } else {
    print("ux.showSnackBarIf: Skipping snack bar for "+debugMessage);
  }
}

updateStatusBarBrightness(BuildContext context, [bool transparent = false, bool reverseBrightness = false]) {
  if (reverseBrightness) {
    if (darkMode(context)) {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      }
    } else {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light, statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    }
  } else {
    if (darkMode(context)) {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light, statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    } else {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarIconBrightness: Brightness.dark, statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      }
    }
  }
}

