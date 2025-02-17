import UIKit
import Flutter
import videosdk_webrtc
import videosdk

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Initialize PiP components
        PictureInPictureManager.shared.preparePiP()
        
        // Register processor
        VideoSDK.getInstance.registerVideoProcessor(
            videoProcessorName: "Pavan",
            videoProcessor: WebRTCFrameProcessor()
        )
        
        // Method channel setup
        let controller = window?.rootViewController as! FlutterViewController
        let pipChannel = FlutterMethodChannel(
            name: "pip_channel",
            binaryMessenger: controller.binaryMessenger
        )
        
        pipChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "startPip":
                PictureInPictureManager.shared.startPiP()
                result(nil)
                
            case "stopPip":
                PictureInPictureManager.shared.stopPip()
                result(nil)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
