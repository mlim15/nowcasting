import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget  {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About MAPLE Nowcasting'),
      ),
      body: Container(
        child: Row(
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
      )
    );
  }
}