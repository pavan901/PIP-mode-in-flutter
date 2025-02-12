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
        
        // Register the custom background video processor
        let bgProcessor = WebRTCFrameProcessor(sampleBufferDisplayLayer: PictureInPictureManager.shared.sampleBufferDisplayLayer)
        let videoSDK = VideoSDK.getInstance
        
        videoSDK.registerVideoProcessor(videoProcessorName: "Pavan", videoProcessor: bgProcessor)
        
        // Setup method channel
        let controller = window?.rootViewController as! FlutterViewController
        let pipChannel = FlutterMethodChannel(
            name: "pip_channel",
            binaryMessenger: controller.binaryMessenger
        )
        
        pipChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "startPip":
                PictureInPictureManager.shared.startPip()
                result(nil)
                
            case "stopPip":
                PictureInPictureManager.shared.stopPiP()
                result(nil)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
//
//import UIKit
//import Flutter
//import videosdk
//
//@UIApplicationMain
//@objc class AppDelegate: FlutterAppDelegate {
//    override func application(
//        _ application: UIApplication,
//        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//    ) -> Bool {
//        
//        let bgProcessor = WebRTCVideoProcessor()
//        let videoSDK = VideoSDK.getInstance
//        
//        videoSDK.registerVideoProcessor(videoProcessorName: "Pavan", videoProcessor: bgProcessor)
//        
//        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
//        let pipChannel = FlutterMethodChannel(name: "pip_channel",
//                                              binaryMessenger: controller.binaryMessenger)
//        
//        pipChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
//            if call.method == "startPip" {
//                PiPManager.shared.startPiP()
//            } else {
//                result(FlutterMethodNotImplemented)
//            }
//        }
//        
//        GeneratedPluginRegistrant.register(with: self)
//        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//    }
//
//}
//
