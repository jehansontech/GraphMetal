//
//  GraphWireFrame.swift
//  ArcWorld
//
//  Created by Jim Hanson on 4/8/21.
//


import SwiftUI
import Metal
import MetalKit
import GenericGraph
import Shaders

struct GraphWireFrameConstants {

    static let edgeColor = RenderingConstants.edgeColor

    static let edgeIndexType = MTLIndexType.uint32
}

//class GraphWireFrameTransfer<G: Graph>: GraphAccessor where G.NodeType.ValueType: RenderableNodeValue, G.EdgeType.ValueType: RenderableEdgeValue {
//    typealias GraphType = G
//
//    var widget: GraphWireFrame<G>
//
//    var nodeIndices: [NodeID: Int]?
//
//    var nodePositions: [SIMD3<Float>]?
//
//    var edgeIndexData: [UInt32]?
//
//    var nodeColors: [NodeID: SIMD4<Float>]?
//
//    var topologyUpdate: Int? = nil
//
//    var positionsUpdate: Int? = nil
//
//    var colorsUpdate: Int? = nil
//
//    init(_ widget: GraphWireFrame<G>) {
//        self.widget = widget
//    }
//
//    func accessGraph(_ holder: GraphHolder<G>) {
//
//        if topologyUpdate == nil || holder.hasTopologyChanged(since: topologyUpdate!) {
//            self.updateTopology(holder)
//        }
//        else {
//
//            if positionsUpdate == nil || holder.havePositionsChanged(since: positionsUpdate!) {
//                self.updateGeometry(holder)
//            }
//            // no 'else' here
//            if colorsUpdate == nil || holder.haveColorsChanged(since: colorsUpdate!) {
//                self.updateColors(holder)
//            }
//        }
//    }
//
//    func afterAccess() {
//        if let topologyUpdate = topologyUpdate {
//            widget.updateTopology(topologyUpdate,
//                                  nodeIndices!,
//                                  nodePositions!,
//                                  edgeIndexData!,
//                                  nodeColors!)
//        }
//        else {
//
//            if let positionsUpdate = positionsUpdate {
//                widget.updateNodePositions(positionsUpdate, nodePositions!)
//            }
//            // no 'else' here
//            if let colorsUpdate = colorsUpdate {
//                widget.updateNodeColors(colorsUpdate, nodeColors!)
//            }
//        }
//    }
//
//    func updateTopology(_ holder: GraphHolder<G>) {
//        var newNodeIndices = [NodeID: Int]()
//        var newNodePositions = [SIMD3<Float>]()
//        var newEdgeIndexData = [UInt32]()
//
//        var nodeIndex: Int = 0
//        for node in holder.graph.nodes {
//            if let nodeValue = node.value,
//               !nodeValue.hidden {
//                newNodeIndices[node.id] = nodeIndex
//                newNodePositions.insert(nodeValue.location, at: nodeIndex)
//                nodeIndex += 1
//            }
//        }
//
//        var edgeIndex: Int = 0
//        for node in holder.graph.nodes {
//            for edge in node.outEdges {
//                if let edgeValue = edge.value,
//                   !edgeValue.hidden,
//                   let sourceIndex = newNodeIndices[edge.source.id],
//                   let targetIndex = newNodeIndices[edge.target.id] {
//                    newEdgeIndexData.insert(UInt32(sourceIndex), at: edgeIndex)
//                    edgeIndex += 1
//                    newEdgeIndexData.insert(UInt32(targetIndex), at: edgeIndex)
//                    edgeIndex += 1
//                }
//            }
//        }
//
//        self.nodeIndices = newNodeIndices
//        self.nodePositions = newNodePositions
//        self.edgeIndexData = newEdgeIndexData
//        self.nodeColors = holder.graph.makeNodeColors()
//        self.topologyUpdate = holder.topologyUpdate
//        self.positionsUpdate = holder.positionsUpdate
//        self.colorsUpdate = holder.colorsUpdate
//    }
//
//    func updateGeometry(_ holder: GraphHolder<G>) {
//
//        var newNodePositions = [SIMD3<Float>]()
//
//        for node in holder.graph.nodes {
//            if let nodeIndex = widget.nodeIndices[node.id],
//               let nodeValue = node.value,
//               !nodeValue.hidden {
//                newNodePositions.insert(nodeValue.location, at: nodeIndex)
//            }
//        }
//
//        self.nodePositions = newNodePositions
//        self.positionsUpdate = holder.positionsUpdate
//    }
//
//    func updateColors(_ holder: GraphHolder<GraphType>) {
//        self.nodeColors = holder.graph.makeNodeColors()
//        self.colorsUpdate = holder.colorsUpdate
//    }
//}


///
///
///
class GraphWireFrame<N: RenderableNodeValue, E: RenderableEdgeValue>: RenderableGraphWidget {
    typealias NodeValueType = N
    typealias EdgeValueType = E

    var pointSize: Float = RenderingConstants.defaultPointSize

    var device: MTLDevice

    var library: MTLLibrary

    var nodePipelineState: MTLRenderPipelineState!

    var lastTopologyUpdate: Int = -1

    var lastPositionsUpdate: Int = -1

    var lastColorsUpdate: Int = -1

    var nodeIndices = [NodeID: Int]()

    var nodeCount: Int = 0

    var nodePositionBuffer: MTLBuffer? = nil

    var nodeColorBuffer: MTLBuffer? = nil

    var edgePipelineState: MTLRenderPipelineState!

    var edgeIndexCount: Int = 0

    var edgeIndexBuffer: MTLBuffer? = nil

    init(_ device: MTLDevice) {
        let shaders = Shaders()
        self.device = shaders.metalDevice
        self.library = shaders.packageMetalLibrary
    }

    func accessGraph<G>(_ holder: RenderableGraphHolder<G>) where G : Graph, E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        if  holder.hasTopologyChanged(since: lastTopologyUpdate) {
            self.updateTopology(holder.graph)
            self.lastTopologyUpdate = holder.topologyUpdate
        }
        else {

            if holder.havePositionsChanged(since: lastPositionsUpdate) {
                self.updatePositions(holder.graph)
                self.lastPositionsUpdate = holder.positionsUpdate
            }
            // no 'else' here
            if holder.haveColorsChanged(since: lastColorsUpdate) {
                self.updateColors(holder.graph)
                self.lastColorsUpdate = holder.colorsUpdate
            }
        }
    }

    func afterAccess() {
        // NOP
    }

    func setup(_ view: MTKView) throws {

        print("library functions:")
        print(library.functionNames)

        if (nodePipelineState == nil) {
            print("building node pipeline")
            self.nodePipelineState = try Self.buildNodePipeline(device, library, view)
            print("done building node pipeline")
        }
        if (edgePipelineState == nil) {
            print("building edge pipeline")
            self.edgePipelineState = try Self.buildEdgePipeline(device, library, view)
            print("done building edge pipeline")
        }
    }

    func teardown() {
        // TODO: maybe nodePipelineState
        // TODO: maybe edgePipelineState
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    /// updates everything
    func updateTopology<G: Graph>(_ graph: G) where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        // print("GraphWireFrame.updateTopology")

        var newNodeIndices = [NodeID: Int]()
        var newNodePositions = [SIMD3<Float>]()
        var newEdgeIndexData = [UInt32]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            if let nodeValue = node.value,
               !nodeValue.hidden {
                newNodeIndices[node.id] = nodeIndex
                newNodePositions.insert(nodeValue.location, at: nodeIndex)
                nodeIndex += 1
            }
        }

        var edgeIndex: Int = 0
        for node in graph.nodes {
            for edge in node.outEdges {
                if let edgeValue = edge.value,
                   !edgeValue.hidden,
                   let sourceIndex = newNodeIndices[edge.source.id],
                   let targetIndex = newNodeIndices[edge.target.id] {
                    newEdgeIndexData.insert(UInt32(sourceIndex), at: edgeIndex)
                    edgeIndex += 1
                    newEdgeIndexData.insert(UInt32(targetIndex), at: edgeIndex)
                    edgeIndex += 1
                }
            }
        }

        self.nodeCount = newNodeIndices.count
        self.nodeIndices = newNodeIndices

        updateNodePositions(newNodePositions)
        updateNodeColors(graph.makeNodeColors())

        self.edgeIndexCount = newEdgeIndexData.count
        if (edgeIndexCount > 0) {
            let bufLen = edgeIndexCount * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndexData, length: bufLen)
        }
        else {
            self.edgeIndexBuffer = nil
        }
    }

    func updatePositions<G: Graph>(_ graph: G) where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        var newNodePositions = [SIMD3<Float>]()
        for node in graph.nodes {
            if let nodeIndex = nodeIndices[node.id],
               let nodeValue = node.value,
               !nodeValue.hidden {
                newNodePositions.insert(nodeValue.location, at: nodeIndex)
            }
        }
        updateNodePositions(newNodePositions)
    }

    func updateColors<G: Graph>(_ graph: G) where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        updateNodeColors(graph.makeNodeColors())
    }

    private func updateNodePositions(_ newNodePositions: [SIMD3<Float>]) {
        // print("GraphWireFrame.updateNodePositions")
        if (self.nodeCount > 0) {
            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
            nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                   length: nodePositionBufLen,
                                                   options: [])
        }
        else {
            nodePositionBuffer = nil
        }
    }

    private func updateNodeColors(_ newColors: [NodeID: SIMD4<Float>]) {
        // print("GraphWireFrame.updateNodeColors")
        if (self.nodeCount > 0) {
            var nodeColors = [SIMD4<Float>](repeating: RenderingConstants.clearColor, count: nodeCount)

            for (nodeID, color) in newColors {
                if let nodeIndex = nodeIndices[nodeID] {
                    nodeColors[nodeIndex] = color
                }
            }

            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
            nodeColorBuffer = device.makeBuffer(bytes: nodeColors,
                                                length: nodeColorBufLen,
                                                options: [])
        }
        else {
            nodeColorBuffer = nil
        }
    }

    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int) {

        // print("GraphWireFreame.draw")

        if !(nodeCount > 0) {
            return
        }

        renderEncoder.pushDebugGroup("Draw Nodes")
        renderEncoder.setRenderPipelineState(nodePipelineState)
        renderEncoder.setVertexBuffer(uniformsBuffer,
                                      offset:uniformsBufferOffset,
                                      index: BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(uniformsBuffer,
                                        offset:uniformsBufferOffset,
                                        index: BufferIndex.uniforms.rawValue)
        renderEncoder.setVertexBuffer(nodePositionBuffer,
                                      offset: 0,
                                      index: BufferIndex.nodePosition.rawValue)
        renderEncoder.setVertexBuffer(nodeColorBuffer,
                                      offset: 0,
                                      index: BufferIndex.nodeColor.rawValue)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
        renderEncoder.popDebugGroup()

        guard
            let edgeIndexBuffer = edgeIndexBuffer
        else {
            return
        }

        renderEncoder.pushDebugGroup("Draw Edges")
        renderEncoder.setRenderPipelineState(edgePipelineState)
        renderEncoder.drawIndexedPrimitives(type: .line,
                                            indexCount: edgeIndexCount,
                                            indexType: GraphWireFrameConstants.edgeIndexType,
                                            indexBuffer: edgeIndexBuffer,
                                            indexBufferOffset: 0)
        renderEncoder.popDebugGroup()

    }

    private static func buildNodePipeline(_ device: MTLDevice, _ library: MTLLibrary, _ view: MTKView) throws -> MTLRenderPipelineState {

        let vertexFunction = library.makeFunction(name: "node_vertex")
        let fragmentFunction = library.makeFunction(name: "node_fragment")
        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.nodePosition.rawValue

        vertexDescriptor.attributes[VertexAttribute.color.rawValue].format = MTLVertexFormat.float4
        vertexDescriptor.attributes[VertexAttribute.color.rawValue].offset = 0
        vertexDescriptor.attributes[VertexAttribute.color.rawValue].bufferIndex = BufferIndex.nodeColor.rawValue

        vertexDescriptor.layouts[BufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[BufferIndex.nodePosition.rawValue].stepRate = 1
        vertexDescriptor.layouts[BufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        vertexDescriptor.layouts[BufferIndex.nodeColor.rawValue].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[BufferIndex.nodeColor.rawValue].stepRate = 1
        vertexDescriptor.layouts[BufferIndex.nodeColor.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        pipelineDescriptor.label = "NodePipeline"
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // FIXME: these are guesses and they don't work
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .max
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .destinationAlpha
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .max
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private static func buildEdgePipeline(_ device: MTLDevice, _ library: MTLLibrary, _ view: MTKView) throws -> MTLRenderPipelineState {

        let vertexFunction = library.makeFunction(name: "net_vertex")
        let fragmentFunction = library.makeFunction(name: "net_fragment")

        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.nodePosition.rawValue

        vertexDescriptor.layouts[BufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[BufferIndex.nodePosition.rawValue].stepRate = 1
        vertexDescriptor.layouts[BufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "EdgePipeline"
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // FIXME: these are guesses and they don't work
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .max
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .destinationAlpha
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .max
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
}
