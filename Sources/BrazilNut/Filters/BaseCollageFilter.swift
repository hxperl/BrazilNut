//
//  BaseCollageFilter.swift
//  BrazilNut
//
//  Created by 김지수 on 2020/04/10.
//

import CoreImage

/// normalized value
public typealias Rect = (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)

open class BaseCollageFilter: ImageRelay{
    public let rects: [Rect]
    
    public init(rects: [Rect]) {
        self.rects = rects
        super.init()
    }
    
    override public func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
        super.newImageAvailable(bnImage, from: source)
        
        let inputImage = bnImage.image
        let inputType = bnImage.type
        let originSize = inputImage.extent.size
        
        if _sources[0].source !== source { return }

        let outputRect = CGRect(x: 0, y: 0, width: originSize.width, height: originSize.height)
        let backgroundImage = CIFilter(name: "CIConstantColorGenerator", parameters: [kCIInputColorKey: CIColor(red:0, green: 0, blue: 0)])!.outputImage!.cropped(to: outputRect)
        var compositeImage = CIImage()
        
        for i in 0..<rects.count {
            guard let rect = rects[safe: i], let currentSource = _sources[safe: i] else { return }
            var target = CIImage()
            
            if var sourceImage = currentSource.ciImage{
                /// unify size
                if outputRect.size != sourceImage.extent.size{
                    let scaleX = outputRect.width / sourceImage.extent.width
                    let scaleY = outputRect.height / sourceImage.extent.height
                    sourceImage = sourceImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                }
                
                target = transformedSource(ciImage: sourceImage, rect: rect)
            }
            
            let translate = target.transformed(by: CGAffineTransform(translationX: outputRect.size.width * rect.x - target.extent.minX,
                                                                     y: outputRect.size.height * (1 - rect.y) - target.extent.height - target.extent.minY))
            
            compositeImage = translate.composited(over: compositeImage)
        }
        
        let collageImage = compositeImage.composited(over: backgroundImage)
        let newImage = BNImage(image: collageImage, type: inputType)
        
        for consumer in consumers {
            consumer.newImageAvailable(newImage, from: self)
        }
    }
    
    /// Transform the source image.
    /// Returns the CIImage by default.
    /// Override the method if needed.
    open func transformedSource(ciImage: CIImage, rect: Rect) -> CIImage {
        var transformedImage: CIImage
        if rect.w == rect.h{
            let scaledImg = ciImage.transformed(by: CGAffineTransform(scaleX: rect.w, y: rect.h))
            transformedImage = scaledImg
        }else{
            let newRect = CGRect(x: ciImage.extent.minX,
                                 y: ciImage.extent.minY,
                                 width: ciImage.extent.width * rect.w,
                                 height: ciImage.extent.height * rect.h)
            let croppedImg = ciImage.cropped(to: newRect)
            transformedImage = croppedImg
        }
            
        return transformedImage
    }

}
