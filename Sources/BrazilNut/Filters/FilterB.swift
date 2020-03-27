//
//  FilterB.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/01/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//
import CoreImage

public class FilterB: ImageRelay {
	
	override public func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
		let inputImage = bnImage.image
		let inputType = bnImage.type

		let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(inputImage, forKey: kCIInputImageKey)
        colorControls?.setDefaults()
        
        let vibrance = CIFilter(name: "CIVibrance")
        vibrance?.setValue(colorControls?.outputImage, forKey: kCIInputImageKey)
        vibrance?.setDefaults()
        
        let hueAdjust = CIFilter(name: "CIHueAdjust")
        hueAdjust?.setValue(vibrance?.outputImage, forKey: kCIInputImageKey)
        hueAdjust?.setValue(CGFloat(0.1619718372821808), forKey: "inputAngle")
		
		if let outputImage = hueAdjust?.outputImage {
			let newImage = BNImage(image: outputImage, type: inputType)
			for consumer in consumers {
				consumer.newImageAvailable(newImage, from: self)
			}
		}
	}
}
