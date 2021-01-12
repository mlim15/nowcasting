import 'package:flutter/material.dart';

import 'package:settings_ui/settings_ui.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-io.dart' as io;

class PlaceSettingsScreen extends StatefulWidget  {
  final VoidCallback rebuildCallback;

  PlaceSettingsScreen(this.rebuildCallback);

  @override
  PlaceSettingsScreenState createState() => new PlaceSettingsScreenState(rebuildCallback);
}

class PlaceSettingsScreenState extends State<PlaceSettingsScreen> {
  GlobalKey<ScaffoldState> _placeSettingsScaffoldKey = GlobalKey();
  final VoidCallback rebuildCallback;

  PlaceSettingsScreenState(this.rebuildCallback);

  SettingsTile _makeEntry(loc.NowcastingLocation location) {
    return SettingsTile.switchTile(
      switchActiveColor: ux.nowcastingColor,
      title: location.name,
      switchValue: location.notify,
      onToggle: (bool value) async {
        // If we are turning on the location specifically for the Current Location
        // entry, check for location permissions first.
        if (location is loc.CurrentLocation && location.coordinates == null) {
          if (!await loc.currentLocation.update(withRequests: true)) {
            _placeSettingsScaffoldKey.currentState.showSnackBar(ux.notificationLocPermissionErrorSnack);
            return;
          }
        }
        // Toggle
        setState(() {
          location.notify = value;
          io.savePlaceData();
        });
        rebuildCallback();
      },
    );
  }

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      key: _placeSettingsScaffoldKey,
      appBar: AppBar(
        title: const Text('Locations'),
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
              title: 'Notifications for...',
              tiles: [ 
                _makeEntry(loc.currentLocation),
                for (loc.NowcastingLocation location in loc.savedPlaces) _makeEntry(location)
              ]
            )
          ],
        ),
    );
  }
}