//
//  CopyMachineTransition.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage

public class CopyMachineTransition: TransitionOperator {

	public init() {
		let filter = CIFilter(name: "CICopyMachineTransition")
		filter?.setDefaults()
		filter?.setValue(CIColor.init(red: 0, green: 0, blue: 1), forKey: kCIInputColorKey)
		super.init(filter: filter)
	}
}
