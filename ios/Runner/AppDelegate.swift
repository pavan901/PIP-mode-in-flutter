import Flutter
import UIKit
import videosdk_webrtc
import videosdk

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        let obj = YourOwnBackgroundProcessor()
        let videoSDK = VideoSDK.getInstance
        videoSDK.registerVideoProcessor(videoProcessorName: "Pavan", videoProcessor: obj)
        
        let controller = window?.rootViewController as! FlutterViewController
        let pipChannel = FlutterMethodChannel(name: "pip_channel", binaryMessenger: controller.binaryMessenger)
        
        pipChannel.setMethodCallHandler { [weak self](call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "startPip":
                PiPHandler.shared.startPiP(with: nil)
                result("PiP Started")
                
            case "stopPip":
                PiPHandler.shared.stopPiP()
                result("PiP Stopped")
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
