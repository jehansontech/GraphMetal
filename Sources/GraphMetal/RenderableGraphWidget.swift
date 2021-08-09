//
//  RenderableGraphWidget.swift
//  
//
//  Created by Jim Hanson on 4/28/21.
//

import MetalKit
import GenericGraph

protocol RenderableGraphWidget {

    associatedtype NodeValueType: RenderableNodeValue
    
    associatedtype EdgeValueType: RenderableEdgeValue

    // TODO remove throws
    func setup(_ view: MTKView) throws

    func teardown()

    func graphHasChanged<G: Graph>(_ graph: G, _ change: GraphChange) where
        G.NodeType.ValueType == NodeValueType,
        G.EdgeType.ValueType == EdgeValueType
    
//    /// prepare to update this widget's state by reading data found in the holder
//    func prepareUpdate<H: RenderableGraphHolder>(_ graphHolder: H) where
//        H.GraphType.NodeType.ValueType == NodeValueType,
//        H.GraphType.EdgeType.ValueType == EdgeValueType


    // TODO rename to 'encode'
    // TODO remove uniforms; move it into the impl's
    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int)
}
