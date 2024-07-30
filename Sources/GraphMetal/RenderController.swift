//
//  RenderController.swift
//  GraphMetal
//
//  Created by Jim Hanson on 7/25/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma

public struct RenderConstants {

    public static let maxBuffersInFlight = 3

    /// The 256 byte aligned size of our uniform structure
    public static let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

    public static let uniformsBufferIndex = 0

    public static let defaultElementColor = SIMD4<Float>(0.2, 0.2, 0.2, 1)

    public static let defaultDarkBackground = SIMD4<Float>(0.025, 0.025, 0.025, 1)

    public static let defaultLightBackground = SIMD4<Float>(0.975, 0.975, 0.975, 1)

    public static let pointSizeMinimum: Float = 1

    /// EMPIRICAL
    public static let pointSizeMaximum: Float = 64

    /// EMPIRICAL
    public static let pointSizeScaleFactor: Float = 400

}

public struct RenderSettings: Equatable {

    public var pointSize: Float

    public var defaultNodeColor: SIMD4<Float>

    public var defaultEdgeColor: SIMD4<Float>

    public var backgroundColor: SIMD4<Float>

    public init(pointSize: Float = 16,
                defaultNodeColor: SIMD4<Float> = RenderConstants.defaultElementColor,
                defaultEdgeColor: SIMD4<Float> = RenderConstants.defaultElementColor,
                backgroundColor: SIMD4<Float> = RenderConstants.defaultDarkBackground) {
        self.pointSize = pointSize
        self.defaultNodeColor = defaultNodeColor
        self.defaultEdgeColor = defaultEdgeColor
        self.backgroundColor = backgroundColor
    }
}

public protocol Renderable {

    /// Called before the first rendering cycle.
    mutating func setup(_ mtkView: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws

    /// Called at the beginning of every rendering cycle.
    mutating func prepareToDraw()

    /// Called on every rendering cycle. Should execute as quickly as possible.
    mutating func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder)

    /// Called when the renderer is destroyed
    mutating func teardown()
}

// ============================================================================
// MARK: - RenderController
// ============================================================================

public class RenderController: ObservableObject, RenderDelegate {
    
    public var backgroundColor: SIMD4<Float> { settings.backgroundColor }
    
    @Published public var settings = RenderSettings()

    public var renderables = [Renderable]()

    public var povController: POVController

    public var fovController: FOVController

    /// The renderer view's bounds, in points
    public private(set) var viewBounds: CGRect = CGRect.zero // DUMMY VALUE

    /// distance in world coordinates between the POV's location and the plane on which a touch is located.
    /// If zero, then pinching and dragging do not work.
    /// Non-negative.
    public var touchPlaneDistance: Float = 1

    @Published public private(set) var snapshotRequested: Bool = false

    private var snapshotCallback: ((String) -> Any?)? = nil

    private let referenceDate = Date()

    private weak var device: MTLDevice!

    private var library: MTLLibrary!

    private var uniformsBuffer: MTLBuffer!

    private var uniformsBufferOffset = 0

    private var uniformsBufferRotation = 0

    var uniforms: UnsafeMutablePointer<Uniforms>!

    public init(_ povController: POVController,
                _ fovController: FOVController) {
        self.povController = povController
        self.fovController = fovController
    }

    public func setColorScheme(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            settings.backgroundColor = RenderConstants.defaultDarkBackground
            break
        case .light:
            settings.backgroundColor = RenderConstants.defaultLightBackground
            break
        @unknown default:
            break
        }
    }

    public func updateViewBounds(_ viewBounds: CGRect) {
        self.viewBounds = viewBounds
        self.fovController.update(viewBounds)
    }

    public func setup(_ view: MTKView) throws {

        // =============
        // Get device and make library

        guard let tmpDevice = view.device
        else {
            throw RenderError.noDevice
        }

        guard let tmpLibrary = try? tmpDevice.makeDefaultLibrary(bundle: Bundle.module)
        else {
            throw RenderError.noDefaultLibrary
        }

        self.device = tmpDevice
        self.library = tmpLibrary

        // ======================
        // Create uniforms buffer

        let bufferLabel = "Uniforms"
        let uniformBufferSize = RenderConstants.alignedUniformsSize * RenderConstants.maxBuffersInFlight
        if let buffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
            self.uniformsBuffer = buffer
            self.uniformsBuffer.label = bufferLabel
            self.uniforms = UnsafeMutableRawPointer(uniformsBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        }
        else {
            throw RenderError.bufferCreationFailed(bufferLabel: bufferLabel)
        }

        // ======================
        // set up renderables

        for i in renderables.indices {
            try renderables[i].setup(view, device, library)
        }
    }

    public func prepareToDraw(_ view: MTKView) {
        let date = Date()
        povController.update(date)
        fovController.update(date)
        prepareUniforms(date)
        for i in renderables.indices {
            renderables[i].prepareToDraw() //view, renderSettings)
        }
    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {

        // Do the uniforms first.
        encoder.setVertexBuffer(uniformsBuffer,
                                offset:uniformsBufferOffset,
                                index: RenderConstants.uniformsBufferIndex)
        encoder.setFragmentBuffer(uniformsBuffer,
                                  offset:uniformsBufferOffset,
                                  index:  RenderConstants.uniformsBufferIndex)

        for i in renderables.indices {
            renderables[i].encodeDrawCommands(encoder)
        }
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

    private func doSetup(_ view: MTKView) throws {
    }

    private func prepareUniforms(_ date: Date) {

        // ======================================
        // Rotate the uniforms buffer

        uniformsBufferRotation = (uniformsBufferRotation + 1) % RenderConstants.maxBuffersInFlight
        uniformsBufferOffset = RenderConstants.alignedUniformsSize * uniformsBufferRotation
        uniforms = UnsafeMutableRawPointer(uniformsBuffer.contents() + uniformsBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        // =====================================
        // Update content of current uniforms buffer
        //
        // NOTE uniforms.modelViewMatrix is equal to povController.viewMatrix
        // because we are drawing the graph in world coordinates, i.e., our model
        // matrix is the identity.

        uniforms[0].projectionMatrix = fovController.projectionMatrix
        uniforms[0].modelViewMatrix = povController.viewMatrix
        uniforms[0].pointSize = makePointSize()
        uniforms[0].edgeColor = settings.defaultEdgeColor
        uniforms[0].fadeoutMidpoint = fovController.fadeoutMidpoint
        uniforms[0].fadeoutDistance = fovController.fadeoutDistance
        uniforms[0].pulsePhase = makePulsePhase(date)
    }

    private func makePulsePhase(_ date: Date) -> Float {
        let millisSinceReferenceDate = Int(date.timeIntervalSince(referenceDate) * 1000)
        return 0.001 * Float(millisSinceReferenceDate % 1000)
    }

    private func makePointSize() -> Float {
        // TODO: settings.getNodeSize(forPOV: povController.pov, bbox: self.bbox)
        //
        //        public func getNodeSize(forPOV pov: POV, bbox: BoundingBox?) -> Float {
        //            if let bbox = bbox {
        //                let newSize = RenderConstants.pointSizeScaleFactor  * self.pointSize / distance(pov.location, bbox.center)
        //                return newSize.clamp(RenderConstants.pointSizeMinimum, RenderConstants.pointSizeMaximum)
        //            }
        //            else {
        //                return pointSize
        //            }
        //        }

        return settings.pointSize
    }
}

// ============================================================================
// MARK: - Gesture handling
// ============================================================================

extension RenderController: DragHandler, PinchHandler, RotationHandler {

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
        let distanceToPoint: Float = depth / simd_dot(self.povController.pov.forward, ray.direction)
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

        return TouchRay(origin: self.povController.pov.location,
                        direction: ray1,
                        range: self.fovController.visibleZ,
                        cross1: cross1,
                        cross2: cross2)
    }

    public func dragBegan(at location: SIMD2<Float>) {
        // print("RenderController.dragBegan")
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

public struct TouchRay: Codable, Sendable {

    /// Ray's point of origin in world coordinates
    public var origin: SIMD3<Float>

    /// Unit vector giving ray's direction in world coordinates
    public var direction: SIMD3<Float>

    /// Start and end of the ray, given as distance along ray
    public var range: ClosedRange<Float>

    /// cross1 and cross2 are two vectors perpendicular to ray direction giving its rate of spreading.
    /// They give the semi-major and semi-minor axes of the ellipse that is the cross-section (we
    /// don't know which is which).
    public var cross1: SIMD3<Float>
    public var cross2: SIMD3<Float>

    public init(origin: SIMD3<Float>, direction: SIMD3<Float>, range: ClosedRange<Float>, cross1: SIMD3<Float>, cross2: SIMD3<Float>) {
        self.origin = origin
        self.direction = direction
        self.range = range
        self.cross1 = cross1
        self.cross2 = cross2
    }
}
