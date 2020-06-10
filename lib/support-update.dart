import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as imglib;

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-imagery.dart' as imagery;

var dio = Dio(BaseOptions(connectTimeout: 2000));
String headerFormat = "EEE, dd MMM yyyy HH:mm:ss zzz";

imglib.PngDecoder pngDecoder = new imglib.PngDecoder();

// Manipulating DateTime
extension on DateTime{
  DateTime roundDown([Duration delta = const Duration(minutes: 10)]) {
    return DateTime.fromMillisecondsSinceEpoch(
        this.millisecondsSinceEpoch -
        this.millisecondsSinceEpoch % delta.inMilliseconds
    );
  }
  DateTime roundUp([Duration delta = const Duration(minutes: 10)]) {
    return DateTime.fromMillisecondsSinceEpoch(
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

Future downloadFile(String url, String savePath, [int retryCount=0, int maxRetries=0]) async {
  try {
    Response response = await dio.get(
      url,
      //onReceiveProgress: showDownloadProgress,
      //Received data with List<int>
      options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          receiveTimeout: 0),
    );
    // Debug info
    //print(response.headers);
    File file = File(savePath);
    var raf = file.openSync(mode: FileMode.write);
    // response.data is List<int> type
    raf.writeFromSync(response.data);
    await raf.close();
  } catch (e) {
    // Retry up to the retryLimit after waiting 2 seconds
    if (retryCount < maxRetries) {
      int newRetryCount = retryCount+1;
      print('update.downloadFile: Failed $url - retrying time $newRetryCount');
      Timer(Duration(seconds: 2), () {downloadFile(url, savePath, newRetryCount, maxRetries);});
    } else {
      // When we have reached max retries just return an error
      throw('update.downloadFile: Failed to download $url with $maxRetries retries.');
    }
  }
}

remoteImagery(BuildContext context, bool forceRefresh, bool notSilent) async {
  ux.showSnackBarIf(notSilent, ux.checkingSnack, context, 'update.remoteImagery: Starting image update process');
  if (forceRefresh) {
    print('update.remoteImagery: This refresh will be forced, ignoring last modified headers');
  }
  bool notYetShownStartSnack = true;
  // Download all the images using our downloadFile method.
  // The HTTP last modified header is individually checked for each file before downloading.
  for (int i = 0; i <= 8; i++) {
    try {
      if (forceRefresh || await checkUpdateAvailable('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', io.localFile('forecast.$i.png'))) {
        if (notYetShownStartSnack) {ux.showSnackBarIf(notSilent, ux.refreshingSnack, context, 'update.remoteImagery: An image was found that needs updating, starting update');notYetShownStartSnack=false;}
        try {
          await downloadFile('https://radar.mcgill.ca/dynamic_content/nowcasting/forecast.$i.png', io.localFilePath('forecast.$i.png'));
        } catch(e) {
          ux.showSnackBarIf(notSilent, ux.errorRefreshSnack, context, 'update.remoteImagery: Error updating image number $i, stopping');
          return false;
        }
      }
    } catch(e) {
      ux.showSnackBarIf(notSilent, ux.errorRefreshSnack, context, 'update.remoteImagery: Error updating image number $i, stopping');
      return false;
    }
  }
  if (notYetShownStartSnack) {
    // If no files needed updating, the start snack will never have been shown.
    // We aren't refreshing because no files needed refreshing.
    // Show a notification saying so and return.
    ux.showSnackBarIf(notSilent, ux.noRefreshSnack, context, 'update.remoteImagery: No images needed updating');
    return false;
  } else {
    // Show a notification saying we successfully refreshed.
    ux.showSnackBarIf(notSilent, ux.refreshedSnack, context, 'update.remoteImagery: Image update successful');
    return true;
  }
}

// Local product updates
forecasts() async {
  print('update.forecasts: Starting update process');
  // Clear the array and reload all the images into it
  // Note that the array is a class-level variable in forecast.dart
  try {
    if (imagery.forecasts.isNotEmpty) {
      imagery.forecasts.clear();
    }
  } catch(e) {
    print(e);
    print("update.forecasts: Could not clear image array");
  }
  for (int i = 0; i <= 8; i++) {
    if (await io.localFile('forecast.$i.png').exists()) {
      print('update.forecasts: decoding image $i of 8.');
      imagery.forecasts.add(pngDecoder.decodeImage(await io.localFile('forecast.$i.png').readAsBytes()));
    }
  }
  print('update.forecasts: Done decoding images');
}

legends() async {
  print('update.legends: Starting update process');
  if (imagery.legends.isNotEmpty) {
    imagery.legends.clear();
  }
  for (int i = 0; i <= 8; i++) {
    if (await io.localFile('forecast.$i.png').exists()) {
      imagery.legends.add((await io.localFile('forecast.$i.png').lastModified()).toUtc().roundUp(Duration(minutes: 10)).add(Duration(minutes: 20*i)).toString());
    }
  }
  // For debug purposes
  print('update.legends: Legend images converted to: '+imagery.legends.toString());
}
