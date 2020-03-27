//
//  AccordingFoldTransition.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage

public class AccordingFoldTransition: TransitionOperator {

	public init() {
		let filter = CIFilter(name: "CIAccordionFoldTransition")
		filter?.setDefaults()
		super.init(filter: filter)
	}
}
