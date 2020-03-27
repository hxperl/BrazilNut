//
//  BarSwipeTranstion.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/05.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//
import CoreImage

public class BarSwipeTransition: TransitionOperator {

	public init() {
		let filter = CIFilter(name: "CIBarsSwipeTransition")
		filter?.setValue(60, forKey: kCIInputWidthKey)
		filter?.setValue(3, forKey: kCIInputAngleKey)
		super.init(filter: filter)
	}
}
