import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:background_fetch/background_fetch.dart';

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

  // Get sharedpref and read notification pr

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