//
//  TransitionOperator.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/12.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage
import QuartzCore.CoreAnimation

public class TransitionOperator: ImageRelay {

	private var filter: CIFilter?
	private var displayLink: CADisplayLink? = nil
	private var progress: Float = 0.0
	private var started = false

	public init(filter: CIFilter?) {
		self.filter = filter
		super.init()
	}

	private func startDisplayLink() {
		displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink))
		displayLink?.preferredFramesPerSecond = 20
		displayLink?.add(to: .main, forMode: .common)
	}

	private func stopDisplayLink() {
		displayLink?.invalidate()
		displayLink = nil
		progress = 0
		started = false
		if let source = sources[safe: 0]?.source {
			source.remove(consumer: self)
			remove(source: source)
		}
	}

	@objc private func updateDisplayLink() {
		progress += 0.05
		if progress >= 1.0 {
			stopDisplayLink()
		}
	}


	public override func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
		super.newImageAvailable(bnImage, from: source)
		let type = bnImage.type
		guard _sources[safe: 0]?.ciImage != nil && _sources[safe: 1]?.ciImage != nil else {
			for consumer in consumers { consumer.newImageAvailable(bnImage, from: self) }
			return
		}
		
		if !started {
			startDisplayLink()
			started.toggle()
		}

		filter?.setValue(_sources[safe: 0]?.ciImage, forKey: kCIInputImageKey)
		filter?.setValue(_sources[safe: 1]?.ciImage, forKey: kCIInputTargetImageKey)
		filter?.setValue(progress, forKey: kCIInputTimeKey)
		if let output = filter?.outputImage {
			let newImage = BNImage(image: output, type: type)
			for consumer in consumers { consumer.newImageAvailable(newImage, from: self) }
		}
	}
}
