//
//  Renderer.swift
//  GraphMetal
//
//  Created by Jim Hanson on 8/3/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public struct RenderConstants {

    public static let darkBackground = SIMD4<Float>(0.025, 0.025, 0.025, 1)

    public static let lightBackground = SIMD4<Float>(0.975, 0.975, 0.975, 1)

    public static let uniformsBufferIndex = 0

    public static let nodePositionBufferIndex = 1

    public static let nodeColorBufferIndex = 2
}

public protocol Renderable: AnyObject {

    func setup(_ view: MTKView, _ device: MTLDevice, _ defaultLibrary: MTLLibrary) throws

    func prepareToDraw(_ date: Date)

    /// We pass a command encoder rather than having the renderable create its own
    /// so that the renderer can add common commands first, e.g., registering the uniforms buffer.
    func encodeCommands(_ encoder: MTLRenderCommandEncoder)

    func renderingIsComplete()

    func teardown()
}

public enum RenderError: Error {
    case noDevice
    case noDefaultLibrary
    case noCommandQueue
    case noDepthStencilState
    case noSuchFunction(name: String)
    case badVertexDescriptor
    case bufferCreationFailed(bufferLabel: String)
    case snapshotInProgress
}

public class Renderer: ObservableObject {

    // TODO: make this no longer necessary.
    /// Distance in world coordinates between the POV's location and the plane on which a touch is located.
    /// Non-negative. If zero, then pinching and dragging do not work.
    // FIXME: needs to be set properly
    public var touchPlaneDistance: Float = 1

    /// In "points"
    // NOTE: Can't mark it Published b/c it gets changed within a view update.
    public private(set) var viewBounds: CGRect

    @Published public var backgroundRenderColor: SIMD4<Float> = RenderConstants.darkBackground
    
    @Published public private(set) var snapshotRequested: Bool = false

    private var povController: POVController

    private var fovController: FOVController

    private var uniforms: UniformsBufferManager

    private var wireframe: Wireframe

    private var decorations: [Renderable]

    private var snapshotCallback: ((String) -> Any?)? = nil

    private var depthStencilState: MTLDepthStencilState!

    public init(_ povController: POVController,
                _ fovController: FOVController,
                _ wireframe: Wireframe,
                decorations: [Renderable] = []) {
        self.povController = povController
        self.fovController = fovController
        self.uniforms = UniformsBufferManager()
        self.wireframe = wireframe
        self.decorations = decorations
        self.viewBounds = CGRect.zero // Dummy value
    }

    public func requestSnapshot(_ callback: @escaping ((String) -> Any?)) throws {
        if snapshotRequested {
            throw RenderError.snapshotInProgress
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

    public func setup(_ mtkView: MTKView) throws {
        // print("ZRenderer.setup: entered")

        guard let device = mtkView.device
        else {
            throw RenderError.noDevice
        }

        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: Bundle.module)
        else {
            throw RenderError.noDefaultLibrary
        }

        guard let depthStencilState = makeDepthStencilState(device)
        else {
            throw RenderError.noDepthStencilState
        }
        self.depthStencilState = depthStencilState

        try uniforms.setup(device)
        try wireframe.setup(mtkView, device, defaultLibrary)
        for i in decorations.indices {
            try decorations[i].setup(mtkView, device, defaultLibrary)
        }

        // print("ZRenderer.setup: exiting")
    }

    public func updateViewBounds(_ viewBounds: CGRect) {
        self.viewBounds = viewBounds
        self.fovController.update(viewBounds)
    }

    public func prepareToDraw(_ view: MTKView) {
        let date = Date()
        povController.update(date)
        fovController.update(date)
        uniforms.prepareToDraw(makeUniforms(date))
        wireframe.prepareToDraw(date)
        for i in decorations.indices {
            decorations[i].prepareToDraw(date)
        }
    }

    public func encodeCommands(_ encoder: MTLRenderCommandEncoder) {
        encoder.setDepthStencilState(depthStencilState)
        uniforms.encodeCommands(encoder)
        wireframe.encodeCommands(encoder)
        for i in decorations.indices {
            decorations[i].encodeCommands(encoder)
        }
    }

    public func renderingIsComplete() {
        uniforms.renderingIsComplete()
        wireframe.renderingIsComplete()
        for i in decorations.indices {
            decorations[i].renderingIsComplete()
        }
    }

    private func makeDepthStencilState(_ device: MTLDevice)  -> MTLDepthStencilState? {
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.lessEqual
        depthStateDesciptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor:depthStateDesciptor)
    }

    private func makeUniforms(_ date: Date) -> Uniforms {

        // NOTE uniforms.modelViewMatrix is equal to povController.viewMatrix
        // because we are drawing the graph in world coordinates, i.e., our model
        // matrix is the identity.

        return Uniforms(projectionMatrix: fovController.projectionMatrix,
                        modelViewMatrix: povController.viewMatrix,
                        pointSize: wireframe.makePointSize(povController.location),
                        edgeColor: wireframe.defaultColor,
                        backgroundColor: self.backgroundRenderColor,
                        fadeoutMidpoint: fovController.fadeoutMidpoint,
                        fadeoutDistance: fovController.fadeoutDistance,
                        pulsePhase: makePulsePhase(date))
    }

    private func makePulsePhase(_ date: Date) -> Float {
        let millisSinceReferenceDate = Int(date.timeIntervalSinceReferenceDate * 1000)
        return 0.001 * Float(millisSinceReferenceDate % 1000)
    }
}

// ============================================================================
// MARK: - RenderCoordinator
// ============================================================================

public class RenderCoordinator: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice!

    weak var renderer: Renderer!

    private var gestureCoordinator: GestureCoordinator

    private let commandQueue: MTLCommandQueue

    public init(_ renderer: Renderer, _ gestureHandlers: GestureHandlers) throws {
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        else {
            throw RenderError.noDevice
        }

        if let queue = device.makeCommandQueue() {
            self.commandQueue = queue
        }
        else {
            throw RenderError.noCommandQueue
        }

        self.renderer = renderer
        self.gestureCoordinator = GestureCoordinator(gestureHandlers)
        super.init()
    }

    public func setup(_ mtkView: MTKView) {
        do {
            try renderer.setup(mtkView)
        }
        catch {
            fatalError("Problem in Renderer setup: \(error)")
        }
    }

    public func connectGestures(_ mtkView: MTKView) {
        gestureCoordinator.connectGestures(mtkView)
    }

    public func disconnectGestures(_ mtkView: MTKView) {
        gestureCoordinator.disconnectGestures(mtkView)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange newSize: CGSize) {

        // print("ZRendererCoordinator.mtkView: entered. view.bounds: \(view.bounds), newSize: \(newSize)")

        // Docco for this method sez: "Updates the view’s contents upon receiving a change
        // in layout, resolution, or size." And: "Use this method to recompute any view or
        // projection matrices, or to regenerate any buffers to be compatible with the view’s
        // new size." However, we're going to do all that in draw() because the matrices
        // depend on user-settable properties that may change anytime, not just when something
        // happens to trigger this method.
        //
        // The newSize arg is in pixels, whereas view.bounds is in "points". The latter is
        // what we care about.

        renderer.updateViewBounds(view.bounds)
        // NO EFFECT view.setNeedsDisplay()

        // print("ZRendererCoordinator.mtkView: exiting")
    }

    // private var drawCount: Int = 0

    public func draw(in view: MTKView) {
//        drawCount += 1
//        if drawCount == 1 {
//            print("RenderCoordinator.draw #\(drawCount) entered")
//        }

        // Swift compiler sez that the snapshot needs to be taken before the current drawable
        // is presented. This means it will capture the figure that was drawn the in PREVIOUS
        // call to this method.

        if renderer.snapshotRequested {
            renderer.snapshotTaken(saveSnapshot(view))
            // MAYBE: return
        }

        renderer.prepareToDraw(view)

//        if drawCount == 1 {
//            print("RenderCoordinator.draw #\(drawCount) prepareToDraw done")
//        }

        if let commandBuffer = commandQueue.makeCommandBuffer() {

            commandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in
                self.renderer.renderingIsComplete()
            }

            // Delay getting the RenderPassDescriptor until we absolutely need it,
            // in order to avoid blocking the display pipeline any longer than
            // necessary.
            if let renderPassDescriptor = view.currentRenderPassDescriptor {

                // [2024-08-16] EMPIRICAL: don't modify the renderPassDescriptor by
                // setting a loadAction or clearAction because it will interfere
                // with rendering on my ipad (tho not on the simulator).

                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    renderer.encodeCommands(renderEncoder)
                    renderEncoder.endEncoding()
                }

                if let drawable = view.currentDrawable {
//                    if drawCount == 1 {
//                        print("RenderCoordinator.draw #\(drawCount) presenting drawable")
//                    }
                    commandBuffer.present(drawable)
                }
            }
//            if drawCount == 1 {
//                print("RenderCoordinator.draw #\(drawCount) committing command buffer")
//            }
            commandBuffer.commit()
        }

//        if drawCount == 1 {
//            print("RenderCoordinator.draw #\(drawCount) exiting")
//        }
    }

    func saveSnapshot(_ view: MTKView) -> String {
        if let cgImage = view.takeSnapshot() {
            let response = cgImage.save()

            // Docco sez, "You are responsible for releasing this object by calling
            // CGImageRelease" but when I do so I get a compiler error w/ message
            // "'CGImageRelease' is unavailable: Core Foundation objects are automatically memory managed"
            // CGImageRelease(cgImage)

            return response
        }
        else {
            return "Image capture failed"
        }
    }
}

// ============================================================================
// MARK: - Renderer gesture handling
// ============================================================================

extension Renderer: DragHandler, PinchHandler, RotationHandler {

    /// Point in world coordinates corresponding to the given point on the glass
    /// location is in clip-space coords
    public func touchPointOnGlass(at clipSpacePoint: SIMD2<Float>) -> SIMD3<Float> {

        // TODO: verify correctness

        let inverseProjectionMatrix = self.fovController.projectionMatrix.inverse
        let inverseViewMatrix = self.povController.viewMatrix.inverse

        var viewSpacePoint = inverseProjectionMatrix * SIMD4<Float>(clipSpacePoint.x, clipSpacePoint.y, 0, 1)
        // print("touchPointOnGlass: clipSpace: \(clipSpacePoint.prettyString) viewSpace: \(viewSpacePoint.prettyString)")
        // viewSpacePoint.z = 0
        viewSpacePoint.w = 0
        let worldSpacePoint = (inverseViewMatrix * viewSpacePoint).xyz
        // print("touchPointOnGlass: clipSpace: \(clipSpacePoint.prettyString) worldSpace: \(worldSpacePoint.prettyString)")
        return worldSpacePoint
    }

    public func touchPointAtDepth(at clipSpacePoint: SIMD2<Float>, depth: Float) -> SIMD3<Float> {

        // I want to find the world coordinates of the point where the center of the
        // touch ray intersects a given plane normal to the POV's forward vector
        // (the "touch plane").
        //
        // touch plane is normal to pov.forward (which is given in world coordinates)
        // depth is distance btw POV and touch plane, in world coordinates
        // touch ray's origin and direction are given in world coordinates

        let ray = touchRay(at: clipSpacePoint, size: .zero)
        let distanceToPoint: Float = depth / simd_dot(self.povController.forward, ray.direction)
        let touchPoint = ray.origin + distanceToPoint * ray.direction

        //        print("touchPoint")
        //        print("    pov.forward: \(povController.pov.forward.prettyString)")
        //        print("    touchPlaneDistance: \(touchPlaneDistance)")
        //        print("    ray.origin: \(ray.origin.prettyString)")
        //        print("    ray.direction: \(ray.origin.prettyString)")
        //        print("    fwd*ray: \(simd_dot(povController.pov.forward, ray.direction))")
        //        print("    distanceToPoint: \(distanceToPoint)")
        //        print("    touchPoint: \(touchPoint.prettyString)")

        return touchPoint

    }

    /// Returns a TouchRay whose origin is in the center of the screen and whose direction is derived from the given location.
    /// location and size are both in clip-space coords
    public func touchRay(at clipSpacePoint: SIMD2<Float>, size: SIMD2<Float>) -> TouchRay {
        let inverseProjectionMatrix = self.fovController.projectionMatrix.inverse
        let inverseViewMatrix = self.povController.viewMatrix.inverse

        var v1 = inverseProjectionMatrix * SIMD4<Float>(clipSpacePoint.x, clipSpacePoint.y, 0, 1)
        v1.z = -1
        v1.w = 0
        let ray1 = normalize(inverseViewMatrix * v1).xyz

        var v2 = inverseProjectionMatrix * SIMD4<Float>(clipSpacePoint.x + size.x, clipSpacePoint.y, 0, 1)
        v2.z = -1
        v2.w = 0
        let ray2 = normalize(inverseViewMatrix * v2).xyz

        var v3 = inverseProjectionMatrix * SIMD4<Float>(clipSpacePoint.x, clipSpacePoint.y + size.y, 0, 1)
        v3.z = -1
        v3.w = 0
        let ray3 = normalize(inverseViewMatrix * v3).xyz

        // Starting at ray origin, make a right triangle in space such that ray1 forms
        // one leg and the hypoteneuse lies along ray2. cross1 is the other leg.
        let cross1 = (ray2 / simd_dot(ray1, ray2)) - ray1

        // Similar thing for ray3
        let cross2 = (ray3 / simd_dot(ray1, ray3)) - ray1

        //        print("              touchRay")
        //        print("                  ray1: \(ray1.prettyString)")
        //        print("                  ray2: \(ray2.prettyString)")
        //        print("                  ray3: \(ray3.prettyString)")
        //        print("                  cross1: \(cross1)")
        //        print("                  cross2: \(cross2)")
        //        print("                  simd_dot(ray1, cross1): \(simd_dot(ray1, cross1))")
        //        print("                  simd_dot(ray1, cross2): \(simd_dot(ray1, cross2))")
        //        print("                  simd_dot(cross1, cross2): \(simd_dot(cross1, cross2))")

        return TouchRay(origin: self.povController.location,
                        direction: ray1,
                        range: self.fovController.visibleZ,
                        cross1: cross1,
                        cross2: cross2)
    }

    private func touchPlaneDistanceForDrag() -> Float? {
        guard let bbox = wireframe.bbox
        else {
            return nil
        }

        // p1, p2 are two diagonally opposite corners of the bbox, in view coords.
        let viewMatrix = povController.viewMatrix
        let p1 = viewMatrix * SIMD4<Float>(bbox.min, 1)
        let p2 = viewMatrix * SIMD4<Float>(bbox.max, 1)
        let dMin = min(p1.z, p2.z)
        let dMax = max(p1.z, p2.z)

        // In view coordinates, forward is along the -z axis, so all the points we can see
        // have negative z.
        //
        // If dMax < 0 then we're facing the bbox.
        // If dMax >= 0 and dMin < 0 then we're inside the bbox.
        // If dMin >= 0 then the bbox is behind us.
        //
        // Assume dMin is negative (else we can't touch the graph at all). If we're inside
        // the bbox, then we'll touch the back wall. If we're facing it, we'll touch the
        // front. I.e., we want the negative value that's closer to 0.
        //
        // Because our viewMatrix is only a rotation, not a rescaling, the distance between the POV
        // and the plane we want to touch is the same in world coordinates as in view coordinates.
        // We just need to correct the sign.

        let facingTheBBox = dMax < 0
        let distance: Float = abs(facingTheBBox ? dMax : dMin)

        //        print("touchPlaneDistanceForDrag")
        //        print("    world coords bbox \(bbox)")
        //        print("    view coords bbox p1: \(p1.xyz.prettyString) p2: \(p2.xyz.prettyString)")
        //        print("    facingTheBBox: \(facingTheBBox), distance: \(distance)")

        return distance
    }

    private func touchPlaneDistanceForPinch() -> Float? {
        guard let bbox = wireframe.bbox
        else {
            return nil
        }

        // p0 is the bbox center, in view coords.
        let viewMatrix = povController.viewMatrix
        let p0 = viewMatrix * SIMD4<Float>(bbox.center, 1)
        return abs(p0.z)
    }

    public func dragBegan(at location: SIMD2<Float>) {
        // print("RenderController.dragBegan")
        if let newDistance = touchPlaneDistanceForDrag() {
            touchPlaneDistance = newDistance
        }
        povController.dragGestureBegan(at: touchPointAtDepth(at: location, depth: touchPlaneDistance))
    }

    public func dragChanged(panFraction: Float, scrollFraction: Float) {
        // print("RenderController.dragChanged")
        // Convert pan & scroll from fractions of the screen (-1...1)
        // to distances in view coordinates.
        let fovSize = fovController.fovSize(touchPlaneDistance)
        povController.dragGestureChanged(panDistance: panFraction * Float(fovSize.width),
                                         scrollDistance: scrollFraction * Float(fovSize.height))
    }

    public func dragEnded() {
        // print("RenderController.dragEnded")
        povController.dragGestureEnded()
    }

    public func pinchBegan(at location: SIMD2<Float>) {
        // print("RenderController.pinchBegan")
        if let newDistance = touchPlaneDistanceForPinch() {
            touchPlaneDistance = newDistance
        }
        // HACK HACK HACK HACK use center of screen, not touch location
        povController.pinchGestureBegan(at: touchPointAtDepth(at: .zero, depth: touchPlaneDistance))
    }

    public func pinchChanged(scale: Float) {
        // print("RenderController.pinchChanged")
        povController.pinchGestureChanged(scale: scale)
    }

    public func pinchEnded() {
        // print("RenderController.pinchEnded")
        povController.pinchGestureEnded()
    }

    public func rotationBegan(at location: SIMD2<Float>) {
        // print("RenderController.rotationBegan")
        // HACK HACK HACK HACK use center of screen, not touch location
        // OLD povController.rotationGestureBegan(at: touchPointAtDepth(.zero))

        povController.rotationGestureBegan(at: touchPointOnGlass(at: location))
    }

    public func rotationChanged(radians: Float) {
        // print("RenderController.rotationChanged")
        povController.rotationGestureChanged(radians: radians)
    }

    public func rotationEnded() {
        // print("RenderController.rotationEnded")
        povController.rotationGestureEnded()
    }

}

// ============================================================================
// MARK: - Uniforms buffer management
// ============================================================================

struct UniformsBufferManager {

    private let maxBuffersInFlight = 3

    private let inFlightSemaphore: DispatchSemaphore

    private var uniformsBufferIndex: Int { RenderConstants.uniformsBufferIndex }

    private var uniformsBufferRotation = 0

    private var uniformsBufferOffset = 0

    private var uniformsBuffer: MTLBuffer!

    private var uniforms: UnsafeMutablePointer<Uniforms>!

    init() {
        self.inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    }

    mutating func setup(_ device: MTLDevice) throws {
        let bufferLabel = "Uniforms"
        let bufferSize = Uniforms.alignedSize * maxBuffersInFlight
        let bufferOptions = MTLResourceOptions.storageModeShared
        if let buffer = device.makeBuffer(length: bufferSize, options: bufferOptions) {
            self.uniformsBuffer = buffer
            self.uniformsBuffer.label = bufferLabel
            self.uniformsBufferRotation = 0
            self.uniformsBufferOffset = 0
            self.uniforms = UnsafeMutableRawPointer(uniformsBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        }
        else {
            throw RenderError.bufferCreationFailed(bufferLabel: bufferLabel)
        }
    }

    //    private var updateCount: Int = 0

    mutating func prepareToDraw(_ newUniforms: Uniforms) {
        //        updateCount += 1
        //        if updateCount % 60 == 1 {
        //            print("UniformsController.update #\(updateCount) entered")
        //        }

        // Wait for GPU to tell us it's done with the part of the buffer we're about to write to

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // ======================================
        // Rotate

        uniformsBufferRotation = (uniformsBufferRotation + 1) % maxBuffersInFlight
        uniformsBufferOffset = Uniforms.alignedSize * uniformsBufferRotation
        uniforms = UnsafeMutableRawPointer(uniformsBuffer.contents() + uniformsBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        // =====================================
        // Replace content

        uniforms[0].projectionMatrix = newUniforms.projectionMatrix
        uniforms[0].modelViewMatrix = newUniforms.modelViewMatrix
        uniforms[0].pointSize = newUniforms.pointSize
        uniforms[0].edgeColor = newUniforms.edgeColor
        uniforms[0].fadeoutMidpoint = newUniforms.fadeoutMidpoint
        uniforms[0].fadeoutDistance = newUniforms.fadeoutDistance
        uniforms[0].pulsePhase = newUniforms.pulsePhase

        //        if updateCount % 60 == 1 {
        //            print("UniformsController.update #\(updateCount) exiting")
        //        }

    }

    func encodeCommands(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(uniformsBuffer,
                                offset:uniformsBufferOffset,
                                index: uniformsBufferIndex)
        encoder.setFragmentBuffer(uniformsBuffer,
                                  offset:uniformsBufferOffset,
                                  index:  uniformsBufferIndex)
    }

    func renderingIsComplete() {
        inFlightSemaphore.signal()
    }

    func teardown() {
    }
}

