import 'package:flutter/material.dart';

import 'package:settings_ui/settings_ui.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-location.dart' as loc;

class PlaceSettingsScreen extends StatefulWidget  {
  final VoidCallback rebuildCallback;

  PlaceSettingsScreen(this.rebuildCallback);

  @override
  PlaceSettingsScreenState createState() => new PlaceSettingsScreenState(rebuildCallback);
}

class PlaceSettingsScreenState extends State<PlaceSettingsScreen> {

  final VoidCallback rebuildCallback;

  PlaceSettingsScreenState(this.rebuildCallback);

  SettingsTile _makeEntry(loc.NowcastingLocation location) {
    return SettingsTile.switchTile(
      switchActiveColor: ux.nowcastingColor,
      title: location.name,
      switchValue: location.notify,
      onToggle: (bool value) {
        // Toggle
        setState(() {
          location.notify = value;
        });
        rebuildCallback();
      },
    );
  }

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
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