import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as imglib;

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// TODO figure out for sure if the legends need 20 min added to their duration
// or if forecasts are for the stated time

// Objects
var dio = Dio(BaseOptions(connectTimeout: 1500, receiveTimeout: 3000));

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

Future downloadFile(String url, String savePath, [int retryCount=0, int maxRetries=0]) async {
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

// TODO find a way to parallelize and still keep track of when all jobs are done
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
  for (int _i = 0; _i <= 8; _i++) {
    // Check if the local png is newer than the decoded image
    // Need to check if file exists before doing this
    //DateTime pngLastModified = (await io.localFile('forecast.$_i.png').lastModified()).toUtc();
    //DateTime rawLastModified = (await io.localFile('decodedForecast.$_i.raw').lastModified()).toUtc();
    //bool updateAvailable = rawLastModified.isBefore(pngLastModified);
    forecast(_i);
  }
}

forecast(int _i) async {
  // First set it to null while it decodes. This lets the future builder know
  // that the image isn't ready yet if it's trying to build.
  if (_i == 0) {
    imagery.decoded0 = null; 
  } else if (_i == 1) {
    imagery.decoded1 = null; 
  } else if (_i == 2) {
    imagery.decoded2 = null; 
  } else if (_i == 3) {
    imagery.decoded3 = null; 
  } else if (_i == 4) {
    imagery.decoded4 = null; 
  } else if (_i == 5) {
    imagery.decoded5 = null; 
  } else if (_i == 6) {
    imagery.decoded6 = null; 
  } else if (_i == 7) {
    imagery.decoded7 = null; 
  } else if (_i == 8) {
    imagery.decoded8 = null; 
  }
  // Then update the decoded image as long as the corresponding png exists to decode.
  // Once the image is decoded, save it to disk as a raw file.
  // Then update its corresponding legend based on the update time.
  if (await io.localFile('forecast.$_i.png').exists()) {
    imglib.Image decodedSingleForecast = await compute(bgForecast, io.localFile('forecast.$_i.png'));
    if (_i == 0) {
      imagery.decoded0 = decodedSingleForecast; 
    } else if (_i == 1) {
      imagery.decoded1 = decodedSingleForecast; 
    } else if (_i == 2) {
      imagery.decoded2 = decodedSingleForecast; 
    } else if (_i == 3) {
      imagery.decoded3 = decodedSingleForecast; 
    } else if (_i == 4) {
      imagery.decoded4 = decodedSingleForecast; 
    } else if (_i == 5) {
      imagery.decoded5 = decodedSingleForecast; 
    } else if (_i == 6) {
      imagery.decoded6 = decodedSingleForecast; 
    } else if (_i == 7) {
      imagery.decoded7 = decodedSingleForecast; 
    } else if (_i == 8) {
      imagery.decoded8 = decodedSingleForecast; 
    }    
    await imagery.saveDecodedForecast(decodedSingleForecast, _i);
  } else {
    throw('update.forecast: Expected file forecast.$_i.png does not exist. Stopping');
  }
}

legends() async {
  List<DateTime> _filesLastMod = [];
  for (int i = 0; i <= 8; i++) {
    if (await io.localFile('forecast.$i.png').exists()) {
      _filesLastMod.add(io.localFile('forecast.$i.png').lastModifiedSync());
    } else {
      throw('update.legends: Expected file forecast.$i.png does not exist. Stopping');
    }
  }
  imagery.legends = await compute(bgLegends, _filesLastMod);
}

// Local product update isolate helper functions (for backgrounding)
FutureOr<imglib.Image> bgForecast(File _file) async {
  imglib.Image _forecast;
  imglib.PngDecoder pngDecoder = new imglib.PngDecoder();
  print('update.forecasts: Decoding image '+_file.path);
  _forecast = pngDecoder.decodeImage(await _file.readAsBytes());
  print('update.forecasts: Done decoding image '+_file.path);
  return _forecast;
}

FutureOr<List<String>> bgLegends(List<DateTime> _filesLastMod) async {
  List<String> _legends = [];
  print('update.legends: Starting update process');
  for (int i = 0; i <= 8; i++) {
    // Files generated at e.g. XX:13 and labelled as a 20 min forecast for XX:20. That means it represents the weather for XX:40.
    _legends.add(_filesLastMod[i].toUtc().roundUp(Duration(minutes: 10)).add(Duration(minutes: 20*i)).toString());
  }
  print('update.legends: Following legends were inferred from file mod times: '+_legends.toString());
  return _legends;
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
