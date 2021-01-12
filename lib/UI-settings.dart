import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget  {
  @override
  SettingsScreenState createState() => new SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Container()
    );
  }
}