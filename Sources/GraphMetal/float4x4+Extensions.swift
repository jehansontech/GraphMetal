//
//  float4x4+Extensions.swift
//  ArcWorld Shared
//
//  Created by James Hanson on 9/11/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import simd

extension float4x4 {

    init(rotationAround axis: SIMD3<Float>, by angle: Float) {

        // from MetalPicking

        let unitAxis = normalize(axis)
        let ct = cosf(angle)
        let st = sinf(angle)
        let ci = 1 - ct
        let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
        self.init(columns:(SIMD4<Float>(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                           SIMD4<Float>(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                           SIMD4<Float>(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                           SIMD4<Float>(                  0,                   0,                   0, 1)))
    }

    init(translationBy v: SIMD3<Float>) {

        // from MetalPicking

        self.init(columns:(SIMD4<Float>(  1,   0,   0,   0),
                           SIMD4<Float>(  0,   1,   0,   0),
                           SIMD4<Float>(  0,   0,   1,   0),
                           SIMD4<Float>(v.x, v.y, v.z,   1)))
    }

    init(perspectiveProjectionRHFovY fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) {

        // from MetalPicking

        let ys = 1 / tanf(fovy * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        self.init(columns:(SIMD4<Float>(xs,  0,  0,          0),
                           SIMD4<Float>( 0, ys,  0,          0),
                           SIMD4<Float>( 0,  0, zs,         -1),
                           SIMD4<Float>( 0,  0, zs * nearZ,  0)))
    }

    init(lookAt center: SIMD3<Float>, eye: SIMD3<Float>, up: SIMD3<Float>) {

        // https://stackoverflow.com/questions/9053377/ios-questions-about-camera-information-within-glkmatrix4makelookat-result
        // https://gist.github.com/CaptainRedmuff/5673450
        //
        // GLKVector3 ev = { eyeX, eyeY, eyeZ };
        // GLKVector3 cv = { centerX, centerY, centerZ };
        // GLKVector3 uv = { upX, upY, upZ };
        //
        // GLKVector3 n = GLKVector3Normalize(GLKVector3Add(ev, GLKVector3Negate(cv)));
        // GLKVector3 u = GLKVector3Normalize(GLKVector3CrossProduct(uv, n));
        // GLKVector3 v = GLKVector3CrossProduct(n, u);
        //
        // GLKMatrix4 m = { u.v[0], v.v[0], n.v[0], 0.0f,
        //                  u.v[1], v.v[1], n.v[1], 0.0f,
        //                  u.v[2], v.v[2], n.v[2], 0.0f,
        //                  GLKVector3DotProduct(GLKVector3Negate(u), ev),
        //                  GLKVector3DotProduct(GLKVector3Negate(v), ev),
        //                  GLKVector3DotProduct(GLKVector3Negate(n), ev),
        //                  1.0f };

        let n = normalize(eye - center)
        let u = normalize(simd_cross(up, n))
        let v = simd_cross(n, u)

        // If GLKMatrix4 constructor takes its args as a list of column vectors:
        self.init(columns: (SIMD4<Float>(              u.x,               v.x,               n.x,  0),
                            SIMD4<Float>(              u.y,               v.y,               n.y,  0),
                            SIMD4<Float>(              u.z,               v.z,               n.z,  0),
                            SIMD4<Float>(simd_dot(-u, eye), simd_dot(-v, eye), simd_dot(-n, eye),  1)))

        // If GLKMatrix4 constructor takes its args in a list of row vectors:
        //        self.init(columns: (SIMD4<Float>(u.x, u.y, u.z, simd_dot(-u, eye)),
        //                            SIMD4<Float>(v.x, v.y, v.z, simd_dot(-v, eye)),
        //                            SIMD4<Float>(n.x, n.y, n.z, simd_dot(-n, eye)),
        //                            SIMD4<Float>(0,   0,   0,   1)))

    }
}

