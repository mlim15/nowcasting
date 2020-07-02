import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong/latlong.dart';
import 'package:intl/intl.dart';

//import 'package:Nowcasting/main.dart'; // Would be needed for sharedpref
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-ux.dart' as ux;

// Widgets
class ForecastScreen extends StatefulWidget  {
  @override
  ForecastScreenState createState() => new ForecastScreenState();
}

class ForecastScreenState extends State<ForecastScreen> {
  Timer _forceRebuildTimer;
  bool _editing = false;
  
  _addLocationPressed() async {
    setState(() {
      if (loc.lastKnownLocation == null || imagery.coordOutOfBounds(loc.lastKnownLocation)) {
        loc.places.add(LatLng(0, 0));
        loc.placeNames.add('New Location');
        loc.notify.add(false);
        loc.savePlaces();
      } else {
        loc.places.add(new LatLng(loc.lastKnownLocation.latitude, loc.lastKnownLocation.longitude));
        loc.placeNames.add('Copy of Current Location');
        loc.notify.add(false);
        loc.savePlaces();
      }
    });
  }

  _editPressed() async {
    _editing
    ? setState(() {
      _editing = false;
      loc.savePlaces();
    })
    : setState(() {
      _editing = true;
    });
  }
  
  _rebuild() {
    setState(() {
      // If we are rebuilding after deleting the last item
      // in the list, swap out of editing mode
      if (loc.places.length == 0) {
        _editing = false;
        loc.savePlaces();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // If initializing the screen with loading indicator, trigger
    // a rebuild every 2 seconds until actual data is available
    // and the screen can properly initialize. When this check occurs,
    // ensure that we stop further refreshes if needed.
    _forceRebuildTimer = Timer.periodic(Duration(seconds: 2), (time) {
      print('forecast.ForecastScreenState.initState: decodedForecasts is empty, trying rebuild in 2 seconds');
      setState(() {
        if (imagery.decodedForecasts.isEmpty == false) {
          if (_forceRebuildTimer != null) {
            print('forecast.ForecastScreenState.initState: Successfully built. No need for rebuild timer, stopping.');
            _forceRebuildTimer.cancel();
          }
        }
      });
    });
    if (imagery.decodedForecasts.isEmpty == false) {
      if (_forceRebuildTimer != null) {
        print('forecast.ForecastScreenState.initState: Successfully built. No need for rebuild timer, stopping.');
        _forceRebuildTimer.cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast'),
        actions: <Widget>[
          loc.places.isNotEmpty && imagery.decodedForecasts.isNotEmpty
            ? IconButton(
              icon: _editing
                ? Icon(Icons.done)
                : Icon(Icons.edit),
              onPressed: () {_editPressed();},
            )
            : Container(), 
        ],
      ),
      body: RefreshIndicator(
        color: ux.darkMode(context)
          ? Colors.white
          : ux.nowcastingColor,
        onRefresh: () async {
            await loc.updateLastKnownLocation();
            await update.radarOutages();
            if (await update.remoteImagery(context, false, true)) {
              await update.legends();
              await update.forecasts();
            }
            _rebuild();
          },
          child: CustomScrollView(
            scrollDirection: Axis.vertical,
            slivers: <Widget>[
              // Radar outage sliver
              loc.radarOutage
                ? SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: ux.sliverThinHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ux.WarningSliver(loc.radarOutageText, ux.WarningLevel.notice, url: loc.radarOutageUrl),
                      childCount: loc.radarOutage ? 1 : 0,
                    ),
                  ),
                ) 
                : SliverToBoxAdapter( 
                  child: Container(),
                ),
              // Weather alert sliver
              loc.weatherAlert
                ? SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: ux.sliverThinHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ux.WarningSliver(loc.alertText, ux.WarningLevel.alert, url: loc.alertUrl),
                      childCount: 1, //TODO loc.alerts.length? store in array for multiple location alerts?
                    ),
                  ),
                )
                : SliverToBoxAdapter( 
                  child: Container(),
                ),
              // Current location sliver
              imagery.decodedForecasts.isEmpty
                // Don't display anything if decodedForecasts is empty.
                // This would cause a build error.
                ? SliverToBoxAdapter( 
                  child: Container(),
                )
                // If decodedForecasts isn't empty, we can safely build.
                : loc.lastKnownLocation != null
                  // If current location is available
                  ? SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    sliver: SliverFixedExtentList(
                      delegate: imagery.coordOutOfBounds(loc.lastKnownLocation) == false 
                        // geoToPixel returns false if location is outside bbox. 
                        // If geoToPixel doesn't return false, build the forecast sliver:
                        ? SliverChildBuilderDelegate(
                          (context, index) => new ForecastSliver(loc.lastKnownLocation, "Current Location", -1, _editing, () {_rebuild();}),
                          childCount: 1,
                        )
                        // Otherwise, display a notice that tells the user they are out of coverage.
                        : SliverChildBuilderDelegate(
                          (context, index) => new ux.WarningSliver("McGill's Nowcasting service does not provide data for your current location.", ux.WarningLevel.notice),
                          childCount: 1,
                        ),
                      itemExtent: imagery.coordOutOfBounds(loc.lastKnownLocation) == false 
                        ? _editing
                          ? ux.sliverHeightExpanded
                          : ux.sliverHeight
                        : ux.sliverThinHeight,
                    ),
                  )
                  // If current location is unavailable
                  : SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    sliver: SliverFixedExtentList(
                      itemExtent: ux.sliverThinHeight,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => new ux.WarningSliver("Could not detect current location.", ux.WarningLevel.notice),
                        childCount: 1,
                      ),
                    ),
                  ),
              // Slivers for stored locations
              imagery.decodedForecasts.isEmpty //TODO || DateTime.parse(prefs.getString('lastDecoded')).isBefore(DateTime.parse(prefs.getString('lastLegendGen')))
                ? SliverToBoxAdapter(
                  child: Container(
                    margin: ux.sliverMargins,
                    height: ux.sliverHeight,
                    width: 64,
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
                        Container(padding: EdgeInsets.all(8), child: Text('Crunching the numbers...', style: ux.darkMode(context) ? ux.latoWhite : ux.latoBlue)),
                      ]
                    )
                  )
                )
                : loc.places.isNotEmpty
                  ? SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    sliver: SliverFixedExtentList(
                      itemExtent: _editing
                        ? ux.sliverHeightExpanded
                        : ux.sliverHeight,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => new ForecastSliver(loc.places[index], loc.placeNames[index], index, _editing, () {_rebuild();}),
                        childCount: loc.places.length,
                      ),
                    ),
                  )
                  : SliverToBoxAdapter( 
                    child: Container(),
                  ),
              // Add location sliver
              imagery.decodedForecasts.isEmpty
                ? SliverToBoxAdapter( 
                  child: Container(),
                )
                : SliverToBoxAdapter( 
                child: GestureDetector(
                  onTap: () {_addLocationPressed();},
                  child: Container(
                    margin: ux.sliverBottomMargins,
                    child: Icon(Icons.add, color: Colors.white),
                    height: ux.sliverTinyHeight,
                    decoration: new BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.rectangle,
                      borderRadius: new BorderRadius.circular(8.0),
                      boxShadow: [ux.sliverShadow],
                    ),
                  ),
                )
              )
            ],
          ),
        )
    );
  }
}

// Forecast sliver widget definition
class ForecastSliver extends StatelessWidget {
  final LatLng _location;
  final String _locName;
  final bool _editing;
  final int _index;
  final VoidCallback rebuildCallback;

  ForecastSliver(this._location, this._locName, [this._index = -1, this._editing = false, this.rebuildCallback]);

  @override
  Widget build(BuildContext context) {

    // Infer whether notifications are on/off based on passed value and
    // store locally as boolean
    bool _notify = false;
    _index != -1
      ? _notify = loc.notify[_index] 
      : _notify = loc.notifyLoc;
    
    // Keys and controllers for later use
    final _formKey = GlobalKey<FormState>();
    TextEditingController _nameTextController = new TextEditingController.fromValue(TextEditingValue(text: _locName));
    
    // Button press methods
    _notifyPressed([bool currentLoc = false]) async {
      // Toggle notify.
      _notify
        ? _notify = false
        : _notify = true;
      if (currentLoc) {
        loc.notifyLoc = _notify;
      } else {
        // Update value in array
        loc.notify[_index] = _notify;
      }
      loc.savePlaces();
    }

    // Main widget return of the build for the sliver
    // TODO this now needs a big pass for readability.
    // preferably separate out by condition into functions that
    // return their repspective subwidget, e.g. a method that returns the widget
    // to build when editing and another method when not
    //
    // also add buttons to reorder items
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
                ? _index == -1
                  // If card is for current location
                  // and we are editing
                  ? Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment(0,0), 
                          child: Column(
                            children: [
                              Row( 
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.all(6),
                                    icon: Icon(Icons.refresh, color: Colors.white), 
                                    onPressed: () async {loc.updateLastKnownLocation();Timer(Duration(seconds: 8), () {rebuildCallback();});},
                                    //padding: EdgeInsets.all(2)
                                  ),
                                  Flexible( 
                                    child: Text(
                                      _locName,
                                      style: TextStyle(fontSize: 16).merge(ux.latoWhite),
                                    )
                                  ),
                                  Spacer(),
                                  // TODO implement notifications and uncomment this button.
                                  // it already works to toggle the boolean.
                                  //IconButton(
                                  //  icon: _notify
                                  //    ? Icon(Icons.notifications_active, color: Colors.white)
                                  //    : Icon(Icons.notifications_off, color: Colors.white),
                                  //  onPressed: () {
                                  //    _notifyPressed(true);
                                  //   rebuildCallback();
                                  //  },
                                  //),
                                ]
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal, 
                                child: Row(
                                  children: [ for (int _i = 0; _i <= 8; _i++)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        children: <Widget>[
                                          Container(
                                            padding: EdgeInsets.all(2),
                                            child: imagery.dec2icon(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.rectangle,
                                              borderRadius: new BorderRadius.circular(8.0),
                                              color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)).opacity == 0
                                                ? Color(0xFF000000)
                                                : imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i))
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)), 
                                              style: ux.latoWhite
                                            ), 
                                          ),
                                          Text(DateFormat('HH:mm').format(DateTime.parse(imagery.legends[_i])), style: ux.latoWhite), 
                                          Text(DateFormat('EEE d').format(DateTime.parse(imagery.legends[_i])), style: ux.latoWhite), 
                                        ]
                                      )
                                    )
                                  ],
                                ) 
                              )
                            ]
                          )
                        )
                      )
                    ],
                  )
                  // If card is not for current location
                  // and we are editing
                  : Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Column(
                        children: <Widget>[
                          Spacer(),
                          IconButton(
                            color: Colors.white,
                            disabledColor: Colors.white.withAlpha(90),
                            icon: Icon(Icons.arrow_upward),
                            onPressed: _index == 0
                              ? null
                              : () {
                                LatLng thisPlace = loc.places[_index];
                                String thisPlaceName = loc.placeNames[_index];
                                bool thisPlaceNot = loc.notify[_index];
                                LatLng swapPlace = loc.places[_index-1];
                                String swapPlaceName = loc.placeNames[_index-1];
                                bool swapPlaceNot = loc.notify[_index-1];
                                loc.places[_index] = swapPlace;
                                loc.placeNames[_index] = swapPlaceName;
                                loc.notify[_index] = swapPlaceNot;
                                loc.places[_index-1] = thisPlace;
                                loc.placeNames[_index-1] = thisPlaceName;
                                loc.notify[_index-1] = thisPlaceNot;
                                rebuildCallback();
                              },
                          ),
                          IconButton(
                            color: Colors.white,
                            disabledColor: Colors.white.withAlpha(90),
                            icon: Icon(Icons.arrow_downward), 
                            onPressed: _index == loc.places.length-1
                              ? null
                              : () {
                                LatLng thisPlace = loc.places[_index];
                                String thisPlaceName = loc.placeNames[_index];
                                bool thisPlaceNot = loc.notify[_index];
                                LatLng swapPlace = loc.places[_index+1];
                                String swapPlaceName = loc.placeNames[_index+1];
                                bool swapPlaceNot = loc.notify[_index+1];
                                loc.places[_index] = swapPlace;
                                loc.placeNames[_index] = swapPlaceName;
                                loc.notify[_index] = swapPlaceNot;
                                loc.places[_index+1] = thisPlace;
                                loc.placeNames[_index+1] = thisPlaceName;
                                loc.notify[_index+1] = thisPlaceNot;
                                rebuildCallback();
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
                                  IconButton(
                                    padding: EdgeInsets.all(6),
                                    icon: Icon(Icons.edit, color: Colors.white), 
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          // Popup dialogue with form when edit button is pressed
                                          return AlertDialog(
                                            title: Text("Coordinates for '"+_locName+"'"),
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
                                                        initialValue: loc.places[_index].latitude.toString(),
                                                        decoration: new InputDecoration(labelText: "Latitude (35 to 51)"),
                                                        keyboardType: TextInputType.number,
                                                        onSaved: (newValue) {
                                                          loc.places[_index].latitude = double.parse(newValue);
                                                        },
                                                        validator: (newValue) {
                                                          if (double.tryParse(newValue) == null) {
                                                            return 'Invalid latitude.';
                                                          } else if (!(imagery.sw.latitude.toDouble() <= double.parse(newValue)) || !(double.parse(newValue) <= imagery.ne.latitude.toDouble())) {
                                                            return "Out of service range.";
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.all(8.0),
                                                      child: TextFormField(
                                                        initialValue: loc.places[_index].longitude.toString(),
                                                        decoration: new InputDecoration(labelText: "Longitude (-88.7 to -66.7)"),
                                                        keyboardType: TextInputType.number,
                                                        onSaved: (newValue) {
                                                          loc.places[_index].longitude = double.parse(newValue);
                                                        },
                                                        validator: (newValue) {
                                                          if (double.tryParse(newValue) == null) {
                                                            return 'Invalid longitude.';
                                                          } else if (!(imagery.sw.longitude.toDouble() <= double.parse(newValue)) || !(double.parse(newValue) <= imagery.ne.longitude.toDouble())) {
                                                            return "Out of service range.";
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Row(
                                                        children: <Widget>[
                                                          FlatButton(
                                                            child: Text("Cancel"), 
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                          Spacer(),
                                                          RaisedButton(
                                                            child: Text("Save"),
                                                            color: ux.nowcastingColor,
                                                            textColor: Colors.white,
                                                            onPressed: () {
                                                              if (_formKey.currentState.validate()) {
                                                                _formKey.currentState.save();
                                                                loc.savePlaces();
                                                                rebuildCallback();
                                                                Navigator.of(context).pop();
                                                              }
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
                                      );
                                    } ,
                                  ),
                                  Flexible( 
                                    child: TextFormField(
                                      controller: _nameTextController,
                                      style: ux.latoWhite,
                                      onChanged: (_content) {loc.placeNames[_index] = _content;},
                                    )
                                  ),
                                  // TODO implement notifications and uncomment this button.
                                  // it already works to toggle the boolean.
                                  //IconButton(
                                  //  icon: loc.notify[_index]
                                  //    ? Icon(Icons.notifications_active, color: Colors.white)
                                  //    : Icon(Icons.notifications_off, color: Colors.white),
                                  //  onPressed: () {
                                  //    _notifyPressed();
                                  //    rebuildCallback();
                                  //  },
                                  //),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.white),
                                    onPressed: () {
                                      loc.places.removeAt(_index);
                                      loc.placeNames.removeAt(_index);
                                      loc.notify.removeAt(_index);
                                      rebuildCallback();
                                    },
                                  ),
                                ]
                              ),
                              imagery.coordOutOfBounds(_location)
                                // If coordinates of the location are out of service range, display a message
                                ? Container(margin: EdgeInsets.all(8), child: Text("Tap the pencil icons to edit this entry and add valid coordinates.", style: ux.latoWhite))
                                // Otherwise read the forecast images
                                : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal, 
                                  child: Row(
                                    children: [ for (int _i = 0; _i <= 8; _i++)
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        child: Column(
                                          children: <Widget>[
                                            Container(
                                              padding: EdgeInsets.all(2),
                                              child: imagery.dec2icon(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.rectangle,
                                                borderRadius: new BorderRadius.circular(8.0),
                                                color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)).opacity == 0
                                                ? Color(0xFF000000)
                                                : imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i))
                                              ),
                                            ),
                                            Container(
                                              child: Text(
                                                imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)), 
                                                style: ux.latoWhite
                                              ), 
                                            ),
                                            Text(DateFormat('HH:mm').format(DateTime.parse(imagery.legends[_i])), style: ux.latoWhite), 
                                            Text(DateFormat('EEE d').format(DateTime.parse(imagery.legends[_i])), style: ux.latoWhite), 
                                          ]
                                        )
                                      )
                                    ],
                                  ) 
                                )
                            ]
                          )
                        )
                      )
                    ],
                  )
                // If not editing for either card
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
                              child: new Text(_locName, textAlign: TextAlign.left, style: TextStyle(fontSize: 16).merge(ux.latoWhite), overflow: TextOverflow.ellipsis),
                            ),
                            imagery.coordOutOfBounds(_location)
                              // If coordinates of the location are out of service range, display a message
                              ? Container(margin: EdgeInsets.all(8), child: Text("Tap the pencil icons to edit this entry and add valid coordinates.", style: ux.latoWhite))
                              // Otherwise read the forecast images
                              : SingleChildScrollView(
                                scrollDirection: Axis.horizontal, 
                                child: Row(
                                  children: [ for (int _i = 0; _i<=8; _i++)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        children: <Widget>[
                                          Container(
                                            padding: EdgeInsets.all(2),
                                            child: imagery.dec2icon(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.rectangle,
                                              borderRadius: new BorderRadius.circular(8.0),
                                              color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)).opacity == 0
                                              ? Color(0xFF000000)
                                              : imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i))
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i)), 
                                              style: ux.latoWhite
                                            ), 
                                          ),
                                          Text(DateFormat('HH:mm').format(DateTime.parse(imagery.legends[_i])), style: ux.latoWhite), 
                                          Text(DateFormat('EEE d').format(DateTime.parse(imagery.legends[_i])), style: ux.latoWhite), 
                                        ]
                                      )
                                    )
                                  ],
                                ) 
                              )
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

