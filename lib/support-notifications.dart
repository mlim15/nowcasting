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

int maxLookahead = 2; // Index 2 is 60 minutes ahead
bool enabledCurrentLoc = false;
List<bool> enabledSavedLoc = [false];

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin  = FlutterLocalNotificationsPlugin();
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
  print('notifications.backgroundFetchCallback: Headless event $taskId received.');

  // Initialize sharedprefs and notification plugins, read notification preferences
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  main.prefs = await SharedPreferences.getInstance();
  loc.updateLastKnownLocation();
  await io.restoreLastKnownLocation();
  await io.restorePlaces();

  for (int _i = 0; _i < maxLookahead; _i++) {
    // Check if any notify locations are left that we haven't found a result for.
    // If not, break out of the for loop, we've notified for all possible locations.
    if (!anyNotificationsEnabled()) {break;}
    // Otherwise, there is something to look for still. Fetch the next image.
    update.completeUpdateSingleImage(_i, false);
    // Check any enabled locations in this image.
    if (enabledCurrentLoc) {
      List<int> _pixelCoord = geoToPixel(loc.lastKnownLocation.latitude, loc.lastKnownLocation.longitude);
      String _thisLocPixel = await getPixel(_pixelCoord[0], _pixelCoord[1], _i);
      if (!_thisLocPixel.startsWith("00")) {
        // Then it's not transparent. There is rain
        enabledCurrentLoc = false; // Don't panic. This isn't saved, it's just a way to make the next iteration skip checking this location
        showNotification(imagery.hex2desc(_thisLocPixel), "your current location", DateFormat('kk:mm').format(DateTime.parse(legends[_i])));
      }
    }
    for (int _n in Iterable<int>.generate(enabledSavedLoc.length)) {
      if (enabledSavedLoc[_n]) {
        List<int> _pixelCoord = geoToPixel(loc.places[_n].latitude, loc.places[_n].longitude);
        String _thisLocPixel = await getPixel(_pixelCoord[0], _pixelCoord[1], _i);
        if (!_thisLocPixel.startsWith("00")) {
          // Then it's not transparent. There is rain
          enabledSavedLoc[_n] = false; // Don't panic. This isn't saved, it's just a way to make the next iteration skip checking this location
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
      print('[BackgroundFetch] configure success: $status');
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
    }
  );
  // Register to receive BackgroundFetch events after app is terminated.
  // Works iff Android and {stopOnTerminate: false, enableHeadless: true}
  if (Platform.isAndroid) {
    BackgroundFetch.registerHeadlessTask(backgroundFetchCallback);
  }
}

initialize() async {
  // Initialize notification channels
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  if (anyNotificationsEnabled()) {
    scheduleBackgroundFetch();
  }
}