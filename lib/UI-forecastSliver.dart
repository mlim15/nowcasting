import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

//import 'package:Nowcasting/main.dart'; // Would be needed for sharedpref
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-notifications.dart' as notifications;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/UI-locationPicker.dart';

// Forecast sliver widget definition
class ForecastSliver extends StatelessWidget {
  final bool _editing;
  final VoidCallback rebuildCallback;
  final loc.NowcastingLocation location;

  ForecastSliver(this.location, [this._editing = false, this.rebuildCallback]);

  Widget _showFailed() {
    return Column(
      children: [
        Padding(child: Icon(Icons.warning), padding: EdgeInsets.only(top: 16)),
        Padding(child: Text("Error: Decoding failed. Pull to refresh.", style: ux.latoWhite), padding: EdgeInsets.all(4))
      ]
    );
  }

  @override
  Widget build(BuildContext context) {

    // Infer whether notifications are on/off based on passed value and
    // store locally as boolean
    bool _notify = this.location.notify;

    // Keys and controllers for later use
    final _formKey = GlobalKey<FormState>();
    final _latControl = TextEditingController();
    final _lonControl = TextEditingController();
    TextEditingController _nameTextController = new TextEditingController.fromValue(TextEditingValue(text: this.location.name));

    // Button press methods
    _notifyPressed() async {
      // Request permissions on iOS if necessary
      if (Platform.isAndroid || await notifications.flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true)) {
        // We have permission to display notifications.
        // Toggle notify.
        _notify
          ? _notify = false
          : _notify = true;
        rebuildCallback();
        this.location.notify = _notify;
        io.savePlaceData();
      } else {
        // Display a snackbar to the user saying they need to grant permission
        ux.showSnackBarIf(true, ux.notificationPermissionErrorSnack, context);
      }
    }

    AlertDialog editPopup(bool _isEditable) {
      // Set initial text values using the controllers for each text field
      _latControl.text = this.location.coordinates.latitude.toString();
      _lonControl.text = this.location.coordinates.longitude.toString();

      return AlertDialog(
        title: Text("Coordinates for '"+this.location.name+"'"),
        content: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _latControl,
                    decoration: new InputDecoration(labelText: "Latitude (35 to 51)"),
                    keyboardType: TextInputType.number,
                    validator: (newValue) {
                      if (double.tryParse(newValue) == null) {
                        return 'Invalid latitude.';
                      } else if (!(imagery.sw.latitude.toDouble() <= double.parse(newValue)) || !(double.parse(newValue) <= imagery.ne.latitude.toDouble())) {
                        return "Out of service range.";
                      }
                      return null;
                    },
                    readOnly: !_isEditable,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _lonControl,
                    decoration: new InputDecoration(labelText: "Longitude (-88.7 to -66.7)"),
                    keyboardType: TextInputType.number,
                    validator: (newValue) {
                      if (double.tryParse(newValue) == null) {
                        return 'Invalid longitude.';
                      } else if (!(imagery.sw.longitude.toDouble() <= double.parse(newValue)) || !(double.parse(newValue) <= imagery.ne.longitude.toDouble())) {
                        return "Out of service range.";
                      }
                      return null;
                    },
                    readOnly: !_isEditable,
                  ),
                ),
                this.location is! loc.CurrentLocation 
                  ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Spacer(),
                        RaisedButton(
                          child: Text("Choose Location"),
                          color: ux.nowcastingColor,
                          textColor: Colors.white,
                          onPressed: () async {
                            LatLng _chosenLoc = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationPickerScreen(this.location),
                              ),
                            );
                            if (_chosenLoc != null) {
                              _latControl.text = _chosenLoc.latitude.toString();
                              _lonControl.text = _chosenLoc.longitude.toString();
                            }
                          }
                        ),
                        Spacer()
                      ],
                    )
                  )
                  : Container(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: <Widget>[
                      FlatButton(
                        child: _isEditable
                          ? Text("Cancel")
                          : Text("Close"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      Spacer(),
                      RaisedButton(
                        child: _isEditable
                          ? Text("Save")
                          : Text("Update"),
                        color: ux.nowcastingColor,
                        textColor: Colors.white,
                        onPressed: _isEditable
                          ? () {
                            if (_formKey.currentState.validate()) {
                              this.location.coordinates = new LatLng(double.parse(_latControl.text), double.parse(_lonControl.text));
                              io.savePlaceData();
                              rebuildCallback();
                              Navigator.of(context).pop();
                            }
                          }
                          : () async {
                            ux.showSnackBarIf(true, ux.updatingLocationSnack,context);
                            bool _updateSucceeded = await loc.currentLocation.update();
                            rebuildCallback();
                            Navigator.of(context).pop();
                            _updateSucceeded
                              ? ux.showSnackBarIf(true, ux.locationUpdatedSnack,context)
                              : ux.showSnackBarIf(true, ux.locationOffSnack,context);
                          },
                      ),
                    ],
                  )
                )
              ],
            ),
          ),
        ),
        elevation: 24.0,
      );
    }

    // Builds the inset horizontal scroll view with the actual forecast for each sliver
    Future<Widget> populateForecast() async {
      List<String> _pixelValues = [];
      for (int _i = 0; _i <= 8; _i++) {
        _pixelValues.add(await imagery.getPixel(imagery.nowcasts[_i], this.location));
      }
      if (_pixelValues.contains(null)) {
        return _showFailed();
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [ for (int _i = 0; _i <= 8; _i++)
            Container(
              padding: EdgeInsets.all(8),
              child: Column(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(2),
                    child: imagery.convert(_pixelValues[_i], imagery.NowcastDataType.icon),
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: new BorderRadius.circular(8.0),
                      color: imagery.convert(_pixelValues[_i], imagery.NowcastDataType.colorObj)
                    ),
                  ),
                  Container(
                    child: Text(imagery.convert(_pixelValues[_i], imagery.NowcastDataType.description), style: ux.latoWhite),
                  ),
                  Text(DateFormat('HH:mm').format(imagery.nowcasts[_i].legend), style: ux.latoWhite),
                  Text(DateFormat('EEE d').format(imagery.nowcasts[_i].legend), style: ux.latoWhite),
                ]
              )
            )
          ]
        )
      );
    }

    Widget futureBuilder() {
      return FutureBuilder<Widget>(
        future: populateForecast(),
        builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Padding(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)), padding: EdgeInsets.only(top: 16));
          } else if (snapshot.data == null) {
            print(snapshot.error.toString());
            return _showFailed();
          } else {
            return snapshot.data;
          }
        },
      );
    }

    // Main widget return of the build for the sliver
    return new Container(
      height: _editing
        ? ux.sliverHeightExpanded
        : ux.sliverHeight,
      margin: ux.sliverMargins,
      child: new Stack(
        children: <Widget>[
          new Container(
            decoration: new BoxDecoration(
              color: _editing
                ? ux.noticeColor
                : ux.nowcastingColor,
              shape: BoxShape.rectangle,
              borderRadius: new BorderRadius.circular(8.0),
              boxShadow: <BoxShadow>[
                new BoxShadow(  
                  color: Colors.black12,
                  blurRadius: 10.0,
                  offset: new Offset(0.0, 10.0),
                ),
              ],
            ),
            child: new Container(
              child: _editing
                // If editing
                ? Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Column(
                      children: <Widget>[
                        Spacer(),
                        IconButton(
                          color: Colors.white,
                          disabledColor: Colors.white.withAlpha(90),
                          icon: Icon(Icons.arrow_upward),
                          onPressed: ((this.location is loc.CurrentLocation) || (loc.savedPlaces.first == this.location))
                            ? null // Disable the "up" button if it's first in the list or the current location box
                            : () {
                              int _index = loc.savedPlaces.indexOf(this.location);
                              loc.SavedLocation _thisLoc = loc.savedPlaces[_index];
                              loc.savedPlaces[_index] = loc.savedPlaces[_index-1];
                              loc.savedPlaces[_index-1] = _thisLoc;
                              rebuildCallback();
                              io.savePlaceData();
                            },
                        ),
                        IconButton(
                          color: Colors.white,
                          disabledColor: Colors.white.withAlpha(90),
                          icon: Icon(Icons.arrow_downward), 
                          onPressed: ((this.location is loc.CurrentLocation) || (loc.savedPlaces.last == this.location))
                            ? null // Disable the "down" button if it's the last in the list  or the current location box
                            : () {
                              int _index = loc.savedPlaces.indexOf(this.location);
                              loc.SavedLocation _thisLoc = loc.savedPlaces[_index];
                              loc.savedPlaces[_index] = loc.savedPlaces[_index+1];
                              loc.savedPlaces[_index+1] = _thisLoc;
                              rebuildCallback();
                              io.savePlaceData();
                            },
                        ),
                        Spacer(),
                      ],
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment(0,0), 
                        child: Column(
                          children: [
                            Row( 
                              children: [
                                this.location is loc.CurrentLocation
                                  ? IconButton(
                                      icon: Icon(Icons.info, color: Colors.white),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return editPopup(false);
                                          }
                                        );
                                      }
                                    )
                                  : IconButton(
                                    padding: EdgeInsets.all(6),
                                    icon: Icon(Icons.edit, color: Colors.white), 
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return editPopup(true);
                                        }
                                      );
                                    } ,
                                  ),
                                this.location is loc.CurrentLocation
                                  ? Expanded(child: Text("Current Location", textAlign: TextAlign.left, style: TextStyle(fontSize: 16).merge(ux.latoWhite), overflow: TextOverflow.ellipsis))
                                  : Flexible( 
                                    child: TextFormField(
                                      controller: _nameTextController,
                                      style: ux.latoWhite,
                                      onChanged: (_content) {this.location.name = _content;},
                                    )
                                  ),
                                IconButton(
                                icon: this.location.notify
                                  ? Icon(Icons.notifications_active, color: Colors.white)
                                  : Icon(Icons.notifications_off, color: Colors.white),
                                  onPressed: () {_notifyPressed();},
                                ),
                                this.location is loc.CurrentLocation
                                  ? Container()
                                  : IconButton(
                                    icon: Icon(Icons.delete, color: Colors.white),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text("Confirm"),
                                            content: SingleChildScrollView( 
                                              scrollDirection: Axis.vertical,
                                              child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    Padding(
                                                      padding: EdgeInsets.all(2.0),
                                                      child: Text("Delete '"+this.location.name+"'?")
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Row(
                                                        children: <Widget>[
                                                          FlatButton(
                                                            child: Text("Cancel"),
                                                            onPressed: () async {
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                          Spacer(),
                                                          RaisedButton(
                                                            child: Text("Delete"),
                                                            color: ux.nowcastingColor,
                                                            textColor: Colors.white,
                                                            onPressed: () async {
                                                              loc.savedPlaces.remove(this.location);
                                                              rebuildCallback();
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                        ],
                                                      )
                                                    )
                                                  ],
                                              ),
                                            ),
                                            elevation: 24.0,
                                          );
                                        }
                                      );

                                    },
                                  ),
                              ]
                            ),
                            imagery.coordOutOfBounds(this.location.coordinates)
                              // If coordinates of the location are out of service range, display a message
                              ? Container(margin: EdgeInsets.all(8), child: Text("Tap the pencil icons to edit this entry and add valid coordinates.", style: ux.latoWhite))
                              // Otherwise read the forecast images
                              : futureBuilder()
                          ]
                        )
                      )
                    )
                  ],
                )
                // If not editing
                : Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment(0,0), 
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8), 
                              child: new Text(this.location.name, textAlign: TextAlign.left, style: TextStyle(fontSize: 16).merge(ux.latoWhite), overflow: TextOverflow.ellipsis),
                            ),
                            imagery.coordOutOfBounds(this.location.coordinates)
                              // If coordinates of the location are out of service range, display a message
                              ? Container(margin: EdgeInsets.all(8), child: Text("Tap the pencil icons to edit this entry and add valid coordinates.", style: ux.latoWhite))
                              // Otherwise read the forecast images
                              : futureBuilder()
                          ]
                        )
                      )
                    )
                  ],
                ),
            ),      
          ),
        ],)
    );
  }
}