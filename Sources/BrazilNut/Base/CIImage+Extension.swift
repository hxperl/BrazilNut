//
//  CIImage+Extension.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import CoreImage

extension CIImage {
  func transformToOrigin(withSize size: CGSize) -> CIImage {
//    let originX = extent.origin.x
//    let originY = extent.origin.y
    
    let scaleX = size.width / extent.width
    let scaleY = size.height / extent.height
    let scale = max(scaleX, scaleY)
    
//    return transformed(by: CGAffineTransform(translationX: -originX, y: -originY))
//      .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
	return transformed(by: CGAffineTransform(scaleX: scale, y: scale))
  }
}
