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
    
    public static let defaultNodeSize: Float = 12

    public static let defaultNodeColor = SIMD4<Float>(0, 0, 0, 0)

    public static let edgeColor = SIMD4<Float>(80/255, 80/255, 80/255, 1)

    public static let rendererBackground = MTLClearColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1)

}
