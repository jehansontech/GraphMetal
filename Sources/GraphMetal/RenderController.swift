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

public struct RenderSettings {

    public var pov: POV

    public var viewMatrix: float4x4

    public var fadeoutMidpoint: Float

    public var fadeoutDistance: Float

    public var projectionMatrix: float4x4

    public var preferredFramesPerSecond: Int
}

public protocol Renderable {

    /// Called at the beginning of every rendering cycle.
    mutating func prepareToDraw(_ mtkView: MTKView, _ renderSettings: RenderSettings)

    /// Called on every rendering cycle. Should execute as quickly as possible.
    func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder)
}

// ============================================================================
// MARK: - RenderController
// ============================================================================

public class RenderController: ObservableObject, RendererDelegate, DragHandler, PinchHandler, RotationHandler {

    public static let defaultDarkBackground = SIMD4<Double>(0.025, 0.025, 0.025, 1)

    public static let defaultLightBackground = SIMD4<Double>(0.975, 0.975, 0.975, 1)

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

    public init(_ povController: POVController,
                _ fovController: FOVController,
                _ backgroundColor: SIMD4<Double> = RenderController.defaultDarkBackground) {
        self.povController = povController
        self.fovController = fovController
        self.backgroundColor = backgroundColor
    }

    public func update(_ viewBounds: CGRect) {
        self.viewBounds = viewBounds
        self.fovController.update(viewBounds)
    }

    public func prepareToDraw(_ view: MTKView) {
        let date = Date()
        povController.update(date)
        fovController.update(date)
        let renderSettings = RenderSettings(pov: povController.pov,
                                            viewMatrix: povController.viewMatrix,
                                            fadeoutMidpoint: fovController.fadeoutMidpoint,
                                            fadeoutDistance: fovController.fadeoutDistance,
                                            projectionMatrix: fovController.projectionMatrix,
                                            preferredFramesPerSecond: view.preferredFramesPerSecond)

        for var renderable in renderables {
            renderable.prepareToDraw(view, renderSettings)
        }
    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
        for renderable in renderables {
            renderable.encodeDrawCommands(encoder)
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
