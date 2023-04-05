//
//  BarCodeVC.swift
//  DMC-Scanner-AVFoundation
//
//  Created by Ibrahim Hassan on 30/03/23.
//

import UIKit
import AVFoundation

class ScannerAVFoundationVC: UIViewController, UIGestureRecognizerDelegate {
    private let output = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let captureSession = AVCaptureSession()
    
    private var zoomScale = CGFloat(1.0)
    private var beginZoomScale = CGFloat(1.0)
    
    weak var delegate: ScannerDelegate?

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
    
    @objc fileprivate func zoomStart(_ recognizer: UIPinchGestureRecognizer) {
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
        
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
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

            let metadataOutput = AVCaptureMetadataOutput()

            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)

                metadataOutput.setMetadataObjectsDelegate(self, queue: .global(qos: .userInitiated))
                metadataOutput.metadataObjectTypes = [.dataMatrix]
            } else {
                print("Could not add metadata output")
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

extension ScannerAVFoundationVC: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // This is the delegate's method that is called when a code is read
        for metadata in metadataObjects {
            if let readableObject = metadata as? AVMetadataMachineReadableCodeObject,
                let code = readableObject.stringValue {
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                    self.delegate?.dataMatrixCodeRead(code)
                }
            }
        }
    }
}
