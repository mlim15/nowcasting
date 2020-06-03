import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_progress_button/flutter_progress_button.dart';

import 'package:Nowcasting/main.dart';

bool cachedSuccessfully = false;

final downloadErrorSnack = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Couldn\'t download data! Try again later.'));
final cannotProceedError = SnackBar(behavior: SnackBarBehavior.floating, content: Text('Can\'t proceed without map data! Go back and download it.'));

class OnboardingScreen extends StatefulWidget {
  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();
  // Key for controlling scaffold (e.g. open drawer)
  GlobalKey<ScaffoldState> _obScaffoldKey = GlobalKey();

  void _onIntroEnd(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (cachedSuccessfully) {
      await prefs.setBool('seen', true);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AppContents()),
      );
    } else {
      _obScaffoldKey.currentState.showSnackBar(cannotProceedError);
    }
  }

  Widget _buildImage(String assetName) {
    return Align(
      child: Image.asset('assets/$assetName.png', width: 350.0),
      alignment: Alignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    PageDecoration pageDecoration;
    if (darkmode(context)) {
      const bodyStyle = TextStyle(fontSize: 14.0, color: Colors.white);
      const headerStyle = TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700, color: Colors.white);
      pageDecoration = const PageDecoration(
        titleTextStyle: headerStyle,
        bodyTextStyle: bodyStyle,
        descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
        pageColor: Color(0xff303030),
        //boxDecoration: BoxDecoration(gradient: Gradient()),
        imagePadding: EdgeInsets.zero,
      );
    } else {
      const bodyStyle = TextStyle(fontSize: 14.0);
      const headerStyle = TextStyle(fontSize: 22.0, fontWeight: FontWeight.w700);
      pageDecoration = const PageDecoration(
        titleTextStyle: headerStyle,
        bodyTextStyle: bodyStyle,
        descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
        pageColor: Colors.white,
        imagePadding: EdgeInsets.zero,
      );
    }
    return Scaffold (
      key: _obScaffoldKey,
      body: IntroductionScreen(
        key: introKey,
        pages: [
          PageViewModel(
            title: "Welcome!",
            body:
            "Please complete this quick one-time setup.",
            image: _buildImage('manypixels-iso-weather'),
            decoration: pageDecoration,
          ),
          PageViewModel(
            title: "Initial Download",
            body:
            "Ensure you are connected to the internet to download ~1MB of initial weather data.",
            image: _buildImage('manypixels-iso-digital_nomad'),
            decoration: pageDecoration,
            footer: ProgressButton(
              defaultWidget: const Text('Download Now', style: TextStyle(color: Colors.white)),
              progressWidget: const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              width: 196,
              height: 48,
              borderRadius: 24,
              color: Color(0xff0075b3),
              onPressed: () async {
                bool doNotProceed = false;
                try {
                  await refreshImages(context, true, false);
                } catch(e) {
                  _obScaffoldKey.currentState.showSnackBar(downloadErrorSnack);
                  doNotProceed = true;
                }
                return () {
                  if (doNotProceed == false) {
                    cachedSuccessfully = true;
                    introKey.currentState?.animateScroll(2);
                  }
                };
              },
            ),
          ),
          PageViewModel(
              title: "Location Permissions",
              body:
              "Giving access to your location will enable the app to provide local forecasts.",
              image: _buildImage('manypixels-iso-navigation'),
              decoration: pageDecoration,
              footer: ProgressButton(
                defaultWidget: const Text('Request Permission', style: TextStyle(color: Colors.white)),
                progressWidget: const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                width: 196,
                height: 48,
                borderRadius: 24,
                color: Color(0xff0075b3),
                onPressed: () async {
                  await getUserLocation();
                  // After [onPressed], it will trigger animation running backwards, from end to beginning
                  return () {
                    introKey.currentState?.animateScroll(3);
                  };
                },
              )
          ),
          //PageViewModel(
          //  title: "Notifications",
          //  body: "Another beautiful body text for this example onboarding",
          //  image: _buildImage('img2'),
          //  decoration: pageDecoration,
          //),
          PageViewModel(
            title: "All done!",
            bodyWidget: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("I hope you find the app useful!"),
              ],
            ),
            image: _buildImage('manypixels-iso-camping'),
            decoration: pageDecoration,
          ),
        ],
        onDone: () => _onIntroEnd(context),
        //onSkip: () => _onIntroEnd(context), // You can override onSkip callback
        //skip: const Text('Skip'),
        showSkipButton: false,
        skipFlex: 0,
        nextFlex: 0,
        //next: const Icon(Icons.arrow_forward),
        done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
        dotsDecorator: const DotsDecorator(
          size: Size(10.0, 10.0),
          color: Color(0xFFBDBDBD),
          activeSize: Size(22.0, 10.0),
          activeShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(25.0)),
          ),
        ),
      )
    );
  }
}
