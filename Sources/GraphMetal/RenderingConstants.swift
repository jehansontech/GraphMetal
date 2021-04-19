//
//  RenderingConstants.swift
//  ArcWorld
//
//  Created by James Hanson on 9/12/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import MetalKit

struct RenderingConstants {
    
    static let defaultPointSize: Float = 12

    static let clearColor = SIMD4<Float>(0, 0, 0, 0)
    
    static let whiteColor = SIMD4<Float>(1, 1, 1, 1)
    
    static let defaultNodeColor = SIMD4<Float>(0, 0, 0, 0)
    
    static let edgeColor = SIMD4<Float>(20/255, 20/255, 20/255, 1)

}
