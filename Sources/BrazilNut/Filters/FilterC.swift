//
//  FilterC.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/01/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage

public class FilterC: ImageRelay {
	
	override public func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
		let inputImage = bnImage.image
		let inputType = bnImage.type
		
		let vibrance = CIFilter(name: "CIVibrance")
        vibrance?.setValue(inputImage, forKey: kCIInputImageKey)
        vibrance?.setDefaults()
        
        let hueAdjust = CIFilter(name: "CIHueAdjust")
        hueAdjust?.setValue(vibrance?.outputImage, forKey: kCIInputImageKey)
        hueAdjust?.setValue(CGFloat(0.1619718372821808), forKey: "inputAngle")
        
        let toneCurve = CIFilter(name: "CIToneCurve")
        toneCurve?.setValue(hueAdjust?.outputImage, forKey: kCIInputImageKey)
        toneCurve?.setValue(CIVector(x: 0.0241312, y: 0.124758), forKey: "inputPoint0")
        toneCurve?.setValue(CIVector(x: 0.190154, y: 0.205996), forKey: "inputPoint1")
        toneCurve?.setValue(CIVector(x: 0.427606, y: 0.383946), forKey: "inputPoint2")
        toneCurve?.setValue(CIVector(x: 0.686293, y: 0.75), forKey: "inputPoint3")
        toneCurve?.setValue(CIVector(x: 0.90444, y: 0.913926), forKey: "inputPoint4")
        
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(toneCurve?.outputImage, forKey: kCIInputImageKey)
        colorControls?.setValue(CGFloat(0.7026603817939758), forKey: "inputSaturation")
        colorControls?.setValue(CGFloat(1.080398917198181), forKey: "inputContrast")
        colorControls?.setValue(CGFloat(0.04381836950778961), forKey: "inputBrightness")
        
        let colorPolynomial = CIFilter(name: "CIColorPolynomial")
        colorPolynomial?.setValue(colorControls?.outputImage, forKey: kCIInputImageKey)
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.864929, z: 0.240476, w: 0.0592416), forKey: "inputAlphaCoefficients")
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.471564, z: 0.0547619, w: 0), forKey: "inputGreenCoefficients")
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.419431, z: 0.164286, w: 0), forKey: "inputRedCoefficients")
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.447867, z: 0.321428, w: 0), forKey: "inputBlueCoefficients")
		
		if let outputImage = colorPolynomial?.outputImage {
			let newImage = BNImage(image: outputImage, type: inputType)
			for consumer in consumers {
				consumer.newImageAvailable(newImage, from: self)
			}
		}
	}
}
