import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {

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



    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupSliders()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .inputPriority
        
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
            if captureDevice.iso >= captureDevice.activeFormat.minISO && captureDevice.iso <= captureDevice.activeFormat.maxISO {
                captureDevice.setExposureModeCustom(duration: captureDevice.exposureDuration, iso: desiredISO, completionHandler: nil)
            }
            
            // Set the initial exposure duration to 2 ms
            let initialExposureDurationSeconds = 0.002
            let minExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration)
            let maxExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration)

            if initialExposureDurationSeconds >= minExposureDurationSeconds && initialExposureDurationSeconds <= maxExposureDurationSeconds {
                let initialExposureDuration = CMTimeMakeWithSeconds(initialExposureDurationSeconds, preferredTimescale: 1000*1000*1000)
                captureDevice.setExposureModeCustom(duration: initialExposureDuration, iso: desiredISO, completionHandler: nil)
            }
            
//            // Ensure slider reflects the initial exposure duration
//            exposureSlider.minimumValue = Float(minExposureDurationSeconds)
//            exposureSlider.maximumValue = Float(maxExposureDurationSeconds)
//            exposureSlider.value = Float(initialExposureDurationSeconds)

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

        // ISO Slider Setup
        isoSlider.frame = CGRect(x: 20, y: 150, width: 280, height: 40)
        isoSlider.minimumValue = captureDevice.activeFormat.minISO
        isoSlider.maximumValue = captureDevice.activeFormat.maxISO
        isoSlider.value = captureDevice.activeFormat.minISO
        view.addSubview(isoSlider)
        isoValueLabel.frame = CGRect(x: 310, y: 150, width: 60, height: 40)
        isoValueLabel.textAlignment = .left
        isoValueLabel.text = String(format: "%.0f", isoSlider.value)
        view.addSubview(isoValueLabel)
        
        // Exposure Slider Setup
        exposureSlider.frame = CGRect(x: 20, y: 200, width: 280, height: 40)
        let minExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.minExposureDuration)
        let maxExposureDurationSeconds = CMTimeGetSeconds(captureDevice.activeFormat.maxExposureDuration)

        exposureSlider.minimumValue = Float(minExposureDurationSeconds)+0.0001
        exposureSlider.maximumValue = Float(maxExposureDurationSeconds)/200
        exposureSlider.value = 0.002 // or any default value within the range
        view.addSubview(exposureSlider)
        
        exposureValueLabel.frame = CGRect(x: 310, y: 200, width: 60, height: 40)
        exposureValueLabel.textAlignment = .left
        exposureValueLabel.text = String(format: "%.2f", exposureSlider.value)
        view.addSubview(exposureValueLabel)
        
        // Focus Slider Setup
        focusSlider.frame = CGRect(x: 20, y: 100, width: 280, height: 40)
        focusSlider.minimumValue = 0.0
        focusSlider.maximumValue = 1.0
        focusSlider.value = 0.5
        view.addSubview(focusSlider)
        // Configure and position the focus value label
        focusValueLabel.frame = CGRect(x: 310, y: 100, width: 60, height: 40)
        focusValueLabel.textAlignment = .left
        focusValueLabel.text = String(format: "%.2f", focusSlider.value)
        view.addSubview(focusValueLabel)
        


        

        
        focusSlider.addTarget(self, action: #selector(focusChanged(_:)), for: .valueChanged)
        isoSlider.addTarget(self, action: #selector(isoChanged(_:)), for: .valueChanged)
        exposureSlider.addTarget(self, action: #selector(exposureChanged(_:)), for: .valueChanged)
                
        let capturePhotoButton = UIButton(frame: CGRect(x: 20, y: 250, width: 100, height: 50))
        capturePhotoButton.setTitle("Photo", for: .normal)
        capturePhotoButton.backgroundColor = .red
        capturePhotoButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(capturePhotoButton)
        
        let recordVideoButton = UIButton(frame: CGRect(x: 140, y: 250, width: 100, height: 50))
        recordVideoButton.setTitle("Record", for: .normal)
        recordVideoButton.backgroundColor = .blue
        recordVideoButton.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
        view.addSubview(recordVideoButton)
        


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

    @objc func exposureChanged(_ sender: UISlider) {
        let exposureDurationSeconds = Double(sender.value)
        let exposureDuration = CMTimeMakeWithSeconds(exposureDurationSeconds, preferredTimescale: 1000*1000*1000)
        
        try? captureDevice.lockForConfiguration()
        captureDevice.setExposureModeCustom(duration: exposureDuration, iso: captureDevice.iso, completionHandler: nil)
        captureDevice.unlockForConfiguration()

        // Display the exposure duration in a more readable format
        let durationInMilliseconds = exposureDurationSeconds * 1000.0
        exposureValueLabel.text = String(format: "%.2f ms", durationInMilliseconds)
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
                // Disable video stabilization
                if videoConnection.isVideoStabilizationSupported {
                    videoConnection.preferredVideoStabilizationMode = .off
                }
                // Generate a unique file name using UUID
                let uniqueFileName = UUID().uuidString + ".mov"
                let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(uniqueFileName)
                // Start recording to the unique file path
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            }
            } else {
            movieOutput.stopRecording()
        }
    }

    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation() {
            let image = UIImage(data: imageData)
            UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
        }
    }
    
    // AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
        }
    }
}
