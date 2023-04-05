//
//  BarCodeVC.swift
//  DMC-Scanner-AVFoundation
//
//  Created by Ibrahim Hassan on 30/03/23.
//

import UIKit
import AVFoundation
import Vision

class ScannerVisionVC: UIViewController, UIGestureRecognizerDelegate {
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let captureSession = AVCaptureSession()
    
    private var zoomScale = CGFloat(1.0)
    private var beginZoomScale = CGFloat(1.0)
    
    weak var delegate: ScannerDelegate?
    
    var usePreprocessing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        captureSession.sessionPreset = .hd1920x1080

        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus(sender:)))

        view.isUserInteractionEnabled = true
        tap.delegate = self
        view.addGestureRecognizer(tap)

        let zoomGesture = UIPinchGestureRecognizer()
        zoomGesture.addTarget(self, action: #selector(zoomStart(_:)))
        zoomGesture.delegate = self
        view.addGestureRecognizer(zoomGesture)

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    @objc private func zoomStart(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = self.view,
            let previewLayer = previewLayer
            else { return }

        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches

        for i in 0 ..< numTouch {
            let location = recognizer.location(ofTouch: i, in: view)
            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
            if !previewLayer.contains(convertedTouch) {
                allTouchesOnPreviewLayer = false
                break
            }
        }

        if allTouchesOnPreviewLayer {
            zoom(recognizer.scale)
        }
    }
    
    @objc func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale
        }
        
        return true
    }

    private func zoom(_ scale: CGFloat) {
        let device = AVCaptureDevice.devices(for: .video).filter({ $0.position == .back }).first
        let maxZoomScale = device?.maxAvailableVideoZoomFactor ?? 1.0
        
        do {
            let captureDevice = device
            try captureDevice?.lockForConfiguration()

            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))

            captureDevice?.videoZoomFactor = zoomScale

            captureDevice?.unlockForConfiguration()
        } catch {
            print("Error locking configuration")
        }
    }

    @objc private func handleTapToFocus(sender: UITapGestureRecognizer) {
        if let device = AVCaptureDevice.devices(for: .video).filter({ $0.position == .back }).first {
            let previewView = self.view ?? UIView()

            let focusPoint = sender.location(in: previewView)
            let focusScaledPointX = focusPoint.x
            let focusScaledPointY = focusPoint.y
            
            showYellowFocusView(CGPoint(x: focusScaledPointX, y: focusScaledPointY))

            if device.isFocusModeSupported(.autoFocus) && device.isFocusPointOfInterestSupported {
                do {
                    try device.lockForConfiguration()
                } catch {
                    print("ERROR: Could not lock camera device for configuration")
                    return
                }
                 
                device.focusMode = .autoFocus
                device.focusPointOfInterest = CGPointMake(focusScaledPointX, focusScaledPointY)

                device.unlockForConfiguration()
            }
        }
    }
    
    private func showYellowFocusView(_ touchPoint: CGPoint) {
        if let focusView = self.view.viewWithTag(1001) {
            focusView.removeFromSuperview()
        }

        let focusView = UIView()
        focusView.tag = 1001
        
        focusView.backgroundColor = .clear
        focusView.layer.borderWidth = 2.0
        focusView.layer.borderColor = UIColor.yellow.cgColor
        
        focusView.frame.size.width = 100
        focusView.frame.size.height = 100
        
        focusView.frame.origin.x = touchPoint.x - 50
        focusView.frame.origin.y = touchPoint.y - 50
        
        self.view.addSubview(focusView)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            focusView.removeFromSuperview()
        }
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession.canAddInput(input) {
                self.captureSession.addInput(input)
            }

            self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]

            let queue = DispatchQueue(label: "my.image.handling.queue", qos: .userInitiated)
            self.videoOutput.setSampleBufferDelegate(self, queue: queue)
            self.captureSession.addOutput(self.videoOutput)

            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            } else {
                print("Could not add video output")
            }

            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer.videoGravity = .resizeAspect

            DispatchQueue.main.async {
                self.previewLayer.frame = self.view.bounds
                self.view.layer.addSublayer(self.previewLayer)
            }
        }
    }
}

extension ScannerVisionVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }

        if let code = extractQRCode(fromFrame: frame) {
            DispatchQueue.main.async {
                self.dismiss(animated: true)
                self.delegate?.dataMatrixCodeRead(code)
            }
        }
    }

    private func extractQRCode(fromFrame frame: CVImageBuffer) -> String? {
        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.dataMatrix]

        let ciimage = CIImage(cvImageBuffer: frame)

        if usePreprocessing, let bwImage = preprocessImagePipeLine1(ciimage) {
            try? self.sequenceHandler.perform([barcodeRequest], on: bwImage)
        } else {
            try? self.sequenceHandler.perform([barcodeRequest], on: frame)
        }

        guard let results = barcodeRequest.results, let firstBarcode = results.first?.payloadStringValue else {
            return nil
        }

        return firstBarcode
    }
    
    private func preprocessImagePipeLine1(_ ciImage: CIImage?) -> CIImage? {
        guard let ciImage else { return nil }

        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputBrightnessKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)
        filter?.setValue(1.1, forKey: kCIInputContrastKey)

        guard let intermediateImage = filter?.outputImage else { return nil }

        let filter1 = CIFilter(name:"CIExposureAdjust")
        filter1?.setValue(intermediateImage, forKey: kCIInputImageKey)
        filter1?.setValue(0.7, forKey: kCIInputEVKey)

        return filter1?.outputImage
    }

    private func preprocessImagePipeLine2(_ inputImage: CIImage?) -> CIImage? {
        guard let inputImage else { return nil }

        let threasholdFilter = CIFilter(name: "CIColorThresholdOtsu")
        threasholdFilter?.setValue(inputImage, forKey: "inputImage")

        return threasholdFilter?.outputImage
    }
}
