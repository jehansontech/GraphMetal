//
//  FigureSettings.swift
//  
//
//  Created by Jim Hanson on 12/10/21.
//

import SwiftUI


// =======================================================
// This protocol is TEMPORARY
// TODO: Delete when RendererSettings refactor is complete
// =======================================================
public protocol POVControllerProperties {

    /// If true, POV's loation orbits its center point around an axis parallel to its up vector
    var orbitEnabled: Bool { get set }

    /// In radians per second
    var orbitSpeed: Float { get set }
}

public protocol GraphRendererProperties {

    /// Angular width, in radians, of the POV's field of view
    var yFOV: Float { get set }

    /// Distance in world coordinates from the plane of the POV to the nearest renderable point
    var zNear: Float { get set }

    /// Distance in world coordinates from the plane of the POV to the farthest renderable point
    var zFar: Float { get set }

    /// Distance in world coordinates from from the plane of the POV  to the the point where the figure starts fading out.
    /// Nodes at distances less than `fadeoutOnset` are opaque.
    var fadeoutOnset: Float { get set }

    /// Distance in world coordinates over which the figure fades out.
    /// Nodes at distances greater than`fadeoutOnset + fadeoutDistance` are transparent.
    var fadeoutDistance: Float { get set }

    var backgroundColor: SIMD4<Double> { get set }
}

public class GraphRendererSettings: ObservableObject, GraphRendererProperties {

    @Published public var yFOV: Float

    @Published public var zNear: Float

    @Published public var zFar: Float

    @Published public var fadeoutOnset: Float

    @Published public var fadeoutDistance: Float

    @Published public var backgroundColor: SIMD4<Double>

    public init(yFOV: Float = .piOverFour,
                zNear: Float = 0.01,
                zFar: Float = 1000,
                fadeoutOnset: Float = 0,
                fadeoutDistance: Float = 1000,
                backgroundColor: SIMD4<Double> = SIMD4<Double>(0.02, 0.02, 0.02, 1)) {
        self.yFOV = yFOV
        self.zNear = zNear
        self.zFar = zFar
        self.fadeoutOnset = fadeoutOnset
        self.fadeoutDistance = fadeoutDistance
        self.backgroundColor = backgroundColor
    }
}
