import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_progress_button/flutter_progress_button.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-ux.dart' as ux;

class OnboardingScreen extends StatefulWidget {
  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  // A boolean to track whether the download process in onboarding was successful.
  // This is used to prevent the user from completing onboarding if the images
  // don't download successfully. Since the rest of the app expects the images
  // to exist, this can have weird consequences if we let it happen.
  bool _cachedSuccessfully = false;
  // Keys used to direct the process and show snackbars in appropriate contexts etc.
  final _introKey = GlobalKey<IntroductionScreenState>();
  GlobalKey<ScaffoldState> _obScaffoldKey = GlobalKey();

  // Called when pressing done at the end of onboarding.
  void _onIntroEnd(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_cachedSuccessfully) {
      await prefs.setBool('seen', true);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => main.AppContents()),
      );
    } else {
      _obScaffoldKey.currentState.showSnackBar(ux.onboardCannotContinueSnack);
      print('onboarding.OnboardingScreenState: User tried to continue without downloading images, prevented');
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
    ux.updateStatusBarBrightness(context,true,false);
    return Scaffold (
      key: _obScaffoldKey,
      body: IntroductionScreen(
        key: _introKey,
        pages: [
          PageViewModel(
            title: "Welcome!",
            body: "Please complete this quick one-time setup.",
            image: _buildImage('manypixels-iso-weather'),
            decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
          ),
          PageViewModel(
            title: "Initial Download",
            body: "Ensure you are connected to the internet to download ~1MB of initial weather data.",
            image: _buildImage('manypixels-iso-digital_nomad'),
            decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
            footer: new ProgressButton(
              defaultWidget: Text('Download Now', style: ux.progressButtonTextStyle),
              progressWidget: ux.progressButtonWidget,
              width: ux.progressButtonWidth,
              height: ux.progressButtonHeight,
              borderRadius: ux.progressButtonBorderRadius,
              color: ux.progressButtonColor,
              onPressed: () async {
                bool doNotProceed = false;
                try {
                  await update.remoteImagery(context, true, false);
                  await update.legends();
                  update.forecasts();
                } catch(e) {
                  print('onboarding.OnboardingScreenState: Could not get initial images');
                  _obScaffoldKey.currentState.showSnackBar(ux.onboardErrorSnack);
                  doNotProceed = true;
                }
                return () {
                  if (doNotProceed == false) {
                    _cachedSuccessfully = true;
                    _introKey.currentState?.animateScroll(2);
                  }
                };
              },
            ),
          ),
          PageViewModel(
              title: "Location Permissions",
              body:  "Giving access to your location will enable the app to provide local forecasts.",
              image: _buildImage('manypixels-iso-navigation'),
              decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
              footer: new ProgressButton(
                defaultWidget: Text('Request Permission', style: ux.progressButtonTextStyle),
                progressWidget: ux.progressButtonWidget,
                width: ux.progressButtonWidth,
                height: ux.progressButtonHeight,
                borderRadius: ux.progressButtonBorderRadius,
                color: ux.progressButtonColor,
                onPressed: () async {    
                  await loc.getUserLocation(); 
                  return () {
                    _introKey.currentState?.animateScroll(3); 
                  }; 
                },
              ),
          ),
          //PageViewModel(
          //  title: "Notifications",
          //  body: "Another beautiful body text for this example onboarding",
          //  image: _buildImage('img2'),
          //  decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
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
            decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
          ),
        ],
        onDone: () => _onIntroEnd(context),
        //onSkip: () => _onIntroEnd(context), // You can override onSkip callback
        //skip: const Text('Skip'),
        showSkipButton: false,
        skipFlex: 0,
        nextFlex: 0,
        //next: const Icon(Icons.arrow_forward),
        done: Text('Done', style: Theme.of(context).textTheme.button),
        dotsDecorator: ux.dotsDecorator,
      )
    );
  }
}
