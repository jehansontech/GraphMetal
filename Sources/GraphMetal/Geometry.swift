//
//  Geometry.swift
//  ArcWorld
//
//  Created by Jim Hanson on 4/6/21.
//

import Foundation
import simd

struct Geometry {

    static let zero = SIMD3<Float>(0, 0, 0)
    
    static func cartesianToSpherical(xyz: SIMD3<Float>) -> SIMD3<Float> {
        var r = sqrt( xyz.x * xyz.x + xyz.y * xyz.y + xyz.z * xyz.z)
        if (r < .epsilon) {
            r = .epsilon
        }
        let theta =  acos(xyz.z/r)
        var phi = atan2(xyz.y, xyz.x)
        if (phi < 0) {
            phi += .twoPi
        }
        return SIMD3<Float>(r, theta, phi)
    }
    
    static func sphericalToCartesian(rtp: SIMD3<Float>) -> SIMD3<Float> {
        let x = rtp.x * sin(rtp.y) * cos(rtp.z)
        let y = rtp.x * sin(rtp.y) * sin(rtp.z)
        let z = rtp.x * cos(rtp.y)
        return SIMD3<Float>(x, y, z)
    }

    ///
    /// Returns rotation matrix that will rotate v1 to be parallel to v2.
    /// v1 and v2 are unit vectors.
    /// Adapted from https://gist.github.com/kevinmoran/b45980723e53edeb8a5a43c49f134724 [2021-04-04]
    ///
    static func rotateAlign(_ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> float3x3 {

        let axis = cross(v1, v2)
        let cosA = dot(v1, v2)
        let k: Float = 1 / (1 + cosA)

        let a = (axis.x * axis.x * k) + cosA
        let b = (axis.y * axis.x * k) - axis.z
        let c = (axis.z * axis.x * k) + axis.y

        let d = (axis.x * axis.y * k) + axis.z
        let e = (axis.y * axis.y * k) + cosA
        let f = (axis.z * axis.y * k) - axis.x

        let g = (axis.x * axis.z * k) - axis.y
        let h = (axis.y * axis.z * k) + axis.x
        let i = (axis.z * axis.z * k) + cosA

        return float3x3(columns: (SIMD3<Float>(a,b,c),
                                  SIMD3<Float>(d,e,f),
                                  SIMD3<Float>(g,h,i)))
    }
}
