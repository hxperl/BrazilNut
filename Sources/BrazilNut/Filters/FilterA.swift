//
//  Filter1.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/01/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage

public class FilterA: ImageRelay {
	override public func newImageAvailable(_ bnImage: BNImage, from source: ImageSource) {
		let inputImage = bnImage.image
		let inputType = bnImage.type

		let toneCurve = CIFilter(name: "CIToneCurve")
        toneCurve?.setValue(inputImage, forKey: kCIInputImageKey)
        toneCurve?.setValue(CIVector(x: 0.0395753, y: 0.124758), forKey: "inputPoint0")
        toneCurve?.setValue(CIVector(x: 0.17471, y: 0.205996), forKey: "inputPoint1")
        toneCurve?.setValue(CIVector(x: 0.340734, y: 0.443907), forKey: "inputPoint2")
        toneCurve?.setValue(CIVector(x: 0.593629, y: 0.75), forKey: "inputPoint3")
        toneCurve?.setValue(CIVector(x: 0.90444, y: 0.913926), forKey: "inputPoint4")
        
        let colorClamp = CIFilter(name: "CIColorControls")
        colorClamp?.setValue(toneCurve?.outputImage, forKey: kCIInputImageKey)
        colorClamp?.setValue(CGFloat(0.9937402009963989), forKey: "inputSaturation")
        colorClamp?.setValue(CGFloat(0.03755868598818779), forKey: "inputBrightness")
        colorClamp?.setValue(CGFloat(1.098004579544067), forKey: "inputContrast")

        let colorPolynomial = CIFilter(name: "CIColorPolynomial")
        colorPolynomial?.setValue(colorClamp?.outputImage, forKey: kCIInputImageKey)
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.727488, z: 0.25, w: 0.158768), forKey: "inputRedCoefficients")
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.722749, z: 0.116667, w: 0.154028), forKey: "inputGreenCoefficients")
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.874408, z: 0.435714, w: 0), forKey: "inputBlueCoefficients")
        colorPolynomial?.setValue(CIVector(x: 0, y: 0.912322, z: 0.0357141, w: 0), forKey: "inputAlphaCoefficients")

        let highlightShadowAdjust = CIFilter(name: "CIHighlightShadowAdjust")
        highlightShadowAdjust?.setValue(colorPolynomial?.outputImage, forKey: kCIInputImageKey)
        highlightShadowAdjust?.setValue(CGFloat(0.2723004817962646), forKey: "inputShadowAmount")
        highlightShadowAdjust?.setValue(CGFloat(0.8302034139633179), forKey: "inputHighlightAmount")
        highlightShadowAdjust?.setValue(CGFloat(0.5868544578552246), forKey: "inputRadius")

        let temperatureAndTint = CIFilter(name: "CITemperatureAndTint")
        temperatureAndTint?.setValue(highlightShadowAdjust?.outputImage, forKey: kCIInputImageKey)
        temperatureAndTint?.setValue(CIVector(x: 4652.18, y: 8.99814), forKey: "inputTargetNeutral")
        temperatureAndTint?.setValue(CIVector(x: 5775.57, y: 0), forKey: "inputNeutral")

		if let outputImage = temperatureAndTint?.outputImage {
			let newImage = BNImage(image: outputImage, type: inputType)
			for consumer in consumers {
				consumer.newImageAvailable(newImage, from: self)
			}
		}
	}
}
