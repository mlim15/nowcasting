import 'package:flutter/material.dart';

import 'package:Nowcasting/support-update.dart' as update;

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
        onPressed: () { setState(() {update.remoteImagery(context, false, true);});},
      ),
    );
  }
}