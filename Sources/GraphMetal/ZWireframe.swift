//
//  ZWireframe.swift
//  GraphMetal
//
//  Created by Jim Hanson on 8/6/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public protocol ZWireframe: ZRenderable {

    /// Nominal factor used in calculating rendered sizes of nodes
    var nodeSize: Float { get set }

    var defaultElementColor: SIMD4<Float> { get set }

    var bbox: BoundingBox? { get }
}

extension ZWireframe {

    public func makePointSize(_ povLocation: SIMD3<Float>) -> Float {
        if let bbox = self.bbox {
            let d = distance(povLocation, bbox.center)
            if d > 0 {
                let newSize = ZWireframeConstants.pointSizeScaleFactor  * self.nodeSize / d
                return newSize.clamp(ZWireframeConstants.pointSizeMinimum, ZWireframeConstants.pointSizeMaximum)
            }
        }

        // Fallback
        return self.nodeSize
    }

}

public struct ZWireframeConstants {

    public static let defaultNodeShape: ZWireframeNodeShape = .disc

    public static let defaultNodeSize: Float = 16

    public static let defaultElementColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1)

    public static let pointSizeMinimum: Float = 1

    /// EMPIRICAL
    public static let pointSizeMaximum: Float = 100

    /// EMPIRICAL
    static let pointSizeScaleFactor: Float = 400

}

public enum ZWireframeNodeShape {
    case disc
    case ring

    var fragmentFunctionName: String {
        switch self {
        case .disc:
            "node_fragment_disc"
        case .ring:
            "node_fragment_ring"
        }
    }
}


