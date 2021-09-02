//
//  GraphRenderer.swift
//  GraphMetal
//

import Metal
import MetalKit
import simd
import GenericGraph
import Shaders
import Wacoma

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
struct RendererConstants {

    // EMPIRICAL
    static let nodeSizeScaleFactor: Double = 800
}


///
///
///
public protocol RendererControls: RendererProperties, AnyObject {

    var updateInProgress: Bool { get }

    /// has no effect if nodeSizeAutomatic is false
    func adjustNodeSize(povDistance: Double)

    func requestScreenshot()
}


///
///
///
public class GraphRenderer<S: RenderableGraphHolder>: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate, RendererControls {

    typealias NodeValueType = S.GraphType.NodeType.ValueType
    typealias EdgeValueType = S.GraphType.EdgeType.ValueType

    public var backgroundColor: SIMD4<Double> = RendererSettings.defaults.backgroundColor

    public var nodeSizeAutomatic: Bool = RendererSettings.defaults.nodeSizeAutomatic

    public var nodeSize = RendererSettings.defaults.nodeSize

    public var nodeSizeMinimum: Double = RendererSettings.defaults.nodeSizeMinimum

    public var nodeSizeMaximum: Double = RendererSettings.defaults.nodeSizeMaximum

    public var edgeColorDefault = RendererSettings.defaults.edgeColorDefault

    public var nodeColorDefault: SIMD4<Double> {
        get {
            return graphWireFrame.nodeColorDefault
        }

        set(newValue) {
            graphWireFrame.nodeColorDefault = newValue
        }
    }

    public var updateInProgress: Bool {
        return updateStartedCount > updateCompletedCount
    }

    var updateStartedCount: Int = 0

    var updateCompletedCount: Int = 0

    var screenshotRequested: Bool = false

    let parent: GraphView<S>

    var tapHandler: RendererTapHandler? = nil

    var longPressHandler: RendererLongPressHandler? = nil

    var dragHandler: RendererDragHandler?

    var pinchHandler: RendererPinchHandler?

    var rotationHandler: RendererRotationHandler?

    let device: MTLDevice!

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    let commandQueue: MTLCommandQueue

    var depthState: MTLDepthStencilState

    var graphWireFrame: GraphWireFrame<NodeValueType, EdgeValueType>
    
    /// This is a hardware factor that affects the visibie size of point primitives, independent of the
    /// screen bounds.
    /// * Retina displays have value 2
    /// * Older displays have value 1
    var screenScaleFactor: Double = 1

    // private var _drawCount: Int = 0

    public init(_ parent: GraphView<S>) throws {

        debug("GraphRenderer", "init")
        
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

        graphWireFrame = try GraphWireFrame(device, self.screenScaleFactor)
        
        super.init()

        self.applySettings(parent.rendererSettings)
        self.graphHasChanged(RenderableGraphChange.ALL)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyGraphHasChanged), name: .graphHasChanged, object: nil)
    }

    deinit {
        debug("Renderer", "deinit")
        // TODO remove observer at some point -- but doesn't it need to be BEFORE deinitialization?
    }

    public func adjustNodeSize(povDistance: Double) {
        if nodeSizeAutomatic {
            let newSize = RendererConstants.nodeSizeScaleFactor / povDistance
            self.nodeSize = newSize.clamp(nodeSizeMinimum, nodeSizeMaximum)
            debug("Renderer", "adjustNodeSize: newSize = \(nodeSize)")
        }
        else {
            debug("Renderer", "adjustNodeSize: doing nothing because nodeSizeAutomatic = \(nodeSizeAutomatic)")
        }
    }
    
    public func requestScreenshot() {
        self.screenshotRequested = true
    }
    
    func applySettings(_ settings: RendererSettings) {
        self.backgroundColor = settings.backgroundColor
        self.nodeSizeAutomatic = settings.nodeSizeAutomatic

        if !nodeSizeAutomatic {
            self.nodeSize = settings.nodeSize
        }
        
        self.nodeSizeMaximum = settings.nodeSizeMaximum
        self.nodeColorDefault = settings.nodeColorDefault
        self.edgeColorDefault = settings.edgeColorDefault
    }

    @objc public func notifyGraphHasChanged(_ notification: Notification) {
        if let graphChange = notification.object as? RenderableGraphChange {
            graphHasChanged(graphChange)
        }
    }

    public func graphHasChanged(_ graphChange: RenderableGraphChange) {
        let t0 = Date()
        debug("GraphRenderer", "graphHasChanged: starting. updateStartedCount=\(updateStartedCount) updateCompletedCount=\(updateCompletedCount)")
        self.updateStartedCount += 1
        graphWireFrame.graphHasChanged(parent.graphHolder.graph, graphChange)
        let dt = Date().timeIntervalSince(t0)
        debug("GraphRenderer", "graphHasChanged: done. dt=\(dt) updateStartedCount=\(updateStartedCount) updateCompletedCount=\(updateCompletedCount)")
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

        // _drawCount += 1
        // FIXME
        let t0 = Date()
        if updateInProgress {
            debug("GraphRenderer", "draw: starting. update in progress. updateStartedCount=\(updateStartedCount) updateCompletedCount=\(updateCompletedCount)")
        }

        if screenshotRequested {
            takeScreenshot(view)
            screenshotRequested = false
        }


        self.preDraw(view)

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in
                semaphore.signal()
            }

            // Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            //   holding onto the drawable and blocking the display pipeline any longer than necessary
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
               let drawable = view.currentDrawable {

                renderEncoder.setDepthStencilState(depthState)

                graphWireFrame.encodeCommands(renderEncoder) //,
                                    // dynamicUniformBuffer,
                                    // uniformBufferOffset)

                renderEncoder.endEncoding()
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }

        // FIXME
        let dt = Date().timeIntervalSince(t0)
        if updateInProgress {
            updateCompletedCount += 1
            debug("GraphRenderer", "draw: done. update completed. dt=\(dt) updateStartedCount=\(updateStartedCount) updateCompletedCount=\(updateCompletedCount)")
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

    private func preDraw(_ view: MTKView) {

        let t0 = Date()


        // Update POV based on current time, in case it's moving on its own
        parent.povController.updateModelView(t0)

        graphWireFrame.preDraw(parent.povController.projectionMatrix, parent.povController.modelViewMatrix, screenScaleFactor, nodeSize, edgeColorDefault)

        let dt = Date().timeIntervalSince(t0)
        if (dt > 1/30) {
            debug("Renderer", "predraw: elapsed time \(dt)")
        }

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
