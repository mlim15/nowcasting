import 'package:image/image.dart' as imglib;
import 'package:latlong/latlong.dart';

List<imglib.Image> forecasts = [];
List<String> legends = [];

// Helper functions
coordinateToPixel(LatLng coordinates) {
  double percEast;
  double percSouth;
  
}

getPixelValue(int x, int y, int index) {
  forecasts[index].getPixel(x, y);
}