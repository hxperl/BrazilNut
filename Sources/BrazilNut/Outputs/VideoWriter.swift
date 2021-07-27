//
//  MovieOutput.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import AVFoundation
import Photos

/* add Audio */
public protocol AudioEncodingTarget {
    func activateAudioTrack()
    func processAudioBuffer(_ sampleBuffer:CMSampleBuffer)
}

public protocol VideoWriterDelegate {
    func currentDuration(duration: CMTime)
}

public class VideoWriter: ImageConsumer, AudioEncodingTarget {
	
	public func add(source: ImageSource) {
		//
	}
	
	public func remove(source: ImageSource) {
		//
	}
	
    private lazy var ciContext: CIContext = { [unowned self] in
        return CIContext(mtlDevice: MetalDevice.shared.device)
    }()
    
    public var delegate: VideoWriterDelegate?
    
    let assetWriter:AVAssetWriter
    let assetWriterVideoInput:AVAssetWriterInput
    var assetWriterAudioInput:AVAssetWriterInput?

    let assetWriterPixelBufferInput:AVAssetWriterInputPixelBufferAdaptor
    let size:CGSize
    private var isRecording = false
    private var videoEncodingIsFinished = false
    private var audioEncodingIsFinished = false
    private var startTime:CMTime?
    private var previousFrameTime = CMTime.negativeInfinity
    private var previousAudioTime = CMTime.negativeInfinity
    private var encodingLiveVideo:Bool
    var pixelBuffer:CVPixelBuffer? = nil

    var transform:CGAffineTransform {
        get {
            return assetWriterVideoInput.transform
        }
        set {
            assetWriterVideoInput.transform = newValue
        }
    }

    public var frameTime:CMTime?    // add Current recording time
    
    public init(URL:Foundation.URL, size:CGSize, fileType:AVFileType = AVFileType.mov) throws {
        self.size = size
        assetWriter = try AVAssetWriter(url:URL, fileType:fileType)
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType:AVMediaType.video, outputSettings:[
            AVVideoCodecKey : AVVideoCodecType.h264,
            AVVideoWidthKey : size.width,
            AVVideoHeightKey : size.height,
            AVVideoCompressionPropertiesKey : [
                AVVideoAverageBitRateKey : 4166400,
            ],
            ])
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        encodingLiveVideo = true
        
        let sourcePixelBufferSetting = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey: size.width, kCVPixelBufferHeightKey: size.height ] as [String: Any]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:assetWriterVideoInput, sourcePixelBufferAttributes: sourcePixelBufferSetting)
        assetWriter.add(assetWriterVideoInput)
        
    }
    
    public func startRecording(transform:CGAffineTransform? = nil) {
        if let transform = transform {
            assetWriterVideoInput.transform = transform
        }
        startTime = nil
        self.isRecording = self.assetWriter.startWriting()
    }
    
    public func finishRecording(_ completionCallback:((AVAsset?, CMTime?) -> ())? = nil) {
        self.isRecording = false
        if (self.assetWriter.status == .completed || self.assetWriter.status == .cancelled || self.assetWriter.status == .unknown) {
            DispatchQueue.global().async{
                completionCallback?(nil, nil)
            }
            return
        }
        if ((self.assetWriter.status == .writing) && (!self.videoEncodingIsFinished)) {
            self.videoEncodingIsFinished = true
            self.assetWriterVideoInput.markAsFinished()
        }
        if ((self.assetWriter.status == .writing) && (!self.audioEncodingIsFinished)) {
            self.audioEncodingIsFinished = true
            self.assetWriterAudioInput?.markAsFinished()
        }
        
        // Why can't I use ?? here for the callback?
        if let callback = completionCallback {
            self.assetWriter.finishWriting {
                let url = self.assetWriter.outputURL
                let asset = AVAsset(url: url)
                callback(asset, self.startTime)
            }
        } else {
            self.assetWriter.finishWriting{}
        }
    }
 
    public func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
        guard isRecording else { return }
        guard let frameTime = bnImage.type.timestamp,
        (frameTime != previousFrameTime) else { return }
        
        let resized = bnImage.image.transformToOrigin(withSize: self.size)
        
        
        if (startTime == nil) {
            if (assetWriter.status != .writing) {
                assetWriter.startWriting()
            }
            assetWriter.startSession(atSourceTime: frameTime)
            startTime = frameTime
        }
        self.frameTime = frameTime
        // TODO: Run the following on an internal movie recording dispatch queue, context
        guard (assetWriterVideoInput.isReadyForMoreMediaData || (!encodingLiveVideo)) else {
            debugPrint("Had to drop a frame at time \(frameTime)")
            return
        }
        
        let duration = CMTimeSubtract(frameTime, self.startTime!)
        delegate?.currentDuration(duration: duration)
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(resized.extent.width), Int(resized.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess, let unwrappedPixelBuffer = pixelBuffer else {
            return
        }
        
        ciContext.render(resized, to: unwrappedPixelBuffer)
        
        CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, [])
        
        if (!assetWriterPixelBufferInput.append(unwrappedPixelBuffer, withPresentationTime:frameTime)) {
            print("Problem appending pixel buffer at time: \(frameTime)")
        }
        
        CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, [])
    }
    
    
    
    /* add audio */
    // MARK: -
    // MARK: Audio support
    
    public func activateAudioTrack() {
        assetWriterAudioInput = AVAssetWriterInput(mediaType:AVMediaType.audio, outputSettings:[
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : 2,
            AVSampleRateKey : 44100.0,
            AVEncoderBitRateKey: 192000])
        assetWriter.add(assetWriterAudioInput!)
        assetWriterAudioInput?.expectsMediaDataInRealTime = encodingLiveVideo
    }
    
    public func processAudioBuffer(_ sampleBuffer:CMSampleBuffer) {
        guard let assetWriterAudioInput = assetWriterAudioInput, (assetWriterAudioInput.isReadyForMoreMediaData || (!self.encodingLiveVideo)) else {
            return
        }
        
        if (!assetWriterAudioInput.append(sampleBuffer)) {
            print("Trouble appending audio sample buffer")
        }
    }
    
}
