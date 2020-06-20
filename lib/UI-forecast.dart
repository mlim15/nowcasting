import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
      if (loc.lastKnownLocation == null) {
        loc.places.add(LatLng(45.504688, -73.574990));
        loc.placeNames.add('New Saved Location');
        loc.notify.add(false);
        loc.savePlaces();
      } else {
        loc.places.add(loc.lastKnownLocation);
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
        onRefresh: () async {
            await loc.updateLastKnownLocation();
            await update.radarOutages();
            if (await update.remoteImagery(context, false, true)) {
              await update.legends();
              await update.forecasts();
              setState( () {});
            }
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
                      (context, index) => new WarningSliver(loc.radarOutageText, ux.WarningLevel.notice, loc.radarOutageUrl),
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
                      (context, index) => new WarningSliver(loc.alertText, ux.WarningLevel.alert, loc.alertUrl),
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
                      delegate: imagery.geoToPixel(loc.lastKnownLocation.latitude, loc.lastKnownLocation.longitude) != false 
                        // geoToPixel returns false if location is outside bbox. 
                        // If geoToPixel doesn't return false, build the forecast sliver:
                        ? SliverChildBuilderDelegate(
                          (context, index) => new ForecastSliver(loc.lastKnownLocation, "Current Location", -1, _editing, () {_rebuild();}),
                          childCount: 1,
                        )
                        // Otherwise, display a notice that tells the user they are out of coverage.
                        : SliverChildBuilderDelegate(
                          (context, index) => new WarningSliver("McGill's Nowcasting service does not provide data for your current location.", ux.WarningLevel.notice),
                          childCount: 1,
                        ),
                      itemExtent: imagery.geoToPixel(loc.lastKnownLocation.latitude, loc.lastKnownLocation.longitude) != false 
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
                        (context, index) => new WarningSliver("Could not detect current location.", ux.WarningLevel.notice),
                        childCount: 1,
                      ),
                    ),
                  ),
              // Slivers for stored locations
              imagery.decodedForecasts.isEmpty
                ? SliverToBoxAdapter(
                  child: Container(
                    margin: ux.sliverMargins,
                    height: ux.sliverHeight,
                    width: 64,
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Container(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor))),
                        Container(padding: EdgeInsets.all(8), child: Text('Crunching the numbers...', style: ux.latoBlue)),
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
                    child: Icon(Icons.add, color: Theme.of(context).buttonColor),
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
    bool _notify = false;
    _index != -1
      ? _notify = loc.notify[_index] 
      : _notify = loc.notifyLoc;
    TextEditingController _textController = new TextEditingController.fromValue(TextEditingValue(text: _locName));
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
    // TODO this now needs a big pass for readability.
    // preferably separate out by condition into functions that
    // return their repspective subwidget.
    // also add buttons to reorder?
    // TODO also fix blue text on loader, add button when in dark mode
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
                                    onPressed: () async {loc.updateLastKnownLocation();},
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
                                  children: [ for (int _i = 0, _decValue = imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i); _i<=8; _i++)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        children: <Widget>[
                                          Container(
                                            padding: EdgeInsets.all(2),
                                            child: imagery.dec2hex(_decValue) == Color(0xFF000000)
                                              ? Icon(Icons.wb_sunny, color: Colors.white)
                                              : imagery.dec2icon(_decValue),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.rectangle,
                                              borderRadius: new BorderRadius.circular(8.0),
                                              color: imagery.dec2hex(_decValue) == Color(0xFF000000)
                                              ? Color(0xFF000000)
                                              : imagery.dec2hex(_decValue)
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              imagery.dec2desc(_decValue), 
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
                                      // TODO call location picker here and update sliver's location
                                    } ,
                                    //padding: EdgeInsets.all(2)
                                  ),
                                  Flexible( 
                                    child: TextFormField(
                                      controller: _textController,
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
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal, 
                                child: Row(
                                  children: [ for (int _i = 0, _decValue = imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i); _i<=8; _i++)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      child: Column(
                                        children: <Widget>[
                                          Container(
                                            padding: EdgeInsets.all(2),
                                            child: imagery.dec2hex(_decValue) == Color(0xFF000000)
                                              ? Icon(Icons.wb_sunny, color: Colors.white)
                                              : imagery.dec2icon(_decValue),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.rectangle,
                                              borderRadius: new BorderRadius.circular(8.0),
                                              color: imagery.dec2hex(_decValue) == Color(0xFF000000)
                                              ? Color(0xFF000000)
                                              : imagery.dec2hex(_decValue)
                                            ),
                                          ),
                                          Container(
                                            child: Text(
                                              imagery.dec2desc(_decValue), 
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
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal, 
                              child: Row(
                                children: [ for (int _i = 0, _decValue = imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], _i); _i<=8; _i++)
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    child: Column(
                                      children: <Widget>[
                                        Container(
                                          padding: EdgeInsets.all(2),
                                          child: imagery.dec2hex(_decValue) == Color(0xFF000000)
                                            ? Icon(Icons.wb_sunny, color: Colors.white)
                                            : imagery.dec2icon(_decValue),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.rectangle,
                                            borderRadius: new BorderRadius.circular(8.0),
                                            color: imagery.dec2hex(_decValue) == Color(0xFF000000)
                                            ? Color(0xFF000000)
                                            : imagery.dec2hex(_decValue)
                                          ),
                                        ),
                                        Container(
                                          child: Text(
                                            imagery.dec2desc(_decValue), 
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

class WarningSliver extends StatelessWidget {
  final String _warningText;
  final ux.WarningLevel _warningLevel;
  final String _url;
  WarningSliver(this._warningText, this._warningLevel, [this._url]);

  _launchURL() async {
    if (await canLaunch(_url)) {
      await launch(_url);
    } else {
      throw 'Could not launch $_url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      margin: ux.sliverMargins,
      child: new GestureDetector(
        onTap: _url != null
          ? () {
            _launchURL();
          } 
          : () {
            // Do nothing if _url is null
          },
        child: Stack(
          children: <Widget>[
            new Container(
              decoration: new BoxDecoration(
                color: _warningLevel == ux.WarningLevel.alert
                  ? ux.alertColor
                  : _warningLevel == ux.WarningLevel.warning 
                    ? ux.warningColor
                    : ux.noticeColor, // else it's a notice
                shape: BoxShape.rectangle,
                borderRadius: new BorderRadius.circular(8.0),
                boxShadow: [ux.sliverShadow],
              ),
              child: new Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment(0,0), 
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6), 
                            child: _warningLevel == ux.WarningLevel.alert
                              ? ux.alertIcon
                              : _warningLevel == ux.WarningLevel.warning 
                                ? ux.warningIcon
                                : ux.noticeIcon, // else it's a notice
                          ),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.all(6), 
                              child: Text(_warningText, style: ux.latoWhite)
                            )
                          ),
                        ]
                      )
                    ),
                  )
                ],
              ),  
            ),
          ],
        )
      )
    );
  }
}