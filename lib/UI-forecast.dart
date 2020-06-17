import 'package:Nowcasting/support-ux.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// TODO beautify, use location data cached by support-location instead of the test coord below, add notice about outages due to environment canada maintenance

// Widgets
class ForecastScreen extends StatefulWidget  {
  @override
  ForecastScreenState createState() => new ForecastScreenState();
}

class ForecastScreenState extends State<ForecastScreen> {
  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast'),
      ),
      body: loc.places.length != 0 ?
      RefreshIndicator(
        onRefresh: () async {
            if (await update.remoteImagery(context, false, true)) {
              await update.legends();
              await update.forecasts();
              await loc.getUserLocation();
              setState( () {});
            }
          },
          child: CustomScrollView(
            scrollDirection: Axis.vertical,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                sliver: SliverFixedExtentList(
                  itemExtent: 152.0,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => new ForecastSliver(loc.places[index]),
                    childCount: loc.places.length,
                  ),
                ),
              ),
            ],
          ),
        )
        : Center(child: CircularProgressIndicator()),
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
  final LatLng location;
  ForecastSliver(this.location);

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
                          Row(children: <Widget>[Text(location.toString(), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)))]),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal, 
                            child: Row(children: [ for (int i=0; i<=8; i++)
                              new Container(
                                padding: EdgeInsets.all(4),
                                child: Column(
                                  children: <Widget>[
                                    Icon(Icons.wb_sunny),
                                    Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(location.latitude, location.longitude)[0], imagery.geoToPixel(location.latitude, location.longitude)[1], i)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(location.latitude, location.longitude)[0], imagery.geoToPixel(location.latitude, location.longitude)[1], i))),
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