//
//  File.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import Shaders

public struct GraphMetal {

    var text = "Hello, World!"

    var uniforms: Uniforms? = nil
    
    var shaders: Shaders

    init() {
        self.shaders = Shaders()
        print(shaders.packageMetalLibrary.functionNames)
    }
    
}
