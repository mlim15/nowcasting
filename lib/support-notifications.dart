import 'dart:io' show Platform;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:background_fetch/background_fetch.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-jobStatus.dart' as job;

DateTime lastShownNotificationCurrentLoc = DateTime.fromMillisecondsSinceEpoch(0);
List<DateTime> lastShownNotificationSavedLoc = [DateTime.fromMillisecondsSinceEpoch(0)];

int maxLookahead = 2; // Index 2 is 60 minutes ahead
Duration minimumTimeBetweenNotifications = Duration(minutes: 180);
// First items of each type (t1, s1, l1) will not generate notifications
// When zero it is effectively disabled because the method that checks
// this will only ever return a result that says it's not under the threshold
int severityThreshold = 1; 

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
const NotificationDetails platformChannelSpecifics = NotificationDetails(
  android: androidPlatformChannelSpecifics, 
  iOS: iOSPlatformChannelSpecifics
);

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
/// This is what determines whether to generate a notification (and does so)
/// when it is triggered by the OS.
void backgroundFetchCallback(String taskId) async {
  print('notifications.backgroundFetchCallback: Headless event $taskId received at '+DateTime.now().toString());

  // Initialize sharedprefs and notification plugins, read notification preferences
  if (!notificationsInitialized) {await flutterLocalNotificationsPlugin.initialize(initializationSettings);}
  if (loc.currentLocation.coordinates == null) {
    // Then we know the app is closed and we need to reload our variables.
    main.prefs = await SharedPreferences.getInstance();
    loc.currentLocation.update();
    await io.loadPlaceData();
  }

  // Work with deep copies because we're manipulating this data
  List<bool> _enabledSavedLocCopy = new List<bool>.generate(loc.savedPlaces.length, (_index) {if (loc.savedPlaces[_index].notify == true) {return true;} else {return false;}});
  bool _enabledCurrentLocCopy;
  if (loc.currentLocation.notify) {_enabledCurrentLocCopy = true;} else {_enabledCurrentLocCopy = false;}
  
  // Disable notifications this go-round for any locations that have already 
  // been shown for in the last minimumTimeBetweenNotifications (default 180 minutes).
  if (DateTime.now().difference(lastShownNotificationCurrentLoc) < minimumTimeBetweenNotifications) {
    print('notifications.backgroundFetchCallback: Might have notified for current location, but skipped because notified too soon ago.');
    _enabledCurrentLocCopy = false;
  }
  for (int _i in Iterable<int>.generate(_enabledSavedLocCopy.length)) {
    if (_enabledSavedLocCopy[_i] == true) {
      if ((DateTime.now().difference(lastShownNotificationSavedLoc[_i]) < minimumTimeBetweenNotifications)) {
        print('notifications.backgroundFetchCallback: Might have notified for saved location '+loc.savedPlaces[_i].name+', but skipped because notified too soon ago.');
        _enabledSavedLocCopy[_i] = false;
      }
    }
  }

  for (int _i = 0; _i < maxLookahead; _i++) {
    // Check if any notify locations are left that we haven't found a result for.
    // If not, break out of the for loop, we've notified for all possible locations.
    if (!(_enabledCurrentLocCopy || _enabledSavedLocCopy.any((entry) {return entry == true;}))) {break;}
    // Otherwise, there is something to look for still. Fetch the next image.
    await update.completeUpdateSingleImage(_i, false);
    // Check this image for current location, if notifications are enabled for it
    if (_enabledCurrentLocCopy) {
      List<int> _pixelCoord = imagery.geoToPixel(loc.currentLocation.coordinates.latitude, loc.currentLocation.coordinates.longitude);
      String _thisLocPixel = await imagery.getPixel(_pixelCoord[0], _pixelCoord[1], _i);
      if (!_thisLocPixel.startsWith("00")) {
        // Then it's not transparent. There is rain
        if (imagery.isUnderThreshold(_thisLocPixel, severityThreshold)) {
          // Disable this location for the next loop, update the time we last notified for it
          // and show the notification.
          _enabledCurrentLocCopy = false;
          lastShownNotificationCurrentLoc = new DateTime.now();
          io.savePlaceData();
          // TODO save this to sharedpref
          showNotification(imagery.hex2desc(_thisLocPixel), "your current location", DateFormat('kk:mm').format(DateTime.parse(imagery.legends[_i])));
        } else {
          print('notifications.backgroundFetchCallback: Would have notified for current location, but skipped because of threshold rules.');
        }
      }
    }
    // Check this image for any saved locations, if notifications are enabled for them
    for (int _n in Iterable<int>.generate(_enabledSavedLocCopy.length)) {
      if (_enabledSavedLocCopy[_n]) {
        List<int> _pixelCoord = imagery.geoToPixel(loc.savedPlaces[_n].coordinates.latitude, loc.savedPlaces[_n].coordinates.longitude);
        String _thisLocPixel = await imagery.getPixel(_pixelCoord[0], _pixelCoord[1], _i);
        if (!_thisLocPixel.startsWith("00")) {
          // Then it's not transparent. There is rain
          if (imagery.isUnderThreshold(_thisLocPixel, severityThreshold)) {
            // Disable this location for the next loop, update the time we last notified for it
            // and show the notification.
            _enabledSavedLocCopy[_n] = false;
            lastShownNotificationSavedLoc[_n] = new DateTime.now();
            io.savePlaceData();
            showNotification(imagery.hex2desc(_thisLocPixel), loc.savedPlaces[_n].name, DateFormat('kk:mm').format(DateTime.parse(imagery.legends[_i])));
          } else {
          print('notifications.backgroundFetchCallback: Would have notified for saved location, but skipped because of threshold rules.');
          }
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

Future<job.CompletionStatus> notificationTapped(String payload) {
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