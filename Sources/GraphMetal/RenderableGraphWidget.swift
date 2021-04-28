//
//  RenderableGraphWidget.swift
//  
//
//  Created by Jim Hanson on 4/28/21.
//

import MetalKit

protocol RenderableGraphWidget: RenderableGraphAccessor {

    // TODO remove throws
    func setup(_ view: MTKView) throws

    func teardown()

    // TODO rename to 'encode'
    // TODO remove uniforms
    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int)
}
