//
//  RenderingConstants.swift
//  ArcWorld
//
//  Created by James Hanson on 9/12/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import MetalKit

public struct RenderingConstants {
    
    public static let defaultNodeSize: Float = 25

    public static let defaultNodeColor = SIMD4<Float>(1, 1, 1, 0)

    public static let defaultEdgeColor = SIMD4<Float>(0.25, 0.25, 0.25, 1)

    public static let defaultBackgroundColor = SIMD4<Double>(0.01, 0.01, 0.01, 1)

    static let edgeIndexType = MTLIndexType.uint32

}
