import Foundation
import AVFoundation
import AVKit
import CoreMedia
import VideoToolbox
import videosdk_webrtc

class PiPHandler: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
    
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return .init(start: .zero, duration: .indefinite)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return true
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {
        
    }
    
    static let shared = PiPHandler()
    
    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?

    private override init() {
        super.init()
        
        // Initialize Sample Buffer Display Layer
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer?.videoGravity = .resizeAspect
        sampleBufferDisplayLayer?.isOpaque = true
    }

    func startPiP(with frame: RTCVideoFrame?) {
        guard let frame = frame, let sampleBufferDisplayLayer = sampleBufferDisplayLayer else { return }
        
        if let sampleBuffer = convertRTCFrameToSampleBuffer(frame) {
            sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }

        // Create PiP Controller
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let contentSource = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: sampleBufferDisplayLayer,
                playbackDelegate: self
            )
            pipController = AVPictureInPictureController(contentSource: contentSource)
            pipController?.delegate = self
            pipController?.startPictureInPicture()
        }
    }
    
    func stopPiP() {
        pipController?.stopPictureInPicture()
        pipController = nil
    }
    /// Convert RTCVideoFrame to CMSampleBuffer for PiP
    private func convertRTCFrameToSampleBuffer(_ frame: RTCVideoFrame) -> CMSampleBuffer? {
        guard let pixelBuffer = frame.buffer as? RTCCVPixelBuffer else {
            print("Error: Could not get pixel buffer from RTCVideoFrame")
            return nil
        }
        
        let width = pixelBuffer.width
        let height = pixelBuffer.height
        
        var formatDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer.pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let validFormatDescription = formatDescription else {
            print("Error: Could not create CMVideoFormatDescription")
            return nil
        }
        
        // Set up CMSampleTimingInfo
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),  // Assuming 30 FPS
            presentationTimeStamp: CMTimeMake(value: frame.timeStampNs / 1000000, timescale: 1000),
            decodeTimeStamp: CMTime.invalid
        )

        // Create CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        let result = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer.pixelBuffer,
            formatDescription: validFormatDescription,  // Use the valid format description here
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        if result != noErr {
            print("Error: Could not create CMSampleBuffer")
            return nil
        }

        return sampleBuffer
    }

}

// MARK: - AVPictureInPictureController Delegate
extension PiPHandler: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        print("PiP Stopped")
    }
}


public class YourOwnBackgroundProcessor: videosdk_webrtc.VideoProcessor {
    public override func onFrameReceived(_ frame: RTCVideoFrame) -> RTCVideoFrame? {
        DispatchQueue.main.async {
            PiPHandler.shared.startPiP(with: frame)
        }
        return frame
    }
}
