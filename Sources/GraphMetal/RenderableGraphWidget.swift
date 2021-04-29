//
//  RenderableGraphWidget.swift
//  
//
//  Created by Jim Hanson on 4/28/21.
//

import MetalKit

protocol RenderableGraphWidget {
    associatedtype NodeValueType: RenderableNodeValue
    associatedtype EdgeValueType: RenderableEdgeValue

    // TODO remove throws
    func setup(_ view: MTKView) throws

    func teardown()

    /// update this widget's state using data found in the controller
    func update<C: RenderableGraphController>(_ controller: C) where
        C.GraphType.NodeType.ValueType == NodeValueType,
        C.GraphType.EdgeType.ValueType == EdgeValueType

    // TODO rename to 'encode'
    // TODO remove uniforms
    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int)
}
