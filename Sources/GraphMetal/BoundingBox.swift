//
//  BoundingBox.swift
//  ArcWorld iOS
//
//  Created by James Hanson on 9/29/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation

struct BoundingBox {

    var xMin: Float
    var yMin: Float
    var zMin: Float

    var xMax: Float
    var yMax: Float
    var zMax: Float

    var min: SIMD3<Float> {
        return SIMD3<Float>(xMin, yMin, zMin)
    }
    
    var max: SIMD3<Float> {
        return SIMD3<Float>(xMax, yMax, zMax)
    }
    
    init(x0: Float, y0: Float, z0: Float, x1: Float, y1: Float, z1: Float) {
        xMin = Float.minimum(x0, x1)
        yMin = Float.minimum(y0, y1)
        zMin = Float.minimum(z0, z1)

        xMax = Float.maximum(x0, x1)
        yMax = Float.maximum(y0, y1)
        zMax = Float.maximum(z0, z1)
    }

    init(_ point: SIMD3<Float>) {
        xMin = point.x
        yMin = point.y
        zMin = point.z
        
        xMax = point.x
        yMax = point.y
        zMax = point.z
    }
    
    mutating func cover(_ point: SIMD3<Float>) {
        if point.x < xMin {
            xMin = point.x
        }
        if point.y < yMin {
            yMin = point.y
        }
        if point.z < zMin {
            zMin = point.z
        }
        
        if point.x > xMax {
            xMax = point.x
        }
        if point.y > yMax {
            yMax = point.y
        }
        if point.z > zMax {
            zMax = point.z
        }
    }
}
