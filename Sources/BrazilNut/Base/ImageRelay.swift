//
//  ImageRelay.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/15.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//
import Foundation

open class ImageRelay: ImageSource, ImageConsumer {

	let lock = DispatchSemaphore(value: 1)
    /// Image consumers
    public var consumers: [ImageConsumer] {
        lock.wait()
        let c = _consumers
        lock.signal()
        return c
    }
    private var _consumers: [ImageConsumer]
    
    /// Image sources
    public var sources: [WeakImageSource] {
        lock.wait()
        let s = _sources
        lock.signal()
        return s
    }
    private(set) var _sources: [WeakImageSource]
	
	public init() {
		_consumers = []
        _sources = []
	}
	
	open func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
		lock.wait()
		for idx in 0..<_sources.count {
			if _sources[safe: idx]?.source === source {
				_sources[idx].ciImage = bnImage.image
			}
		}
		lock.signal()
	}

	// MARK: - ImageSource
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

    public func removeSelf() {
        for wSource in _sources {
            wSource.source?.remove(consumer: self)
            for (idx, consumer) in consumers.enumerated() {
                wSource.source?.add(consumer: consumer, at: idx)
            }
        }
        removeAllConsumers()
        self._sources.removeAll()
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

    // MARK: - ImageConsumer

    public func add(source: ImageSource) {
		remove(source: source)
        lock.wait()
        _sources.append(WeakImageSource(source: source))
        lock.signal()
    }

    public func remove(source: ImageSource) {
        lock.wait()
        if let index = _sources.firstIndex(where: { $0.source === source }) {
            _sources.remove(at: index)
        }
        lock.signal()
    }

}

public extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
