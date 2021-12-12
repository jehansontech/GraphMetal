//
//  Color+Extensions.swift
//  GraphMetal
//
//  Created by Jim Hanson on 12/12/21.
//

import Foundation
import SwiftUI

fileprivate let rgbColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)

extension Color {
    
    public var renderColor: SIMD4<Float> {

        guard
            let colorSpace = rgbColorSpace
        else {
            print("COLOR PROBLEM: colorSpace = nil")
            return .zero
        }

        guard
            let myCGColor = self.cgColor
        else {
            print("COLOR PROBLEM: myCGColor = nil. self=\(self)")
            return .zero
        }

        guard
            let cgColor = (myCGColor.colorSpace?.name == colorSpace.name) ? myCGColor : myCGColor.converted(to: colorSpace, intent: .defaultIntent, options: nil)
        else {
            print("COLOR PROBLEM: cgColor = nil")
            return .zero
        }

        guard
            let components = cgColor.components
        else {
            print("COLOR PROBLEM: no components")
            return .zero
        }

        if components.count != 4 {
            print("COLOR PROBLEM: components.count=\(components.count)")
            return .zero
        }

        return SIMD4<Float>(Float(components[0]),
                                Float(components[1]),
                                Float(components[2]),
                                Float(components[3]))
    }

    public init(renderColor: SIMD4<Float>) {
        self.init(red: Double(renderColor.x),
                  green: Double(renderColor.y),
                  blue: Double(renderColor.z),
                  opacity: Double(renderColor.w))
    }

}
