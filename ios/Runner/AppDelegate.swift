import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    var flutter_native_splash = 1
    UIApplication.shared.isStatusBarHidden = false
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let pngChannel = FlutterMethodChannel(name: "com.github.the_salami.nowcasting/pngj",
                                              binaryMessenger: controller.binaryMessenger)
    pngChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: FlutterResult) -> Void in
        // Note: this method is invoked on the UI thread.
        guard call.method == "getPixel" else {
            result(FlutterMethodNotImplemented)
            return
        }
        if let _arguments = call.arguments as? Dictionary<String, Any> {
            guard let _filePath = _arguments["filePath"] as? String else {
                result(FlutterError(code: "ERROR", message: "Did not pass valid filepath", details: nil))
                return
            }
            let _xCoord = _arguments["xCoord"] as? NSNumber
            let _yCoord = _arguments["yCoord"] as? NSNumber
            let _result: String = getPixel(_filePath: _filePath, _x: _xCoord ?? 0, _y: _yCoord ?? 0)
            if (_result == "ERROR") {
                result(FlutterError(code: "ERROR", message: "Failed to decode image", details: nil))
            }
            result(_result)
        } else {
            result(FlutterError(code: "ERROR", message: "Error processing required arguments", details: nil))
        }
        return
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

func getPixel(_filePath: String, _x: NSNumber, _y: NSNumber) -> String {
    
    if let _image = UIImage.init(contentsOfFile: _filePath) {
        let _rawImage = (_image.cgImage)!.dataProvider!.data
        let _rawData: UnsafePointer<UInt8> = CFDataGetBytePtr(_rawImage)
        let _pixelIndex: Int = ((Int(_image.size.width) * Int(truncating: _y)) + Int(truncating: _x)) * 4
        let _pixelValueA = UInt8(_rawData[_pixelIndex+3])
        // Check if pixel is transparent and return the only possible value if so
        if (_pixelValueA == 0) {
            return "0000FF00"
        }
        let _pixelValueR = UInt8(_rawData[_pixelIndex])
        let _pixelValueG = UInt8(_rawData[_pixelIndex+1])
        let _pixelValueB = UInt8(_rawData[_pixelIndex+2])
        let _pixelValueRStr = String(format:"%02X", _pixelValueR)
        let _pixelValueGStr = String(format:"%02X", _pixelValueG)
        let _pixelValueBStr = String(format:"%02X", _pixelValueB)
        let _pixelValueAStr = String(format:"%02X", _pixelValueA)
        return _pixelValueAStr+_pixelValueRStr+_pixelValueGStr+_pixelValueBStr
    }
    // In case of an error
    return "ERROR"
}
