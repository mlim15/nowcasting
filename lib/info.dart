import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget  {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('About MAPLE Nowcasting'),
        ),
        body: Container(
            child: Text('Information')
        )
    );
  }
}