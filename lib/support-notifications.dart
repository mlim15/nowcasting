import 'dart:io' show Platform;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:background_fetch/background_fetch.dart';

import 'package:nowcasting/main.dart' as main;
import 'package:nowcasting/support-io.dart' as io;
import 'package:nowcasting/support-update.dart' as update;
import 'package:nowcasting/support-location.dart' as loc;
import 'package:nowcasting/support-imagery.dart' as imagery;

bool notificationsEnabled = false;
bool notificationsInitialized = false;
int maxLookahead = 2; // Index 2 is 60 minutes ahead
Duration minimumTimeBetween = Duration(minutes: 180);
double dataUsage = 0.1 * (maxLookahead + 1) * (1440 / checkIntervalMinutes);
int checkIntervalMinutes = 60;
// First items of each type (t1, s1, l1) will not generate notifications
// When zero it is effectively disabled because the method that checks
// this will only ever return a result that says it's not under the threshold
int severityThreshold = 1;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('notification_icon');
final IOSInitializationSettings initializationSettingsIOS =
    IOSInitializationSettings(
  requestSoundPermission: false,
  requestBadgePermission: false,
  requestAlertPermission: false,
);
final InitializationSettings initializationSettings = InitializationSettings(
  android: initializationSettingsAndroid,
  iOS: initializationSettingsIOS,
);
const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails('nowcasting', 'Alerts',
        'Notfies you about precipitation in your area during the coming hour',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: false);
const IOSNotificationDetails iOSPlatformChannelSpecifics =
    IOSNotificationDetails(
        // Not sure if anything needed/wanted here
        );
const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);

updateDataUsageEstimate() {
  // 100KB per image
  // * images per update (lookahead+1)
  // * times updated per day (24 hours/minimum time between)
  // this is a maximum, some updates will stop before reaching the
  // max lookahead
  dataUsage = 0.1 * (maxLookahead + 1) * (1440 / checkIntervalMinutes);
}

showNotification(String _desc, String _placeName, String _time) async {
  // TODO On android information can be cut off when strings are too long.
  await flutterLocalNotificationsPlugin.show(
      0, '$_desc detected!', '$_placeName at $_time', platformChannelSpecifics);
}

bool anyNotificationsEnabled() {
  if (loc.currentLocation.notify ||
      loc.savedPlaces.any((_location) {
        return _location.notify == true;
      })) {
    return true;
  } else {
    return false;
  }
}

int countEnabledLocations() {
  int _enabledPlaces = 0;
  if (loc.currentLocation.notify) {
    _enabledPlaces += 1;
  }
  for (loc.nowcastingLocation location in loc.savedPlaces) {
    if (location.notify) {
      _enabledPlaces += 1;
    }
  }
  return _enabledPlaces;
}

/// This "Headless Task" is run when app is terminated.
/// This is what determines whether to generate a notification (and does so)
/// when it is triggered by the OS.
void backgroundFetchCallback(String taskId) async {
  print(
      'notifications.backgroundFetchCallback: Headless event $taskId received at ' +
          DateTime.now().toString());

  // Initialize sharedprefs and notification plugins, read notification preferences
  if (!notificationsInitialized) {
    // Then we know the app is closed and we need to reload our variables.
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    main.prefs = await SharedPreferences.getInstance();
    //loc.currentLocation.update();
    await io.loadPlaceData();
    await io.loadNowcastData();
    await io.loadNotificationPreferences();
  }

  // Now that we know we can access the preference, check to see if notifications are actually enabled.
  // This shouldn't happen but this will prevent the method from running again until
  // notifications are turned back on.
  if (!notificationsEnabled) {
    cancelBackgroundFetch();
    return;
  }

  // Work with deep copies because we're manipulating this data
  List<bool> _enabledSavedLocCopy =
      new List<bool>.generate(loc.savedPlaces.length, (_index) {
    if (loc.savedPlaces[_index].notify == true) {
      return true;
    } else {
      return false;
    }
  });
  bool _enabledCurrentLocCopy;
  if (loc.currentLocation.notify) {
    _enabledCurrentLocCopy = true;
  } else {
    _enabledCurrentLocCopy = false;
  }

  // Disable notifications this go-round for any locations that have already
  // been shown for in the last minimumTimeBetween (default 180 minutes).
  if (DateTime.now().difference(loc.currentLocation.lastNotified) <
      minimumTimeBetween) {
    print(
        'notifications.backgroundFetchCallback: Might have notified for current location, but skipped because notified too soon ago.');
    _enabledCurrentLocCopy = false;
  }
  for (int _i in Iterable<int>.generate(_enabledSavedLocCopy.length)) {
    if (_enabledSavedLocCopy[_i] == true) {
      if ((DateTime.now().difference(loc.savedPlaces[_i].lastNotified) <
          minimumTimeBetween)) {
        print(
            'notifications.backgroundFetchCallback: Might have notified for saved location ' +
                loc.savedPlaces[_i].name +
                ', but skipped because notified too soon ago.');
        _enabledSavedLocCopy[_i] = false;
      }
    }
  }
  for (int _i = 0; _i < maxLookahead; _i++) {
    // Check if any notify locations are left that we haven't found a result for.
    // If not, break out of the for loop, we've notified for all possible locations.
    if (!(_enabledCurrentLocCopy ||
        _enabledSavedLocCopy.any((entry) {
          return entry == true;
        }))) {
      break;
    }
    // Otherwise, there is something to look for still. Fetch the next image.
    await imagery.nowcasts[_i].refresh(false);
    // Check this image for current location, if notifications are enabled for it
    if (_enabledCurrentLocCopy) {
      String _thisLocPixel =
          await imagery.getPixel(imagery.nowcasts[_i], loc.currentLocation);
      if (!_thisLocPixel.startsWith("00")) {
        // Then it's not transparent. There is rain
        if (!imagery.isUnderThreshold(_thisLocPixel, severityThreshold)) {
          // Disable this location for the next loop, update the time we last notified for it
          // and show the notification.
          _enabledCurrentLocCopy = false;
          loc.currentLocation.lastNotified = new DateTime.now();
          io.savePlaceData();
          showNotification(
              imagery.convert(
                  _thisLocPixel, imagery.NowcastDataType.description),
              "Your current location",
              imagery.nowcasts[_i].shownTime);
        } else {
          print(
              'notifications.backgroundFetchCallback: Would have notified for current location, but skipped because of threshold rules.');
        }
      }
    }
    // Check this image for any saved locations, if notifications are enabled for them
    for (int _n in Iterable<int>.generate(_enabledSavedLocCopy.length)) {
      if (_enabledSavedLocCopy[_n]) {
        String _thisLocPixel =
            await imagery.getPixel(imagery.nowcasts[_i], loc.savedPlaces[_n]);
        if (!_thisLocPixel.startsWith("00")) {
          // Then it's not transparent. There is rain
          if (!imagery.isUnderThreshold(_thisLocPixel, severityThreshold)) {
            // Disable this location for the next loop, update the time we last notified for it
            // and show the notification.
            _enabledSavedLocCopy[_n] = false;
            loc.savedPlaces[_n].lastNotified = new DateTime.now();
            io.savePlaceData();
            showNotification(
                imagery.convert(
                    _thisLocPixel, imagery.NowcastDataType.description),
                loc.savedPlaces[_n].name,
                imagery.nowcasts[_i].shownTime);
          } else {
            print(
                'notifications.backgroundFetchCallback: Would have notified for saved location, but skipped because of threshold rules.');
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
              minimumFetchInterval:
                  checkIntervalMinutes, // TODO find best interval for Android.
              startOnBoot: true,
              stopOnTerminate: false,
              enableHeadless: true,
              requiresBatteryNotLow: false,
              requiresCharging: false,
              requiresStorageNotLow: false,
              requiresDeviceIdle: false,
              requiredNetworkType: NetworkType
                  .NOT_ROAMING // Not sure if this is the best default either
              ),
          backgroundFetchCallback)
      .then((int status) {
    print('notifications.scheduleBackgroundFetch: configure success: $status');
  }).catchError((e) {
    print('notifications.scheduleBackgroundFetch: configure ERROR: $e');
  });
  // Register to receive BackgroundFetch events after app is terminated.
  // Works iff Android and {stopOnTerminate: false, enableHeadless: true}
  if (Platform.isAndroid) {
    BackgroundFetch.registerHeadlessTask(backgroundFetchCallback);
  }
}

Future<update.CompletionStatus> notificationTapped(String payload) {
  return update.completeUpdate(false, true);
}

initialize() async {
  // Initialize notification channels
  // TODO when launched using notification, trigger refresh
  //loc.location.enableBackgroundMode(enable: true);
  if (await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: notificationTapped)) {
    notificationsInitialized = true;
  }
  if (anyNotificationsEnabled()) {
    scheduleBackgroundFetch();
  }
}
