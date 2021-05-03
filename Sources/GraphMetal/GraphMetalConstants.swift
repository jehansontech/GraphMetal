//
//  GraphMetalConstants.swift
//  ArcWorld
//
//  Created by James Hanson on 9/12/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import MetalKit

public struct GraphMetalConstants {
    
    public static let defaultNodeSize: Float = 12

    public static let defaultNodeColor = SIMD4<Float>(0, 0, 0, 0)

    public static let defaultEdgeColor = SIMD4<Float>(0.5, 0.5, 0.5, 1)

    public static let defaultBackgroundColor = SIMD4<Double>(0.12, 0.12, 0.12, 1)

    static let edgeIndexType = MTLIndexType.uint32

}
