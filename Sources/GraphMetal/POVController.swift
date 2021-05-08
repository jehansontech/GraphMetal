//
//  POVController.swift
//  ArcWorld iOS
//
//  Created by James Hanson on 9/26/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import CoreGraphics
import SwiftUI
import simd
import Taconic

///
///
///
public class POVController: ObservableObject, CustomStringConvertible, RendererDragHandler, RendererPinchHandler, RendererRotationHandler  {

    /// EMPIRICAL
    public let fovyRadians = Float(65) * .pi / 180

    /// EMPIRICAL
    public let nearZ: Float = 0.001

    /// EMPIRICAL
    public let farZ: Float = 1000

    /// macOS and iOS use opposite conventions for scrolling b/c their coordinate systems have
    /// opposite "vertical" orientations. macOS has option to 'flip' the coordinate system so that it
    /// matches that of iOS.
    /// * scrollReversed = false is appropriate for iOS and macOS flipped views.
    /// * scrollReversed = true is appropriate macOS unflipped vlews
    var scrollReversed = false
    
    /// Determined by hardware
    var scrollFlipFactor: Float = 1

    // for POV
    var location: SIMD3<Float>

    // for POV
    var center: SIMD3<Float>

    // for POV
    var up: SIMD3<Float>

    var viewSize: CGSize

    public var projectionMatrix: float4x4
    
    public var modelViewMatrix: float4x4

    weak var renderControls: RenderControls? = nil

    private var _motionEnabled: Bool = false

    private var _velocityRTP: SIMD3<Float> = Geometry.zero

    private var _lastUpdateTimestamp: Date? = nil

    var dragPOV: DragPOV? = nil

    var pinchPOV: PinchPOV? = nil

    var rotatePOV: RotatePOV? = nil

    var flyPOV: FlyPOV? = nil

    var flying: Bool {
        return (flyPOV != nil)
    }

    public var pov: POV {
        get {
            return POV(location: self.location,
                       center: self.center,
                       up: self.up)
        }
        set {
            debug("NEW POV: \(newValue)")
            self.location = newValue.location
            self.center = newValue.center
            self.up = normalize(newValue.up)
            self.modelViewMatrix = Self.makeModelViewMatrix(location: self.location, center: self.center, up: self.up)
            updateRenderingParameters()
        }
    }

    public var povDefault: POV? = nil

    public var markIsSet: Bool {
        return _povMark != nil
    }

    private var _povMark: POV? = nil

    public var description: String {
        return "POV: posn=\(stringify(location)) cntr=\(stringify(center)) up=\(stringify(up))"
    }

    public init() {
        debug("POVController", "init")

        // Dummy values
        self.location = POV.defaultLocation
        self.center = POV.defaultCenter
        self.up = POV.defaultUp
        self.viewSize = CGSize(width: 100, height: 100)
        self.modelViewMatrix = POVController.makeModelViewMatrix(location: location, center: center, up: up)
        self.projectionMatrix = POVController.makeProjectionMatrix(viewSize, fovyRadians, nearZ, farZ)
    }

    public func requestScreenshot() {
        if let renderControls = renderControls {
            renderControls.requestScreenshot()
        }
    }
    public func markPOV() {
        self._povMark = pov
        // print("POV mark: \(pov)")
    }

    public func unsetMark() {
        self._povMark = nil
    }
    
    public func goToMarkedPOV() {
        if let pov = _povMark {
            flyTo(pov)
        }
    }

    public func goToDefaultPOV() {
        if let pov = povDefault {
            flyTo(pov)
        }
    }

    public func turnToward(_ newCenter: SIMD3<Float>) {
        flyTo(POV(location: pov.location,
                  center: newCenter,
                  up: pov.up))
    }

    public func flyTo(_ destination: POV) {
        if !flying {
            self.flyPOV = FlyPOV(self.pov, destination)
        }
    }

    public func dragBegan(at location: SIMD2<Float>) {
        // print("POVController.dragBegan")
        if !flying {
            self.dragPOV = DragPOV(self.pov, location)
        }
    }

    public func dragChanged(pan: Float, scroll: Float) {
        // print("POVController.dragChanged")
        if var povDragHandler = self.dragPOV {
            if let newPOV = povDragHandler.dragChanged(self.pov, pan: pan, scroll: scroll) {
                self.pov = newPOV
            }
        }
    }

    public func dragEnded() {
        // print("POVController.dragEnded")
        self.dragPOV = nil
    }

    public func pinchBegan(at center: SIMD2<Float>) {
        // print("POVController.pinchBegan")
        if !flying {
            self.pinchPOV = PinchPOV(self.pov, center)
        }
    }

    public func pinchChanged(by scale: Float) {
        // print("POVController.pinchChanged")
        if var povPinchHandler = self.pinchPOV {
            if let newPOV = povPinchHandler.magnificationChanged(self.pov, scale: scale) {
                self.pov = newPOV
            }
        }
    }

    public func pinchEnded() {
        // print("POVController.pinchEnded")
        pinchPOV = nil
    }

    public func rotationBegan(at location: SIMD2<Float>) {
        // print("POVController.rotationBegan")
        if !flying {
            rotatePOV = RotatePOV(self.pov, location)
        }
    }
    
    public func rotationChanged(by radians: Float) {
        // print("POVController.rotationChanged")
        if var povRotationHandler = self.rotatePOV {
            if let newPOV = povRotationHandler.rotationChanged(self.pov, radians: radians) {
                self.pov = newPOV
            }
        }
    }

    public func rotationEnded() {
        // print("POVController.rotationEnded")
        self.rotatePOV = nil
    }

    func updateProjection(viewSize: CGSize) {
        self.viewSize = viewSize
        self.projectionMatrix = Self.makeProjectionMatrix(viewSize, fovyRadians, nearZ, farZ)
        self.modelViewMatrix = Self.makeModelViewMatrix(location: location, center: center, up: up)
        // _modelViewStale = true
    }

    func updateRenderingParameters() {
        let povDistance = Double(simd_length(self.location - self.center))
        debug("POVController: new povDistance = \(povDistance)")
        if let controls = renderControls {
            controls.adjustNodeSize(povDistance: povDistance)
        }
    }

    func updateModelView(_ timestamp: Date) {

        // if we're flying, ignore pov.velocity

        if let newPOV = flyPOV?.update(timestamp) {
            self.pov = newPOV
        }
        else {
            self.flyPOV = nil

            // FIXME Doesn't work...
            //            if (_motionEnabled && self._velocityRTP != Geometry.zero) {
            //                if let t0 = _lastUpdateTimestamp {
            //                    let dt = timestamp.timeIntervalSince(t0)
            //
            //                    // FIXME this is wrong
            //                    let locationRTP = Geometry.cartesianToSpherical(xyz: self.location)
            //                    let newLocationRTP = locationRTP + Float(dt) * _velocityRTP
            //                    self.location = Geometry.sphericalToCartesian(rtp: newLocationRTP)
            //
            //                    self.modelViewMatrix = Self.makeModelViewMatrix(location: location, center: center, up: up)
            //                }
            //            }
        }
        _lastUpdateTimestamp = timestamp
    }

    static func makeModelViewMatrix(location: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        return float4x4(lookAt: center, eye: location, up: up)
    }

    /// viewBounds are (width, height, depth). All three must be > 0
    static func makeProjectionMatrix(_ viewSize: CGSize, _ fovyRadians: Float, _ nearZ: Float, _ farZ: Float) -> float4x4 {
        let aspectRatio = (viewSize.height > 0) ? Float(viewSize.width) / Float(viewSize.height) : 1
        return float4x4(perspectiveProjectionRHFovY: fovyRadians, aspectRatio: aspectRatio, nearZ: nearZ, farZ: farZ)
    }
}

// ===========================================================
///
///
///
struct DragPOV {

    let scrollSensitivity: Float = 1.5 * .piOverTwo

    let panSensitivity: Float = 1.5 * .pi

    let initialPOV: POV

    let touchLocation: SIMD2<Float>

    init(_ pov: POV, _ touchLocation: SIMD2<Float>) {
        self.initialPOV = pov
        self.touchLocation = touchLocation
    }

    mutating func dragChanged(_ pov: POV, pan: Float, scroll: Float) -> POV? {

        // PAN is a rotation of the POV's location about an axis that is
        // parallel to the POV's up axis and that passes through the POV's
        // center point
        //
        // SCROLL is a rotation of the location and up vectors.
        // --location rotates about an axis that is perpendicular to both 
        //   forward and up axes and that passes through the center point
        // --up vector rotates about the same axis
        //

        /// unit vector perpendicular to POV's forward and up vectors
        let perpAxis = normalize(simd_cross(initialPOV.forward, initialPOV.up))

        let newLocation = (
            float4x4(translationBy: initialPOV.center)
                * float4x4(rotationAround: initialPOV.up, by: -pan * panSensitivity)
                * float4x4(rotationAround: perpAxis, by: scroll * scrollSensitivity)
                * float4x4(translationBy: -initialPOV.center)
                * SIMD4<Float>(initialPOV.location, 1)
        ).xyz


        let newUp = (
            float4x4(rotationAround: perpAxis, by: scroll * scrollSensitivity)
                * SIMD4<Float>(initialPOV.up, 1)
        ).xyz


        return POV(location: newLocation,
                   center: pov.center,
                   up: newUp)

    }
}


// ===========================================================
///
///
///
struct PinchPOV {

    var magnificationSensitivity: Float = 2

    let initialPOV: POV

    let touchLocation: SIMD2<Float>

    init(_ pov: POV, _ touchLocation: SIMD2<Float>) {
        self.initialPOV = pov
        self.touchLocation = touchLocation
    }

    mutating func magnificationChanged(_ pov: POV, scale: Float) -> POV? {

        // This is translation of POV's location toward or away from its center

        let displacementXYZ = initialPOV.location - initialPOV.center
        let newDisplacementXYZ = displacementXYZ / scale
        let newLocation = newDisplacementXYZ + initialPOV.center
        return POV(location: newLocation,
                   center: pov.center,
                   up: pov.up)
    }
}


// ===========================================================
///
///
///
struct RotatePOV {

    var rotationSensitivity: Float = 1.5

    let initialPOV: POV

    let touchLocation: SIMD2<Float>

    init(_ pov: POV, _ touchLocation: SIMD2<Float>) {
        self.initialPOV = pov
        self.touchLocation = touchLocation
    }

    mutating func rotationChanged(_ pov: POV, radians: Float) -> POV? {

        // This is a rotation of the POV's up vector about its forward vector

        let upMatrix = float4x4(rotationAround: pov.forward, by: Float(-rotationSensitivity * radians))
        let newUp = (upMatrix * SIMD4<Float>(initialPOV.up, 1)).xyz
        return POV(location: pov.location,
                   center: pov.center,
                   up: newUp)
    }
}


// ===========================================================
//
//
//
class FlyPOV {

    enum Phase: Double {
        case new
        case accelerating
        case coasting
        case decelerating
        case arrived
    }

    /// EMPIRICAL
    let coastingThreshold: Double = 0.33

    /// EMPIRICAL
    let normalizedAcceleration: Double = 8

    /// EMPIRICAL: not reached
    let minSpeed: Double = 0.01

    /// EMPIRICAL: not reached
    let maxSpeed: Double = 10

    let initialPOV: POV

    let finalPOV: POV

    var lastUpdateTime: Date = .distantPast

    var normalizedSpeed: Double = 0

    var fractionalDistance: Double = 0

    var phase: Phase = .new

    init(_ pov: POV, _ destination: POV) {
        self.initialPOV = pov
        self.finalPOV = destination
    }

    /// returns nil when finished
    func update(_ timestamp: Date) -> POV? {

        // It's essential that the first time this func is called,
        // phase = .new
        // normalizedSpeed = 0

        let dt = timestamp.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = timestamp

        fractionalDistance += normalizedSpeed * dt

        switch phase {
        case .new:
            phase = .accelerating
        case .accelerating:
            if fractionalDistance >= coastingThreshold {
                phase = .coasting
            }
            else {
                normalizedSpeed += normalizedAcceleration * dt
                if normalizedSpeed > maxSpeed {
                    normalizedSpeed = maxSpeed
                    phase = .coasting
                }
            }
        case .coasting:
            if fractionalDistance >= (1 - coastingThreshold) {
                phase = .decelerating
            }
        case .decelerating:
            if fractionalDistance >= 1  {
                fractionalDistance = 1
                phase = .arrived
            }
            else {
                normalizedSpeed -= (normalizedAcceleration * dt)
                if normalizedSpeed < minSpeed {
                    normalizedSpeed = minSpeed
                }
            }
        case .arrived:
            return nil
        }

        let newLocation = Float(fractionalDistance) * (finalPOV.location - initialPOV.location) + initialPOV.location
        let newCenter   = Float(fractionalDistance) * (finalPOV.center - initialPOV.center) + initialPOV.center
        let newUp       = Float(fractionalDistance) * (finalPOV.up - initialPOV.up) + initialPOV.up
        return POV(location: newLocation,
                   center: newCenter,
                   up: newUp)
    }
}
