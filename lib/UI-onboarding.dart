import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:flutter_progress_button/flutter_progress_button.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:Nowcasting/main.dart' as main;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-notifications.dart' as notifications;

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
    if (_cachedSuccessfully) {
      await main.prefs.setBool('obComplete', true);
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
    bool _showLocationsPage = Platform.isIOS || (Platform.isAndroid && main.androidInfo.version.sdkInt >= 23);
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
            body: "To get started, we need to download ~1MB of initial weather data.",
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
                bool doNotProceed = true;
                try {
                  // TODO if I make the forecast screen a little more flexible
                  // the entire onboarding page here can be removed
                  if (await update.completeUpdate(context, true, false)) {
                    doNotProceed = false;
                  }
                } catch(e) {
                  print('onboarding.OnboardingScreenState: Could not get initial images');
                  _obScaffoldKey.currentState.showSnackBar(ux.onboardErrorSnack);
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
          // Only show permissions page on android if version supports runtime permissions
          if (_showLocationsPage)
            PageViewModel(
              title: "Location Permissions",
              body:  "Giving access to your location will enable the app to provide local forecasts. Giving access to your location in the background will enable more accurate notifications.",
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
                  await loc.updateLastKnownLocation(withRequests: true); 
                  return () {
                    _introKey.currentState?.animateScroll(3); 
                  }; 
                },
              ),
            ),
          PageViewModel(
            title: "Notifications",
            body: "The app can alert you about incoming rain. If enabled, it will check roughly once per hour, notifying you if it will rain or snow at your location in the coming hour. Would you like to enable these alerts now?",
            image: _buildImage('img2'),
            decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
            footer: new ProgressButton(
              defaultWidget: Text("Enable Notifications", style: ux.progressButtonTextStyle),
              progressWidget: ux.progressButtonWidget,
              width: ux.progressButtonWidth,
              height: ux.progressButtonHeight,
              borderRadius: ux.progressButtonBorderRadius,
              color: ux.progressButtonColor,
              onPressed: () async {
                // Either be android, or request permission on iOS
                if (Platform.isAndroid || await notifications.flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true,)) {
                  // If we got permission, set the boolean to enable notifications
                  // Set the boolean to enable notifications
                  notifications.enabledCurrentLoc = true;
                } else {
                  // iOS user rejected notification permissions.
                  ux.showSnackBarIf(true, ux.notificationPermissionErrorSnack, context);
                }
                return () {
                  _introKey.currentState?.animateScroll(4); 
                }; 
              },)
          ),
          PageViewModel(
            title: "All done!",
            bodyWidget: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("We hope you find the app useful!"),
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
