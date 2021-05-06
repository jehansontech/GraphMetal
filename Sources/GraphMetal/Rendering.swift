//
//  Rendering.swift
//  ArcWorld
//
//  Created by James Hanson on 9/12/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import MetalKit

public struct RenderingConstants {
    
    public static let defaultNodeSize: Float = 25

    public static let defaultNodeColor = SIMD4<Float>(0, 0, 0, 0)

    public static let defaultEdgeColor = SIMD4<Float>(0.2, 0.2, 0.2, 1)

    public static let defaultBackgroundColor = SIMD4<Double>(0.02, 0.02, 0.02, 1)

    static let edgeIndexType = MTLIndexType.uint32

    // EMPIRICAL
    static let nodeSizeMax: GLfloat = 32

    // EMPIRICAL
    static let nodeSizeScaleFactor: GLfloat = 800
}

public protocol RenderingParameters: AnyObject {

    /// Indicates whether the nodeSize and edgeColor should be automatically adjusted when the POV changes
    var autoAdjust: Bool { get set }

    var nodeSize: Float { get set }

    var edgeColor: SIMD4<Float> { get set }

    /// Setting this to true causes renderer to take a screenshot at the earliest opportunity
    var screenshotRequested: Bool { get set }
}
