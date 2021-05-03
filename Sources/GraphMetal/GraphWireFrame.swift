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


public class GraphWireFrame<N: RenderableNodeValue, E: RenderableEdgeValue>: RenderableGraphWidget {

    typealias NodeValueType = N
    typealias EdgeValueType = E

    public var pointSize: Float = RenderingConstants.defaultNodeSize

    var device: MTLDevice

    var library: MTLLibrary

    var lastTopologyUpdate: Int = -1

    var lastPositionsUpdate: Int = -1

    var lastColorsUpdate: Int = -1

    var nodePipelineState: MTLRenderPipelineState!

    var nodeCount: Int = 0

    var nodeIndices = [NodeID: Int]()

    var newNodePositions: [SIMD3<Float>]? = nil

    var nodePositionBuffer: MTLBuffer? = nil

    var newNodeColors: [NodeID: SIMD4<Float>]? = nil

    var nodeColorBuffer: MTLBuffer? = nil

    var edgeColor = RenderingConstants.defaultEdgeColor
    
    var edgePipelineState: MTLRenderPipelineState!

    var edgeIndexCount: Int = 0

    var newEdgeIndices: [UInt32]? = nil

    var edgeIndexBuffer: MTLBuffer? = nil

    var _drawCount: Int = 0

    init(_ device: MTLDevice) {
        let shaders = Shaders()
        self.device = shaders.metalDevice
        self.library = shaders.packageMetalLibrary
    }

    func setup(_ view: MTKView) throws {

        // print("library functions: \(library.functionNames)")

        if (nodePipelineState == nil) {
            // print("building node pipeline")
            self.nodePipelineState = try Self.buildNodePipeline(device, library, view)
            // print("done building node pipeline")
        }
        if (edgePipelineState == nil) {
            // print("building edge pipeline")
            self.edgePipelineState = try Self.buildEdgePipeline(device, library, view)
            // print("done building edge pipeline")
        }
    }

    func teardown() {
        // TODO: maybe nodePipelineState
        // TODO: maybe edgePipelineState
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    func prepareUpdate<H>(_ graphHolder: H) where
        H : RenderableGraphHolder,
        E == H.GraphType.EdgeType.ValueType,
        N == H.GraphType.NodeType.ValueType {

        // print("GraphWireFrame.prepareUpdate")

        if  graphHolder.hasTopologyChanged(since: lastTopologyUpdate) {
            self.prepareTopologyUpdate(graphHolder.graph)
            self.lastTopologyUpdate = graphHolder.topologyUpdate
        }
        else {

            if graphHolder.havePositionsChanged(since: lastPositionsUpdate) {
                self.preparePositionsUpdate(graphHolder.graph)
                self.lastPositionsUpdate = graphHolder.positionsUpdate
            }
            // no 'else' here
            if graphHolder.haveColorsChanged(since: lastColorsUpdate) {
                self.prepareColorsUpdate(graphHolder.graph)
                self.lastColorsUpdate = graphHolder.colorsUpdate
            }
        }
    }

    func applyUpdate() {

        // print("GraphWireFrame.applyUpdate")

        if nodeCount == 0 {
            nodePositionBuffer = nil
        }
        else if let nodePositions = self.newNodePositions {
            // print("GraphWireFrame: creating nodePositionBuffer")
            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
            nodePositionBuffer = device.makeBuffer(bytes: nodePositions,
                                                   length: nodePositionBufLen,
                                                   options: [])
        }
        self.newNodePositions = nil

        if nodeCount == 0 {
            nodeColorBuffer = nil
        }
        else if let nodeColors = self.newNodeColors {
            // print("GraphWireFrame: creating nodeColorBuffer")
            var colorsArray = [SIMD4<Float>](repeating: RenderingConstants.defaultNodeColor, count: nodeCount)
            for (nodeID, color) in nodeColors {
                if let nodeIndex = nodeIndices[nodeID] {
                    colorsArray[nodeIndex] = color
                }
            }

            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
            nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                length: nodeColorBufLen,
                                                options: [])
        }
        self.newNodeColors = nil

        if edgeIndexCount == 0 {
            self.edgeIndexBuffer = nil
        }
        else if let edgeIndices = self.newEdgeIndices {
            // print("GraphWireFrame: creating edgeIndexBuffer")
            let bufLen = edgeIndices.count * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: edgeIndices, length: bufLen)
        }
        self.newEdgeIndices = nil
    }

    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int) {

        _drawCount += 1
        // print("GraphWireFrame.draw[\(_drawCount)]")

        guard
            let nodePositionBuffer = nodePositionBuffer
        else {
            print("GraphWireFrame.draw[\(_drawCount)]: nodePositionBuffer = nil")
            return
        }

        guard
            let nodeColorBuffer = nodeColorBuffer
        else {
            print("GraphWireFrame.draw[\(_drawCount)]: nodeColorBuffer = nil")
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
            print("GraphWireFrame.draw[\(_drawCount)]: edgeIndexBuffer = nil")
            return
        }

        renderEncoder.pushDebugGroup("Draw Edges")
        renderEncoder.setRenderPipelineState(edgePipelineState)
        renderEncoder.drawIndexedPrimitives(type: .line,
                                            indexCount: edgeIndexCount,
                                            indexType: RenderingConstants.edgeIndexType,
                                            indexBuffer: edgeIndexBuffer,
                                            indexBufferOffset: 0)
        renderEncoder.popDebugGroup()

    }

    private func prepareTopologyUpdate<G: Graph>(_ graph: G) where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {

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
        self.newNodePositions = newNodePositions
        self.newNodeColors = graph.makeNodeColors()
        self.edgeIndexCount = newEdgeIndexData.count
        self.newEdgeIndices = newEdgeIndexData

    }

    private func preparePositionsUpdate<G: Graph>(_ graph: G) where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        var newNodePositions = [SIMD3<Float>]()
        for node in graph.nodes {
            if let nodeIndex = nodeIndices[node.id],
               let nodeValue = node.value,
               !nodeValue.hidden {
                newNodePositions.insert(nodeValue.location, at: nodeIndex)
            }
        }

        self.newNodePositions = newNodePositions
    }

    private func prepareColorsUpdate<G: Graph>(_ graph: G) where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        self.newNodeColors = graph.makeNodeColors()
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

        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false

        // These are guesses
        //        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        //        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .max
        //        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        //        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .destinationAlpha
        //        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .max
        //        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        //        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

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

        // pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false

        // These are guesses
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

struct BufferData {

}
