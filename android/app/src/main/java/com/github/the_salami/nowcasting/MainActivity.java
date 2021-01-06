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
                        final String _fileName = call.argument("fileName");
                        final int _x = call.argument("xCoord");
                        final int _y = call.argument("ycoord");
                        int _pixelValue = 0;
                        try {
                            File _sourceFile = new File(_fileName);
                            PngReaderInt _pngReader = new PngReaderInt(_sourceFile);
                            ImageLineInt _pixelRow = ((ImageLineInt) _pngReader.readRow(_x));
                            _pixelValue = _pixelRow.getElem(_y);
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