//
//  DissolveTransition.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2020/02/07.
//  Copyright © 2020 Geonseok Lee. All rights reserved.
//

import CoreImage

public class DissolveTransition: TransitionOperator {

	public init() {
		let filter = CIFilter(name: "CIDissolveTransition")
		filter?.setDefaults()
		super.init(filter: filter)
	}
}
