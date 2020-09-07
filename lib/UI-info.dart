import 'package:flutter/material.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Nowcasting/support-ux.dart' as ux;

class InfoScreen extends StatelessWidget  {

  _launchURL(String _url) async {
    if (await canLaunch(_url)) {
      await launch(_url);
    } else {
      throw 'Could not launch $_url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About MAPLE Nowcasting'),
      ),
      body: Container(
        child: 
          CustomScrollView(
          scrollDirection: Axis.vertical,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(margin: EdgeInsets.all(16), child: Image.asset('assets/launcher/icon_android.png', width: 96, height: 96)),
                          Center(child: 
                            Column(
                              children: <Widget>[
                                Container(margin: EdgeInsets.all(8), child: Text('Version 0.1', style: ux.latoForeground(context))),
                                Container(child: Text('Made with  ❤️  in  🇨🇦 ', style: ux.latoForeground(context))),
                                Row(children: [Text('Fork us on GitHub: ', style: ux.latoForeground(context)), IconButton(icon: Icon(MdiIcons.github), onPressed: () {_launchURL('https://github.com/the-salami/nowcasting');})]),
                              ],
                            )
                          )
                        ]
                      ),
                    ],
                  ),
                )
              )
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8.0),
              sliver: SliverToBoxAdapter(
                child: Center(child: Container(child: Text('FAQ', style: ux.latoForeground(context).copyWith(fontSize: 24)))),
              )
            ),
            // TODO add info about 20 min windows and missing shorter downpours when storm is moving fast, advise users to look at map screen
            // perhaps add some kind of "rain in your area" info to forecast screen to account for this
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8.0),
              sliver: SliverFixedExtentList(
                itemExtent: ux.sliverHalfThinHeight,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => new ux.IconTextSliver("How are the forecasts generated?", ux.noticeIcon, ux.nowcastingColor, () async {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        // Popup dialogue with form when edit button is pressed
                        return AlertDialog(
                          title: Text("About the Algorithm"),
                          content: SingleChildScrollView( 
                            scrollDirection: Axis.vertical,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('Researchers at McGill University developed an algorithm called MAPLE (McGill Algorithm for Precipitation Nowcasting by Lagrangian Extrapolation) that uses past radar imagery and wind directions to predict the motion of rain and snow storms. \n\nA series of papers outlining this technique was published in the Journal of Applied Meteorology. Tap below to learn more.'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: <Widget>[
                                        FlatButton(
                                          child: Text("Neat!"), 
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        Spacer(),
                                        RaisedButton(
                                          child: Text("Learn More"),
                                          color: ux.nowcastingColor,
                                          textColor: Colors.white,
                                          onPressed: () async {
                                            if (await canLaunch('https://doi.org/10.1175/1520-0493(2002)130%3C2859:SDOTPO%3E2.0.CO;2')) {
                                              await launch('https://doi.org/10.1175/1520-0493(2002)130%3C2859:SDOTPO%3E2.0.CO;2');
                                            } else {
                                              throw 'Could not launch https://doi.org/10.1175/1520-0493(2002)130%3C2859:SDOTPO%3E2.0.CO;2';
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  )
                                ],
                            ),
                          ),
                          elevation: 24.0,
                        );
                      }
                    );
                  }),
                  childCount: 1,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8.0),
              sliver: SliverFixedExtentList(
                itemExtent: ux.sliverHalfThinHeight,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => new ux.IconTextSliver("Why are there straight lines of 'rain' or other artefacts on the radar images?", ux.noticeIcon, ux.nowcastingColor, () async {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        // Popup dialogue with form when edit button is pressed
                        return AlertDialog(
                          title: Text("About Radar Anomalies"),
                          content: SingleChildScrollView( 
                            scrollDirection: Axis.vertical,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text('This is likely the result of electromagnetic interference in the region of spectrum used by Environment Canada\'s weather radars for operation. Tap below to learn more.'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: <Widget>[
                                        FlatButton(
                                          child: Text("OK"), 
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        Spacer(),
                                        RaisedButton(
                                          child: Text("Learn More"),
                                          color: ux.nowcastingColor,
                                          textColor: Colors.white,
                                          onPressed: () async {
                                            if (await canLaunch('https://www.canada.ca/en/environment-climate-change/services/weather-general-tools-resources/radar-overview/about.html#Common_interpretation_errors')) {
                                              await launch('https://www.canada.ca/en/environment-climate-change/services/weather-general-tools-resources/radar-overview/about.html#Common_interpretation_errors');
                                            } else {
                                              throw 'Could not launch https://www.canada.ca/en/environment-climate-change/services/weather-general-tools-resources/radar-overview/about.html#Common_interpretation_errors';
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  )
                                ],
                            ),
                          ),
                          elevation: 24.0,
                        );
                      }
                    );
                  }),
                  childCount: 1,
                ),
              ),
            ),
            SliverPadding(
              padding:  const EdgeInsets.symmetric(vertical: 8.0),
              sliver: SliverToBoxAdapter(
                child: Center(child: Container(child: Text('Credits', style: ux.latoForeground(context).copyWith(fontSize: 24)))),
              )
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8.0),
              sliver: SliverFixedExtentList(
                itemExtent: ux.sliverHalfThinHeight,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => new ux.IconTextSliver("Forecasts provided by McGill University", Icon(MdiIcons.weatherRainy, color: Colors.white), ux.nowcastingColor, () async {
                    if (await canLaunch('https://radar.mcgill.ca/imagery/nowcasting.html')) {
                      await launch('https://radar.mcgill.ca/imagery/nowcasting.html');
                    } else {
                      throw 'Could not launch https://radar.mcgill.ca/imagery/nowcasting.html';
                    }
                  }),
                  childCount: 1,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8.0),
              sliver: SliverFixedExtentList(
                itemExtent: ux.sliverHalfThinHeight,
                delegate: SliverChildBuilderDelegate(
                  (context, index) => new ux.IconTextSliver("Basemaps by Jawg.io", Icon(Icons.map, color: Colors.white), ux.nowcastingColor, () async {
                    if (await canLaunch('https://jawg.io')) {
                      await launch('https://jawg.io');
                    } else {
                      throw 'Could not launch https://jawg.io';
                    }
                  }),
                  childCount: 1,
                ),
              ),
            ),
          ] 
        )
      )
    );
  }
}
