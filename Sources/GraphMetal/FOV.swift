//
//  FOV.swift
//  GraphMetal
//
//  Created by Jim Hanson on 1/8/22.
//

import SwiftUI
import simd

public protocol FOVController {

    /// The midpoint of the visible slice.
    /// Only points for which the forward distance in view coords from the plane of the POV is in the range fadeoutMidpoint +/- fadeoutDistance will be visible.
    var fadeoutMidpoint: Float { get set }

    /// The half-width of the visible slice
    /// Only points for which the forward distance in view coords from the plane of the POV is in the range fadeoutMidpoint +/- fadeoutDistance will be visible.
    /// Visibility decreases linearly with distance from the midpoint.
    var fadeoutDistance: Float { get set }

    //    /// The physical dimensions of the UI view in pixels.
    //    /// This is NOT the same as the view's size in its local coordinates (which are measured in "points")..
    //    var drawableSize: CGSize { get set }
    //
    //    /// The bounds of the UI view in points.
    //    var viewBounds: CGRect { get set }

    /// front of the FOV, i.e.,  forward distance in view coords from the plane of the POV to the nearest renderable point
    var zNear: Float { get set }

    /// back of the FOV, i.e., forward distance in view coords from the plane of the POV to the farthest renderable point
    var zFar: Float { get set }

    var projectionMatrix: float4x4 { get }

    func reset()

    /// size of the field of view at the given distance from the POV, in world coordinates,
    func fovSize(_ zDistance: Float) -> CGSize

    /// Sets the FOV's properties to the values they should have at the given system time.
    /// This is called during each rendering cycle as a way to support an FOV that changes on its own
    func update(_ date: Date)

    /// Set the FOV's properties to be consistent with the given view bounds (in points).
    func update(_ viewBounds: CGRect)

}

extension FOVController {

    //    var aspectRatio: Float {
    //        // OLD (drawableSize.height > 0) ? Float(drawableSize.width) / Float(drawableSize.height) : 1
    //        viewBounds.height > 0 ? Float(viewBounds.width) / Float(viewBounds.height) : 1
    //    }

    public var visibleZ: ClosedRange<Float> {
        return max(zNear, fadeoutMidpoint-fadeoutDistance)...min(zFar, fadeoutMidpoint+fadeoutDistance)
    }

    public func isInVisibleSlice(z: Float) -> Bool {
        return z >= zNear && z <= zFar && z > fadeoutMidpoint - fadeoutDistance && z < fadeoutMidpoint + fadeoutDistance
    }
}

public class PerspectiveFOVController: ObservableObject, FOVController {

    public static let defaultZNear: Float = 0.001

    public static let defaultZFar: Float = 1000

    public static var defaultFadeoutDistance: Float {
        return defaultZFar - defaultZNear
    }

    public static var defaultFadeoutMidpoint: Float {
        return defaultZNear
    }

    public static var defaultYFOV: Float {
        return .piOverThree
    }

    @Published public var fadeoutMidpoint: Float

    @Published public var fadeoutDistance: Float

    //    public var drawableSize = CGSize(width: 1, height: 1) // dummy values > 0 for safety
    //
    //    public var viewBounds = CGRect(x: 0, y: 0, width: 1, height: 1) // dummy values > 0 for safety

    public var aspectRatio: Float

    public var zNear: Float

    public var zFar: Float

    /// angular width in radians
    public var yFOV: Float

    public let initialYFOV: Float

    public var projectionMatrix: float4x4 {
        return float4x4(perspectiveProjectionRHFovY: yFOV,
                        aspectRatio: aspectRatio,
                        nearZ: zNear,
                        farZ: zFar)
    }

    public init(fadeoutMidpoint: Float = PerspectiveFOVController.defaultFadeoutMidpoint,
                fadeoutDistance: Float = PerspectiveFOVController.defaultFadeoutDistance,
                zNear: Float = PerspectiveFOVController.defaultZNear,
                zFar: Float = PerspectiveFOVController.defaultZFar,
                yFOV: Float = PerspectiveFOVController.defaultYFOV) {
        self.fadeoutMidpoint = fadeoutMidpoint
        self.fadeoutDistance = fadeoutDistance
        self.aspectRatio = 1 // Dummy value
        self.zNear = zNear
        self.zFar = zFar
        self.yFOV = yFOV
        self.initialYFOV = yFOV
    }

    public func reset() {
        // FIXME: decide what to do about these
        //        self.fadeoutMidpoint = 0
        //        self.fadeoutDistance = 1000
        //        self.zNear = 0.001
        //        self.zFar = 1000
        self.yFOV = initialYFOV
    }

    public func fovSize(_ zDistance: Float) -> CGSize {
        let width = zDistance * tan(yFOV/2)
        return CGSize(width: Double(width), height: Double(width / aspectRatio))
    }

    public func update(_ date: Date) {
        // NOP
    }

    public func update(_ viewBounds: CGRect) {
        self.aspectRatio = viewBounds.height > 0 ? Float(viewBounds.width) / Float(viewBounds.height) : 1
    }

}
