// black screen

import UIKit
import AVFoundation
import AVKit
import WebRTC
import videosdk_webrtc

// MARK: - Protocol Definition
protocol PictureInPictureManagerDelegate: AnyObject {
    func willStartPictureInPicture()
    func didStartPictureInPicture()
    func willStopPictureInPicture()
    func didStopPictureInPicture()
    func failedToStartPictureInPicture(error: Error)
}

// Default implementations
extension PictureInPictureManagerDelegate {
    func willStartPictureInPicture() {}
    func didStartPictureInPicture() {}
    func willStopPictureInPicture() {}
    func didStopPictureInPicture() {}
    func failedToStartPictureInPicture(error: Error) {}
}

// MARK: - PictureInPictureManager
class PictureInPictureManager: NSObject {
    
    // MARK: - Properties
    static let shared = PictureInPictureManager()
    
    private var pipController: AVPictureInPictureController?
    public private(set) var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var pipViewController: AVPictureInPictureVideoCallViewController?
    private var displayLayerContainer: UIView?
    weak var delegate: PictureInPictureManagerDelegate?
    
    var isActive: Bool {
        return pipController?.isPictureInPictureActive ?? false
    }
    
    var isSupported: Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupAudioSession()
        setupPiPLayer()
    }
    
    // MARK: - Setup Methods
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }
    
    private func setupPiPLayer() {
        guard isSupported else {
            print("PiP not supported on this device")
            return
        }
        
        // Initialize display layer
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer?.videoGravity = .resizeAspect
        
        // Create container view
        let screenBounds = UIScreen.main.bounds
        displayLayerContainer = UIView(frame: screenBounds)
        guard let displayLayerContainer = displayLayerContainer else { return }
        
        // Configure display layer
        sampleBufferDisplayLayer?.frame = displayLayerContainer.bounds
//        displayLayerContainer.backgroundColor = .black
        
        // Add to view hierarchy
        if let window = UIApplication.shared.windows.first {
            window.addSubview(displayLayerContainer)
            if let sampleBufferDisplayLayer = sampleBufferDisplayLayer {
                displayLayerContainer.layer.addSublayer(sampleBufferDisplayLayer)
            }
        }
        
        // Setup PiP controller
        setupPiPController()
    }
    
    private func setupPiPController() {
        // Create PiP view controller
        pipViewController = AVPictureInPictureVideoCallViewController()
        pipViewController?.preferredContentSize = CGSize(width: 16, height: 9)
        
        guard let pipVC = pipViewController,
              let displayLayerContainer = displayLayerContainer else { return }
        
        // Create content source
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: displayLayerContainer,
            contentViewController: pipVC
        )
        
        // Initialize PiP controller
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
    }
    
    // MARK: - Public Methods
    func startPip() {
        guard isSupported else {
            print("PiP not supported")
            return
        }
        
        guard let pipController = pipController,
              !pipController.isPictureInPictureActive else {
            print("PiP already active or controller not ready")
            return
        }
        
        guard let displayLayer = sampleBufferDisplayLayer,
              displayLayer.status != .failed else {
            print("Display layer not ready")
            return
        }
        
        DispatchQueue.main.async {
            pipController.startPictureInPicture()
        }
    }
    
    func stopPiP() {
        guard let pipController = pipController,
              pipController.isPictureInPictureActive else {
            print("PiP not active")
            return
        }
        
        DispatchQueue.main.async {
            pipController.stopPictureInPicture()
        }
    }
    
    func destroy() {
        stopPiP()
        
        // Clean up resources
        sampleBufferDisplayLayer?.flushAndRemoveImage()
        sampleBufferDisplayLayer = nil
        
        displayLayerContainer?.removeFromSuperview()
        displayLayerContainer = nil
        
        pipController?.contentSource = nil
        pipController = nil
        
        pipViewController = nil
    }
    
    // MARK: - Layout Methods
    func updateLayout() {
        guard let displayLayerContainer = displayLayerContainer else { return }
        
        let screenBounds = UIScreen.main.bounds
        displayLayerContainer.frame = screenBounds
        sampleBufferDisplayLayer?.frame = displayLayerContainer.bounds
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.willStartPictureInPicture()
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.didStartPictureInPicture()
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.willStopPictureInPicture()
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        delegate?.didStopPictureInPicture()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("Failed to start PiP: \(error.localizedDescription)")
        delegate?.failedToStartPictureInPicture(error: error)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // Handle UI restoration when PiP is stopped
        if let window = UIApplication.shared.windows.first {
            window.makeKeyAndVisible()
        }
        completionHandler(true)
    }
    
    func enqueueVideoFrame(_ frame: RTCVideoFrame) {
        print("Received video frame for PiP")
        
        // Convert RTC frame to CMSampleBuffer
        guard let sampleBuffer = convertRTCFrameToSampleBuffer(frame) else {
            print("Failed to convert RTCVideoFrame to CMSampleBuffer")
            return
        }
        
        // Log the details of the sample buffer
        print("Successfully converted RTCVideoFrame to CMSampleBuffer")
        
        // Ensure display layer is valid and ready
        guard let displayLayer = sampleBufferDisplayLayer else {
            print("SampleBufferDisplayLayer is not initialized")
            return
        }

        if displayLayer.status == .failed {
            print("Display layer is in a failed state.")
            return
        }

        // Log the status of the display layer before enqueuing
        print("Enqueuing sample buffer into SampleBufferDisplayLayer")

        // Enqueue the sample buffer into the display layer
        DispatchQueue.main.async { [weak self] in
            print("Enqueuing sample buffer into display layer on main thread")
            self?.sampleBufferDisplayLayer?.enqueue(sampleBuffer)
        }
    }

    
    private func convertRTCFrameToSampleBuffer(_ frame: RTCVideoFrame) -> CMSampleBuffer? {
            print("Converting RTCVideoFrame to CMSampleBuffer")
            guard let pixelBuffer = frame.buffer as? RTCCVPixelBuffer else {
                print("Frame buffer is not a valid RTCCVPixelBuffer")
                return nil
            }
            
            var formatDescription: CMVideoFormatDescription?
            let status = CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer.pixelBuffer,
                formatDescriptionOut: &formatDescription
            )
            
            guard status == noErr, let formatDescription = formatDescription else {
                print("Failed to create video format description")
                return nil
            }
            
            var timingInfo = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: 30),
                presentationTimeStamp: CMTimeMake(value: Int64(frame.timeStampNs), timescale: 1_000_000_000),
                decodeTimeStamp: CMTime.invalid
            )
            
            var sampleBuffer: CMSampleBuffer?
            let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer.pixelBuffer,
                formatDescription: formatDescription,
                sampleTiming: &timingInfo,
                sampleBufferOut: &sampleBuffer
            )
            
            if bufferStatus != noErr {
                print("Failed to create sample buffer")
                return nil
            }
            
            print("Successfully converted frame to sample buffer")
            return sampleBuffer
        }
}

// MARK: - Frame Processor
class WebRTCFrameProcessor: VideoProcessor {
    private weak var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private let queue = DispatchQueue(label: "com.app.webrtc.frameprocessor")
    
    
    init(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?) {
        self.sampleBufferDisplayLayer = sampleBufferDisplayLayer
    }
    
    public override func onFrameReceived(_ frame: RTCVideoFrame) -> RTCVideoFrame? {
        queue.async { [weak self] in
            if let pixelBuffer = frame.buffer.toPixelBuffer(),
               let sampleBuffer = pixelBuffer.toCMSampleBuffer(),
               let displayLayer = self?.sampleBufferDisplayLayer,
               displayLayer.status != .failed {
                
                DispatchQueue.main.async {
                    PictureInPictureManager.shared.enqueueVideoFrame(frame)
                }
            }
        }
        return frame
    }
}

// MARK: - Helper Extensions
extension RTCVideoFrameBuffer {
    func toPixelBuffer() -> CVPixelBuffer? {
        guard let i420Buffer = self as? RTCCVPixelBuffer else { return nil }
        return i420Buffer.pixelBuffer
    }
}

extension CVPixelBuffer {
    func toCMSampleBuffer() -> CMSampleBuffer? {
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: self,
            formatDescriptionOut: &formatDescription)
        
        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: CMTime.zero,
            decodeTimeStamp: CMTime.invalid)
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: self,
            formatDescription: formatDescription!,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer)
        
        return sampleBuffer
    }
}


// vertical video

//import Foundation
//import AVFoundation
//import CoreMedia
//import VideoToolbox
//import videosdk_webrtc
//import AVKit
//
//class PiPHandler: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate, AVPictureInPictureControllerDelegate {
//
//    static let shared = PiPHandler()
//    
//    private var pipController: AVPictureInPictureController?
//    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
//    private var isPiPActive = false
//    
//    private override init() {
//        super.init()
//        setupSampleBufferDisplayLayer()
//    }
//    
//    private func setupSampleBufferDisplayLayer() {
//        print("Initializing SampleBufferDisplayLayer")
//        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
//        sampleBufferDisplayLayer?.videoGravity = .resizeAspect
//        sampleBufferDisplayLayer?.isOpaque = true
//        
//        // Ensure it is added to the main window
//        if let layer = sampleBufferDisplayLayer {
//            DispatchQueue.main.async {
//                if let window = UIApplication.shared.windows.first {
//                    layer.frame = window.bounds
//                    window.layer.addSublayer(layer)
//                    print("SampleBufferDisplayLayer added to the window")
//                } else {
//                    print("Failed to get the main window")
//                }
//            }
//        }
//    }
//    
//    // MARK: - Public Methods
//    func startPiP() {
//        print("Entering startPiP()")
//        guard !isPiPActive else {
//            print("PiP is already active")
//            return
//        }
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else {
//                print("self is nil in startPiP()")
//                return
//            }
//            
//            print("Checking PiP support: \(AVPictureInPictureController.isPictureInPictureSupported())")
//            
//            guard AVPictureInPictureController.isPictureInPictureSupported(),
//                  let displayLayer = self.sampleBufferDisplayLayer else {
//                print("PiP not supported or display layer is nil")
//                return
//            }
//            
//            let contentSource = AVPictureInPictureController.ContentSource(
//                sampleBufferDisplayLayer: displayLayer,
//                playbackDelegate: self
//            )
//            
//            self.pipController = AVPictureInPictureController(contentSource: contentSource)
//            self.pipController?.delegate = self
//            self.pipController?.startPictureInPicture()
//            self.isPiPActive = true
//            print("Started PiP successfully")
//        }
//    }
//    
//    func stopPiP() {
//        print("Stopping PiP")
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self, self.isPiPActive else {
//                print("PiP was not active")
//                return
//            }
//            self.pipController?.stopPictureInPicture()
//            self.isPiPActive = false
//            print("PiP stopped")
//        }
//    }
//    
//    func enqueueVideoFrame(_ frame: RTCVideoFrame) {
//        print("Received video frame for PiP")
//        guard isPiPActive else {
//            print("PiP is not active, dropping frame")
//            return
//        }
//        
//        guard let sampleBuffer = convertRTCFrameToSampleBuffer(frame) else {
//            print("Failed to convert RTCVideoFrame to CMSampleBuffer")
//            return
//        }
//        
//        DispatchQueue.main.async { [weak self] in
//            print("Enqueuing video frame into SampleBufferDisplayLayer")
//            self?.sampleBufferDisplayLayer?.enqueue(sampleBuffer)
//        }
//    }
//    
//    // MARK: - Sample Buffer Conversion
//    private func convertRTCFrameToSampleBuffer(_ frame: RTCVideoFrame) -> CMSampleBuffer? {
//        print("Converting RTCVideoFrame to CMSampleBuffer")
//        guard let pixelBuffer = frame.buffer as? RTCCVPixelBuffer else {
//            print("Frame buffer is not a valid RTCCVPixelBuffer")
//            return nil
//        }
//        
//        var formatDescription: CMVideoFormatDescription?
//        let status = CMVideoFormatDescriptionCreateForImageBuffer(
//            allocator: kCFAllocatorDefault,
//            imageBuffer: pixelBuffer.pixelBuffer,
//            formatDescriptionOut: &formatDescription
//        )
//        
//        guard status == noErr, let formatDescription = formatDescription else {
//            print("Failed to create video format description")
//            return nil
//        }
//        
//        var timingInfo = CMSampleTimingInfo(
//            duration: CMTime(value: 1, timescale: 30),
//            presentationTimeStamp: CMTimeMake(value: Int64(frame.timeStampNs), timescale: 1_000_000_000),
//            decodeTimeStamp: CMTime.invalid
//        )
//        
//        var sampleBuffer: CMSampleBuffer?
//        let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
//            allocator: kCFAllocatorDefault,
//            imageBuffer: pixelBuffer.pixelBuffer,
//            formatDescription: formatDescription,
//            sampleTiming: &timingInfo,
//            sampleBufferOut: &sampleBuffer
//        )
//        
//        if bufferStatus != noErr {
//            print("Failed to create sample buffer")
//            return nil
//        }
//        
//        print("Successfully converted frame to sample buffer")
//        return sampleBuffer
//    }
//    
//    // MARK: - PiP Delegate Methods
//    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
//        print("PiP started successfully")
//        isPiPActive = true
//    }
//    
//    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
//        print("PiP stopped")
//        isPiPActive = false
//        pipController = nil
//        sampleBufferDisplayLayer?.flush()
//    }
//    
//    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
//        print("Failed to start PiP: \(error.localizedDescription)")
//        isPiPActive = false
//        pipController = nil
//    }
//    
//    // Required delegate methods
//    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
//    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
//        return CMTimeRange(start: .zero, duration: .indefinite)
//    }
//    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }
//    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
//    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {}
//
//}
//
//// MARK: - Video Processor
//public class YourOwnBackgroundProcessor: videosdk_webrtc.VideoProcessor {
//    public override func onFrameReceived(_ frame: RTCVideoFrame) -> RTCVideoFrame? {
//        print("Processing video frame in YourOwnBackgroundProcessor")
//        PiPHandler.shared.enqueueVideoFrame(frame)
//        return frame
//    }
//}
//
