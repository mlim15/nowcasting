import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;

LatLng testCoord = ***REMOVED***;

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
      body: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment(0,0), 
              child: Column(
                children: [
                  Row(children: <Widget>[Text(testCoord.toString())],),
                  Row(children: <Widget>[Text(imagery.legends[0]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 0)))]),
                  Row(children: <Widget>[Text(imagery.legends[1]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 1)))]),
                  Row(children: <Widget>[Text(imagery.legends[2]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 2)))]),
                  Row(children: <Widget>[Text(imagery.legends[3]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 3)))]),
                  Row(children: <Widget>[Text(imagery.legends[4]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 4)))]),
                  Row(children: <Widget>[Text(imagery.legends[5]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 5)))]),
                  Row(children: <Widget>[Text(imagery.legends[6]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 6)))]),
                  Row(children: <Widget>[Text(imagery.legends[7]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 7)))]),
                  Row(children: <Widget>[Text(imagery.legends[8]), Container(child: Icon(Icons.info, color: Color(0x00000000)), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 8)))]),
                ]
              )
            )
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () async {
          if (await update.remoteImagery(context, false, true)) {
            await update.legends();
            await update.forecasts();
            setState( () {});
          }
        },
      ),
    );
  }
}