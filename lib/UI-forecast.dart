import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;

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
                  Icon(Icons.warning), 
                  Text("Under Construction")
                ]
              )
            )
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () async {
          // for debugging coordinate/pixel conversion
          //List<int> coord = imagery.coordinateToPixel(LatLng(43.5,-80.5));
          //print(coord.toString());
          //print(imagery.decodedForecasts[1].getPixelSafe(coord[0], coord[1]));
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