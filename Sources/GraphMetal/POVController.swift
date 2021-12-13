//
//  POVController.swift
//  GraphMetal
//

import Foundation
import CoreGraphics
import SwiftUI
import simd
import Wacoma

struct POVControllerConstants {

    let scrollSensitivity: Float

    let panSensitivity: Float

    let magnificationSensitivity: Float

    let rotationSensitivity: Float

    let flyCoastingThreshold: Double

    let flyNormalizedAcceleration: Double

    let flyMinSpeed: Double

    let flyMaxSpeed: Double

#if os(iOS)
    init() {
        self.scrollSensitivity = 1.5 * .piOverTwo
        self.panSensitivity = 1.5 * .pi
        self.magnificationSensitivity = 2
        self.rotationSensitivity = 1.25
        self.flyCoastingThreshold = 0.33
        self.flyNormalizedAcceleration = 6
        self.flyMinSpeed  = 0.01
        self.flyMaxSpeed = 10
    }
#elseif os(macOS)
    init() {
        self.scrollSensitivity = 1.5 * .piOverTwo
        self.panSensitivity = 1.5 * .pi
        self.magnificationSensitivity = 2
        self.rotationSensitivity = 1.25
        self.flyCoastingThreshold = 0.33
        self.flyNormalizedAcceleration = 6
        self.flyMinSpeed  = 0.01
        self.flyMaxSpeed = 10
    }
#endif

}

///
///
///
public class POVController: ObservableObject, CustomStringConvertible, RendererDragHandler, RendererPinchHandler, RendererRotationHandler  {

    var constants = POVControllerConstants()

    // Don't publish pov: causes performance issues on macOS
    public var pov: POV

    @Published public var orbitEnabled: Bool

    @Published public var orbitSpeed: Float

    private var _lastUpdateTimestamp: Date? = nil

    private var dragInProgress: POVDragAction? = nil

    private var pinchInProgress: POVPinchAction? = nil

    private var rotationInProgress: POVRotationAction? = nil

    private var flightInProgress: POVFlightAction? = nil

    public var flying: Bool {
        return (flightInProgress != nil)
    }

    public var povDefault: POV? = nil

    public var markIsSet: Bool {
        return _povMark != nil
    }

    private var _povMark: POV? = nil

    public var description: String {
        return "POVController POV: posn=\(pov.location.prettyString) cntr=\(pov.center.prettyString) up=\(pov.up.prettyString)"
    }

    public init(pov: POV = POV(),
                povDefault: POV? = nil,
                orbitEnabled: Bool = false,
                orbitSpeed: Float = .pi/30) {
        debug("POVController.init")
        self.pov = pov
        self.povDefault = povDefault
        self.orbitEnabled = orbitEnabled
        self.orbitSpeed = orbitSpeed
    }

    deinit {
        debug("POVController.deinit")
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

    public func centerOn(_ newCenter: SIMD3<Float>) {
        flyTo(POV(location: pov.location,
                  center: newCenter,
                  up: pov.up))
    }

    public func flyTo(_ destination: POV) {
        debug("POVController.flyTo", "pov = \(pov)")
        debug("POVController.flyTo", "destination = \(destination)")
        debug("POVController.flyTo", "flying = \(flying)")
        if !flying {
            self.flightInProgress = POVFlightAction(self.pov, destination, constants)
        }
    }

    public func dragBegan(at location: SIMD2<Float>) {
        debug("POVController.dragBegan", "location=\(location.prettyString)")
        if !flying {
            self.dragInProgress = POVDragAction(self.pov, location, constants)
        }
    }

    public func dragChanged(pan: Float, scroll: Float) {
        // print("POVController.dragChanged")
        if var povDragHandler = self.dragInProgress {
            if let newPOV = povDragHandler.dragChanged(self.pov, pan: pan, scroll: scroll) {
                self.pov = newPOV
            }
        }
    }

    public func dragEnded() {
        debug("POVController.dragEnded")
        self.dragInProgress = nil
    }

    public func pinchBegan(at center: SIMD2<Float>) {
        // print("POVController.pinchBegan")
        if !flying {
            self.pinchInProgress = POVPinchAction(self.pov, center, constants)
        }
    }

    public func pinchChanged(by scale: Float) {
        // print("POVController.pinchChanged")
        if var povPinchHandler = self.pinchInProgress {
            if let newPOV = povPinchHandler.magnificationChanged(self.pov, scale: scale) {
                self.pov = newPOV
            }
        }
    }

    public func pinchEnded() {
        // print("POVController.pinchEnded")
        pinchInProgress = nil
    }

    public func rotationBegan(at location: SIMD2<Float>) {
        // print("POVController.rotationBegan")
        if !flying {
            rotationInProgress = POVRotationAction(self.pov, location, constants)
        }
    }
    
    public func rotationChanged(by radians: Float) {
        // print("POVController.rotationChanged")
        if var povRotationHandler = self.rotationInProgress {
            if let newPOV = povRotationHandler.rotationChanged(self.pov, radians: radians) {
                self.pov = newPOV
            }
        }
    }

    public func rotationEnded() {
        self.rotationInProgress = nil
    }

    func updatePOV(_ timestamp: Date) -> POV {
        var updatedPOV: POV
        if let newPOV = flightInProgress?.update(timestamp) {
            updatedPOV = newPOV
        }
        else {
            self.flightInProgress = nil
            updatedPOV = self.pov
        }

        // =======================================
        // Q: orbital motion even if we're flying or handling a gesture?
        // A: Sure, what could go wrong?
        // =======================================

        if let t0 = _lastUpdateTimestamp,
           orbitEnabled {
            // STET: multiply by -1 so that positive speed looks like earth's direction of rotation
            let dPhi = -1 * orbitSpeed * Float(timestamp.timeIntervalSince(t0))
            updatedPOV.location = (float4x4(rotationAround: pov.up, by: dPhi) * SIMD4<Float>(pov.location, 1)).xyz
        }
        _lastUpdateTimestamp = timestamp

        self.pov = updatedPOV // this will automatically update the modelViewMatrix
        return updatedPOV
    }
}

// ===========================================================
// MARK:- Actions
// ===========================================================

///
///
///
struct POVDragAction {

    let initialPOV: POV

    let touchLocation: SIMD2<Float>

    let scrollSensitivity: Float

    let panSensitivity: Float

    init(_ pov: POV, _ touchLocation: SIMD2<Float>, _ constants: POVControllerConstants) {
        self.initialPOV = pov
        self.touchLocation = touchLocation
        self.scrollSensitivity = constants.scrollSensitivity
        self.panSensitivity = constants.panSensitivity
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
            float4x4(rotationAround: initialPOV.up, by: -pan * panSensitivity)
            * float4x4(rotationAround: perpAxis, by: scroll * scrollSensitivity)
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


///
///
///
struct POVPinchAction {

    let initialPOV: POV

    let touchLocation: SIMD2<Float>

    let magnificationSensitivity: Float

    init(_ pov: POV, _ touchLocation: SIMD2<Float>, _ constants: POVControllerConstants) {
        self.initialPOV = pov
        self.touchLocation = touchLocation
        self.magnificationSensitivity = constants.magnificationSensitivity
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


///
///
///
struct POVRotationAction {

    let initialPOV: POV

    let touchLocation: SIMD2<Float>

    let rotationSensitivity: Float

    init(_ pov: POV, _ touchLocation: SIMD2<Float>, _ constants: POVControllerConstants) {
        self.initialPOV = pov
        self.touchLocation = touchLocation
        self.rotationSensitivity = constants.rotationSensitivity
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


//
//
//
class POVFlightAction {

    enum Phase: Double {
        case new
        case accelerating
        case coasting
        case decelerating
        case arrived
    }

    // Needed for multi-step flying, NOT USED yet.
    let povSequence: [POV]

    // Needed for multi-step flying, NOT USED yet.
    let totalDistance: Float

    let coastingThreshold: Double

    let normalizedAcceleration: Double

    let minSpeed: Double

    let maxSpeed: Double

    var lastUpdateTime: Date = .distantPast

    var normalizedSpeed: Double = 0

    var currentStepIndex: Int = 0

    /// fraction of the distance in the current step has been covered
    var currentStepFractionalDistance: Double = 0

    var phase: Phase = .new

    init(_ pov: POV, _ destination: POV, _ constants: POVControllerConstants) {
        let povSequence = [pov, destination]
        self.povSequence = povSequence
        self.totalDistance = Self.calculateTotalDistance([pov, destination])
        self.coastingThreshold = constants.flyCoastingThreshold
        self.normalizedAcceleration = constants.flyNormalizedAcceleration
        self.minSpeed = constants.flyMinSpeed
        self.maxSpeed = constants.flyMaxSpeed
    }

    static func calculateTotalDistance(_ povSequence: [POV]) -> Float {
        var distance: Float = 0
        for i in 1..<povSequence.count {
            distance += simd_distance(povSequence[i-1].location, povSequence[i].location)
        }
        return distance
    }

    /// returns nil when finished
    func update(_ timestamp: Date) -> POV? {
        debug("POVFlightAction.update", "phase = \(phase)")

        // It's essential that the first time this func is called,
        // phase = .new
        // currentStepFractionalDistance = 0

        let dt = timestamp.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = timestamp

        currentStepFractionalDistance += normalizedSpeed * dt

        switch phase {
        case .new:
            phase = .accelerating
        case .accelerating:
            if currentStepFractionalDistance >= coastingThreshold {
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
            if currentStepFractionalDistance >= (1 - coastingThreshold) {
                phase = .decelerating
            }
        case .decelerating:
            if currentStepFractionalDistance >= 1  {
                currentStepFractionalDistance = 1
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

        let initialPOV = povSequence[currentStepIndex]
        let finalPOV = povSequence[currentStepIndex+1]
        let newLocation = Float(currentStepFractionalDistance) * (finalPOV.location - initialPOV.location) + initialPOV.location
        let newCenter   = Float(currentStepFractionalDistance) * (finalPOV.center - initialPOV.center) + initialPOV.center
        let newUp       = Float(currentStepFractionalDistance) * (finalPOV.up - initialPOV.up) + initialPOV.up
        return POV(location: newLocation,
                   center: newCenter,
                   up: newUp)
    }
}
