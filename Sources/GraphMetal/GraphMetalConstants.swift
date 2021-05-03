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

    public static let defaultEdgeColor = SIMD4<Float>(80.0/255.0, 80.0/255.0, 80.0/255.0, 1)

    static let rendererClearColor = MTLClearColor(red: 10.0/255.0, green: 10.0/255.0, blue: 10.0/255.0, alpha: 1)

    static let edgeIndexType = MTLIndexType.uint32

}
