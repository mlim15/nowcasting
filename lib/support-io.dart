import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:Nowcasting/support-imagery.dart' as imagery;

Directory appDocPath;

// Initialization
updateAppDocPath() async {
  appDocPath = await getApplicationSupportDirectory();
}

// File helper functions
File localFile(String fileName) {
  return File(localFilePath(fileName));
}

String localFilePath(String fileName) {
  String pathName = join(appDocPath.path, fileName);
  return pathName;
}

// This functionality is only useful if the app is opened within 10 minutes
// and it has also been killed in the background before the user opens it again,
// or the user has no internet when opening the second time.
// Frankly it's of very limited use, but it will certainly improve the experience
// on very low end devices if the app is frequently opened and closed.
saveForecastCache(int _index) async {
  File _file = localFile('forecast.$_index.cache');
  _file.writeAsStringSync(json.encode(imagery.forecastCache[_index]));
  print('imagery.saveForecastCache: Finished saving decoded values for image $_index');
}

loadForecastCaches() async {
  Map<String, dynamic> _json;
  for (int i = 0; i <= 8; i++) {
    File _file = localFile('forecast.$i.cache');
    if (_file.existsSync()) {
      _json = json.decode(_file.readAsStringSync());
      if(_json != null && _json.isNotEmpty) {
        imagery.forecastCache[i] = _json;
      } 
    }
  }
  print('imagery.loadForecastCache: Finished loading cached image values');
}