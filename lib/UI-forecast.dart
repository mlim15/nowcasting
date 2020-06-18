import 'dart:async';

import 'package:Nowcasting/support-ux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong/latlong.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// TODO beautify
// TODO add a grey 'add location' sliver with a plus sign to bottom of the list that adds a new card or brings up a menu to add a new card 

// Widgets
class ForecastScreen extends StatefulWidget  {
  @override
  ForecastScreenState createState() => new ForecastScreenState();
}

class ForecastScreenState extends State<ForecastScreen> {
  @override
  void initState() {
    super.initState();
    // If initializing the screen with loading indicator, trigger
    // a rebuild every 2 seconds until actual data is available
    // and the screen can properly initialize
    imagery.decodedForecasts.isEmpty ? 
      Timer.periodic(Duration(seconds: 2), (time) {
        setState(() {});
      }) 
      : null;
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
            if (await update.remoteImagery(context, false, true)) {
              await update.legends();
              await update.forecasts();
              await loc.updateLastKnownLocation();
              setState( () {});
            }
          },
          child: CustomScrollView(
            scrollDirection: Axis.vertical,
            slivers: <Widget>[
              loc.radarOutage ? 
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: 96.0,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new WarningSliver(loc.radarOutageText, loc.radarOutageUrl),
                      childCount: loc.radarOutage ? 1 : 0,
                    ),
                  ),
                ) : SliverToBoxAdapter( 
                  child: Container(),
                ),
              loc.weatherAlert ? 
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: 96.0,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new WarningSliver(loc.alertText, loc.alertUrl),
                      childCount: 1, //loc.alerts.length? store in array?
                    ),
                  ),
                )
                : SliverToBoxAdapter( 
                  child: Container(),
                ),
              imagery.decodedForecasts.isEmpty ?
                SliverToBoxAdapter(
                  child: Container(
                    height: 64,
                    width: 64,
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                        Container(padding: EdgeInsets.all(8), child: Text('Crunching the numbers...', style: GoogleFonts.lato(fontWeight: FontWeight.w400, color: Theme.of(context).primaryColor))),
                      ]
                    )
                  )
                )
                : SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: 152.0,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ForecastSliver(loc.places[index], index),
                      childCount: loc.places.length,
                    ),
                  ),
                ),
            ],
          ),
        )
      // 
      //floatingActionButton: FloatingActionButton(
      //  child: Icon(Icons.add),
      //  onPressed: () async {
      //    // TODO
      //  },
      //),
    );
  }
}

// Forecast sliver widget definition
class ForecastSliver extends StatelessWidget {
  final LatLng _location;
  final int _index;
  ForecastSliver(this._location, this._index);

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: 128.0,
      margin: const EdgeInsets.symmetric(
        vertical: 12.0,
        horizontal: 18.0,
      ),
      child: new Stack(
        children: <Widget>[
          new Container(
            height: 128.0,
            decoration: new BoxDecoration(
              color: nowcastingColor,
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
              child: new Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment(0,0), 
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6), 
                              child: new Text(loc.placeNames[_index].toString(), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)))
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal, 
                              child: Row(children: [ for (int i=0; i<=8; i++)
                                new Container(
                                  padding: EdgeInsets.all(4),
                                  child: Column(
                                    children: <Widget>[
                                      Icon(Icons.wb_sunny),
                                      Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], i)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(_location.latitude, _location.longitude)[0], imagery.geoToPixel(_location.latitude, _location.longitude)[1], i))),
                                      Text(DateFormat('HH:mm').format(DateTime.parse(imagery.legends[i])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), 
                                      Text(DateFormat('EEE d').format(DateTime.parse(imagery.legends[i])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), 
                                    ]
                                  )
                                )
                              ],) 
                            )
                          ]
                        )
                      )
                    )
                  ],
                ),
            ),      
         ),
        ],
      )
    );
  }
}

class WarningSliver extends StatelessWidget {
  final String _warningText;
  final String _url;
  WarningSliver(this._warningText, this._url);

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
      margin: const EdgeInsets.symmetric(
        vertical: 12.0,
        horizontal: 18.0,
      ),
      child: new GestureDetector(
        onTap: () {
          _launchURL();
        },
        child: Stack(
          children: <Widget>[
            new Container(
              decoration: new BoxDecoration(
              color: Color(0xFFEF5A5A),
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
            child: new Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment(0,0), 
                    child: Row(
                      children: [
                        Container(padding: EdgeInsets.all(6), child: Icon(Icons.warning, color: Colors.white)),
                        Flexible(child: Container(padding: EdgeInsets.all(6), child: Text(_warningText, style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))))),
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