import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

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
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[0])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 0)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 0)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[1])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 1)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 1)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[2])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 2)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 2)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[3])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 3)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 3)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[4])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 4)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 4)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[5])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 5)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 5)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[6])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 6)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 6)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[7])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 7)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 7)))]),
                  Row(children: <Widget>[Text(DateFormat('EEE MMM d @ HH:mm').format(DateTime.parse(imagery.legends[8])), style: GoogleFonts.lato(fontWeight: FontWeight.w600)), Container(child: Text(imagery.dec2desc(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 8)), style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF))), color: imagery.dec2hex(imagery.getPixelValue(imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[0], imagery.geoToPixel(testCoord.latitude, testCoord.longitude)[1], 8)))]),
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
            await loc.getUserLocation();
            setState( () {});
          }
        },
      ),
    );
  }
}