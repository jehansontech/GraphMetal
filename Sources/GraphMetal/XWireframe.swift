//
//  XWireframe.swift
//  GraphMetal
//
//  Created by Jim Hanson on 7/30/24.
//

import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public struct XWireframe: Renderable {


    public init() {

    }
    
    /// Called before the first rendering cycle.
    public mutating func setup(_ mtkView: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws {

    }

    /// Called at the beginning of every rendering cycle.
    public mutating func prepareToDraw() {

    }

    /// Called on every rendering cycle. Should execute as quickly as possible.
    public mutating func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {

    }

    /// Called when the renderer is destroyed
    public mutating func teardown() {

    }

}
