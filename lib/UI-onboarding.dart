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
import 'package:Nowcasting/support-io.dart' as io;

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
                  update.CompletionStatus _result = await update.completeUpdate(true, true);
                  if (_result == update.CompletionStatus.success || _result == update.CompletionStatus.unnecessary) {
                    doNotProceed = false;
                  }
                } catch(e) {
                  print('onboarding.OnboardingScreenState: Could not get initial images'+e.toString());
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
                  await loc.currentLocation.update(withRequests: true); 
                  return () {
                    _introKey.currentState?.animateScroll(3); 
                  }; 
                },
              ),
            ),
          PageViewModel(
            title: "Notifications",
            body: "Would you like the app to check roughly once an hour in the background for incoming rain at your location? You won't be notified more than once per three hours at the very most.",
            image: _buildImage('manypixels-iso-fishing'),
            decoration: ux.darkMode(context) ? ux.pageDecorationDark : ux.pageDecorationLight,
            footer: new ProgressButton(
              defaultWidget: Text("Enable Notifications", style: ux.progressButtonTextStyle),
              progressWidget: ux.progressButtonWidget,
              width: ux.progressButtonWidth,
              height: ux.progressButtonHeight,
              borderRadius: ux.progressButtonBorderRadius,
              color: ux.progressButtonColor,
              onPressed: () async {
                // We must have a valid location
                // Also either be android, or request permission on iOS
                if (loc.currentLocation.coordinates != null) {
                  bool _notifPermGranted = true;
                  if (Platform.isIOS) {
                    _notifPermGranted = false;
                    _notifPermGranted = await notifications.flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
                  } 
                  if (_notifPermGranted) {
                    // If we got permission, set the boolean to enable notifications
                    // Set the boolean to enable notifications
                    notifications.notificationsEnabled = true;
                    loc.currentLocation.notify = true;
                    io.savePlaceData();
                    io.saveNotificationPreferences();
                    notifications.scheduleBackgroundFetch();
                  } else {
                    // User gave location perms but denied notification
                    _obScaffoldKey.currentState.showSnackBar(ux.notificationPermissionErrorSnack);
                  }
                } else {
                  // User did not grant location perms
                  _obScaffoldKey.currentState.showSnackBar(ux.notificationLocPermissionErrorSnack);
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
