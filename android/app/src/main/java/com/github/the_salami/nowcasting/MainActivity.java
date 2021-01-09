package com.github.the_salami.nowcasting;

import ar.com.hjg.pngj.IImageLine;
import ar.com.hjg.pngj.ImageLineInt;
import ar.com.hjg.pngj.PngReaderInt;
import androidx.annotation.NonNull;

import java.io.File;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.github.the_salami.nowcasting/pngj";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    // Note: this method is invoked on the main thread.
                    if (call.method.equals("getPixel")) {
                        final String _filePath = call.argument("filePath");
                        final int _x = call.argument("xCoord");
                        final int _y = call.argument("yCoord");
                        String _pixelValue = "";
                        try {
                            File _sourceFile = new File(_filePath);
                            PngReaderInt _pngReader = new PngReaderInt(_sourceFile);
                            ImageLineInt _pixelRow = ((ImageLineInt) _pngReader.readRow(_y));

                            int _pixelValueA = _pixelRow.getElem(_x*4+3);
                            // If the pixel is transparent there is no point in continuing.
                            if (_pixelValueA == 0) {
                                _pngReader.close();
                                result.success("0000FF00");
                                return;
                            }
                            int _pixelValueR = _pixelRow.getElem(_x*4);
                            int _pixelValueG = _pixelRow.getElem(_x*4+1);
                            int _pixelValueB = _pixelRow.getElem(_x*4+2);
                            String _pixelValueAStr = String.format("%02X", _pixelValueA);
                            String _pixelValueRStr = String.format("%02X", _pixelValueR);
                            String _pixelValueGStr = String.format("%02X", _pixelValueG);
                            String _pixelValueBStr = String.format("%02X", _pixelValueB);
                            _pixelValue = _pixelValueAStr+_pixelValueRStr+_pixelValueGStr+_pixelValueBStr;
                            _pngReader.close();
                        } catch(Error e) {
                            System.out.println(e.toString());
                            result.error("ERROR", "platformChannel: Error "+e.toString()+" while processing.", null);
                        }
                        result.success(_pixelValue);
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }
}