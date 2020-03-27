//
//  Camera.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import AVFoundation
import CoreImage

public class Camera: NSObject, ImageSource {
	
	private let lock = DispatchSemaphore(value: 1)
    
    /// Image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }
    private var _consumers: [ImageConsumer]
    
    // capture session
    var captureSession: AVCaptureSession?
    
    // Processing Queue
    let cameraProcessingQueue = DispatchQueue.global()
    let audioProcessingQueue = DispatchQueue.global()
    let cameraFrameProcessingQueue = DispatchQueue(label: "cameraFrameProcessingQueue")
    let cameraPhotoProcessingQueue = DispatchQueue(label: "cameraPhotoProcessingQueue")
    
    // Device
    var audioDevice: AVCaptureDevice?
    var audioDeviceInput: AVCaptureDeviceInput?
    
    var frontCamera: AVCaptureDevice?
    var frontCameraInput: AVCaptureDeviceInput?

	var frontWideCamera: AVCaptureDevice?
    var frontWideCameraInput: AVCaptureDeviceInput?

	var frontUltraWideCamera: AVCaptureDevice?
	var frontUltraWideCameraInput: AVCaptureDeviceInput?

	var backCamera: AVCaptureDevice?
	var backCameraInput: AVCaptureDeviceInput?
	
    var backWideCamera: AVCaptureDevice?
    var backWideCameraInput: AVCaptureDeviceInput?

	var backUltraWideCamera: AVCaptureDevice?
	var backUltraWideCameraInput: AVCaptureDeviceInput?
	
	public var isUltraWideAngleSupported: Bool {
		if self.cameraPosition == .back {
			return self.backUltraWideCamera != nil
		}
		return self.frontUltraWideCamera != nil
	}

    // Output
    var videoDataOutput: AVCaptureVideoDataOutput?
    var photoOutput: AVCapturePhotoOutput?
    var audioOutput: AVCaptureAudioDataOutput?
    
    let minimumZoom: CGFloat = 1
    let maximumZoom: CGFloat = 3
    var lastZoomFactor: CGFloat = 1

    public var audioEncodingTarget: AudioEncodingTarget? {
        didSet {
            audioEncodingTarget?.activateAudioTrack()
        }
    }

    let sessionPreset: AVCaptureSession.Preset
	var cameraPosition: AVCaptureDevice.Position
    private var orientation: AVCaptureVideoOrientation

	public init(
		sessionPreset: AVCaptureSession.Preset,
		position: AVCaptureDevice.Position = .back,
		orientation: AVCaptureVideoOrientation = .portrait) throws {
        self.sessionPreset = sessionPreset
        self.cameraPosition = position
        self.orientation = orientation
		_consumers = []
        super.init()
        createCaptureSession()
        try configureCaptureDevices()
        try configureDeviceInputs()
        try configureFrameOutput()
        try configureAudioOutput()
        try configurePhotoOutput()
        self.captureSession?.commitConfiguration()
    }

    public func startCapture() {
        if let session = self.captureSession, !session.isRunning {
            session.startRunning()
        }
    }

    public func stopCapture() {
        if let session = self.captureSession, session.isRunning {
            session.stopRunning()
        }
    }
}

// MARK: - Public Methods
extension Camera {

	public func setUltraWideAngle() throws {
		guard let captureSession = self.captureSession,
			captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
		captureSession.beginConfiguration()
		defer {
			captureSession.commitConfiguration()
		}

		func switchToUltraWideBack() throws {
			guard let backCameraInput = self.backCameraInput, captureSession.inputs.contains(backCameraInput),
				let backUltraWideCamera = self.backUltraWideCamera else { throw CameraError.inputsAreInvalid }

			self.backUltraWideCameraInput = try AVCaptureDeviceInput(device: backUltraWideCamera)

			captureSession.removeInput(backCameraInput)

			if captureSession.canAddInput(self.backUltraWideCameraInput!) {
				captureSession.addInput(self.backUltraWideCameraInput!)

				self.backCamera = self.backUltraWideCamera
				self.backCameraInput = self.backUltraWideCameraInput
				captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = false
			} else {
                throw CameraError.invalidOperation
            }

		}

		func switchToUltraWideFront() throws {
			guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
				let frontUltraWideCamera = self.frontUltraWideCamera else { throw CameraError.inputsAreInvalid }
			self.frontUltraWideCameraInput = try AVCaptureDeviceInput(device: frontUltraWideCamera)
			captureSession.removeInput(frontCameraInput)
			if captureSession.canAddInput(self.frontUltraWideCameraInput!) {
				captureSession.addInput(self.frontUltraWideCameraInput!)
				self.frontCamera = self.frontUltraWideCamera
				self.frontCameraInput = self.frontUltraWideCameraInput
			} else {
                throw CameraError.invalidOperation
            }
		}

		switch cameraPosition {
		case .back:
			try switchToUltraWideBack()
		case .front:
			try switchToUltraWideFront()
		default:
			break
		}
	}

	public func setWideAngle() throws {
		guard let captureSession = self.captureSession,
			captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
		captureSession.beginConfiguration()
		defer {
			captureSession.commitConfiguration()
		}

		func switchToWideBack() throws {
			guard let backCameraInput = self.backCameraInput, captureSession.inputs.contains(backCameraInput),
				let backWideCamera = self.backWideCamera else { throw CameraError.inputsAreInvalid }

			self.backWideCameraInput = try AVCaptureDeviceInput(device: backWideCamera)

			captureSession.removeInput(backCameraInput)

			if captureSession.canAddInput(self.backWideCameraInput!) {
				captureSession.addInput(self.backWideCameraInput!)

				self.backCamera = self.backWideCamera
				self.backCameraInput = self.backWideCameraInput
				captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = false
			} else {
                throw CameraError.invalidOperation
            }

		}

		func switchToWideFront() throws {
			guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
				let frontWideCamera = self.frontWideCamera else { throw CameraError.inputsAreInvalid }

			self.frontWideCameraInput = try AVCaptureDeviceInput(device: frontWideCamera)

			captureSession.removeInput(frontCameraInput)

			if captureSession.canAddInput(self.frontWideCameraInput!) {
				captureSession.addInput(self.frontWideCameraInput!)

				self.frontCamera = self.frontWideCamera
				self.frontCameraInput = self.frontWideCameraInput
				captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = true
			} else {
                throw CameraError.invalidOperation
            }

		}

		switch cameraPosition {
		case .back:
			try switchToWideBack()
		case .front:
			try switchToWideFront()
		default:
			break
		}
	}

    public func takePhoto(with settings: AVCapturePhotoSettings? = nil) {
        let settings = settings ??
			AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    public func switchCameras() throws {
        guard let captureSession = self.captureSession,
			captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
        captureSession.beginConfiguration()
        func switchToFrontCamera() throws {
			guard let rearCameraInput = self.backCameraInput, captureSession.inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraError.invalidOperation }
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            captureSession.removeInput(rearCameraInput)
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                self.cameraPosition = .front
                captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = true
            } else {
                throw CameraError.invalidOperation
            }
        }

        func switchToRearCamera() throws {
            guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
                let backCamera = self.backCamera else { throw CameraError.invalidOperation }
            self.backCameraInput = try AVCaptureDeviceInput(device: backCamera)
            captureSession.removeInput(frontCameraInput)
            if captureSession.canAddInput(self.backCameraInput!) {
				captureSession.addInput(self.backCameraInput!)
				self.cameraPosition = .back
                captureSession.outputs.first?.connections.first?.videoOrientation = self.orientation
                captureSession.outputs.first?.connections.first?.isVideoMirrored = false
			} else { throw CameraError.invalidOperation }
        }

        switch cameraPosition {
        case .front:
            try switchToRearCamera()
        case .back:
            try switchToFrontCamera()
		default:
			break
        }
        captureSession.commitConfiguration()
    }

    public func setFocusPoint(point: CGPoint) throws {
        
        guard let device = cameraPosition == .back ? self.backCamera : self.frontCamera else { return }
        try device.lockForConfiguration()
        defer {
            device.unlockForConfiguration()
        }
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }
        
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = point
            device.exposureMode = .continuousAutoExposure
        }
    }
    
	public func currentPosition() -> AVCaptureDevice.Position {
		return self.cameraPosition
    }
    
    public func changeZoom(scale: CGFloat) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
        
        func setZoomFactor(device: AVCaptureDevice) {
            
            func minMaxZoom(_ factor: CGFloat) -> CGFloat {
                return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
            }
            
            let newScaleFactor = minMaxZoom(scale * lastZoomFactor)
            
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = newScaleFactor
            } catch {
                print(error)
            }
            
            lastZoomFactor = minMaxZoom(newScaleFactor)
        }
        
        switch cameraPosition {
        case .front:
            if let device = self.frontCamera {
                setZoomFactor(device: device)
            }
		case .back:
			if let device = self.backCamera {
                setZoomFactor(device: device)
            }
		default:
			break
        }
    }
    
    public func changeBrightness(value: CGFloat) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraError.captureSessionIsMissing }
        
        func setBrightnessValue(device: AVCaptureDevice) {
            var newBias: Float = 0
            let minBias = device.minExposureTargetBias
            let maxBias = device.maxExposureTargetBias
            let range = maxBias - minBias
            let el = range / 100
            
            newBias = minBias + el * (Float(value) * 100)
            
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.setExposureTargetBias(newBias, completionHandler: nil)
            }catch {
                print(error)
            }
        }
        
        switch cameraPosition {
        case .front:
            if let device = self.frontCamera {
                setBrightnessValue(device: device)
            }
		case .back:
			if let device = self.backCamera {
                setBrightnessValue(device: device)
            }
		default:
			break
        }
        
    }
	
	
	@discardableResult
    public func add<T: ImageConsumer>(consumer: T) -> T {
		remove(consumer: consumer)
        lock.wait()
        _consumers.append(consumer)
        lock.signal()
        consumer.add(source: self)
        return consumer
    }
    
    public func add(consumer: ImageConsumer, at index: Int) {
		remove(consumer: consumer)
        lock.wait()
        _consumers.insert(consumer, at: index)
        lock.signal()
        consumer.add(source: self)
    }
    
    public func add(chain: ImageRelay) {
        for (idx, consumer) in consumers.enumerated() {
            chain.add(consumer: consumer, at: idx)
        }
        removeAllConsumers()
        add(consumer: chain, at: 0)
    }
    
    public func remove(consumer: ImageConsumer) {
        lock.wait()
        if let index = _consumers.firstIndex(where: { $0 === consumer }) {
            _consumers.remove(at: index)
            lock.signal()
            consumer.remove(source: self)
        } else {
            lock.signal()
        }
    }
    
    public func removeAllConsumers() {
        lock.wait()
        let consumers = _consumers
        _consumers.removeAll()
        lock.signal()
        for consumer in consumers {
            consumer.remove(source: self)
        }
    }
}


/// MARK: - Private Methods
extension Camera {
    private func createCaptureSession() {
            self.captureSession = AVCaptureSession()
            self.captureSession?.sessionPreset = self.sessionPreset
            self.captureSession?.beginConfiguration()
    }
        
        
    private func configureCaptureDevices() throws {
		let cameraSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera], mediaType: .video, position: .unspecified)
        
        let cameras = cameraSession.devices.compactMap { $0 }
        guard !cameras.isEmpty else { throw CameraError.noCamerasAvailable }
		
		self.frontWideCamera = cameras.filter({ $0.position == .front && $0.deviceType == .builtInWideAngleCamera }).first
		self.frontUltraWideCamera = cameras.filter({ $0.position == .front && $0.deviceType == .builtInUltraWideCamera }).first
		self.backWideCamera = cameras.filter({ $0.position == .back && $0.deviceType == .builtInWideAngleCamera }).first
		self.backUltraWideCamera = cameras.filter({ $0.position == .back && $0.deviceType == .builtInUltraWideCamera }).first
		
		self.frontCamera = frontWideCamera
		self.backCamera = backWideCamera
        
        let audioSession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: .audio, position: .unspecified)
        
        self.audioDevice = audioSession.devices.compactMap { $0 }.first
        
    }

    private func configureDeviceInputs() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        
        if self.cameraPosition == .back, let backCamera = self.backCamera {
            self.backCameraInput = try AVCaptureDeviceInput(device: backCamera)
            
            if captureSession.canAddInput(self.backCameraInput!) { captureSession.addInput(self.backCameraInput!) }
            else { throw CameraError.inputsAreInvalid }
        } else if self.cameraPosition == .front, let frontCamera = self.frontCamera {
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
            else { throw CameraError.inputsAreInvalid }
        } else {
            throw CameraError.noCamerasAvailable
        }
        
        if let audioDevice = self.audioDevice {
            self.audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if captureSession.canAddInput(self.audioDeviceInput!) {
                captureSession.addInput(self.audioDeviceInput!)
            }
        }
    }


    private func configureFrameOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        
        // capture frame
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        videoDataOutput?.setSampleBufferDelegate(self, queue: cameraProcessingQueue)
        guard captureSession.canAddOutput(videoDataOutput!) else { return }
        captureSession.addOutput(videoDataOutput!)
        guard let connection = videoDataOutput?.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        connection.videoOrientation = self.orientation
        connection.isVideoMirrored = cameraPosition == .front
    }
    
    private func configureAudioOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        
        // capture audio
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput?.setSampleBufferDelegate(self, queue: audioProcessingQueue)
        audioOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
        guard captureSession.canAddOutput(audioOutput!) else { return }
        captureSession.addOutput(audioOutput!)
        
    }
    
    private func configurePhotoOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraError.captureSessionIsMissing }
        photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput!) else { return }
        captureSession.addOutput(photoOutput!)
        photoOutput?.connection(with: .video)?.videoOrientation = .portrait
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoDataOutput {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            cameraFrameProcessingQueue.async { [weak self] in
				guard let self = self else { return }
                let image = CIImage(cvPixelBuffer: imageBuffer)
				for consumer in self.consumers {
					consumer.newImageAvailable(BNImage(image: image, type: .videoFrame(timestamp: timestamp)), from: self)
				}
            }
            
        } else if output == audioOutput {
            self.processAudioSampleBuffer(sampleBuffer)
        }
    }
    
    public func processAudioSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        self.audioEncodingTarget?.processAudioBuffer(sampleBuffer)
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if error != nil { return }
        
        if let sampleBuffer = photoSampleBuffer, let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            cameraPhotoProcessingQueue.async { [weak self] in
				guard let self = self else { return }
                let image = CIImage(cvPixelBuffer: imageBuffer)
                let trasnform = image.orientationTransform(for: .right)
                let transformed = image.transformed(by: trasnform)
				for consumer in self.consumers {
					consumer.newImageAvailable(BNImage(image: transformed, type: .photo), from: self)
				}
				
            }
        }
    }
	
}

public extension Camera {
    enum CameraError: Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    enum CameraPosition {
        case front
        case rear
    }
}

