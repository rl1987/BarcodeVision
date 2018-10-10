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
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
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
        
        let title = "\(observation.symbology.rawValue) barcode detected (confidence \(observation.confidence))"
        
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
        
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        
        present(alertView, animated: false) {
            generator.selectionChanged()
        }
    }
}

