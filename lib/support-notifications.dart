import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  await flutterLocalNotificationsPlugin.show(0, 'Nowcasting', '$_desc detected at $_placeName at $_time! Check the app for more details.', platformChannelSpecifics);
}

// Methods meant to be used throughout the program
initialize() async {
  // Initialize notifications
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}