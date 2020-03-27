//
//  Pipeline.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//
import CoreImage

infix operator --> : AdditionPrecedence

@discardableResult public func --><T: ImageConsumer>(source: ImageSource, destination:T) -> T {
    return source.add(consumer: destination)
}

public protocol ImageSource: AnyObject {
    /// Output 텍스처를 출력하기 위한 image consumer 추가
    ///
    /// - Parameter consumer: image consumer object to add
    /// - Returns: image consumer object
    func add<T: ImageConsumer>(consumer: T) -> T
    
    /// Adds an image consumer at the specific index
    ///
    /// - Parameters:
    ///   - consumer: image consumer object to add
    ///   - index: index for the image consumer object
    func add(consumer: ImageConsumer, at index: Int)
    
    /// image consumer 제거
    ///
    /// - Parameters consumer: image consumer object to remove
    func remove(consumer: ImageConsumer)
    
    /// Removs all image consumers
    func removeAllConsumers()
}

public protocol ImageConsumer: AnyObject {
    /// 텍스처를 제공 받기 위한 image source 추가
    ///
    /// - Parameter source: image source object to add
    func add(source: ImageSource)
    
    /// image source 제거
    ///
    /// - Parameter source: image source object to remove
    func remove(source: ImageSource)
    
    /// image source로 부터 새로운 텍스처를 받음
    ///
    /// - Parameters:
    ///     - texture: 새로운 텍스처
    ///     - source: 새로운 텍스처를 전달한 image source object
    func newImageAvailable(_ bnImage: BNImage, from source: ImageSource)
}

public struct WeakImageSource {
    public weak var source: ImageSource?
    public var ciImage: CIImage?
    
    public init(source: ImageSource) { self.source = source }
}
