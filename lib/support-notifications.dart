import 'package:intl/intl.dart';
import 'dart:io' show Platform;

import 'package:Nowcasting/support-imagery.dart';
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-imagery.dart' as imagery;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:background_fetch/background_fetch.dart';

DateTime lastShownNotificationCurrentLoc = DateTime.fromMillisecondsSinceEpoch(0);
List<DateTime> lastShownNotificationSavedLoc = [DateTime.fromMillisecondsSinceEpoch(0)];

int maxLookahead = 2; // Index 2 is 60 minutes ahead
Duration minimumTimeBetweenNotifications = Duration(minutes: 180);
bool doNotNotifyUnderThreshold = true;
int severityThreshold = 2; // First two items of each type (t1, t2, s1, s2, etc) will be ignored

bool enabledCurrentLoc = false;
List<bool> enabledSavedLoc = [false];
bool notificationsInitialized = false;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('notification_icon');
final IOSInitializationSettings initializationSettingsIOS = IOSInitializationSettings(
  requestSoundPermission: false,
  requestBadgePermission: false,
  requestAlertPermission: false,
);
final InitializationSettings initializationSettings = InitializationSettings(
  android: initializationSettingsAndroid,
  iOS: initializationSettingsIOS,
);

const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
  'nowcasting', 'Alerts', 'Notfies you about precipitation in your area during the coming hour',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  showWhen: false
);
const IOSNotificationDetails iOSPlatformChannelSpecifics = IOSNotificationDetails(
  // Not sure if anything needed/wanted here
);
const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);

showNotification(String _desc, String _placeName, String _time) async {
  // TODO On android information can be cut off when strings are too long.
  await flutterLocalNotificationsPlugin.show(0, '$_desc detected at $_placeName at $_time', 'Tap for more details.', platformChannelSpecifics);
}

bool anyNotificationsEnabled() {
  if (enabledCurrentLoc || enabledSavedLoc.any((entry) {return entry == true;})) {
    return true;
  } else {
    return false;
  }
}

/// This "Headless Task" is run when app is terminated.
void backgroundFetchCallback(String taskId) async {
  // TODO do not generate more notifications if the first are not yet dismissed,
  // if such a thing is possible. Perhaps store array of lastNotified DateTimes
  // and restrict to once per couple hours per location.
  // TODO configurable threshold so you aren't notified for a drizzle
  print('notifications.backgroundFetchCallback: Headless event $taskId received at '+DateTime.now().toString());

  // Initialize sharedprefs and notification plugins, read notification preferences
  if (!notificationsInitialized) {await flutterLocalNotificationsPlugin.initialize(initializationSettings);}
  if (loc.lastKnownLocation == null) {
    // Then we know the app is closed and we need to reload our variables.
    main.prefs = await SharedPreferences.getInstance();
    loc.updateLastKnownLocation();
    await io.loadLastKnownLocation();
    await io.loadPlaceData();
  }

  // Work with deep copies because we're manipulating this data
  List<bool> _enabledSavedLocCopy = new List<bool>.generate(enabledSavedLoc.length, (_index) {if (enabledSavedLoc[_index] == true) {return true;} else {return false;}});
  bool _enabledCurrentLocCopy;
  if (enabledCurrentLoc) {_enabledCurrentLocCopy = true;} else {_enabledCurrentLocCopy = false;}
  
  for (int _i = 0; _i < maxLookahead; _i++) {
    // Check if any notify locations are left that we haven't found a result for.
    // If not, break out of the for loop, we've notified for all possible locations.
    if (!(_enabledCurrentLocCopy || _enabledSavedLocCopy.any((entry) {return entry == true;}))) {break;}
    // Otherwise, there is something to look for still. Fetch the next image.
    await update.completeUpdateSingleImage(_i, false);
    // Check any enabled locations in this image.
    if (_enabledCurrentLocCopy) {
      List<int> _pixelCoord = geoToPixel(loc.lastKnownLocation.latitude, loc.lastKnownLocation.longitude);
      String _thisLocPixel = await getPixel(_pixelCoord[0], _pixelCoord[1], _i);
      if (!_thisLocPixel.startsWith("00")) {
        // Then it's not transparent. There is rain
        _enabledCurrentLocCopy = false;
        showNotification(imagery.hex2desc(_thisLocPixel), "your current location", DateFormat('kk:mm').format(DateTime.parse(legends[_i])));
      }
    }
    for (int _n in Iterable<int>.generate(_enabledSavedLocCopy.length)) {
      if (_enabledSavedLocCopy[_n]) {
        List<int> _pixelCoord = geoToPixel(loc.places[_n].latitude, loc.places[_n].longitude);
        String _thisLocPixel = await getPixel(_pixelCoord[0], _pixelCoord[1], _i);
        if (!_thisLocPixel.startsWith("00")) {
          // Then it's not transparent. There is rain
          _enabledSavedLocCopy[_n] = false;
          showNotification(imagery.hex2desc(_thisLocPixel), loc.placeNames[_n], DateFormat('kk:mm').format(DateTime.parse(legends[_i])));
        }
      }
    }
  }

  BackgroundFetch.finish(taskId);
}

cancelBackgroundFetch() {
  BackgroundFetch.stop();
}

scheduleBackgroundFetch() {
  // Configure background_fetch
  BackgroundFetch.configure(
    BackgroundFetchConfig(
        minimumFetchInterval: Platform.isIOS ? 15 : 15, // TODO find best interval for Android.
        startOnBoot: true,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NOT_ROAMING // Not sure if this is the best default either
    ),
    backgroundFetchCallback
  ).then((int status) {
      print('notifications.scheduleBackgroundFetch: configure success: $status');
    }).catchError((e) {
      print('notifications.scheduleBackgroundFetch: configure ERROR: $e');
    }
  );
  // Register to receive BackgroundFetch events after app is terminated.
  // Works iff Android and {stopOnTerminate: false, enableHeadless: true}
  if (Platform.isAndroid) {
    BackgroundFetch.registerHeadlessTask(backgroundFetchCallback);
  }
}

Future<bool> notificationTapped(String payload) {
  return update.completeUpdate(false, true);
}

initialize() async {
  // Initialize notification channels
  // TODO when launched using notification, trigger refresh
  if (await flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: notificationTapped)) {
    notificationsInitialized = true;
  }
  if (anyNotificationsEnabled()) {
    scheduleBackgroundFetch();
  }
}