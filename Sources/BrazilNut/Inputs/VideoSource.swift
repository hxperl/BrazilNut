//
//  VideoSource.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/03.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//
import AVFoundation
import CoreImage
import Combine

public typealias VideoSourceProgress = (CMTime) -> Void
public typealias VideoSourceCompletion = (Bool) -> Void

/// Video source reading video frame and providing Core Image
public class VideoSource: ImageSource {
	
	/// Image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }
    private var _consumers: [ImageConsumer]
    private let url: URL
    private let lock: DispatchSemaphore
    private var asset: AVAsset!
    private var assetReader: AVAssetReader!
    private var videoOutput: AVAssetReaderTrackOutput!
    private var audioOutput: AVAssetReaderTrackOutput!
    private var lastAudioBuffer: CMSampleBuffer?

	let queue = DispatchQueue(label: "VideoProcessingQueue")
	var subscription: Cancellable?
    /// Audio consumer processing audio sample buffer.
    /// Set this property to nil (default value) if not processing audio.
    /// Set this property to a given audio consumer if processing audio.
    public var audioEncodingTarget: AudioEncodingTarget? {
        didSet {
            audioEncodingTarget?.activateAudioTrack()
        }
    }
    
    /// Whether to process video with the actual rate. False by default, meaning the
	/// processing speed is faster than the actual video rate.
    public var playWithVideoRate: Bool {
        get {
            lock.wait()
            let playRate = _playWithVideoRate
            lock.signal()
            return playRate
        }
        set {
            lock.wait()
            _playWithVideoRate = newValue
            lock.signal()
        }
    }
    private var _playWithVideoRate: Bool
    
    private var lastSampleFrameTime: CMTime!
    private var lastActualPlayTime: Double!

    public init(url: URL) {
        self.url = url
        lock = DispatchSemaphore(value: 1)
		_consumers = []
        _playWithVideoRate = false
    }

    /// Starts reading and processing video frame
    ///
    /// - Parameter completion: a closure to call after processing;
	/// The parameter of closure is true if succeed processing all video frames,
	/// or false if fail to processing all the video frames (due to user cancel or error)
    public func start(progress: VideoSourceProgress? = nil, completion: VideoSourceCompletion? = nil) {
        lock.wait()
        let isReading = (assetReader != nil)
        lock.signal()
        if isReading {
            print("Should not call \(#function) while asset reader is reading")
            return
        }
        let asset = AVAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            guard let self = self else { return }
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded,
                asset.tracks(withMediaType: .video).first != nil {
                DispatchQueue.global().async { [weak self] in
                    guard let self = self else { return }
                    self.lock.wait()
                    self.asset = asset
                    if self.prepareAssetReader() {
                        self.lock.signal()
                        self.processAsset(progress: progress, completion: completion)
                    } else {
                        self.reset()
                        self.lock.signal()
                    }
                }
            } else {
                self.safeReset()
            }
        }
    }

    /// Cancels reading and processing video frame
    public func cancel() {
        lock.wait()
        if let reader = assetReader,
            reader.status == .reading {
            reader.cancelReading()
            reset()
        }
        lock.signal()
    }

    private func safeReset() {
        lock.wait()
        reset()
        lock.signal()
    }

    private func reset() {
        asset = nil
        assetReader = nil
        videoOutput = nil
        audioOutput = nil
        lastAudioBuffer = nil
    }

    private func prepareAssetReader() -> Bool {
        guard let reader = try? AVAssetReader(asset: asset),
            let videoTrack = asset.tracks(withMediaType: .video).first else { return false }
        assetReader = reader
        videoOutput = AVAssetReaderTrackOutput(track: videoTrack,
											   outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        videoOutput.alwaysCopiesSampleData = false
        if !assetReader.canAdd(videoOutput) { return false }
        assetReader.add(videoOutput)

        if audioEncodingTarget != nil,
            let audioTrack = asset.tracks(withMediaType: .audio).first {
            audioOutput = AVAssetReaderTrackOutput(track: audioTrack,
												   outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
            audioOutput.alwaysCopiesSampleData = false
            if !assetReader.canAdd(audioOutput) { return false }
            assetReader.add(audioOutput)
        }
        return true
    }

    private func processAsset(progress: VideoSourceProgress?, completion: VideoSourceCompletion?) {
        lock.wait()
        guard let reader = assetReader,
            reader.status == .unknown,
            reader.startReading() else {
            reset()
            lock.signal()
            return
        }
        lock.signal()
        // Read and process video buffer
        let useVideoRate = _playWithVideoRate
        var sleepTime: Double = 0

		subscription = queue.schedule(after: queue.now, interval: .milliseconds(1)) { [weak self] in
			guard reader.status == .reading, let sampleBuffer = self?.videoOutput.copyNextSampleBuffer(),
				let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
					self?.subscription?.cancel()
					// Read and process the rest audio buffers
					if let consumer = self?.audioEncodingTarget,
						let audioBuffer = self?.lastAudioBuffer {
						consumer.processAudioBuffer(audioBuffer)
					}
					while let consumer = self?.audioEncodingTarget,
						reader.status == .reading,
						self?.audioOutput != nil,
						let audioBuffer = self?.audioOutput.copyNextSampleBuffer() {
							consumer.processAudioBuffer(audioBuffer)
					}
					var finish = false
					if self?.assetReader != nil {
						self?.reset()
						finish = true
					}
					completion?(finish)
					return
			}
			let sampleFrameTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
			if useVideoRate {
				if let lastFrameTime = self?.lastSampleFrameTime,
					let lastPlayTime = self?.lastActualPlayTime {
					let detalFrameTime = CMTimeGetSeconds(CMTimeSubtract(sampleFrameTime, lastFrameTime))
					let detalPlayTime = CACurrentMediaTime() - lastPlayTime
					if detalFrameTime > detalPlayTime {
						sleepTime = detalFrameTime - detalPlayTime
						usleep(UInt32(1000000 * sleepTime))
					} else {
						sleepTime = 0
					}
				}
				self?.lastSampleFrameTime = sampleFrameTime
				self?.lastActualPlayTime = CACurrentMediaTime()
			}

			// Read and process audio buffer
			// Let video buffer go faster than audio buffer
			// Make sure audio and video buffer have similar output presentation timestamp
			var currentAudioBuffer: CMSampleBuffer?
			if self?.audioEncodingTarget != nil {
				if let last = self?.lastAudioBuffer,
					CMTimeCompare(CMSampleBufferGetOutputPresentationTimeStamp(last), sampleFrameTime) <= 0 {
					// Process audio buffer
					currentAudioBuffer = last
					self?.lastAudioBuffer = nil

				} else if self?.lastAudioBuffer == nil,
					self?.audioOutput != nil,
					let audioBuffer = self?.audioOutput.copyNextSampleBuffer() {
					if CMTimeCompare(CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer), sampleFrameTime) <= 0 {
						// Process audio buffer
						currentAudioBuffer = audioBuffer
					} else {
						// Audio buffer goes faster than video
						// Process audio buffer later
						self?.lastAudioBuffer = audioBuffer
					}
				}
			}
			let bnImage = BNImage(image: CIImage(cvPixelBuffer: imageBuffer), type: .videoFrame(timestamp: sampleFrameTime))
			for consumer in self!.consumers {
				consumer.newImageAvailable(bnImage, from: self!)
			}
			if let audioBuffer = currentAudioBuffer { self?.audioEncodingTarget?.processAudioBuffer(audioBuffer) }
			progress?(sampleFrameTime)
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
