import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate,

    AVCaptureFileOutputRecordingDelegate {

    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var captureDevice: AVCaptureDevice!
    var photoOutput: AVCapturePhotoOutput!
    var movieOutput: AVCaptureMovieFileOutput!
    
    let focusSlider = UISlider()
    let isoSlider = UISlider()
    let exposureSlider = UISlider()
    let focusValueLabel = UILabel() // Label to display the focus value
    let isoValueLabel = UILabel() // Label to display the ISO value
    let exposureValueLabel = UILabel() // Label to display the exposure value
    let recordVideoButton = UIButton()

    
        



    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupSliders()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        
        // Set the session preset to high quality
        captureSession.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Unable to access back camera!")
            return
        }
        
        captureDevice = backCamera
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            photoOutput = AVCapturePhotoOutput()
            movieOutput = AVCaptureMovieFileOutput()
            
            captureSession.addInput(input)
            captureSession.addOutput(photoOutput)
            captureSession.addOutput(movieOutput)
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            // Rotate the videoPreviewLayer by 180 degrees
            videoPreviewLayer.setAffineTransform(CGAffineTransform(rotationAngle: -.pi/2))
            videoPreviewLayer.videoGravity = .resizeAspectFill
            videoPreviewLayer.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer)
            

            configureDeviceFor4K()
            
            // Turn off autofocus and set the initial focus to 0.5
            try? captureDevice.lockForConfiguration()
            if captureDevice.isFocusModeSupported(.locked) {
                captureDevice.focusMode = .locked
                captureDevice.setFocusModeLocked(lensPosition: 0.5, completionHandler: nil)
            }
            
            // Set the initial ISO value
            let desiredISO: Float = captureDevice.activeFormat.minISO
            if desiredISO >= captureDevice.activeFormat.minISO && desiredISO <= captureDevice.activeFormat.maxISO {
                // Set the initial exposure duration to 2 ms (0.002 seconds)
                let initialExposureDurationSeconds = 0.002
                let minExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration)
                let maxExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration)
                
                if initialExposureDurationSeconds >= minExposureDurationSeconds && initialExposureDurationSeconds <= maxExposureDurationSeconds {
                    let initialExposureDuration = CMTimeMakeWithSeconds(initialExposureDurationSeconds, preferredTimescale: 1000*1000*1000)
                    captureDevice.setExposureModeCustom(duration: initialExposureDuration, iso: desiredISO, completionHandler: nil)
                }
            }
            
            captureDevice.unlockForConfiguration()
            
            // Start running the session on a background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
            
        } catch {
            print("Error setting up the camera: \(error)")
        }
    }
    
    func configureDeviceFor4K() {
        if let format = captureDevice.formats.first(where: { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dimensions.width == 3840 && dimensions.height == 2160 && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate == 60 }
        }) {
            try? captureDevice.lockForConfiguration()
            captureDevice.activeFormat = format
            captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 60)
            captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 60)
            captureDevice.unlockForConfiguration()
        }
    }
    
    func setupSliders() {
        let screenWidth = UIScreen.main.bounds.width
//        let screenHeight = UIScreen.main.bounds.height
        let sliderWidth = 280
        let sliderHeight = 40
        let sliderSpacer = 60
        let isoLabel = UILabel()
        let exposureLabel = UILabel()
        let focusLabel = UILabel()
        let sliderXposition = Int(screenWidth) - sliderWidth - sliderSpacer
        let valueXposition = Int(screenWidth) - sliderSpacer
        let labelXposition = Int(screenWidth) - sliderWidth - sliderSpacer - 30
        let isoY = 50
        let exposureY = 90
        let focusY = 130
        let buttonsY = 200


        // ISO Slider Setup
        isoSlider.frame = CGRect(x: sliderXposition, y: isoY, width: sliderWidth, height: sliderHeight)
        isoSlider.minimumValue = captureDevice.activeFormat.minISO
        isoSlider.maximumValue = captureDevice.activeFormat.maxISO
        isoSlider.value = captureDevice.iso // Current ISO value
        view.addSubview(isoSlider)
        isoLabel.frame = CGRect(x: labelXposition, y: isoY, width: 60, height: 40)
        isoLabel.textAlignment = .left
        isoLabel.text = "ISO"
        view.addSubview(isoLabel)
        isoValueLabel.frame = CGRect(x: valueXposition, y: isoY, width: 60, height: 40)
        isoValueLabel.textAlignment = .left
        isoValueLabel.text = String(format: "%.0f", isoSlider.value)
        view.addSubview(isoValueLabel)

        
        // Exposure Slider Setup
        exposureSlider.frame = CGRect(x: sliderXposition, y: exposureY, width: 280, height: sliderHeight)
        let minExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration)+0.0001
        let maxExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration)/200

        exposureSlider.minimumValue = Float(minExposureDurationSeconds)
        exposureSlider.maximumValue = Float(maxExposureDurationSeconds)
        exposureSlider.value = 0.002 // Initial exposure duration set to 2 ms
        view.addSubview(exposureSlider)
        
        exposureLabel.frame = CGRect(x: labelXposition, y: exposureY, width: 100, height: 40)
        exposureLabel.textAlignment = .left
        exposureLabel.text = "Exposure"
        view.addSubview(exposureLabel)
        
        exposureValueLabel.frame = CGRect(x: valueXposition, y: exposureY, width: 100, height: 40)
        exposureValueLabel.textAlignment = .left
        exposureValueLabel.text = String(format: "%.2f ms", exposureSlider.value * 1000) // Display in ms
        view.addSubview(exposureValueLabel)
        
        // Focus Slider Setup
        focusSlider.frame = CGRect(x: sliderXposition, y: focusY, width: 280, height: 40)
        focusSlider.minimumValue = 0.0
        focusSlider.maximumValue = 1.0
        focusSlider.value = 0.5
        view.addSubview(focusSlider)

        focusLabel.frame = CGRect(x: labelXposition, y: focusY, width: 100, height: 40)
        focusLabel.textAlignment = .left
        focusLabel.text = "Focus"
        view.addSubview(focusLabel)

        // Configure and position the focus value label
        focusValueLabel.frame = CGRect(x: valueXposition, y: focusY, width: 60, height: 40)
        focusValueLabel.textAlignment = .left
        focusValueLabel.text = String(format: "%.2f", focusSlider.value)
        view.addSubview(focusValueLabel)
        
        focusSlider.addTarget(self, action: #selector(focusChanged(_:)), for: .valueChanged)
        isoSlider.addTarget(self, action: #selector(isoChanged(_:)), for: .valueChanged)
        exposureSlider.addTarget(self, action: #selector(exposureChanged(_:)), for: .valueChanged)
        
        let capturePhotoButton = UIButton(frame: CGRect(x: Int(screenWidth) - 120, y: buttonsY, width: 100, height: 50))
        capturePhotoButton.setTitle("Photo", for: .normal)
        capturePhotoButton.backgroundColor = .red
        capturePhotoButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(capturePhotoButton)
        
        // Record Video Button Setup
        recordVideoButton.frame = CGRect(x: Int(screenWidth) - 240, y: buttonsY, width: 100, height: 50)
        recordVideoButton.setTitle("Video", for: .normal)
        recordVideoButton.backgroundColor = .blue
        recordVideoButton.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
        view.addSubview(recordVideoButton)

    }

    @objc func exposureChanged(_ sender: UISlider) {
        let exposureDurationSeconds = Double(sender.value)
        let exposureDuration = CMTimeMakeWithSeconds(exposureDurationSeconds, preferredTimescale: 1000*1000*1000)
        
        try? captureDevice.lockForConfiguration()
        captureDevice.setExposureModeCustom(duration: exposureDuration, iso: captureDevice.iso, completionHandler: nil)
        captureDevice.unlockForConfiguration()

        // Display the exposure duration in milliseconds for better readability
        let durationInMilliseconds = exposureDurationSeconds * 1000.0
        exposureValueLabel.text = String(format: "%.2f ms", durationInMilliseconds)
    }
    
    @objc func focusChanged(_ sender: UISlider) {
        // Round the slider's value to the nearest 0.1 increment
        let roundedValue = round(sender.value * 50) / 50
        sender.value = roundedValue
        
        try? captureDevice.lockForConfiguration()
        captureDevice.setFocusModeLocked(lensPosition: sender.value, completionHandler: nil)
        captureDevice.unlockForConfiguration()

        // Update the focus value label with the current value of the slider
        focusValueLabel.text = String(format: "%.2f", sender.value)
    }

    
    @objc func isoChanged(_ sender: UISlider) {
        try? captureDevice.lockForConfiguration()
        captureDevice.setExposureModeCustom(duration: captureDevice.exposureDuration, iso: sender.value, completionHandler: nil)
        captureDevice.unlockForConfiguration()

        // Update the ISO value label with the current value of the slider
        isoValueLabel.text = String(format: "%.0f", sender.value)
    }

    
    @objc func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()

        // Set the maximum photo dimensions (this is a high-resolution 4K equivalent)
        if #available(iOS 16.0, *) {
            photoSettings.maxPhotoDimensions = .init(width: 3840, height: 2160)
        }

        // Turn off flash
        photoSettings.flashMode = .off
        // Capture the photo with the specified settings
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    
    @objc func startRecording() {
        if !movieOutput.isRecording {
            if let videoConnection = movieOutput.connection(with: .video) {
                videoConnection.videoRotationAngle = 0 // Rotate the video to landscape right
                // Disable video stabilization
                if videoConnection.isVideoStabilizationSupported {
                    videoConnection.preferredVideoStabilizationMode = .off
                }
                // Generate a unique file name using UUID
                let uniqueFileName = UUID().uuidString + ".mov"
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uniqueFileName)
                // Start recording to the unique file path
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                
                // Update button to show "Recording" and change color to green
                recordVideoButton.setTitle("Recording", for: .normal)
                recordVideoButton.backgroundColor = .green
            }
        } else {
            movieOutput.stopRecording()
            
            // Revert button to initial state after stopping recording
            recordVideoButton.setTitle("Video", for: .normal)
            recordVideoButton.backgroundColor = .blue
        }
    }



    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(), let originalImage = UIImage(data: imageData) {
            
            // Create a new image with the desired orientation
            let rotatedImage = UIImage(cgImage: originalImage.cgImage!, scale: 1.0, orientation: .up) // Adjust orientation here
            
            // Save the rotated image to the photo album
            UIImageWriteToSavedPhotosAlbum(rotatedImage, nil, nil, nil)
        }
    }
    
    // AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
        }
    }
}
