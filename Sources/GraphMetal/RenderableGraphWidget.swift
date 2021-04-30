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

    /// prepare to update this widget's state by reading data found in the holder
    func prepareUpdate<H: RenderableGraphHolder>(_ graphHolder: H) where
        H.GraphType.NodeType.ValueType == NodeValueType,
        H.GraphType.EdgeType.ValueType == EdgeValueType

    func applyUpdate()

    // TODO rename to 'encode'
    // TODO remove uniforms
    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int)
}
