import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:nowcasting/support-ux.dart' as ux;
import 'package:nowcasting/support-io.dart' as io;
import 'package:nowcasting/support-imagery.dart' as imagery;
import 'package:nowcasting/support-location.dart' as loc;

// TODO figure out for sure if the legends need 20 min added to their duration
// or if forecasts are for the stated time

// Objects
var dio = Dio(BaseOptions()); //connectTimeout: 3000, receiveTimeout: 6000));

// Variables
String headerFormat = "EEE, dd MMM yyyy HH:mm:ss zzz";

enum CompletionStatus {
  success, // "cold" states
  unnecessary,
  timedOut,
  failure,
  inactive,
  inProgress, // "hot" states
  isQueued, // either being processed or will be soon
}
bool isHotState(dynamic element) {
  if (element == CompletionStatus.isQueued ||
      element == CompletionStatus.inProgress) {
    return true;
  } else {
    return false;
  }
}

// Functions for checking availability and updating files from remote source
Future<bool> checkUpdateAvailable(String url, File file) async {
  var urlLastModHeader;
  DateTime fileLastModified = (await file.lastModified()).toUtc();
  try {
    Response header = await dio.head(url);
    urlLastModHeader = header.headers.value(HttpHeaders.lastModifiedHeader);
  } catch (e) {
    print('update.checkUpdateAvailable: Failed to get header for $url');
    // return false by default on failure
    // otherwise in bad network conditions, refreshing takes forever
    // and the status becomes absolutely unclear to the user.
    // this is especially serious for the splash screen.
    throw ('Error: could not get header for $url, cancelling');
  }
  DateTime urlLastModified =
      DateFormat(headerFormat).parse(urlLastModHeader, true);
  bool updateAvailable = fileLastModified.isBefore(urlLastModified);
  // Debug info
  print('update.checkUpdateAvailable: Local $file modified ' +
      fileLastModified.toString());
  print('update.checkUpdateAvailable: Remote URL $file modified ' +
      urlLastModified.toString());
  if (updateAvailable) {
    print(
        'update.checkUpdateAvailable: Updating $file, remote version is newer');
  } else {
    print(
        'update.checkUpdateAvailable: Not updating $file, remote version not newer');
  }
  return updateAvailable;
}

Future downloadFile(String url, String savePath,
    [int retryCount = 0, int maxRetries = 2]) async {
  try {
    Response response = await dio.get(
      url,
      options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          receiveTimeout: 0),
    );
    File file = File(savePath);
    var raf = file.openSync(mode: FileMode.write);
    raf.writeFromSync(response.data);
    await raf.close();
  } catch (e) {
    // Retry up to the retryLimit after waiting 1 second
    if (retryCount < maxRetries) {
      int newRetryCount = retryCount + 1;
      print('update.downloadFile: Failed $url - retrying time $newRetryCount');
      Timer(Duration(seconds: 1), () {
        downloadFile(url, savePath, newRetryCount, maxRetries);
      });
    } else {
      // When we have reached max retries just return an error
      throw ('update.downloadFile: Failed to download $url with $maxRetries retries.');
    }
  }
}

// Full local product generation from start to finish
Future<CompletionStatus> completeUpdate(bool forceRefresh, bool silent,
    {BuildContext context, bool parallel = false}) async {
  // If an update is already in progress, just return.
  if (imagery.nowcasts.any((nowcast) {
    return isHotState(nowcast.status);
  })) {
    return CompletionStatus.inProgress;
  }
  // Update location
  loc.currentLocation.update();
  // The actual update process
  print('update.completeUpdate: Starting update process.');
  await radarOutages();
  imagery.nowcasts.forEach((nowcast) {
    nowcast.status = CompletionStatus.isQueued;
  });
  // Running all the requests at the same time could theoretically
  // speed up the process, but it unfortunately often results in
  // failed requests and breaks things.
  if (parallel) {
    imagery.nowcasts.forEach((nowcast) {
      nowcast.refresh(forceRefresh);
    });
  } else {
    // TODO verify this awaits in order like the for loop used to
    imagery.nowcasts.forEach((nowcast) async {
      await nowcast.refresh(forceRefresh);
    });
  }
  Duration interval = const Duration(milliseconds: 1000);
  int counter = 0;
  int maxTries = 15;
  // All the garbage we use to determine when the job is actually done
  // and give feedback to the user.
  while (true) {
    // Every ${interval} proceed to check to see if any ending condition is true.
    await Future.delayed(interval);
    // Check to see if we have exceeded the max waiting time.
    if (counter >= maxTries) {
      ux.showSnackBarIf(!silent, ux.refreshTimedOutSnack, context,
          'update.completeUpdate: Timed out waiting for success, but no failure detected.');
      return CompletionStatus.timedOut;
    }
    if (imagery.nowcasts.every((image) {
      return image.status == CompletionStatus.success;
    })) {
      // Then the update has fully succeeded.
      ux.showSnackBarIf(!silent, ux.refreshedSnack, context,
          'update.completeUpdate: Image update successful');
      return CompletionStatus.success;
    } else if (imagery.nowcasts.any((image) {
      return image.status == CompletionStatus.failure;
    })) {
      // Then we know the update has failed somewhere.
      ux.showSnackBarIf(!silent, ux.errorRefreshSnack, context,
          'update.completeUpdate: An image failed to update.');
      return CompletionStatus.failure;
    } else if (imagery.nowcasts.every((image) {
      return image.status == CompletionStatus.unnecessary;
    })) {
      // Then the update was not necessary. Tell the user so.
      ux.showSnackBarIf(!silent, ux.noRefreshSnack, context,
          'update.completeUpdate: No images needed updating.');
      return CompletionStatus.unnecessary;
    } else if (imagery.nowcasts.every((image) {
      return (image.status == CompletionStatus.success) ||
          (image.status == CompletionStatus.unnecessary);
    })) {
      // Perhaps we have a mix of only success and unnecessary. In this case, just display to the user as a success.
      ux.showSnackBarIf(!silent, ux.refreshedSnack, context,
          'update.completeUpdate: Image update successful');
      return CompletionStatus.success;
    } else {
      // Otherwise continue to wait until any of the above situations is true,
      // or we time out.
      counter += 1;
    }
  }
}

// Update functions for booleans stored in support-location that determine
// whether certain message slivers are shown on the forecast screen.
weatherAlert() async {
  // TODO implement. For now loc.weatherAlert will always be false so the message is never shown
}

radarOutages() async {
  // We are guessing about whether or not to show this outage message.
  // We will only show the message if there is no remote imagery update available
  // and the local images are older than 22 minutes. Typically the images will have
  // an update available after 10-11 minutes has elapsed, so this is a safe buffer
  // to ensure we are really seeing an outage. We don't know for sure that this outage is
  // due to environment canada radar outages, but we'll blame it on them anyway.
  //
  // First of all, if the files don't exist then just return.
  if (!io.localFile('forecast.0.png').existsSync()) {
    return;
  }
  try {
    bool _updateAvailable = await checkUpdateAvailable(
        'https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.0.png',
        io.localFile('forecast.0.png'));
    DateTime _fileLastMod =
        (await io.localFile('forecast.0.png').lastModified()).toUtc();
    if (_updateAvailable == false &&
        DateTime.now().difference(_fileLastMod) > Duration(minutes: 22)) {
      print(
          'update.radarOutages: Seems to be an outage. checkUpdateAvailable returned ' +
              _updateAvailable.toString() +
              ' but difference between file modification and now is ' +
              _fileLastMod.difference(DateTime.now()).toString());
      loc.radarOutage = true;
    } else {
      print(
          'update.radarOutages: Doesn\'t seem to be an outage. checkUpdateAvailable returned ' +
              _updateAvailable.toString() +
              ' and difference between file modification and now is ' +
              DateTime.now().difference(_fileLastMod).toString());
      loc.radarOutage = false;
    }
  } catch (e) {
    print(
        'update.radarOutages: Check timed out, cannot determine if outage or not. Defaulting to false. Error was ' +
            e.toString());
  }
}
