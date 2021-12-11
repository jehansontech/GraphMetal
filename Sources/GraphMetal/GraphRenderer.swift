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

//// =======================================================
//// This protocol is TEMPORARY
//// TODO: Delete when RendererSettings refactor is complete
//// =======================================================
//public protocol GraphRendererProperties {
//
//    /// Angular width, in radians, of the POV's field of view
//    var yFOV: Float { get set }
//
//    /// Distance in world coordinates from the plane of the POV to the nearest renderable point
//    var zNear: Float { get set }
//
//    /// Distance in world coordinates from the plane of the POV to the farthest renderable point
//    var zFar: Float { get set }
//
//    /// Distance in world coordinates from from the plane of the POV  to the the point where the figure starts fading out.
//    /// Nodes at distances less than `fadeoutOnset` are opaque.
//    var fadeoutOnset: Float { get set }
//
//    /// Distance in world coordinates over which the figure fades out.
//    /// Nodes at distances greater than`fadeoutOnset + fadeoutDistance` are transparent.
//    var fadeoutDistance: Float { get set }
//
//    var backgroundColor: SIMD4<Double> { get set }
//}


public class GraphRendererSettings: ObservableObject { // }, GraphRendererProperties {

    @Published public private(set) var updateInProgress: Bool

    @Published public var yFOV: Float

    @Published public var zNear: Float

    @Published public var zFar: Float

    @Published public var fadeoutOnset: Float

    @Published public var fadeoutDistance: Float

    @Published public private(set) var backgroundColor: SIMD4<Double>

    private var updateStartedCount: Int = 0

    private var updateCompletedCount: Int = 0

    public init(yFOV: Float = .piOverFour,
                zNear: Float = 0.01,
                zFar: Float = 1000,
                fadeoutOnset: Float = 0,
                fadeoutDistance: Float = 1000,
                backgroundColor: SIMD4<Double> = SIMD4<Double>(0.02, 0.02, 0.02, 1)) {
        self.updateInProgress = false
        self.yFOV = yFOV
        self.zNear = zNear
        self.zFar = zFar
        self.fadeoutOnset = fadeoutOnset
        self.fadeoutDistance = fadeoutDistance
        self.backgroundColor = backgroundColor
    }

    func updateStarted() {
        updateStartedCount += 1
        debug("GraphRendererSettings", "updateStated. new updateStartedCount=\(updateStartedCount), updateCompletedCount=\(updateCompletedCount)")
        self.updateInProgress = (updateStartedCount > updateCompletedCount)
    }

    func updateCompleted() {
        updateCompletedCount += 1
        debug("GraphRendererSettings", "updateCompleted. updateStartedCount=\(updateStartedCount), new updateCompletedCount=\(updateCompletedCount)")
        self.updateInProgress = (updateStartedCount > updateCompletedCount)
    }
}

//public protocol RendererControls: AnyObject { //, POVControllerProperties  {
//
//    // var updateInProgress: Bool { get }
//
//    func requestScreenshot()
//}


///
///
///
public class GraphRendererBase<S: RenderableGraphHolder>: NSObject, MTKViewDelegate { //, RendererControls {

    public typealias NodeValueType = S.GraphType.NodeType.ValueType

    public typealias EdgeValueType = S.GraphType.EdgeType.ValueType

    // NOT USED
    // public var updateInProgress: Bool = false
//
//    public var backgroundColor: SIMD4<Double> = RendererSettings.defaults.backgroundColor
//
//    public var fadeoutOnset: Float = RendererSettings.defaults.fadeoutOnset
//
//    public var fadeoutDistance: Float = RendererSettings.defaults.fadeoutDistance
//
//    public var yFOV: Float = RendererSettings.defaults.yFOV
//
//    public var zNear: Float = RendererSettings.defaults.zNear
//
//    public var zFar: Float = RendererSettings.defaults.zFar

    var viewSize: CGSize

    weak var settings: GraphRendererSettings!

    private var _fallbackSettings: GraphRendererSettings? = nil

//    public var updateInProgress: Bool {
//        return updateStartedCount > updateCompletedCount
//    }
//
//    public var orbitEnabled: Bool = RendererSettings.defaults.orbitEnabled
//    public var orbitSpeed: Float = RendererSettings.defaults.orbitSpeed
//
//    private var updateStartedCount: Int = 0 {
//        didSet {
//            settings.updateInProgress = (updateStartedCount > updateCompletedCount)
//        }
//    }
//
//    private var updateCompletedCount: Int = 0 {
//        didSet {
//            settings.updateInProgress = (updateStartedCount > updateCompletedCount)
//        }
//    }

    private var screenshotRequested: Bool = false

    let parent: GraphView<S>

    var projectionMatrix: float4x4

    var modelViewMatrix: float4x4

    var tapHandler: RendererTapHandler? = nil

    var longPressHandler: RendererLongPressHandler? = nil

    var dragHandler: RendererDragHandler?

    var pinchHandler: RendererPinchHandler?

    var rotationHandler: RendererRotationHandler?

    let device: MTLDevice!

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    let commandQueue: MTLCommandQueue

    var depthState: MTLDepthStencilState

    var wireFrame: GraphWireFrame<NodeValueType, EdgeValueType>
    
    // private var _drawCount: Int = 0

    public init(_ parent: GraphView<S>,
                _ rendererSettings: GraphRendererSettings? = nil,
                _ wireframeSettings: GraphWireFrameSettings? = nil) throws {

        debug("GraphRenderer", "init")
        
        self.parent = parent

        self.viewSize = CGSize(width: 100, height: 100) // dummy nonzero values

        if let settings = rendererSettings {
            self.settings = settings
        }
        else {
            let settings = GraphRendererSettings()
            self._fallbackSettings = settings
            self.settings = settings
        }

        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        else {
            throw RendererError.noDevice
        }

        // Dummy values
        self.projectionMatrix = Self.makeProjectionMatrix(viewSize, settings)
        self.modelViewMatrix = Self.makeModelViewMatrix(POV())

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

        wireFrame = try GraphWireFrame(device, wireframeSettings)
        
        super.init()

        // self.applySettings(parent.rendererSettings)
        self.graphHasChanged(RenderableGraphChange.ALL)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyGraphHasChanged), name: .graphHasChanged, object: nil)
    }

    deinit {
        debug("GraphRenderer", "deinit")
        // TODO remove observer at some point -- but doesn't it need to be BEFORE deinitialization?
    }

    static func makeProjectionMatrix(_ viewSize: CGSize, _ settings: GraphRendererSettings) -> float4x4 {
        let aspectRatio = (viewSize.height > 0) ? Float(viewSize.width) / Float(viewSize.height) : 1
        return float4x4(perspectiveProjectionRHFovY: settings.yFOV,
                        aspectRatio: aspectRatio,
                        nearZ: settings.zNear,
                        farZ: settings.zFar)
    }

    static func makeModelViewMatrix(_ pov: POV) -> float4x4 {
        return float4x4(lookAt: pov.center, eye: pov.location, up: pov.up)
    }

    public func requestScreenshot() {
        self.screenshotRequested = true
    }
    
//    func applySettings(_ settings: RendererSettings) {
//        debug("Renderer", "applySettings")
//
//        // FIXME: this method's existence is proof of bad design
//
//        // self.orbitEnabled = settings.orbitEnabled
//        // self.orbitSpeed = settings.orbitSpeed
//        // parent.povController.settings.copyFrom(settings)
//
//        self.yFOV = settings.yFOV
//        self.zNear = settings.zNear
//        self.zFar = settings.zFar
//        self.fadeoutOnset = settings.fadeoutOnset
//        self.fadeoutDistance = settings.fadeoutDistance
//        self.backgroundColor = settings.backgroundColor
//    }

    @objc public func notifyGraphHasChanged(_ notification: Notification) {
        if let graphChange = notification.object as? RenderableGraphChange {
            graphHasChanged(graphChange)
        }
    }

    public func graphHasChanged(_ graphChange: RenderableGraphChange) {
        let t0 = Date()
        debug("GraphRenderer.graphHasChanged", "starting.")
        settings.updateStarted()
        wireFrame.graphHasChanged(parent.graphHolder.graph, graphChange)
        let dt = Date().timeIntervalSince(t0)
        debug("GraphRenderer.graphHasChanged", "done. dt=\(dt)")
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        debug("GraphRenderer.mtkView(size)", "started. size=\(size)")

        self.viewSize = size
        // let projectionMatrix = Self.makeProjectionMatrix(viewSize, settings)

        do {
            try wireFrame.setup(view)
        }
        catch {
            // TODO log it
            print("Problem initializing graph rendering pipelines: \(error)")
        }
    }

    public func draw(in view: MTKView) {
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // _drawCount += 1
        let t0 = Date()

        // FIXME: what's this doing here?
        if settings.updateInProgress {
            debug("GraphRenderer.draw", "starting. update is currently in progress.")
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

                wireFrame.encodeCommands(renderEncoder) //,
                                    // dynamicUniformBuffer,
                                    // uniformBufferOffset)

                renderEncoder.endEncoding()
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }

        // FIXME: why the if statement?
        if settings.updateInProgress {
            settings.updateCompleted()
        }

        let dt = Date().timeIntervalSince(t0)
        debug("GraphRenderer.draw", "done. dt=\(dt)")
    }
    
    
    private func preDraw(_ view: MTKView) {

        self.projectionMatrix = Self.makeProjectionMatrix(viewSize, settings)

        // Update POV, in case it's moving on its own
        self.modelViewMatrix = Self.makeModelViewMatrix(parent.povController.updatePOV(Date()))

        wireFrame.preDraw(projectionMatrix: projectionMatrix,
                               modelViewMatrix: modelViewMatrix,
                               pov: parent.povController.pov,
                               fadeoutOnset: settings.fadeoutOnset,
                               fadeoutDistance: settings.fadeoutDistance)


//        let dt = Date().timeIntervalSince(t0)
//        if (dt > 1/30) {
//            debug("Renderer", "predraw: elapsed time \(dt)")
//        }

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

#if os(iOS)
            let uiImage = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
#elseif os(macOS)
            // TODO
#endif
        }
    }

}

#if os(iOS)
public class GraphRenderer<S: RenderableGraphHolder>: GraphRendererBase<S>, UIGestureRecognizerDelegate {

    @objc func tap(_ gesture: UITapGestureRecognizer) {
        // print("Renderer.tap")
        if var tapHandler = self.tapHandler,
           let view = gesture.view,
           gesture.numberOfTouches > 0 {

            debug("GraphRenderer(iOS)", "tap at \(gesture.location(ofTouch: 0, in: view)) -> \(clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))")


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
                // STET: scroll is multiplied by -1
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
}
#elseif os(macOS)
public class GraphRenderer<S: RenderableGraphHolder>: GraphRendererBase<S>, NSGestureRecognizerDelegate {

    @objc func tap(_ gesture: NSClickGestureRecognizer) {
        // print("GraphRenderer(macOS) tap")

        if var tapHandler = self.tapHandler,
           let view = gesture.view {
            switch gesture.state {
            case .possible:
                break
            case .began:
                break
            case .changed:
                break
            case .ended:
                tapHandler.tap(at: clipPoint(gesture.location(in: view), view.bounds))
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func longPress(_ gesture: NSPressGestureRecognizer) {
        // print("GraphRenderer(macOS) longPress")

        if var longPressHandler = longPressHandler,
           let view = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                longPressHandler.longPressBegan(at: clipPoint(gesture.location(in: view), view.bounds))
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

    @objc func pan(_ gesture: NSPanGestureRecognizer) {
        // print("GraphRenderer(macOS) pan")

        if var dragHandler = self.dragHandler,
           let view  = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                dragHandler.dragBegan(at: clipPoint(gesture.location(in: view), view.bounds))
            case .changed:
                let translation = gesture.translation(in: view)
                // macOS uses upside-down clip coords, so the scroll value is the opposite of that on iOS
                dragHandler.dragChanged(pan: Float(translation.x / view.bounds.width),
                                        scroll: Float(translation.y / view.bounds.height))
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

    @objc func pinch(_ gesture: NSMagnificationGestureRecognizer) {

        if var pinchHandler = pinchHandler,
           let view  = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                pinchHandler.pinchBegan(at: clipPoint(gesture.location(in: view),
                                                      view.bounds))
            case .changed:
                // macOS gesture's magnification=0 corresponds to iOS gesture's scale=1
                pinchHandler.pinchChanged(by: Float(1 + gesture.magnification))
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

    @objc func rotate(_ gesture: NSRotationGestureRecognizer) {
        // print("Renderer(macOS) rotate")

        if var rotationHandler = rotationHandler,
           let view  = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                rotationHandler.rotationBegan(at: clipPoint(gesture.location(in: view),
                                                            view.bounds))
            case .changed:
                // multiply by -1 because macOS gestures use upside-down clip space
                rotationHandler.rotationChanged(by: Float(-gesture.rotation))
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
    public func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith: NSGestureRecognizer) -> Bool {
        // print("simultaneous gestures: \(describeGR(gestureRecognizer)) + \(describeGR(shouldRecognizeSimultaneouslyWith))")
        if gestureRecognizer is NSPanGestureRecognizer || shouldRecognizeSimultaneouslyWith is NSPanGestureRecognizer {
            return false
        }

        return true
    }

}
#endif

// ======================================================================
// MARK:- conversion to clip space
// ======================================================================

fileprivate func clipX(_ viewX: CGFloat, _ viewWidth: CGFloat) -> Float {
    return Float(2 * viewX / viewWidth - 1)
}

#if os(iOS)
fileprivate func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
    // In iOS, viewY increases toward the TOP of the screen
    return Float(1 - 2 * viewY / viewHeight)
}
#elseif os(macOS)
fileprivate func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
    // In macOS, viewY increaases toward the BOTTOM of the screen
    return Float(2 * viewY / viewHeight - 1)
}
#endif

fileprivate func clipPoint(_ viewPt: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
    return SIMD2<Float>(clipX(viewPt.x, viewSize.width), clipY(viewPt.y, viewSize.height))
}

fileprivate func clipPoint(_ viewPt0: CGPoint, _ viewPt1: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
    return SIMD2<Float>(clipX((viewPt0.x + viewPt1.x)/2, viewSize.width),
                        clipY((viewPt0.y + viewPt1.y)/2, viewSize.height))
}

#if os(iOS)
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
#endif
