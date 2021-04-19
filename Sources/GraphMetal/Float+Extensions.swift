//
//  Float+Extensions.swift
//  ArcWorld
//
//  Created by Jim Hanson on 10/13/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
 
extension Float {
    
    static let twoPi: Float = 2 * .pi
    
    static let piOverTwo: Float = 0.5 * .pi
    
    static let threePiOverTwo: Float = 1.5 * .pi

    static let piOverFour: Float = 0.25 * .pi

    static let epsilon: Float = 1e-6
    
    static let goldenRatio: Float = (0.5 * (1 + sqrt(5)))
    
    static let logTwo: Float = log(2)
    
    func clamp(_ min: Self, _ max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }

    func fuzz(_ fuzzFactor: Self) -> Self {
        let lo = (1 - fuzzFactor) * self
        let hi = (1 + fuzzFactor) * self
        return Float.random(in: lo...hi)
    }

    func differentFrom(_ x: Self) -> Bool {
        return abs(x - self) > .epsilon
    }
 }
