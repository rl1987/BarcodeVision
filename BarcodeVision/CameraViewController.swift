//
//  CameraViewController.swift
//  BarcodeVision
//
//  Created by Rimantas Lukosevicius on 24/06/2018.
//  Copyright © 2018 Rimantas Lukosevicius. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var session = AVCaptureSession()
    let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
    var previewLayer : AVCaptureVideoPreviewLayer?
    var request : VNDetectBarcodesRequest?
    var seqHandler : VNSequenceRequestHandler!
    var paused : Bool = false
    
    @IBOutlet weak var cameraView: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if previewLayer == nil {
            startVideoFeed()
        }
        
        self.paused = false
    }
    
    override func viewDidLayoutSubviews() {
        previewLayer?.frame = self.cameraView.bounds
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    private func startVideoFeed() {
        session.sessionPreset = .high
        
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        
        let imageLayer = AVCaptureVideoPreviewLayer(session: session)
        imageLayer.frame = self.view.bounds
        self.cameraView.layer.addSublayer(imageLayer)
        
        session.startRunning()
        
        request = VNDetectBarcodesRequest { (request, error) in
            guard let observations = request.results as? [VNObservation],
                observations.count > 0 else {
                return
            }
            
            for r in observations {
                if let barcodeObservation = r as? VNBarcodeObservation {
                    DispatchQueue.main.async {
                        self.handleObservation(observation: barcodeObservation)
                    }
                }
            }
        }
        
        seqHandler = VNSequenceRequestHandler()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if paused {
            return
        }
        
        // https://stackoverflow.com/questions/51214586/value-of-type-cmsamplebuffer-has-no-member-imagebuffer
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        guard let request = request else {
            return
        }
        
        try? seqHandler.perform([request], on: pixelBuffer)
    }

    func handleObservation(observation: VNBarcodeObservation) {
        if self.paused {
            return
        }
        
        guard let payload = observation.payloadStringValue else {
            return
        }
        
        self.paused = true
        
        let barcodeType = observation.symbology.rawValue.deletingPrefix("VNBarcodeSymbology")
        
        let title = "\(barcodeType) barcode detected (confidence \(observation.confidence))"
        
        let alertView = UIAlertController(title: title, message: payload, preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            self.paused = false
        }
        
        let shareAction = UIAlertAction(title: "Share", style: .default) { (action) in
            self.paused = false
            
            let shareSheet = UIActivityViewController(activityItems: [payload], applicationActivities: nil)
            self.present(shareSheet, animated: true, completion: nil)
        }
        
        alertView.addAction(cancelAction)
        alertView.addAction(shareAction)
        
        if observation.symbology == .EAN13 || observation.symbology == .EAN8 {
            let searchAction = UIAlertAction(title: "Search", style: .default) { (action) in
                alertView.dismiss(animated: true, completion: nil)
                
                self.paused = false
                
                guard let url = URL(string: "https://www.google.com/search?q=EAN+\(payload)") else {
                    return
                }
                
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            
            alertView.addAction(searchAction)
        }
        
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        
        present(alertView, animated: false) {
            generator.selectionChanged()
        }
    }
    
    @IBAction func flashlightSwitchFlipped(_ sender: UISwitch) {
        if let captureDevice = self.captureDevice,
            captureDevice.isTorchAvailable && captureDevice.isTorchModeSupported(.on) {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = sender.isOn ? .on : .off
                captureDevice.unlockForConfiguration()
            } catch {
                print("setting torch mode failed!")
                sender.isOn = !sender.isOn
            }
        }
    }
}

// https://www.hackingwithswift.com/example-code/strings/how-to-remove-a-prefix-from-a-string
extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
