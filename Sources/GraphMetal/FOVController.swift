//
//  FOV.swift
//  GraphMetal
//
//  Created by Jim Hanson on 1/8/22.
//

import SwiftUI
import simd

public protocol FOVController {

    //    /// The physical dimensions of the UI view in pixels.
    //    /// This is NOT the same as the view's size in its local coordinates (which are measured in "points")..
    //    var drawableSize: CGSize { get set }
    //
    //    /// The bounds of the UI view in points.
    //    var viewBounds: CGRect { get set }

    var aspectRatio: Float { get }

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
    func update(timestamp: Date)

    /// Set the FOV's properties to be consistent with the given view bounds (in points).
    func update(viewBounds: CGRect)

}

//extension FOVController {
//
//    public var aspectRatio: Float {
//        // OLD (drawableSize.height > 0) ? Float(drawableSize.width) / Float(drawableSize.height) : 1
//        viewBounds.height > 0 ? Float(viewBounds.width) / Float(viewBounds.height) : 1
//    }
//}

public class PerspectiveFOVController: ObservableObject, FOVController {

    public static let defaultZNear: Float = 0.001

    public static let defaultZFar: Float = 1000

    public static let defaultYFOV: Float  = .piOverThree

    @Published public var aspectRatio: Float {
        didSet {
            self.projectionMatrix = makeProjectionMatrix()
        }
    }

    @Published public var zNear: Float  {
        didSet {
            self.projectionMatrix = makeProjectionMatrix()
        }
    }

    @Published public var zFar: Float  {
        didSet {
            self.projectionMatrix = makeProjectionMatrix()
        }
    }

    /// angular width in radians
    @Published public var yFOV: Float  {
        didSet {
            self.projectionMatrix = makeProjectionMatrix()
        }
    }

    private let initialZNear: Float
    private let initialZFar: Float
    private let initialYFOV: Float

    public private(set) var projectionMatrix: float4x4

    public init(zNear: Float = PerspectiveFOVController.defaultZNear,
                zFar: Float = PerspectiveFOVController.defaultZFar,
                yFOV: Float = PerspectiveFOVController.defaultYFOV) {
        self.initialZNear = zNear
        self.initialZFar = zFar
        self.initialYFOV = yFOV
        self.zNear = zNear
        self.zFar = zFar
        self.yFOV = yFOV
        self.aspectRatio = 1 // Dummy value
        self.projectionMatrix = float4x4() // Dummy value
    }

    public func reset() {
        self.zNear = initialZNear
        self.zFar = initialZFar
        self.yFOV = initialYFOV
        self.projectionMatrix = makeProjectionMatrix()
    }

    public func fovSize(_ zDistance: Float) -> CGSize {
        let width = zDistance * tan(yFOV/2)
        return CGSize(width: Double(width), height: Double(width / aspectRatio))
    }

    public func update(timestamp: Date) {
        // NOP
    }

    public func update(viewBounds: CGRect) {
        self.aspectRatio = viewBounds.height > 0 ? Float(viewBounds.width) / Float(viewBounds.height) : 1
    }

    private func makeProjectionMatrix() -> float4x4 {
        return float4x4(perspectiveProjectionRHFovY: yFOV,
                        aspectRatio: aspectRatio,
                        nearZ: zNear,
                        farZ: zFar)
    }
}
