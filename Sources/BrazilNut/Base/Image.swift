//
//  Image.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import CoreImage
import AVFoundation

public enum BNImageType {
    case photo
	case videoFrame(timestamp: CMTime)
    
    var timestamp: CMTime? {
        get {
            switch self {
            case .photo: return nil
            case let .videoFrame(timestamp): return timestamp
            }
        }
    }
}

public struct BNImage {
    public let image: CIImage
    public let type: BNImageType
    public init(image: CIImage, type: BNImageType) {
        self.image = image
        self.type = type
    }
}

