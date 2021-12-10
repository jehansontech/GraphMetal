//
//  FigureSettings.swift
//  
//
//  Created by Jim Hanson on 12/10/21.
//

public protocol POVControllerProperties {

    /// If true, POV's loation orbits its center point around an axis parallel to its up vector
    var orbitEnabled: Bool { get set }

    /// In radians per second
    var orbitSpeed: Float { get set }
}

public protocol GraphWireFrameProperties {

    /// Width in pixels of the node's dot
    var nodeSize: Double { get set }

    /// indicates whether node size should be automatically adjusted when the POV changes
    var nodeSizeAutomatic: Bool { get set }

    /// Minimum automatic node size. Ignored if nodeSizeAutomatic is false
    var nodeSizeMinimum: Double { get set }

    /// Maximum automatic node size. Ignored if nodeSizeAutomatic is false
    var nodeSizeMaximum: Double { get set }

    var nodeColorDefault: SIMD4<Double> { get set }

    var edgeColor: SIMD4<Double> { get set }
}

public protocol GraphRendererProperties {

    /// Angular width, in radians, of the POV's field of view
    var yFOV: Float { get set }

    /// Distance in world coordinates from the plane of the POV to the nearest renderable point
    var zNear: Float { get set }

    /// Distance in world coordinates from the plane of the POV to the farthest renderable point
    var zFar: Float { get set }

    /// Distance in world coordinates from from the plane of the POV  to the the point where the figure starts fading out
    var fadeoutOnset: Float { get set }

    var fadeoutDistance: Float { get set }

    var backgroundColor: SIMD4<Double> { get set }
}

