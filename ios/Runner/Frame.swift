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

// MARK: - CustomPiPVideoView
// This view's backing layer is an AVSampleBufferDisplayLayer.
class CustomPiPVideoView: UIView {
    override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    
    var displayLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.flushAndRemoveImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - PictureInPictureManager
class PictureInPictureManager: NSObject {
    
    // MARK: - Properties
    static let shared = PictureInPictureManager()
    
    private var pipController: AVPictureInPictureController?
    private let pipContentViewController = AVPictureInPictureVideoCallViewController()
    private let pipVideoContainer = UIView()
    private var isPiPPrepared = false
    
    var isActive: Bool { pipController?.isPictureInPictureActive ?? false }
    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }
    
    private var pipVideoView: CustomPiPVideoView?
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupPiPComponents()
        setupAudioSession()
        setupVideoViews()
    }
    
    private func setupVideoViews() {
        // Create our custom PiP video view (uses AVSampleBufferDisplayLayer)
        pipVideoView = CustomPiPVideoView(frame: .zero)
        if let pipView = pipVideoView {
            pipVideoContainer.addSubview(pipView)
            pipView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                pipView.leadingAnchor.constraint(equalTo: pipVideoContainer.leadingAnchor),
                pipView.trailingAnchor.constraint(equalTo: pipVideoContainer.trailingAnchor),
                pipView.topAnchor.constraint(equalTo: pipVideoContainer.topAnchor),
                pipView.bottomAnchor.constraint(equalTo: pipVideoContainer.bottomAnchor)
            ])
        }
    }
    
    private func setupPiPComponents() {
        // Setup main container
        pipVideoContainer.backgroundColor = .black
        pipVideoContainer.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        
        // Setup PiP content view
        pipContentViewController.view.addSubview(pipVideoContainer)
        pipVideoContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pipVideoContainer.centerXAnchor.constraint(equalTo: pipContentViewController.view.centerXAnchor),
            pipVideoContainer.centerYAnchor.constraint(equalTo: pipContentViewController.view.centerYAnchor),
            pipVideoContainer.widthAnchor.constraint(equalToConstant: 200),
            pipVideoContainer.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .videoChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }
    
    func preparePiP() {
        guard !isPiPPrepared else { return }
        
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: pipVideoContainer,
            contentViewController: pipContentViewController
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        print("PiP controller prepared: isPictureInPicturePossible: \(pipController?.isPictureInPicturePossible ?? false)")
        isPiPPrepared = true
    }
    
    func startPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // When in background, let the system handle PiP.
            // When in foreground, use our floating PiP view.
            if UIApplication.shared.applicationState == .background {
                // System PiP mode
                if self.pipContentViewController.view.window == nil {
                    if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                        window.addSubview(self.pipContentViewController.view)
                        self.pipContentViewController.view.frame = window.bounds
                        print("Added pipContentViewController.view to window for background PiP")
                    } else {
                        print("No key window found")
                    }
                }
                self.preparePiP()
                print("isPictureInPicturePossible: \(self.pipController?.isPictureInPicturePossible ?? false)")
                self.pipVideoContainer.isHidden = false
                self.pipController?.startPictureInPicture()
                print("System PiP started")
            } else {
                // Foreground: simulate a floating PiP window.
                self.attachFloatingPiPView()
                print("Floating PiP view attached in foreground")
            }
        }
    }
    
    // New method: When app is in foreground, attach the PiP view as a draggable, floating view.
    func attachFloatingPiPView() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            print("No key window for floating PiP view")
            return
        }
        // If not already added, add the content view to the window.
        if self.pipContentViewController.view.superview == nil {
            window.addSubview(self.pipContentViewController.view)
        }
        let size: CGFloat = 200
        let x = window.bounds.width - size - 10
        let y = window.bounds.height - size - 10
        self.pipContentViewController.view.frame = CGRect(x: x, y: y, width: size, height: size)
        self.pipContentViewController.view.layer.cornerRadius = 8
        self.pipContentViewController.view.clipsToBounds = true
        // Add pan gesture recognizer for repositioning if not already added.
        if self.pipContentViewController.view.gestureRecognizers == nil || self.pipContentViewController.view.gestureRecognizers?.isEmpty == true {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            self.pipContentViewController.view.addGestureRecognizer(panGesture)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, let superview = view.superview else { return }
        let translation = gesture.translation(in: superview)
        view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
    }
    
    func stopPip() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pipController?.stopPictureInPicture()
            self.pipVideoContainer.isHidden = true
        }
    }
    
    func renderFrame(_ frame: RTCVideoFrame) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Convert the RTCVideoFrame to a CMSampleBuffer and enqueue it onto our custom pip view's display layer.
            if let sampleBuffer = self.convertFrameToSampleBuffer(frame),
               let pipView = self.pipVideoView {
                pipView.displayLayer.enqueue(sampleBuffer)
            }
        }
    }
    
    private func convertFrameToSampleBuffer(_ frame: RTCVideoFrame) -> CMSampleBuffer? {
        guard let pixelBuffer = (frame.buffer as? RTCCVPixelBuffer)?.pixelBuffer else {
            print("Invalid pixel buffer")
            return nil
        }
        
        var formatDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let formatDescription = formatDescription else {
            print("Failed to create format description: \(status)")
            return nil
        }
        
        let timestamp = CMTime(
            value: CMTimeValue(frame.timeStampNs),
            timescale: 1_000_000_000
        )
        
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: CMTime.invalid
        )
        
        let result = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard result == noErr else {
            print("Failed to create sample buffer: \(result)")
            return nil
        }
        
        return sampleBuffer
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP started successfully")
        pipVideoContainer.isHidden = false
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        print("PiP stopped")
        pipVideoContainer.isHidden = true
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed to start: \(error.localizedDescription)")
        pipVideoContainer.isHidden = true
    }
}

// MARK: - Frame Processor
class WebRTCFrameProcessor: VideoProcessor {
    private var isProcessing = false
    
    override func onFrameReceived(_ frame: RTCVideoFrame) -> RTCVideoFrame? {
        // Validate frame
        guard let buffer = frame.buffer as? RTCCVPixelBuffer,
              CVPixelBufferGetWidth(buffer.pixelBuffer) > 0 else {
            print("Invalid frame buffer")
            return frame
        }
        
        // Ensure we're not already processing
        guard !isProcessing else { return frame }
        
        isProcessing = true
        
        // Process frame via our PiP manager so the sample buffer gets enqueued
        PictureInPictureManager.shared.renderFrame(frame)
        
        isProcessing = false
        print("frame processed before return")
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
