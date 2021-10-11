import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:introduction_screen/introduction_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// Snack bars
final checkingSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text('Checking for updates...'));
final noRefreshSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text('No new data to fetch!'));
final errorRefreshSnack = SnackBar(
    behavior: SnackBarBehavior.floating, content: Text('Error refreshing.'));
final refreshedSnack = SnackBar(
    behavior: SnackBarBehavior.floating, content: Text('Done refreshing.'));
final refreshingSnack = SnackBar(
    behavior: SnackBarBehavior.floating, content: Text('Refreshing...'));
final refreshTimedOutSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text('Error: Refresh timed out.'));
final updatingLocationSnack = SnackBar(
    behavior: SnackBarBehavior.floating, content: Text('Updating location...'));
final locationUpdatedSnack = SnackBar(
    behavior: SnackBarBehavior.floating, content: Text('Location updated.'));
// Snack bars for onboarding
final onboardErrorSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text('Couldn\'t download data! Try again later.'));
final onboardCannotContinueSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text('Can\'t proceed without map data! Go back and download it.'));
// Snack bars about location updates
final locationOffSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text(
        'Cannot update location. Check permissions or turn on location services.'));
final restoreErrorSnack = SnackBar(
    behavior: SnackBarBehavior.floating,
    content:
        Text('Error restoring location list. It has been reset to default.'));
// Snack bars about notifications
final notificationPermissionErrorSnack = SnackBar(
  behavior: SnackBarBehavior.floating,
  content: Text(
      'To display notifications, you\'ll need to grant the requested permissions.'),
);
final notificationLocPermissionErrorSnack = SnackBar(
  behavior: SnackBarBehavior.floating,
  content: Text(
      'To display notifications for your location, you\'ll need to grant the app location permissions.'),
);

// Strings displayed on alerts, and urls opened by tapping certain alerts
String radarOutageText =
    'The nowcasting service is currently experiencing an outage. This may be due to unscheduled outages in Environment Canada\'s radar system. Tap for more info.';
String alertText = 'Severe weather alert at your location. Tap for more info.';
String radarOutageUrl =
    'https://www.canada.ca/en/environment-climate-change/services/weather-general-tools-resources/radar-overview/outages-maintenance.html';
String alertUrl = 'url-not-set';

// Theme definitions
final nowcastingColor = const Color(0xFF0075b3);
final nowcastingColorLighter = const Color(0xff0085c7);
final nowcastingColorDarker = const Color(0xFF005591);
final grey850 = const Color(0xFF303030);
final grey250 = const Color(0xFFFAFAFA);
final lightTheme = ThemeData(
    primaryColor: nowcastingColor,
    accentColor: nowcastingColor,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: Colors.white,
      backgroundColor: nowcastingColor,
    ),
    textTheme: Typography.blackMountainView);
final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: nowcastingColor,
    accentColor: nowcastingColorLighter,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: Colors.white,
      backgroundColor: nowcastingColor,
    ),
    textTheme: Typography.whiteMountainView);
// This number*160 is the actual DPI threshold.
// At 2 we are treating devices above 320dpi as high DPI (smaller maps, etc)
final dpiThreshold = 2;

// Onboarding object theme definitions
final pageDecorationDark = PageDecoration(
  titleTextStyle: TextStyle(
      fontSize: 22.0, fontWeight: FontWeight.w700, color: Colors.white),
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
final progressButtonWidget = const CircularProgressIndicator(
    valueColor: AlwaysStoppedAnimation<Color>(Colors.white));

// Sliver padding
final sliverMargins = const EdgeInsets.only(
  top: 12.0,
  left: 18.0,
  right: 18.0,
);
final sliverBottomMargins = const EdgeInsets.symmetric(
  vertical: 12,
  horizontal: 18,
);
final sliverShadow = const BoxShadow(
  color: Colors.black12,
  blurRadius: 10.0,
  offset: Offset(0.0, 10.0),
);
final double sliverHeightExpanded = 164;
final double sliverHeight = 148;
final double sliverThinHeight = 96;
final double sliverHalfThinHeight = 64;
final double sliverTinyHeight = 32;

// Warning levels and styling for slivers
enum WarningLevel { notice, warning, alert }
final noticeColor = Color(0xFF00b398);
final warningColor = Color(0xFFB33E00);
final alertColor = Color(0xFFB3001C);
final noticeIcon = Icon(Icons.help, color: Colors.white);
final warningIcon = Icon(Icons.error, color: Colors.white);
final alertIcon = Icon(Icons.warning, color: Colors.white);

// Fonts
final latoWhite =
    GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF));
final latoBlue =
    GoogleFonts.lato(fontWeight: FontWeight.w600, color: nowcastingColor);
final latoBlack =
    GoogleFonts.lato(fontWeight: FontWeight.w600, color: Colors.black);

TextStyle latoForeground(BuildContext context) {
  if (darkMode(context)) {
    return latoWhite;
  } else {
    return latoBlack;
  }
}

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
showSnackBarIf(bool showControl, SnackBar passedSnack, BuildContext context,
    [String debugMessage = '']) {
  if (showControl) {
    Scaffold.of(context).removeCurrentSnackBar();
    Scaffold.of(context).showSnackBar(passedSnack);
    print(debugMessage);
  } else {
    print("ux.showSnackBarIf: Skipping snack bar for " + debugMessage);
  }
}

updateStatusBarBrightness(BuildContext context,
    [bool transparent = false, bool reverseBrightness = false]) {
  if (reverseBrightness) {
    if (darkMode(context)) {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      }
    } else {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    }
  } else {
    if (darkMode(context)) {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
      }
    } else {
      if (transparent) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarColor: Colors.transparent));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
      }
    }
  }
}

Widget locMarker(BuildContext context,
    {Color markerColor = const Color(0xFFFFFFFF),
    Color borderColor = const Color(0xFF0075b3)}) {
  return Container(
    padding: EdgeInsets.all(4),
    //height: 2,
    //width: 2,
    decoration: BoxDecoration(
        border: Border.all(color: borderColor.withOpacity(0.8), width: 3),
        shape: BoxShape.circle,
        color: markerColor.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black54.withOpacity(0.1),
            blurRadius: 0.0,
          ) //offset: const Offset(1, 2.5),)
        ]),
  );
}

// Multi-use sliver definitions
class WarningSliver extends StatelessWidget {
  final String _warningText;
  final WarningLevel _warningLevel;
  final String url;
  final VoidCallback onTap;
  WarningSliver(this._warningText, this._warningLevel, {this.url, this.onTap});

  _launchURL() async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
        margin: sliverMargins,
        child: new GestureDetector(
            onTap: url != null
                ? () {
                    _launchURL();
                  }
                : () {
                    onTap();
                  },
            child: Stack(
              children: <Widget>[
                new Container(
                  decoration: new BoxDecoration(
                    color: _warningLevel == WarningLevel.alert
                        ? alertColor
                        : _warningLevel == WarningLevel.warning
                            ? warningColor
                            : noticeColor, // else it's a notice
                    shape: BoxShape.rectangle,
                    borderRadius: new BorderRadius.circular(8.0),
                    boxShadow: [sliverShadow],
                  ),
                  child: new Row(
                    children: [
                      Expanded(
                        child: Align(
                            alignment: Alignment(0, 0),
                            child: Row(children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                child: _warningLevel == WarningLevel.alert
                                    ? alertIcon
                                    : _warningLevel == WarningLevel.warning
                                        ? warningIcon
                                        : noticeIcon, // else it's a notice
                              ),
                              Flexible(
                                  child: Container(
                                      padding: EdgeInsets.all(6),
                                      child: Text(_warningText,
                                          style: latoWhite))),
                            ])),
                      )
                    ],
                  ),
                ),
              ],
            )));
  }
}

class IconTextSliver extends StatelessWidget {
  final String _text;
  final Icon _icon;
  final Color _color;
  final VoidCallback onTap;
  IconTextSliver(this._text, this._icon, this._color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return new Container(
        margin: sliverMargins,
        child: new GestureDetector(
            onTap: () {
              onTap();
            },
            child: Stack(
              children: <Widget>[
                new Container(
                  decoration: new BoxDecoration(
                    color: _color,
                    shape: BoxShape.rectangle,
                    borderRadius: new BorderRadius.circular(8.0),
                    boxShadow: [sliverShadow],
                  ),
                  child: new Row(
                    children: [
                      Expanded(
                        child: Align(
                            alignment: Alignment(0, 0),
                            child: Row(children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                child: _icon, // else it's a notice
                              ),
                              Flexible(
                                  child: Container(
                                      padding: EdgeInsets.all(6),
                                      child: Text(_text, style: latoWhite))),
                            ])),
                      )
                    ],
                  ),
                ),
              ],
            )));
  }
}
