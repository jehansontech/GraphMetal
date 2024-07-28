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

extension RenderConstants {

    public static let defaultDarkBackground = SIMD4<Double>(0.025, 0.025, 0.025, 1)

    public static let defaultLightBackground = SIMD4<Double>(0.975, 0.975, 0.975, 1)

    public static let pointSizeMinimum: Float = 2

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
                defaultNodeColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1),
                defaultEdgeColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1),
                backgroundColor: SIMD4<Float> = SIMD4<Float>(0,0,0,1)) {
        self.pointSize = pointSize
        self.defaultNodeColor = defaultNodeColor
        self.defaultEdgeColor = defaultEdgeColor
        self.backgroundColor = backgroundColor
    }

    public func getNodeSize(forPOV pov: POV, bbox: BoundingBox?) -> Float {
        if let bbox = bbox {
            let newSize = RenderConstants.pointSizeScaleFactor  * self.pointSize / distance(pov.location, bbox.center)
            return newSize.clamp(RenderConstants.pointSizeMinimum, RenderConstants.pointSizeMaximum)
        }
        else {
            return pointSize
        }
    }
}

public protocol Renderable {

    /// Called before the first rendering cycle.
    mutating func setup(_ mtkView: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws

    /// Called at the beginning of every rendering cycle.
    mutating func prepareToDraw()

    /// Called on every rendering cycle. Should execute as quickly as possible.
    mutating func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder)

    // mutating teardown()

}

// ============================================================================
// MARK: - RenderController
// ============================================================================

public class RenderController: ObservableObject, RendererDelegate {

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

    @Published public var backgroundColor: SIMD4<Double>

    @Published public private(set) var snapshotRequested: Bool = false

    public var projectionMatrix: float4x4 { fovController.projectionMatrix }

    public var viewMatrix: float4x4 { povController.viewMatrix }

    public var visibleZ: ClosedRange<Float> { fovController.visibleZ }

    public var pov: POV { povController.pov }
    
    private var snapshotCallback: ((String) -> Any?)? = nil

    private let referenceDate = Date()

    /// The 256 byte aligned size of our uniform structure
    private let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

    // MAYBE: pass in to init
    private let dynamicUniformBufferIndex: Int = WireframeBufferIndex.uniform.rawValue

    private var isSetup: Bool = false

    private weak var device: MTLDevice!

    private var library: MTLLibrary!

    private var dynamicUniformBuffer: MTLBuffer!

    private var uniformBufferOffset = 0

    private var uniformBufferRotation = 0

    var uniforms: UnsafeMutablePointer<Uniforms>!

    public init(_ povController: POVController,
                _ fovController: FOVController,
                _ backgroundColor: SIMD4<Double> = RenderConstants.defaultDarkBackground) {
        self.povController = povController
        self.fovController = fovController
        self.backgroundColor = backgroundColor
    }

    public func update(_ viewBounds: CGRect) {
        self.viewBounds = viewBounds
        self.fovController.update(viewBounds)
    }

    public func prepareToDraw(_ view: MTKView) {

        if !isSetup {
            do {
                try doSetup(view)
                isSetup = true
            }
            catch {
                fatalError("Problem in RenderController setup: \(error)")
            }
        }

        let date = Date()
        povController.update(date)
        fovController.update(date)
        prepareUniforms(date)
        for i in renderables.indices {
            renderables[i].prepareToDraw() //view, renderSettings)
        }
    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {

        // Do the uniforms no matter what.

        encoder.setVertexBuffer(dynamicUniformBuffer,
                                offset:uniformBufferOffset,
                                index: dynamicUniformBufferIndex)
        encoder.setFragmentBuffer(dynamicUniformBuffer,
                                  offset:uniformBufferOffset,
                                  index: dynamicUniformBufferIndex)

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

        // =============
        // Create device and library

        guard let newDevice = view.device
        else {
            throw RenderError.noDevice
        }

        guard let newLibrary = try? newDevice.makeDefaultLibrary(bundle: Bundle.module)
        else {
            throw RenderError.noDefaultLibrary
        }

        self.device = newDevice
        self.library = newLibrary

        // ======================
        // Create uniforms buffer

        let uniformBufferSize = alignedUniformsSize * RenderConstants.maxBuffersInFlight
        if let buffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
            self.dynamicUniformBuffer = buffer
            self.dynamicUniformBuffer.label = "UniformBuffer"
            self.uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        }
        else {
            throw RenderError.bufferCreationFailed
        }

        // ======================
        // set up renderables

        for i in renderables.indices {
            try renderables[i].setup(view, device, library)
        }
    }

    private func prepareUniforms(_ date: Date) {

        // ======================================
        // Rotate the uniforms buffer

        uniformBufferRotation = (uniformBufferRotation + 1) % RenderConstants.maxBuffersInFlight
        uniformBufferOffset = alignedUniformsSize * uniformBufferRotation
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        // =====================================
        // Update content of current uniforms buffer
        //
        // NOTE uniforms.modelViewMatrix is equal to renderSettings.viewMatrix
        // because we are drawing the graph in world coordinates, i.e., our model
        // matrix is the identity.

        uniforms[0].projectionMatrix = fovController.projectionMatrix
        uniforms[0].modelViewMatrix = povController.viewMatrix
        uniforms[0].pointSize = settings.pointSize // TODO: settings.getNodeSize(forPOV: povController.pov, bbox: self.bbox)
        uniforms[0].edgeColor = settings.defaultEdgeColor // SIMD4<Float>(0.2, 0.2, 0.2, 1)
        uniforms[0].fadeoutMidpoint = fovController.fadeoutMidpoint
        uniforms[0].fadeoutDistance = fovController.fadeoutDistance
        uniforms[0].pulsePhase = pulsePhase(date)
    }

    private func pulsePhase(_ date: Date) -> Float {
        let millisSinceReferenceDate = Int(date.timeIntervalSince(referenceDate) * 1000)
        return 0.001 * Float(millisSinceReferenceDate % 1000)
    }

}

extension RenderController: DragHandler, PinchHandler, RotationHandler {

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
