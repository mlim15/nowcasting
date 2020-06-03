import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

import 'package:image/image.dart' as imglib;

import 'package:Nowcasting/main.dart';

// Variables for this class
imglib.PngDecoder pngDecoder = new imglib.PngDecoder();
List<imglib.Image> forecasts;

// Helper functions
coordinateToPixel(LatLng coordinates) {
  double percEast;
  double percSouth;
  
}

getPixelValue(int x, int y, int index) {
  forecasts[index].getPixel(x, y);
}

// Widgets
class ForecastScreen extends StatefulWidget  {
  @override
  ForecastScreenState createState() => new ForecastScreenState();
}

class ForecastScreenState extends State<ForecastScreen> {
  @override
  void initState() {
    super.initState();
    safeUpdate();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast'),
      ),
      body: Text('Forecast'),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () { setState(() {refreshImages(context, false, true);});},
      ),
    );
  }
}