//
//  RenderView.swift
//  BrazilNut
//
//  Created by Geonseok Lee on 2019/11/13.
//  Copyright © 2019 Geonseok Lee. All rights reserved.
//
import MetalKit
import CoreImage

public class RenderView: MTKView, ImageConsumer {
	public func add(source: ImageSource) {
		//
	}
	
	public func remove(source: ImageSource) {
		//
	}
	
    
    private var lock: DispatchSemaphore!
    
    fileprivate var ciimage: CIImage?
    
    /// Render only video frame type image
    ///
    /// - Parameter image: image object
	public func newImageAvailable(_ image: BNImage, from source: ImageSource) {
        // Render if image type is video frame
        guard case .videoFrame = image.type else { return }
        self.ciimage = image.image
    }
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        commonInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
        
    }
    
    private func commonInit() {
        framebufferOnly = false
        autoResizeDrawable = true
        self.device = MetalDevice.shared.device
        self.lock = DispatchSemaphore(value: 1)
    }
    
    private lazy var ciContext: CIContext = { [unowned self] in
        return CIContext(mtlDevice: self.device!)
    }()
    
    public override func draw(_ rect: CGRect) {
        _ = lock.wait(wallTimeout: .distantFuture)
        guard let currentDrawable = self.currentDrawable,
            let image = self.ciimage else {
                lock.signal()
                return }
		let resized = image.transformToOrigin(withSize: drawableSize)
        let commandBuffer = MetalDevice.shared.commandQueue.makeCommandBuffer()
		let destination = CIRenderDestination(width: Int(drawableSize.width), height: Int(drawableSize.height), pixelFormat: colorPixelFormat, commandBuffer: commandBuffer, mtlTextureProvider: {
			() -> MTLTexture in
			currentDrawable.texture
		})
		do {
			try ciContext.startTask(toRender: resized, to: destination)
		} catch {
			print(error)
		}
        commandBuffer?.present(currentDrawable)
        commandBuffer?.commit()
        lock.signal()
    }
}
