//
//  POV.swift
//  ArcWorld
//
//  Created by Jim Hanson on 10/18/20.
//  Copyright © 2020 J.E. Hanson Technologies LLC. All rights reserved.
//

import Foundation
import simd

///
///
///
public struct POV: Codable, CustomStringConvertible {
    
    public static let defaultLocation = SIMD3<Float>(0, 0, 1)
    public static let defaultCenter    = SIMD3<Float>(0, 0, 0)
    public static let defaultUp       = SIMD3<Float>(0, 1, 0)

    /// The POV's location in world coordinates.
    public var location: SIMD3<Float>

    /// The point in world coordinates that the POV is focused on
    public var center: SIMD3<Float>

    /// Unit vector giving direction the POV is looking
    public var forward: SIMD3<Float> {
        return normalize(center - location)
    }

    /// Unit vector giving the POV's orientation: i.e., the direction of "up".
    public var up: SIMD3<Float>

    public var description: String {
        return "loc=\(location) cntr=\(center) fwd=\(forward) up=\(up)"
    }
    
    public init(location: SIMD3<Float> = POV.defaultLocation,
         center: SIMD3<Float> = POV.defaultCenter,
         up: SIMD3<Float> = POV.defaultUp) {
        self.location = location
        self.center = center
        self.up = normalize(up)
    }

    public init(from decoder: Decoder) throws {
        // print("POV init(from decoder)")
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            self.location = try values.decode(SIMD3<Float>.self, forKey: .location)
        }
        catch {
            self.location = POV.defaultLocation
        }
        
        do {
            self.center = try values.decode(SIMD3<Float>.self, forKey: .center)
        }
        catch {
            self.center = POV.defaultCenter
        }
        
        do {
            let decodedUp = try values.decode(SIMD3<Float>.self, forKey: .up)
            self.up = normalize(decodedUp)
        }
        catch {
            self.up = normalize(POV.defaultUp)
        }
    }

    func turnToward(center newCenter: SIMD3<Float>) -> POV {
        let oldForward = self.forward
        let newForward = normalize(center - location)
        let newUp = Geometry.rotateAlign(newForward, oldForward) * up
        return POV(location: location,
                   center: newCenter,
                   up: newUp)
    }


    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(center, forKey: .center)
        try container.encode(up, forKey: .up)
    }
    
    enum CodingKeys: String, CodingKey {
        case location = "location"
        case center = "center"
        case up = "up"
    }
}

