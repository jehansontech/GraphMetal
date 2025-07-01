//
//  POVController.swift
//  GraphMetal
//
//  Created by Jim Hanson on 1/8/22.
//

import Foundation
import simd
import Wacoma

public protocol POVController {

    var settings: POVControllerSettings { get set }

    var location: SIMD3<Float> { get }

    var forward: SIMD3<Float> { get }

    var up: SIMD3<Float> { get }

    var focus: SIMD3<Float> { get }

    var viewMatrix: float4x4 { get }

    var isFlying: Bool { get }

    var isDragging: Bool { get }

    var isPinching: Bool { get }

    var isRotating: Bool { get }

    func reset()

    /// Sets the POV's properties to the values they should have at the given system time.
    /// This method is called during each rendering cycle as a way to support a POV that changes on its own.
    func update(timestamp: Date)

    func markPOV(_ name: String)

    func hasMark(_ name: String) -> Bool

    func unsetMark(_ name: String)

    func flyTo(mark: String, flightTime: TimeInterval?)

    func dragGestureBegan(at: SIMD3<Float>)

    func dragGestureChanged(panDistance: Float, scrollDistance: Float)

    func dragGestureEnded()

    func pinchGestureBegan(at: SIMD3<Float>)

    func pinchGestureChanged(scale: Float)

    func pinchGestureEnded()

    func rotationGestureBegan(at: SIMD3<Float>)

    func rotationGestureChanged(radians: Float)

    func rotationGestureEnded()
}

extension POVController {

    public var viewMatrix: float4x4 {

        // Adapted from:
        // https://stackoverflow.com/questions/9053377/ios-questions-about-camera-information-within-glkmatrix4makelookat-result
        // https://gist.github.com/CaptainRedmuff/5673450

        let n = -self.forward
        let u = normalize(simd_cross(self.up, n))
        let v = simd_cross(n, u)

        return float4x4(columns: (SIMD4<Float>(u.x, v.x, n.x,  0),
                                  SIMD4<Float>(u.y, v.y, n.y,  0),
                                  SIMD4<Float>(u.z, v.z, n.z,  0),
                                  SIMD4<Float>(simd_dot(-u, self.location), simd_dot(-v, self.location), simd_dot(-n, self.location),  1)))
    }

    public func jumpTo(mark: String) {
        flyTo(mark: mark, flightTime: 0)
    }
}

public struct POVControllerSettings {

    public var scrollSensitivity: Float

    public var panSensitivity: Float

    public var rotationSensitivity: Float

    public var defaultFlightTime: TimeInterval

    public var flyCoastingThreshold: Double

    public var flyNormalizedAcceleration: Double

    public var flyMinSpeed: Double

    public var flyMaxSpeed: Double

    public init() {

        // If we need to make os-specific tweaks to these values,
        // put conditional-compilation switches in here.
        // #if os(iOS)
        // #elseif os(macOS)
        // #endif

        self.scrollSensitivity = 2.5
        self.panSensitivity = 2.5
        self.rotationSensitivity = 1.25
        self.defaultFlightTime = 1
        self.flyCoastingThreshold = 0.33
        self.flyNormalizedAcceleration = 3.5
        self.flyMinSpeed  = 0.05
        self.flyMaxSpeed = 5
    }
}

// ============================================================================
// MARK: - CenteredPOVController
// ============================================================================

public class CenteredPOVController: ObservableObject, POVController {

    /// Not @Published because it changes too frequently
    public var location: SIMD3<Float> { pov.location }

    /// Not @Published because it changes too frequently
    public var forward: SIMD3<Float> { pov.forward }

    /// Not @Published because it changes too frequently
    public var up: SIMD3<Float> { pov.up }

    /// Not @Published because it changes too frequently
    public var focus: SIMD3<Float> { pov.center }

    /// Not @Published because it changes too frequently
    public var center: SIMD3<Float> { pov.center }

    public var isFlying: Bool {
        return flightInProgress != nil || !queuedFlights.isEmpty
    }

    public var isDragging: Bool { dragInProgress != nil }

    public var isPinching: Bool { pinchInProgress != nil }

    public var isRotating: Bool { rotationInProgress != nil }

    @Published public var orbitEnabled: Bool

    /// angular rotation rate in radians per second
    @Published public var orbitSpeed: Float

    /// Not @Published because it changes too frequently
    public private(set) var pov: CenteredPOV

    public private(set) var markedPOVs = [String: CenteredPOV]()

    public var settings = POVControllerSettings()

    private var _lastUpdateTimestamp: Date? = nil

    private var flightInProgress: CenteredPOVFlight? = nil

    private var dragInProgress: CenteredPOVTangentialMove? = nil

    private var pinchInProgress: CenteredPOVRadialMove? = nil

    private var rotationInProgress: CenteredPOVRoll? = nil

    private var queuedFlights = [CenteredPOVFlight.Spec]()

    public init(location: SIMD3<Float> = SIMD3<Float>(1, 1, 1),
                center: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
                orbitEnabled: Bool = true,
                orbitSpeed: Float = 0.125) {
        self.pov = CenteredPOV(location: location, center: center, up: up)
        self.orbitEnabled = orbitEnabled
        self.orbitSpeed = orbitSpeed
    }

    public func reset() {
        // TODO: reset to the values given in the initializer instead of to their defaults.
        self.pov = CenteredPOV(location: SIMD3<Float>(1, 1, 1), center: SIMD3<Float>(0, 0, 0), up: SIMD3<Float>(0, 1, 0))
        self.orbitEnabled = true
        self.orbitSpeed = 0.125

        self.markedPOVs.removeAll()
        self.queuedFlights.removeAll()
        self.flightInProgress = nil
        self.dragInProgress = nil
        self.pinchInProgress = nil
        self.rotationInProgress = nil
        self._lastUpdateTimestamp = nil
    }

    public func markPOV(_ name: String) {
        markedPOVs[name] = pov
    }

    public func hasMark(_ name: String) -> Bool {
        markedPOVs[name] != nil
    }

    public func unsetMark(_ name: String) {
        markedPOVs[name] = nil
    }

    public func setMark(_ name: String, pov: CenteredPOV) {
        markedPOVs[name] = pov
    }

    public func setMark(_ name: String, location: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) {
        setMark(name, pov: CenteredPOV(location: location, center: center, up: up))
    }

    public func flyTo(mark: String, flightTime: TimeInterval? = nil)  {
        if let destination = markedPOVs[mark] {
            flyTo(location: destination.location,
                  center: destination.center,
                  up: destination.up,
                  flightTime: flightTime)
        }
    }

    public func flyTo(pov: CenteredPOV, flightTime: TimeInterval? = nil) {
        let trueFlightTime = flightTime ?? settings.defaultFlightTime
        queuedFlights.append(CenteredPOVFlight.Spec(location: pov.location, center: pov.center, up: pov.up, flightTime: trueFlightTime))
    }

    public func flyTo(location newLocation: SIMD3<Float>? = nil,
                      center newCenter: SIMD3<Float>? = nil,
                      up newUp: SIMD3<Float>? = nil,
                      flightTime: TimeInterval? = nil) {
        let trueLocation = newLocation ?? self.pov.location
        let trueCenter = newCenter ?? self.pov.center
        let trueUp = newUp ?? self.pov.up
        let trueFlightTime = flightTime ?? settings.defaultFlightTime
        queuedFlights.append(CenteredPOVFlight.Spec(location: trueLocation, center: trueCenter, up: trueUp, flightTime: trueFlightTime))
    }

    public func centerOn(_ newCenter: SIMD3<Float>, flightTime: TimeInterval? = nil) {
        flyTo(center: newCenter, flightTime: flightTime)
    }

    public func hoverOver(_ point: SIMD3<Float>, _ distance: Float = 5, flightTime: TimeInterval? = nil) {
        self.orbitEnabled = false
        var displacementRTP = cartesianToSpherical(xyz: point - self.pov.center)
        displacementRTP.x += distance
        let destination = sphericalToCartesian(rtp: displacementRTP)
        flyTo(location: destination, flightTime: flightTime)
    }

    // DEBUGGING
    private var unfinishedDragCount: Int = 0

    public func dragGestureBegan(at touchPoint: SIMD3<Float>) {
        if isFlying {
            // print("CenteredPOVController.dragGestureBegan: aborting because flight is in progress")
            return
        }

        if self.unfinishedDragCount > 0 {
            Messages.debug("CenteredPOVController.dragGestureBegan", "PROBLEM: unfinishedDragCount=\(unfinishedDragCount)")
        }
        self.unfinishedDragCount += 1
        self.dragInProgress = CenteredPOVTangentialMove(self.pov, touchPoint, settings)
    }

    public func dragGestureChanged(panDistance pan: Float, scrollDistance scroll: Float) {
        if let handler = self.dragInProgress {
            // NO GOOD:
            // let viewDelta = SIMD4<Float>(pan, scroll, 0, 1)
            // if let newPOV = handler.touchLocationChanged(delta: (viewMatrix.inverse * viewDelta).xyz) {

            // ORIG
            if let newPOV = handler.locationChanged(panDistance: pan, scrollDistance: scroll) {
                self.pov = newPOV
            }
        }
    }

    /// EMPIRICAL: Don't count on this. Sometimes it's not delivered
    public func dragGestureEnded() {
        // print("CenteredPOVController.dragGestureEnded")
        self.unfinishedDragCount -= 1
        self.dragInProgress = nil
    }

    // DEBUGGING
    private var unfinishedPinchCount: Int = 0

    public func pinchGestureBegan(at pinchCenter: SIMD3<Float>) {
        if isFlying {
            // print("CenteredPOVController.pinchGestureBegan: aborting because flight is in progress")
            return
        }
        if unfinishedPinchCount > 0 {
            Messages.debug("CenteredPOVController.pinchGestureBegan", "PROBLEM: unfinishedPinchCount=\(unfinishedPinchCount)")
        }
        self.unfinishedPinchCount += 1
        self.pinchInProgress = CenteredPOVRadialMove(self.pov, pinchCenter, settings)
    }

    public func pinchGestureChanged(scale: Float) {
        if let handler = self.pinchInProgress {
            if let newPOV = handler.scaleChanged(scale: scale) {
                self.pov = newPOV
            }
        }
    }

    /// EMPIRICAL: Don't count on this. Sometimes it's not delivered
    public func pinchGestureEnded() {
        // print("CenteredPOVController.pinchGestureEnded")
        self.unfinishedPinchCount -= 1
        pinchInProgress = nil
    }

    // DEBUGGING
    private var unfinishedRotationCount: Int = 0

    public func rotationGestureBegan(at rotationCenter: SIMD3<Float>) {
        if isFlying {
            // print("CenteredPOVController.rotationGestureBegan: aborting because flight is in progress")
            return
        }

        if unfinishedRotationCount > 0 {
            Messages.debug("CenteredPOVController.rotationGestureBegan", "PROBLEM: unfinishedRotationCount=\(unfinishedRotationCount)")
        }
        self.unfinishedRotationCount += 1
        self.rotationInProgress = CenteredPOVRoll(self.pov, rotationCenter, settings)
    }

    public func rotationGestureChanged(radians: Float) {
        if let handler = self.rotationInProgress {
            if let newPOV = handler.rotationChanged(radians: radians) {
                self.pov = newPOV
            }
        }
    }

    /// EMPIRICAL: Don't count on this. Sometimes it's not delivered
    public func rotationGestureEnded() {
        // print("CenteredPOVController.rotationGestureEnded")
        self.unfinishedRotationCount += 1
        self.rotationInProgress = nil
    }

    public func update(timestamp: Date) {
        self.pov = makeUpdatedPOV(timestamp)
        self._lastUpdateTimestamp = timestamp

        // print("CenteredPOVController.update: Exiting. new POV: \(currentPOV)")
    }

    private func makeUpdatedPOV(_ timestamp: Date) -> CenteredPOV {

        // ==================================================================
        // Q: orbital motion even if we're flying?
        // A: Naaah, unnecessary complication.
        //
        // Q: how about if we're handling a gesture?
        // A: Problem there is that we don't always get notified when a gesture
        //    ends. So we can't disallow update during a gesture.
        //
        // If orbit speed is > 0 then it looks like we're flying *east* over
        // the figure.
        // ==================================================================

        if flightInProgress == nil && !queuedFlights.isEmpty {
            let spec = queuedFlights.removeFirst()
            flightInProgress = CenteredPOVFlight(initialLocation: pov.location,
                                                 initialCenter: pov.center,
                                                 initialUp: pov.up,
                                                 finalLocation: spec.location,
                                                 finalCenter: spec.center,
                                                 finalUp: spec.up,
                                                 flightTime: spec.flightTime)
        }

        if let pov = flightInProgress?.update(timestamp) {
            return pov
        }
        else {
            flightInProgress = nil // cleanup
            var updatedPOV = pov
            if orbitEnabled, let t0 = _lastUpdateTimestamp {
                let transform = float4x4(translationBy: updatedPOV.center)
                * float4x4(rotationAround: updatedPOV.up, by: orbitSpeed * Float(timestamp.timeIntervalSince(t0)))
                * float4x4(translationBy: -updatedPOV.center)
                let newLocation = (transform * SIMD4<Float>(updatedPOV.location, 1)).xyz

                updatedPOV = CenteredPOV(location: newLocation,
                                         center: pov.center,
                                         up: pov.up)
            }
            return updatedPOV
        }
    }
}

/// POV whose forward vector always points toward a fixed point in world coordinates.
public struct CenteredPOV: Codable, Sendable, Hashable, Equatable, CustomStringConvertible   {

    public var description: String {
        "{ location: \(location.prettyString), center: \(center.prettyString), up: \(trueUp.prettyString) }"
    }

    public var radius: Float {
        simd_distance(location, center)
    }

    public var forward: SIMD3<Float> {
        normalize(center - location)
    }

    public var up: SIMD3<Float> {
        get { trueUp }
        set { trueUp = normalize(newValue - dot(forward, newValue) * forward) }
    }

    public var location: SIMD3<Float>

    public var center: SIMD3<Float>

    private var trueUp: SIMD3<Float>

    /// location is any point
    /// center can be any point not equal to location
    /// up can be any nonzero vector not parallel to the displacement between center and location
    public init(location: SIMD3<Float> = SIMD3<Float>(0, 0, -1),
                center: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
                up: SIMD3<Float> = SIMD3<Float>(0,1,0)) {
        self.location = location
        self.center = center
        let delta = center - location
        self.trueUp =  normalize(up - (simd_dot(delta, up) / simd_dot(delta, delta)) * delta)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(location: try container.decode(SIMD3<Float>.self, forKey: .location),
                  center: try container.decode(SIMD3<Float>.self, forKey: .center),
                  up: try container.decode(SIMD3<Float>.self, forKey: .up))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(center, forKey: .center)
        try container.encode(trueUp, forKey: .up)
    }

    private enum CodingKeys: String, CodingKey {
        case location
        case center
        case up
    }
}

// ===========================================================
// MARK: - CenteredPOVController Actions
// ===========================================================

class CenteredPOVFlight {

    struct Spec {
        var location: SIMD3<Float>
        var center: SIMD3<Float>
        var up: SIMD3<Float>
        var flightTime: TimeInterval
    }

    enum Phase: Double {
        case new
        case accelerating
        case coasting
        case decelerating
        case arrived
    }


    /// Chosen because default frame rate is 60/sec
    static let minFlightTime: TimeInterval = 1/60

    /// fraction of time during which we are coasting
    static let coastingFraction: Double = 0.33

    /// Normalized units
    static let minSpeed: Double = 1/60

    //    let initialPOV: CenteredPOV
    //    let finalPOV: CenteredPOV

    let initialLocation: SIMD3<Float>

    let initialCenter: SIMD3<Float>

    let initialUp: SIMD3<Float>

    let finalLocation: SIMD3<Float>

    let finalCenter: SIMD3<Float>

    let finalUp: SIMD3<Float>

    private var isJump: Bool = true

    /// rate at which we accelerate or decelarate
    /// Normalized units
    private var acceleration: Double = 0

    /// fractional distance at which we stop accelerating
    /// Normalized units
    private var accelerationEnd: Double = 0

    /// fractional distance at which we start decelerating
    /// Normalized units
    private var decelerationStart: Double = 1

    private var phase: Phase = .new

    private(set) var lastUpdateTime: Date = .distantPast

    /// Normalized units
    private(set) var speed: Double = 0

    /// fractional distance, i.e., fraction of the total distance that has been covered so far
    /// Normalized units
    private(set) var distance: Double = 0


    public init(initialLocation: SIMD3<Float>,
                initialCenter: SIMD3<Float>,
                initialUp: SIMD3<Float>,
                finalLocation: SIMD3<Float>,
                finalCenter: SIMD3<Float>,
                finalUp: SIMD3<Float>,
                flightTime: TimeInterval) {
        self.initialLocation = initialLocation
        self.initialCenter = initialCenter
        self.initialUp = initialUp
        self.finalLocation = finalLocation
        self.finalCenter = finalCenter
        self.finalUp = finalUp
        fixDerivedVars(flightTime)
    }

    public init(from initialPOV: CenteredPOV,
                to finalPOV: CenteredPOV,
                flightTime: TimeInterval)
    {
        self.initialLocation = initialPOV.location
        self.initialCenter = initialPOV.center
        self.initialUp = initialPOV.up
        self.finalLocation = finalPOV.location
        self.finalCenter = finalPOV.center
        self.finalUp = finalPOV.up
        fixDerivedVars(flightTime)
    }

    private func fixDerivedVars(_ flightTime: TimeInterval) {
        if flightTime > Self.minFlightTime {
            // ======================================================
            // tA: time spent accelerating
            // tC: time spent coasting
            // tD: time spent decenerating
            // dA: fractional distance traveled while accelerating
            // dC: fractional distance traveled while coasting
            // dD: fractional distance traveled while decelerating
            // a:  acceleration rate
            // v1: maximum velocity
            //
            // tA + tC + tD = flightTime
            // dA + dC + dD = 1
            //
            // tC = coastingFraction * flightTime
            // tA = tD = (flightTime - tC)/2
            //
            // v1 = a * tA
            //
            // dA = a * (tA * tA / 2)
            // dC = v1 * tC = a * (tA * tC)
            // dD = v1 * tD - (a * tD * tD / 2) = a * (tA * tD - tD * tD / 2)
            //
            // 1 = dA + dC + dD
            //
            // 1 = a * [ (tA * tA / 2) + (tA * tC) + (tA * tD) - (tD * tD / 2) ]
            //
            // a = 1 / [ (tA * tA / 2) + (tA * tC) + (tA * tD) - (tD * tD / 2) ]
            // ======================================================

            let tC: TimeInterval = Self.coastingFraction * flightTime
            let tA: TimeInterval = (flightTime - tC) / 2
            let tD: TimeInterval = flightTime - tA - tC // do it this way b/c of roundoff error.
            let invA: Double = (tA * tA / 2.0) + (tA * tC) + (tA * tD) - (tD * tD / 2.0)

            let a = 1.0 / invA
            let dA = a * tA * tA / 2
            let dC = a * tA * tC

            self.isJump = false
            self.acceleration = a
            self.accelerationEnd = dA
            self.decelerationStart = dA + dC
        }
    }

    /// returns nil when the flight finished
    func update(_ timestamp: Date) -> CenteredPOV? {

        // debug("POVFlightAction.update", "phase = \(phase)")

        let dt = timestamp.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = timestamp

        switch phase {
        case .new:
            beginFlight()
            return newPOV()
        case .accelerating:
            continueAcceleration(dt)
            return newPOV()
        case .coasting:
            continueCoasting(dt)
            return newPOV()
        case .decelerating:
            continueDeceleration(dt)
            return newPOV()
        case .arrived:
            return nil
        }
    }

    private func beginFlight() {
        if isJump {
            distance = 1
            phase = .arrived
        }
        else {
            distance = 0
            speed = 0
            phase = .accelerating
        }
    }

    private func continueAcceleration(_ dt: Double) {
        distance += speed * dt
        if distance >= accelerationEnd {
            phase = .coasting
        }
        else {
            speed += acceleration * dt
        }
    }

    private func continueCoasting(_ dt: Double) {
        distance += speed * dt
        if distance >= decelerationStart {
            phase = .decelerating
        }
    }

    private func continueDeceleration(_ dt: Double) {
        distance += speed * dt
        if distance >= 1  {
            distance = 1
            phase = .arrived
        }
        else {
            speed -= acceleration * dt
            if speed < Self.minSpeed {
                speed = Self.minSpeed
            }
        }
    }

    private func newPOV() -> CenteredPOV {
        let newLocation = (Float(distance) * (finalLocation - initialLocation)) + initialLocation
        let newCenter   = (Float(distance) * (finalCenter - initialCenter)) + initialCenter
        let newUp       = (Float(distance) * (finalUp - initialUp)) + initialUp
        return CenteredPOV(location: newLocation, center: newCenter, up: newUp)
    }
}

///
/// PAN is a rotation of the POV's location about an axis that is
/// parallel to the POV's up axis and that passes through the POV's
/// center point
///
/// SCROLL is a rotation of the location and up vectors.
/// --location rotates about an axis that is perpendicular to both
///   forward and up axes and that passes through the center point
/// --up vector rotates about the same axis
///
struct CenteredPOVTangentialMove {

    let initialPOV: CenteredPOV

    let initialTouch: SIMD3<Float>

    let touchToCenterDistance: Float

    let initialTheta: Float

    let initialPhi: Float

    /// unit vector perpendicular to initial POV's forward and up vectors
    let scrollRotationAxis: SIMD3<Float>

    let panRotationAxis: SIMD3<Float>

    let scrollFactor: Float

    let panFactor: Float

    init(_ initialPOV: CenteredPOV, _ touchPoint: SIMD3<Float>, _ settings: POVControllerSettings) {

        self.initialPOV = initialPOV
        self.initialTouch = touchPoint
        self.scrollRotationAxis = normalize(simd_cross(initialPOV.forward, initialPOV.up))
        self.panRotationAxis = initialPOV.up

        let d = simd_dot((touchPoint - initialPOV.center), -initialPOV.forward)
        self.touchToCenterDistance = (d == 0) ? 1 : d

        let initialDisplacementRTP = cartesianToSpherical(xyz: touchPoint - initialPOV.center)
        self.initialTheta = initialDisplacementRTP.y
        self.initialPhi = initialDisplacementRTP.z
        // print("initialTheta: \(initialTheta), initialPhi: \(initialPhi)")

        self.scrollFactor = settings.scrollSensitivity
        self.panFactor = settings.panSensitivity
    }

    // ALT.
    // Didn't work when I tried it.
    // But I tried it before touchPoint calculation was fixed.
    //    func touchLocationChanged(delta: SIMD3<Float>) -> CenteredPOV? {
    //
    //
    //        let newTouch = initialTouch + delta
    //        let newDisplacementRTP = cartesianToSpherical(xyz: (newTouch - initialPOV.center))
    //        let dTheta = newDisplacementRTP.y - initialTheta
    //        let dPhi = newDisplacementRTP.z - initialPhi
    //
    //        // print("dTheta: \(dTheta), dPhi: \(dPhi)")
    //
    //        let newLocation = (
    //            float4x4(translationBy: initialPOV.center)
    //            * float4x4(rotationAround: panRotationAxis, by: dPhi)
    //            * float4x4(rotationAround: scrollRotationAxis, by: dTheta)
    //            * float4x4(translationBy: -initialPOV.center)
    //            * SIMD4<Float>(initialPOV.location, 1)
    //        ).xyz
    //
    //        let newUp = (
    //            float4x4(rotationAround: scrollRotationAxis, by: dTheta)
    //            * SIMD4<Float>(initialPOV.up, 1)
    //        ).xyz
    //
    //        return CenteredPOV(location: newLocation,
    //                           center: initialPOV.center,
    //                           up: newUp)
    //
    //    }

    func locationChanged(panDistance: Float, scrollDistance: Float) -> CenteredPOV? {

        let dTheta = scrollFactor * atan(scrollDistance/touchToCenterDistance)
        let dPhi = -panFactor * atan(panDistance/touchToCenterDistance)
        // print("dTheta: \(dTheta), dPhi: \(dPhi)")

        let newLocation = (
            float4x4(translationBy: initialPOV.center)
            * float4x4(rotationAround: panRotationAxis, by: dPhi)
            * float4x4(rotationAround: scrollRotationAxis, by: dTheta)
            * float4x4(translationBy: -initialPOV.center)
            * SIMD4<Float>(initialPOV.location, 1)
        ).xyz

        let newUp = (
            float4x4(rotationAround: scrollRotationAxis, by: dTheta)
            * SIMD4<Float>(initialPOV.up, 1)
        ).xyz

        return CenteredPOV(location: newLocation,
                           center: initialPOV.center,
                           up: newUp)
    }
}

///
/// This is a translation of POV's location toward or away from a given center that it's pointed toward
///
struct CenteredPOVRadialMove {

    let minRadius: Float = 0.001

    let maxRadiusChangeFactor: Float = 1000

    let initialPOV: CenteredPOV

    let pinchRadius: Float

    /// displacement from POV center to POV location, in spherical world coordinates
    let initialRTP: SIMD3<Float>

    init(_ initialPOV: CenteredPOV, _ pinchCenter: SIMD3<Float>, _ settings: POVControllerSettings) {
        self.initialPOV = initialPOV
        self.pinchRadius = cartesianToSpherical(xyz: (pinchCenter-initialPOV.center)).x
        self.initialRTP = cartesianToSpherical(xyz: (initialPOV.location-initialPOV.center))
        // print("pinchRadius: \(pinchRadius), initialRadius: \(initialRTP.x)")
    }

    func scaleChanged(scale: Float) -> CenteredPOV? {
        let tmpRadius = (((initialRTP.x - pinchRadius) / scale) + pinchRadius).clamp(lowerBound: minRadius)
        let newRadius = (tmpRadius < maxRadiusChangeFactor * initialRTP.x) ? tmpRadius : initialRTP.x
        let newLocation = initialPOV.center + sphericalToCartesian(rtp: SIMD3<Float>(newRadius,
                                                                                     initialRTP.y,
                                                                                     initialRTP.z))
        // print("    scale: \(scale), newRadius: \(newRadius)")
        return CenteredPOV(location: newLocation,
                           center: initialPOV.center,
                           up: initialPOV.up)
    }
}


struct CenteredPOVRoll {

    let initialPOV: CenteredPOV
    let rotationCenter: SIMD3<Float>
    let rotationSensitivity: Float

    init(_ initialPOV: CenteredPOV, _ rotationCenter: SIMD3<Float>, _ settings: POVControllerSettings) {
        self.initialPOV = initialPOV
        self.rotationCenter = rotationCenter
        self.rotationSensitivity = settings.rotationSensitivity
    }

    func rotationChanged(radians: Float) -> CenteredPOV? {

        // First try:
        // Rotate pov.location and .up around the rotation axis
        // - Gets it right if the center of rotation is the center of the screen
        // - If center of rotation is not center of the screen, it does something but not what I expected

        let rotationAxis = initialPOV.center - rotationCenter

        let transform = float4x4(rotationAround: rotationAxis, by: radians)

        // Second try:
        // 1. transform the view coords until rotationAxis vector intersects the glass at the center
        // of the screen.
        // - That's a rotation around some derived axis (not rotationAxis) by some
        //   amount (not radians). Maybe I can calculate the matrix in the initer.
        // - in view coords, initialPOV.location is in the spot where I want to transform the rotationAxis vector to.
        //   therfore the displacement vector between rotationCenter and pov.location is the key.
        //
        // 2. rotate view coords by radians
        //
        // 3. do reverse of step 1
        // I can calculate the matrix in the initer.
        //
        // To do step 1:
        // v1 = displacement vector from pov location to pov center
        // v2 = displacement vector from touch location to pov center
        // a = axis of rotation = cross product of v1 and v2
        // theta = angle to rotate. Found by solving for theta in dot(v1, v2) = |v1| * |v2| * cos(theta
        //
        // - Not much different from the first try!
        //
        //        let v1 = initialPOV.center - initialPOV.location
        //        let m1 = simd_length(v1)
        //        let v2 = initialPOV.center - rotationCenter
        //        let m2 = simd_length(v2)
        //        let rotationAxis = simd_cross(v1, v2)
        //        let cosTheta = simd_dot(v1, v2) / (m1 * m2)
        //        let theta = acos(cosTheta)
        //        let zAxis = SIMD3<Float>(0, 0, -1)
        //        let transform = float4x4(rotationAround: rotationAxis, by: theta)
        //        * float4x4(rotationAround: zAxis, by: radians)
        //        * float4x4(rotationAround: rotationAxis, by: -theta)

        return CenteredPOV(location: (transform * SIMD4<Float>(initialPOV.location, 1)).xyz,
                           center: initialPOV.center,
                           up: (transform * SIMD4<Float>(initialPOV.up, 1)).xyz)
    }
}
