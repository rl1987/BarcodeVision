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
    var request : VNDetectBarcodesRequest!
    var seqHandler : VNSequenceRequestHandler!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        startVideoFeed()
    }
    
    override func viewDidLayoutSubviews() {
        previewLayer?.frame = self.view.bounds
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
        self.view.layer.addSublayer(imageLayer)
        
        session.startRunning()
        
        request = VNDetectBarcodesRequest { (request, error) in
            guard let observations = request.results as? [VNObservation],
                observations.count > 0 else {
                return
            }
            
            for r in observations {
                if let barcodeObservation = r as? VNBarcodeObservation,
                    let payload = barcodeObservation.payloadStringValue {
                    print(payload)
                }
            }
        }
        
        seqHandler = VNSequenceRequestHandler()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer : CVPixelBuffer = sampleBuffer.imageBuffer!
        
        try? seqHandler.perform([request], on: pixelBuffer)
    }

}

