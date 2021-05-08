//
//  Renderer.swift
//  ArcWorld
//
//  Created by James Hanson on 8/14/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd
import GenericGraph
import Shaders
import Taconic

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case noDevice
    case noDefaultLibrary
    case noDepthStencilState
    case badVertexDescriptor
    case bufferCreationFailed
}

///
///
///
public class Renderer<C: RenderableGraphController>: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate, RenderControls {

    public var backgroundColor: SIMD4<Double> = RenderSettings.defaults.backgroundColor

    public var nodeSizeAutomatic: Bool = RenderSettings.defaults.nodeSizeAutomatic

    public var nodeSize = RenderSettings.defaults.nodeSize

    public var nodeSizeMaximum: Double = RenderSettings.defaults.nodeSizeMaximum

    public var edgeColor = RenderSettings.defaults.edgeColor

    public var nodeColorDefault: SIMD4<Double> {
        get {
            return graphWireFrame.nodeColorDefault
        }

        set(newValue) {
            graphWireFrame.nodeColorDefault = newValue
        }
    }

    var screenshotRequested: Bool = false

    let parent: RendererView<C>

    var tapHandler: RendererTapHandler? = nil

    var longPressHandler: RendererLongPressHandler? = nil

    var dragHandler: RendererDragHandler?

    var pinchHandler: RendererPinchHandler?

    var rotationHandler: RendererRotationHandler?

    let device: MTLDevice!

    let commandQueue: MTLCommandQueue
    
    var dynamicUniformBuffer: MTLBuffer
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var depthState: MTLDepthStencilState

    var graphWireFrame: GraphWireFrame<C.HolderType.GraphType.NodeType.ValueType, C.HolderType.GraphType.EdgeType.ValueType>
    
    /// This is a hardware factor that affects the visibie size of point primitives, independent of the
    /// screen bounds.
    /// * Retina displays have value 2
    /// * Older displays have value 1
    var screenScaleFactor: Double = 1

    public init(_ parent: RendererView<C>) throws {

        debug("Renderer", "init")
        
        self.parent = parent

        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        else {
            throw RendererError.noDevice
        }

        self.commandQueue = device.makeCommandQueue()!
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.lessEqual
        depthStateDesciptor.isDepthWriteEnabled = true

        if let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) {
            depthState = state
        }
        else {
            throw RendererError.noDepthStencilState
        }


        //        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        //        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        //
        //        let viewBounds = SIMD3<Float>(Float(metalKitView.drawableSize.width),
        //                                      Float(metalKitView.drawableSize.height),
        //                                      frustumDepth)
        //        AppModel.instance.povController.updateProjection(viewBounds: viewBounds)
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        if let buffer = self.device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
            self.dynamicUniformBuffer = buffer
        }
        else {
            throw RendererError.bufferCreationFailed
        }

        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        graphWireFrame = GraphWireFrame(self.device)

        super.init()
        self.applySettings(parent.rendererSettings)
    }

    deinit {
        debug("Renderer", "deinit")
    }

    public func adjustNodeSize(povDistance: Double) {
        let newSize = RenderingConstants.nodeSizeScaleFactor / povDistance
        nodeSize = newSize.clamp(1, nodeSizeMaximum)
    }
    
    public func requestScreenshot() {
        self.screenshotRequested = true
    }
    
    func applySettings(_ settings: RenderSettings) {
        self.backgroundColor = settings.backgroundColor
        self.nodeSizeAutomatic = settings.nodeSizeAutomatic
        self.nodeSize = settings.nodeSize
        self.nodeSizeMaximum = settings.nodeSizeMaximum
        self.nodeColorDefault = settings.nodeColorDefault
        self.edgeColor = settings.edgeColor
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        debug("Renderer", "mtkView size=\(size)")
        parent.updateProjection(viewSize: size)

        do {
            try graphWireFrame.setup(view)
        }
        catch {
            // TODO log it
            print("Problem initializing graph rendering pipelines: \(error)")
        }
    }

    public func draw(in view: MTKView) {
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        if screenshotRequested {
            takeScreenshot(view)
            screenshotRequested = false
        }

        // was getting segv's because of bad node count when beginDraw was here

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }

            // put beginDraw inside here to see if it will help with segv's
            self.beginDraw(view)

            // Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            //   holding onto the drawable and blocking the display pipeline any longer than necessary
            
            // OLD:
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                // NEW . . . and broken
                // if  let drawable = view.currentDrawable {
                //
                //    let renderPassDescriptor = MTLRenderPassDescriptor()
                //
                //    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
                //    renderPassDescriptor.colorAttachments[0].loadAction = .clear
                //    renderPassDescriptor.colorAttachments[0].clearColor = AppDefaults.backgroundColor
                //    renderPassDescriptor.colorAttachments[0].storeAction = .store
                //
                //    let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                //         descriptor: renderPassDescriptor)!
                
                renderEncoder.setDepthStencilState(depthState)


                graphWireFrame.draw(renderEncoder,
                                    dynamicUniformBuffer,
                                    uniformBufferOffset)

                renderEncoder.endEncoding()
                
                // OLD, WORKING
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
                
                // NEW, BROKEN
                // commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }
    }
    
    
    @objc func tap(_ gesture: UITapGestureRecognizer) {
        // print("Renderer.tap")
        if var tapHandler = self.tapHandler,
           let view = gesture.view,
           gesture.numberOfTouches > 0 {

            switch gesture.state {
            case .possible:
                break
            case .began:
                break
            case .changed:
                break
            case .ended:
                tapHandler.tap(at: clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func longPress(_ gesture: UILongPressGestureRecognizer) {
        // print("Renderer.longPress")
        if var longPressHandler = longPressHandler,
           let view = gesture.view,
           gesture.numberOfTouches > 0  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                longPressHandler.longPressBegan(at: clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))
            case .changed:
                longPressHandler.longPressEnded()
                break
            case .ended:
                longPressHandler.longPressEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func pan(_ gesture: UIPanGestureRecognizer) {
        // print("Renderer.pan")
        if var dragHandler = self.dragHandler,
           let view  = gesture.view,
           gesture.numberOfTouches > 0  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                dragHandler.dragBegan(at: clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))
            case .changed:
                let translation = gesture.translation(in: view)
                dragHandler.dragChanged(pan: Float(translation.x / view.bounds.width),
                                        scroll: Float(-translation.y / view.bounds.height))
            case .ended:
                dragHandler.dragEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        // print("Renderer.pinch")
        if var pinchHandler = pinchHandler,
           let view  = gesture.view,
           gesture.numberOfTouches > 1  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                pinchHandler.pinchBegan(at: clipPoint(gesture.location(ofTouch: 0, in: view),
                                                      gesture.location(ofTouch: 1, in: view),
                                                      view.bounds))
            case .changed:
                pinchHandler.pinchChanged(by: Float(gesture.scale))
            case .ended:
                pinchHandler.pinchEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func rotate(_ gesture: UIRotationGestureRecognizer) {
        // print("Renderer.rotate")
        if var rotationHandler = rotationHandler,
           let view  = gesture.view,
           gesture.numberOfTouches > 1  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                rotationHandler.rotationBegan(at: clipPoint(gesture.location(ofTouch: 0, in: view),
                                                            gesture.location(ofTouch: 1, in: view),
                                                            view.bounds))
            case .changed:
                rotationHandler.rotationChanged(by: Float(gesture.rotation))
            case .ended:
                rotationHandler.rotationEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    /// needed in order to do simultaneous gestures
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith: UIGestureRecognizer) -> Bool {
        // print("simultaneous gestures: \(describeGR(gestureRecognizer)) + \(describeGR(shouldRecognizeSimultaneouslyWith))")
        if gestureRecognizer is UIPanGestureRecognizer || shouldRecognizeSimultaneouslyWith is UIPanGestureRecognizer {
            return false
        }

        return true
    }

    private func beginDraw(_ view: MTKView) {

        // ======================================
        // 1. Rotate the uniforms buffers.

        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight

        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        // ======================================
        // 2. Have RendererView update POV and the wireframe

        parent.updatePOV()
        parent.updateWidget(graphWireFrame)

        // =====================================
        // 3. Update content of current uniforms buffer

        uniforms[0].projectionMatrix = parent.projectionMatrix
        uniforms[0].modelViewMatrix = parent.modelViewMatrix
        uniforms[0].pointSize = Float(screenScaleFactor * nodeSize)
        uniforms[0].edgeColor = SIMD4<Float>(Float(edgeColor.x),
                                             Float(edgeColor.y),
                                             Float(edgeColor.z),
                                             Float(edgeColor.w))
    }

    private func takeScreenshot(_ view: MTKView) {

        // Adapted from
        // https://stackoverflow.com/questions/33844130/take-a-snapshot-of-current-screen-with-metal-in-swift
        // [accessed 04/2021]

        guard
            let texture = view.currentDrawable?.texture
        else {
            return
        }

        let width = texture.width
        let height   = texture.height
        let rowBytes = texture.width * 4
        let p = malloc(width * height * 4)
        texture.getBytes(p!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        let pColorSpace = CGColorSpaceCreateDeviceRGB()

        let rawBitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: rawBitmapInfo)

        let selftureSize = texture.width * texture.height * 4
        let releaseMaskImagePixelData: CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
            return
        }
        let provider = CGDataProvider(dataInfo: nil, data: p!, size: selftureSize, releaseData: releaseMaskImagePixelData)
        let cgImage = CGImage(width: texture.width,
                              height: texture.height,
                              bitsPerComponent: 8,
                              bitsPerPixel: 32,
                              bytesPerRow: rowBytes,
                              space: pColorSpace,
                              bitmapInfo: bitmapInfo,
                              provider: provider!,
                              decode: nil,
                              shouldInterpolate: true,
                              intent: CGColorRenderingIntent.defaultIntent)

        if let cgImage = cgImage {
            let uiImage = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        }
    }

}


fileprivate func clipX(_ viewX: CGFloat, _ viewWidth: CGFloat) -> Float {
    //            let clipX: Float = Float(2 * loc.x / view.bounds.width - 1)
    return Float(2 * viewX / viewWidth - 1)
}

fileprivate func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
    //            let clipY: Float = Float(1 - (2 * loc.y) / view.bounds.height)
    return Float(1 - (2 * viewY) / viewHeight)
}

fileprivate func clipPoint(_ viewPt: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
    return SIMD2<Float>(clipX(viewPt.x, viewSize.width), clipY(viewPt.y, viewSize.height))
}

fileprivate func clipPoint(_ viewPt0: CGPoint, _ viewPt1: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
    return SIMD2<Float>(clipX((viewPt0.x + viewPt1.x)/2, viewSize.width),
                        clipY((viewPt0.y + viewPt1.y)/2, viewSize.height))
}

fileprivate func describeGR(_ gr: UIGestureRecognizer) -> String {

    let grName: String
    if gr is UILongPressGestureRecognizer {
        grName = "longPress"
    }
    else if gr is UIPanGestureRecognizer {
        grName = "pan"
    }
    else if gr is UIPinchGestureRecognizer {
        grName = "pinch"
    }
    else if gr is UIRotationGestureRecognizer {
        grName = "rotation"
    }
    else if (gr is UITapGestureRecognizer) {
        grName = "tap"
    }
    else {
        grName = "\(gr)"
    }

    let stateString: String
    switch (gr.state) {
    case .began:
        stateString = "began"
    case .cancelled:
        stateString = "cancelled"
    case .changed:
        stateString = "changed"
    case .ended:
        stateString = "ended"
    case .failed:
        stateString = "failed"
    case .possible:
        stateString = "possible"
    @unknown default:
        stateString = "(unknown)"
    }

    return "\(grName) \(stateString)"
}



