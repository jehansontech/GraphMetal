//
//  Color+Extensions.swift
//  GraphMetal
//
//  Created by Jim Hanson on 12/12/21.
//

import SwiftUI

extension Color {
    
    public var renderColor: SIMD4<Float> {
        if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
           let cgColor = self.cgColor?.converted(to: colorSpace, intent: .defaultIntent, options: nil),
           let components = cgColor.components,
           components.count >= 4 {
            return SIMD4<Float>(Float(components[0]),
                                Float(components[1]),
                                Float(components[2]),
                                Float(components[3]))
        }
        else {
            return .zero
        }
    }

    public init(renderColor: SIMD4<Float>) {
        self.init(red: Double(renderColor.x),
                  green: Double(renderColor.y),
                  blue: Double(renderColor.z),
                  opacity: Double(renderColor.w))
    }

}
