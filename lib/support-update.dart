import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-jobStatus.dart' as job;

// TODO figure out for sure if the legends need 20 min added to their duration
// or if forecasts are for the stated time

// Objects
var dio = Dio(BaseOptions()); //connectTimeout: 3000, receiveTimeout: 6000));

// Variables
String headerFormat = "EEE, dd MMM yyyy HH:mm:ss zzz";

// Extensions for manipulating DateTime
extension on DateTime {
  DateTime roundDown([Duration delta = const Duration(minutes: 10)]) {
    return DateTime.fromMillisecondsSinceEpoch(
        this.millisecondsSinceEpoch -
        this.millisecondsSinceEpoch % delta.inMilliseconds
    );
  }
  DateTime roundUp([Duration delta = const Duration(minutes: 10)]) {
    return DateTime.fromMillisecondsSinceEpoch(
        // add the duration then follow the round down procedure
        this.millisecondsSinceEpoch + delta.inMilliseconds - 
        this.millisecondsSinceEpoch % delta.inMilliseconds
    );
  }
}

// Functions for checking availability and updating files from remote source
Future<bool> checkUpdateAvailable(String url, File file) async {
  var urlLastModHeader;
  DateTime fileLastModified = (await file.lastModified()).toUtc();
  try {
    Response header = await dio.head(url);
    urlLastModHeader = header.headers.value(HttpHeaders.lastModifiedHeader);
  } catch(e) {
    print('update.checkUpdateAvailable: Failed to get header for $url');
    // return false by default on failure
    // otherwise in bad network conditions, refreshing takes forever
    // and the status becomes absolutely unclear to the user.
    // this is especially serious for the splash screen.
    throw('Error: could not get header for $url, cancelling');
  }
  DateTime urlLastModified = DateFormat(headerFormat).parse(urlLastModHeader, true);
  bool updateAvailable = fileLastModified.isBefore(urlLastModified);
  // Debug info
  print('update.checkUpdateAvailable: Local $file modified '+fileLastModified.toString());
  print('update.checkUpdateAvailable: Remote URL $file modified '+urlLastModified.toString());
  if (updateAvailable) {
    print('update.checkUpdateAvailable: Updating $file, remote version is newer');
  } else {
    print('update.checkUpdateAvailable: Not updating $file, remote version not newer');
  }
  return updateAvailable;
}

Future downloadFile(String url, String savePath, [int retryCount=0, int maxRetries=2]) async {
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
      int newRetryCount = retryCount+1;
      print('update.downloadFile: Failed $url - retrying time $newRetryCount');
      Timer(Duration(seconds: 1), () {downloadFile(url, savePath, newRetryCount, maxRetries);});
    } else {
      // When we have reached max retries just return an error
      throw('update.downloadFile: Failed to download $url with $maxRetries retries.');
    }
  }
}

remoteImage(bool forceRefresh, int i) async {
  try {
    if (forceRefresh || await checkUpdateAvailable('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', io.localFile('forecast.$i.png'))) {
      await downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', io.localFilePath('forecast.$i.png'));
    } else {
      return false;
    }
  } catch(e) {
    return false;
  }
  return true;
}

// Full local product generation from start to finish
Future<job.CompletionStatus> completeUpdate(bool forceRefresh, bool silent, {BuildContext context, bool parallel = false}) async {
  // If an update is already in progress, just return.
  if (job.imageUpdateStatus.any(job.isHotState)) {return job.CompletionStatus.inProgress;}
  // The actual update process
  print('update.completeUpdate: Starting update process.');
  await radarOutages();
  job.setAll(job.imageUpdateStatus, job.CompletionStatus.isQueued);
  // Running all the requests at the same time could theoretically
  // speed up the process, but it unfortunately often results in
  // failed requests and breaks things.
  if (parallel) {
    for (int _i = 0; _i <= 8; _i++) {
      completeUpdateSingleImage(_i, forceRefresh);
    }
  } else {
    for (int _i = 0; _i <= 8; _i++) {
      await completeUpdateSingleImage(_i, forceRefresh);
    }
  }
  job.CompletionStatus result = await job.completion(job.imageUpdateStatus);
  if (context != null) {
    if (result == job.CompletionStatus.timedOut) {
      ux.showSnackBarIf(!silent, ux.refreshTimedOutSnack, context, 'update.completeUpdate: Timed out waiting for success, but no failure detected.');
    } else if (result == job.CompletionStatus.success) {
      ux.showSnackBarIf(!silent, ux.refreshedSnack, context, 'update.completeUpdate: Image update successful');
    } else if (result == job.CompletionStatus.failure) {
      ux.showSnackBarIf(!silent, ux.errorRefreshSnack, context, 'update.completeUpdate: An image failed to update.');
    } else if (result == job.CompletionStatus.unnecessary) {
      ux.showSnackBarIf(!silent, ux.noRefreshSnack, context, 'update.completeUpdate: No images needed updating.');
    }
  }
  return result;
}

completeUpdateSingleImage(int index, bool forceRefresh) async {
  job.imageUpdateStatus[index] = job.CompletionStatus.inProgress;
  try {
    // First check for remote update for the image and download it if necessary.
    if (await remoteImage(forceRefresh, index)) {
      // If an update occurred, then also update its legend and clear its cache.
      imagery.forecastCache[index].clear();
      await legend(index);
      job.imageUpdateStatus[index] = job.CompletionStatus.success;
      return true;
    } else {
      // No update was needed for the image.
      job.imageUpdateStatus[index] = job.CompletionStatus.unnecessary;
      return false;
    }
  } catch(e) {
    print('update.completeUpdateSingleImage: Error updating image $index: '+e.toString());
    job.imageUpdateStatus[index] = job.CompletionStatus.failure;
    return false;
  }
}

legend(int i) async {
  DateTime _fileLastMod;
  if (await io.localFile('forecast.$i.png').exists()) {
    _fileLastMod = io.localFile('forecast.$i.png').lastModifiedSync();
  } else {
    throw('update.legends: Expected file forecast.$i.png does not exist. Stopping');
  }
  String _newLegend = _fileLastMod.toUtc().roundUp(Duration(minutes: 10)).add(Duration(minutes: 20*i)).toString();
  imagery.legends[i] = _newLegend;
  print("update.legend: Legend "+_newLegend+" inferred from file forecast.$i.png last modified date");
}

legends() async {
  for (int i = 0; i <= 8; i++) {
    legend(i);
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
    bool _updateAvailable = await checkUpdateAvailable('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.0.png', io.localFile('forecast.0.png'));
    DateTime _fileLastMod = (await io.localFile('forecast.0.png').lastModified()).toUtc();
    if (_updateAvailable == false && DateTime.now().difference(_fileLastMod) > Duration(minutes: 22)) {
      print('update.radarOutages: Seems to be an outage. checkUpdateAvailable returned '+_updateAvailable.toString()+' but difference between file modification and now is '+_fileLastMod.difference(DateTime.now()).toString());
      loc.radarOutage = true;
    } else {
      print('update.radarOutages: Doesn\'t seem to be an outage. checkUpdateAvailable returned '+_updateAvailable.toString()+' and difference between file modification and now is '+DateTime.now().difference(_fileLastMod).toString());
      loc.radarOutage = false;
    }
  } catch(e) {
    print('update.radarOutages: Check timed out, cannot determine if outage or not. Defaulting to false. Error was '+e.toString());
  }
  
}
