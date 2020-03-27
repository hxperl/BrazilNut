//
//  MetalDevice.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//

import Metal
import CoreGraphics

public class MetalDevice {
    
    public static var shared = MetalDevice()
    
    public var device: MTLDevice!
    var library: MTLLibrary!
    public var colorSpace: CGColorSpace!
    
    var commandQueue: MTLCommandQueue!
    
    private var renderPipelineState: MTLRenderPipelineState?
    
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            return
        }
        self.device = device
        self.library = device.makeDefaultLibrary()
        self.commandQueue = commandQueue
        self.colorSpace = CGColorSpaceCreateDeviceRGB()
    }
    
}
