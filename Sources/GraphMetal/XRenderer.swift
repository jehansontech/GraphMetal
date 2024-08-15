//
//  Renderer.swift
//
//
//  Created by Jim Hanson on 1/8/22.
//

import simd
import SwiftUI
import MetalKit
import Wacoma

public enum XRenderError: Error {
    case noDevice
    case noDefaultLibrary
    case noDepthStencilState
    case badVertexDescriptor
    case bufferCreationFailed
    case snapshotInProgress
    case noSuchFunction(_ name: String)
}

public struct XRenderConstants {

    public static let maxBuffersInFlight = 3
}

public struct XRenderSettings {

    public var pov: POV

    public var viewMatrix: float4x4

    public var fadeoutMidpoint: Float

    public var fadeoutDistance: Float

    public var projectionMatrix: float4x4

    public var preferredFramesPerSecond: Int
}

public protocol XRenderable {

    /// Called at the beginning of every rendering cycle.
    mutating func prepareToDraw(_ mtkView: MTKView, _ renderSettings: XRenderSettings)

    /// Called on every rendering cycle. Should execute as quickly as possible.
    func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder)
}

public class XRenderController: ObservableObject, DragHandler, PinchHandler, RotationHandler {

    public static let defaultDarkBackground = SIMD4<Double>(0.025, 0.025, 0.025, 1)

    public static let defaultLightBackground = SIMD4<Double>(0.975, 0.975, 0.975, 1)

    public var renderables = [XRenderable]()

    public var povController: POVController

    public var fovController: FOVController

    /// The renderer view's bounds, in points
    public private(set) var viewBounds: CGRect = CGRect.zero // DUMMY VALUE

    /// distance in world coordinates between the POV's location and the plane on which a touch is located.
    /// If zero, then pinching and dragging do not work.
    /// Non-negative.
    public var touchPlaneDistance: Float = 1

    @Published public var backgroundColor: SIMD4<Double>

    @Published public private(set) var snapshotRequested: Bool = false

    private var snapshotCallback: ((String) -> Any?)? = nil

    public init(_ povController: POVController,
                _ fovController: FOVController,
                _ backgroundColor: SIMD4<Double> = XRenderController.defaultDarkBackground) {
        self.povController = povController
        self.fovController = fovController
        self.backgroundColor = backgroundColor
    }
    
    public func setColorScheme(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            backgroundColor = Self.defaultDarkBackground
            break
        case .light:
            backgroundColor = Self.defaultLightBackground
            break
        @unknown default:
            break
        }
    }
    
    public func update(_ viewBounds: CGRect) {
        self.viewBounds = viewBounds
        self.fovController.update(viewBounds)
    }

    public func requestSnapshot(_ callback: @escaping ((String) -> Any?)) throws {
        if snapshotRequested {
            throw XRenderError.snapshotInProgress
        }
        snapshotRequested = true
        snapshotCallback = callback
    }

    public func snapshotTaken(_ response: String) {
        let callback = snapshotCallback
        snapshotRequested = false
        snapshotCallback = nil
        Task {
            if let callback {
                _ = callback(response)
            }
        }
    }

    /// Returns a TouchRay whose origin is in the center of the screen and whose direction is derived from the given location.
    /// location and size are both in clip-space coords
    public func touchRay(at location: SIMD2<Float>, size: SIMD2<Float>) -> TouchRay {
        let inverseProjectionMatrix = fovController.projectionMatrix.inverse
        let inverseViewMatrix = povController.viewMatrix.inverse

        var v1 = inverseProjectionMatrix * SIMD4<Float>(location.x, location.y, 0, 1)
        v1.z = -1
        v1.w = 0
        let ray1 = normalize(inverseViewMatrix * v1).xyz

        var v2 = inverseProjectionMatrix * SIMD4<Float>(location.x + size.x, location.y, 0, 1)
        v2.z = -1
        v2.w = 0
        let ray2 = normalize(inverseViewMatrix * v2).xyz

        var v3 = inverseProjectionMatrix * SIMD4<Float>(location.x, location.y + size.y, 0, 1)
        v3.z = -1
        v3.w = 0
        let ray3 = normalize(inverseViewMatrix * v3).xyz

        // Starting at ray origin, make a right triangle in space such that ray1 forms
        // one leg and the hypoteneuse lies along ray2. cross1 is the other leg.
        let cross1 = (ray2 / simd_dot(ray1, ray2)) - ray1

        // Similar thing for ray3
        let cross2 = (ray3 / simd_dot(ray1, ray3)) - ray1

        //        print("XRenderController.touchRay")
        //        print("                  ray1: \(ray1.prettyString)")
        //        print("                  ray2: \(ray2.prettyString)")
        //        print("                  ray3: \(ray3.prettyString)")
        //        print("                  cross1: \(cross1)")
        //        print("                  cross2: \(cross2)")
        //        print("                  simd_dot(ray1, cross1): \(simd_dot(ray1, cross1))")
        //        print("                  simd_dot(ray1, cross2): \(simd_dot(ray1, cross2))")
        //        print("                  simd_dot(cross1, cross2): \(simd_dot(cross1, cross2))")

        return TouchRay(origin: povController.pov.location,
                        direction: ray1,
                        range: fovController.visibleZ,
                        cross1: cross1,
                        cross2: cross2)
    }


    /// Point in world coordinates corresponding to the given point on the glass
    /// location is in clip-space coords
    public func touchPointOnGlass(_ clipSpacePoint: SIMD2<Float>) -> SIMD3<Float> {

        // TODO: verify correctness

        let inverseProjectionMatrix = fovController.projectionMatrix.inverse
        let inverseViewMatrix = povController.viewMatrix.inverse

        var viewSpacePoint = inverseProjectionMatrix * SIMD4<Float>(clipSpacePoint.x, clipSpacePoint.y, 0, 1)
        // print("touchPointOnGlass: clipSpace: \(clipSpacePoint.prettyString) viewSpace: \(viewSpacePoint.prettyString)")
        // viewSpacePoint.z = 0
        viewSpacePoint.w = 0
        let worldSpacePoint = (inverseViewMatrix * viewSpacePoint).xyz
        // print("touchPointOnGlass: clipSpace: \(clipSpacePoint.prettyString) worldSpace: \(worldSpacePoint.prettyString)")
        return worldSpacePoint
    }

    /// I THOUGHT this was:
    /// "Point in world coordinates derived from the given point on the glass and an imputed depth below the screen"
    /// but I might have been wrong
    ///
    /// location is in clip-space coords
    public func touchPointAtDepth(_ location: SIMD2<Float>) -> SIMD3<Float> {

        // I want to find the world coordinates of the point where the
        // touch ray intersects the touch plane
        //
        // touch plane is normal to pov.forward (which is given in world coordinates)
        // touchPlaneDistance is distance btw POV and touch plane, in world coordinates
        // touch ray's origin and direction are given in world coordinates

        let ray = touchRay(at: location, size: .zero)
        let distanceToPoint: Float = touchPlaneDistance / simd_dot(povController.pov.forward, ray.direction)
        let touchPoint = ray.origin + distanceToPoint * ray.direction

        //        print("XRenderController.touchPoint")
        //        print("    pov.forward: \(povController.pov.forward.prettyString)")
        //        print("    touchPlaneDistance: \(touchPlaneDistance)")
        //        print("    ray.origin: \(ray.origin.prettyString)")
        //        print("    ray.direction: \(ray.origin.prettyString)")
        //        print("    fwd*ray: \(simd_dot(povController.pov.forward, ray.direction))")
        //        print("    distanceToPoint: \(distanceToPoint)")
        //        print("    touchPoint: \(touchPoint.prettyString)")

        return touchPoint
    }

    public func dragBegan(at location: SIMD2<Float>) {
        // print("XRenderController.dragBegan")
        povController.dragGestureBegan(at: touchPointAtDepth(location))
    }

    public func dragChanged(panFraction: Float, scrollFraction: Float) {
        // print("XRenderController.dragChanged")
        // Convert pan & scroll from fractions of the screen (-1...1)
        // to distances in view coordinates.
        let fovSize = fovController.fovSize(touchPlaneDistance)
        povController.dragGestureChanged(panDistance: panFraction * Float(fovSize.width),
                                         scrollDistance: scrollFraction * Float(fovSize.height))
    }

    public func dragEnded() {
        // print("XRenderController.dragEnded")
        povController.dragGestureEnded()
    }

    public func pinchBegan(at location: SIMD2<Float>) {
        // print("XRenderController.pinchBegan")
        // HACK HACK HACK HACK use center of screen, not touch location
        povController.pinchGestureBegan(at: touchPointAtDepth(.zero))
    }

    public func pinchChanged(scale: Float) {
        // print("XRenderController.pinchChanged")
        povController.pinchGestureChanged(scale: scale)
    }

    public func pinchEnded() {
        // print("XRenderController.pinchEnded")
        povController.pinchGestureEnded()
    }

    public func rotationBegan(at location: SIMD2<Float>) {
        // print("XRenderController.rotationBegan")
        // HACK HACK HACK HACK use center of screen, not touch location
        // OLD povController.rotationGestureBegan(at: touchPointAtDepth(.zero))

        povController.rotationGestureBegan(at: touchPointOnGlass(location))
    }

    public func rotationChanged(radians: Float) {
        // print("XRenderController.rotationChanged")
        povController.rotationGestureChanged(radians: radians)
    }

    public func rotationEnded() {
        // print("XRenderController.rotationEnded")
        povController.rotationGestureEnded()
    }

}



extension XRenderController {

    public static func clipPoint(_ viewPt: CGPoint, _ viewBounds: CGRect) -> SIMD2<Float> {
        // FIXME: ASSUMES viewBounds origin is (0,0)
        return SIMD2<Float>(clipX(viewPt.x, viewBounds.width), clipY(viewPt.y, viewBounds.height))
    }

    public static func clipPoint(_ viewPt0: CGPoint, _ viewPt1: CGPoint, _ viewBounds: CGRect) -> SIMD2<Float> {
        // FIXME: ASSUMES viewBounds origin is (0,0)
        return SIMD2<Float>(clipX((viewPt0.x + viewPt1.x)/2, viewBounds.width),
                            clipY((viewPt0.y + viewPt1.y)/2, viewBounds.height))
    }

    private static func clipX(_ viewX: CGFloat, _ viewWidth: CGFloat) -> Float {
        return Float(2 * viewX / viewWidth - 1)
    }

#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    private static func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
        // In iOS, viewY increases toward the TOP of the screen
        return Float(1 - 2 * viewY / viewHeight)
    }

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    private static func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
        // In macOS, viewY increaases toward the BOTTOM of the screen
        return Float(2 * viewY / viewHeight - 1)
    }

#endif  // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

}

public class XRenderer: NSObject, MTKViewDelegate {

    weak var controller: XRenderController!

    var gestureCoordinator: GestureCoordinator

    let device: MTLDevice!

    let inFlightSemaphore = DispatchSemaphore(value: XRenderConstants.maxBuffersInFlight)

    let commandQueue: MTLCommandQueue

    var depthState: MTLDepthStencilState

    public init(_ controller: XRenderController, _ gestureHandlers: GestureHandlers) throws {
        self.controller = controller
        self.gestureCoordinator = GestureCoordinator(gestureHandlers)
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        else {
            throw XRenderError.noDevice
        }

        self.commandQueue = device.makeCommandQueue()!

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true

        if let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) {
            depthState = state
        }
        else {
            throw XRenderError.noDepthStencilState
        }

        super.init()

    }

    public func connectGestures(_ mtkView: MTKView) {
        gestureCoordinator.connectGestures(mtkView)
    }

    public func disconnectGestures(_ mtkView: MTKView) {
        gestureCoordinator.disconnectGestures(mtkView)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange newSize: CGSize) {

        // print("XRenderer.mtkView. view.bounds: \(view.bounds), newSize: \(newSize)")

        // Docco for this method sez: "Updates the view’s contents upon receiving a change
        // in layout, resolution, or size." And: "Use this method to recompute any view or
        // projection matrices, or to regenerate any buffers to be compatible with the view’s
        // new size." However, we're going to do all that in draw() because the matrices
        // depend on user-settable properties that may change anytime, not just when something
        // happens to trigger this method.

        // newSize is in pixels, view.bounds is in points.
        controller.update(view.bounds)
    }

    public func draw(in view: MTKView) {

        // print("XRenderer.draw")

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // _drawCount += 1
        // let t0 = Date()

        // Swift compiler sez that the snapshot needs to be taken before the current drawable
        // is presented. This means it will capture the figure that was drawn the in PREVIOUS
        // call to this method.
        if controller.snapshotRequested {
            controller.snapshotTaken(saveSnapshot(view))
        }

        // Make sure all the renderables get exactly the same values
        let date = Date()
        controller.povController.update(date)
        controller.fovController.update(date)
        let renderSettings = XRenderSettings(pov: controller.povController.pov,
                                            viewMatrix: controller.povController.viewMatrix,
                                            fadeoutMidpoint: controller.fovController.fadeoutMidpoint,
                                            fadeoutDistance: controller.fovController.fadeoutDistance,
                                            projectionMatrix: controller.fovController.projectionMatrix,
                                            preferredFramesPerSecond: view.preferredFramesPerSecond)

        for var renderable in controller.renderables {
            renderable.prepareToDraw(view, renderSettings)
        }

        if let commandBuffer = commandQueue.makeCommandBuffer() {

            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in
                semaphore.signal()
            }

            // Delay getting the current Drawable and RenderPassDescriptor until we absolutely
            // them, in order to avoid holding onto the drawable and therby blocking the display
            // pipeline any longer than necessary
            if let drawable = view.currentDrawable,
               let renderPassDescriptor = view.currentRenderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                // The figure's background is opaque and we doing single-pass rendering, so we don't
                // need to do anything for loadAction or storeAction.
                renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
                renderPassDescriptor.colorAttachments[0].storeAction = .dontCare

                renderEncoder.setDepthStencilState(depthState)

                for renderable in controller.renderables {
                    renderable.encodeDrawCommands(renderEncoder)
                }
                renderEncoder.endEncoding()
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }
    }

    func saveSnapshot(_ view: MTKView) -> String {
        if let cgImage = view.takeSnapshot() {
            return cgImage.save()

            // Docco sez: "You are responsible for releasing this object by calling CGImageRelease"
            // but I get a compiler error: "'CGImageRelease' is unavailable: Core Foundation objects
            // are automatically memory managed"
            // CGImageRelease(cgImage)
        }
        else {
            return "Image capture failed"
        }
    }
}

public struct XRendererView {

    @ObservedObject var controller: XRenderController

    var gestureHandlers: GestureHandlers?

    public init(_ controller: XRenderController,
                _ gestureHandlers: GestureHandlers? = nil) {
        self.controller = controller
        self.gestureHandlers = gestureHandlers
    }

    public func makeCoordinator() -> XRenderer {
        // Docco sez, "Implement this method if changes to your view might affect other
        // parts of your app. In your implementation, create a custom Swift instance that
        // can communicate with other parts of your interface. For example, you might
        // provide an instance that binds its variables to SwiftUI properties, causing
        // the two to remain synchronized."
        do {
            return try XRenderer(controller, gestureHandlers ?? GestureHandlers())
        }
        catch {
            fatalError("Problem creating render coordinator: \(error)")
        }
    }

    public func makeMTKView(_ coordinator: XRenderer) -> MTKView {
        // "Creates the view object and configures its initial state."

        // print("XRendererView.makeMTKView")

        let mtkView = MTKView()

        // Pause to stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        mtkView.delegate = coordinator
        mtkView.device = coordinator.device
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

        mtkView.framebufferOnly = false // necessary for screenshots

        coordinator.connectGestures(mtkView)

        // Update and unpause
        doUpdate(mtkView, coordinator)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        return mtkView
    }

    public func updateMTKView(_ mtkView: MTKView, _ coordinator: XRenderer) {

        // Docco for this method sez, "Updates the state of the specified view with
        // new information from SwiftUI." This struct gets recreated many many times,
        // and I think the system calls makeMTKView the first time this is created
        // but it calls this method all the subsequent times.

        // EMPIRICAL: I'm seeing this method called once per handful of calls to draw()

        // print("XRendererView.updateMTKView")
        doUpdate(mtkView, coordinator)
    }

    private func doUpdate(_ mtkView: MTKView, _ coordinator: XRenderer) {

        // XRenderController's backgroundColor MIGHT have changed
        mtkView.clearColor = MTLClearColorMake(coordinator.controller.backgroundColor.x,
                                               coordinator.controller.backgroundColor.y,
                                               coordinator.controller.backgroundColor.z,
                                               coordinator.controller.backgroundColor.w)

        // mtkView's bounds are measured in points while its drawableSize is measured in pixels.
        // They need not match, e.g., on my ipad, bounds: (0.0, 0.0, 1180.0, 820.0), drawableSize: (2360.0, 1640.0)
        // print("RendererView.doUpdate. view bounds: \(mtkView.bounds), drawableSize: \(mtkView.drawableSize)")
    }

    static public func dismantleMTKView(_ mtkView: MTKView, _ coordinator: XRenderer) {
        coordinator.disconnectGestures(mtkView)
    }
}

#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension XRendererView: UIViewRepresentable {

    public typealias UIViewType = MTKView
    public typealias Coordinator = XRenderer

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = makeMTKView(context.coordinator)
        mtkView.isMultipleTouchEnabled = true
        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleUIView(_ mtkView: MTKView, coordinator: XRenderer) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension XRendererView: NSViewRepresentable {

    public typealias NSViewType = MTKView
    public typealias Coordinator = XRenderer

    public func makeNSView(context: Context) -> MTKView {
        return makeMTKView(context.coordinator)
    }

    public func updateNSView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleNSView(_ mtkView: MTKView, coordinator: XRenderer) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#endif // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


