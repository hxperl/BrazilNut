//
//  SwipeTransition.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage

public class SwipeTransition: TransitionOperator {

	public init() {
		let filter = CIFilter(name: "CISwipeTransition")
		filter?.setDefaults()
		filter?.setValue(CIColor.init(red: 1, green: 1, blue: 1), forKey: kCIInputColorKey)
		super.init(filter: filter)
	}
}
