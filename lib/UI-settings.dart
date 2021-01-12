import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-notifications.dart' as notifications;
import 'package:Nowcasting/UI-settings-places.dart';

class SettingsScreen extends StatefulWidget  {
  @override
  SettingsScreenState createState() => new SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {

  _rebuild() {
    setState(() {});
  }

  _launchURL(String _url) async {
    if (await canLaunch(_url)) {
      await launch(_url);
    } else {
      throw 'Could not launch $_url';
    }
  }

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SettingsList(
          darkBackgroundColor: ux.darkTheme.canvasColor,
          lightBackgroundColor: ux.lightTheme.canvasColor,
          sections: [
            CustomSection(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(),
                  ),
                ],
              ),
            ),
            SettingsSection(
              title: 'Notifications',
              tiles: [
                SettingsTile.switchTile(
                  switchActiveColor: ux.nowcastingColor,
                  title: 'Enable Notifications',
                  leading: Icon(Icons.notifications),
                  switchValue: notifications.notificationsEnabled,
                  onToggle: (bool value) async {
                    if (value) {
                      // To turn them on on iOS, we'll need permissions.
                      if (Platform.isIOS && await notifications.flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true)) {
                        ux.showSnackBarIf(true, ux.notificationPermissionErrorSnack, context);
                        return;
                      }
                    }
                    // Toggle
                    setState(() {
                      notifications.notificationsEnabled = value;
                      if (value) {
                        notifications.scheduleBackgroundFetch();
                        if (!notifications.anyNotificationsEnabled()) {
                          // I considered snowing a snack but I think it's more intuitive
                          // for users for us to just do this.
                          loc.currentLocation.notify = true;
                        }
                      } else {
                        notifications.cancelBackgroundFetch();
                      }
                    });
                  },
                ),
                SettingsTile(
                  title: 'Locations',
                  enabled: notifications.notificationsEnabled,
                  subtitle: (notifications.notificationsEnabled)
                    ? (notifications.countEnabledLocations() != 0) 
                      ? 'Notifications enabled for '+notifications.countEnabledLocations().toString()+' locations.' 
                      : 'Tap to choose locations to notify for.'
                    : 'Notifications are disabled.',
                  leading: Icon(Icons.language),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => PlaceSettingsScreen(_rebuild)));
                  },
                  trailing: Icon(MdiIcons.menuRight)
                ),
                SettingsTile.switchTile(
                  // This could be more configurable but for now
                  // it will be presented to the user as an on/off
                  title: 'Ignore Drizzle',
                  switchActiveColor: ux.nowcastingColor,
                  enabled: notifications.notificationsEnabled,
                  leading: Icon(MdiIcons.weatherPartlyRainy),
                  onToggle: (bool value) {
                    setState(() {
                      if (value) {
                        // Turning on
                        notifications.severityThreshold = 1;
                      } else {
                        // Turning off
                        notifications.severityThreshold = 0;
                      }
                    });
                  },
                  switchValue: (notifications.severityThreshold == 1)
                ),
                SettingsTile(
                  title: 'Check Max Once per...',
                  subtitle: notifications.minimumTimeBetween.inMinutes.toString()+' Minutes',
                  enabled: notifications.notificationsEnabled,
                  leading: Icon(Icons.timer),
                  trailing: Container(
                    width: 128,
                    child: Slider.adaptive(
                      activeColor: ux.nowcastingColor,
                      min: 15,
                      max: 60,
                      divisions: 4,
                      value: notifications.checkIntervalMinutes.toDouble(),
                      onChanged: notifications.notificationsEnabled ? 
                        (value) {
                          setState(() {
                            notifications.checkIntervalMinutes = value.toInt();
                            notifications.updateDataUsageEstimate();                 
                          });
                          io.saveNotificationPreferences();
                        }
                        : null,
                    )
                  ),
                ),
                SettingsTile(
                  title: 'Looking Ahead...',
                  subtitle: (20+notifications.maxLookahead*20).toString()+' Minutes',
                  enabled: notifications.notificationsEnabled,
                  leading: Icon(MdiIcons.crystalBall),
                  trailing: Container(
                    width: 128,
                    child: Slider.adaptive(
                      activeColor: ux.nowcastingColor,
                      min: 0,
                      max: 8,
                      divisions: 9,
                      value: notifications.maxLookahead.toDouble(),
                      onChanged: notifications.notificationsEnabled ? 
                        (value) {
                          notifications.updateDataUsageEstimate();
                          setState(() {
                            notifications.maxLookahead = value.toInt();
                          });
                          io.saveNotificationPreferences();
                        }
                        : null,
                    )
                  )
                ),
                SettingsTile(
                  title: 'Estimated Data Usage',
                  subtitle: notifications.notificationsEnabled ? 'Up to '+notifications.dataUsage.toStringAsFixed(1)+' MB/day' : 'No data will be used in the background.',
                  leading: Icon(MdiIcons.gauge),
                ),
              ],
            ),
            SettingsSection(
              title: 'Information',
              tiles: [
                SettingsTile(
                  title: 'Privacy Policy', 
                  leading: Icon(Icons.description),
                  onTap: () {
                    _launchURL('https://raw.githubusercontent.com/mlim15/nowcasting/master/privacy-policy.txt');
                  },
                ),
                //SettingsTile(
                //  title: 'Source Licenses',
                //  leading: Icon(Icons.collections_bookmark),
                //  onTap: () {
                //    
                //  }
                //),
              ],
            )
          ],
        ),
    );
  }
}