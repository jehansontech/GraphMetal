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
import Taconic

class GraphWireFrame<N: RenderableNodeValue, E: RenderableEdgeValue>: RenderableGraphWidget {

    typealias NodeValueType = N
    typealias EdgeValueType = E

    // ==============================================================
    // Rendering properties -- Access these only on rendering thread

    var nodeColorDefault = RenderSettings.defaults.nodeColorDefault

    var device: MTLDevice

    var library: MTLLibrary

    var nodePipelineState: MTLRenderPipelineState!

    var nodeCount: Int = 0

    var nodePositionBuffer: MTLBuffer? = nil

    var nodeColorBuffer: MTLBuffer? = nil

    var edgePipelineState: MTLRenderPipelineState!

    var edgeIndexCount: Int = 0

    var edgeIndexBuffer: MTLBuffer? = nil

    var _drawCount: Int = 0


    // ==============================================================
    // Data properties -- Access these only on background thread

    var lastTopologyUpdate: Int = -1

    var lastPositionsUpdate: Int = -1

    var lastColorsUpdate: Int = -1

    private var nodeIndices = [NodeID: Int]()

    private var bufferUpdate: BufferUpdate? = nil


    // ==============================================================

    init(_ device: MTLDevice) {
        debug("GraphWireFrame", "init")
        let shaders = Shaders()
        self.device = shaders.metalDevice
        self.library = shaders.packageMetalLibrary
    }

    deinit {
        debug("GraphWireFrame", "deinit")
    }

    func setup(_ view: MTKView) throws {
        debug("GraphWireFrame", "setup. library functions: \(library.functionNames)")

        if (nodePipelineState == nil) {
            // debug("building node pipeline")
            self.nodePipelineState = try Self.buildNodePipeline(device, library, view)
            // debug("done building node pipeline")
        }
        if (edgePipelineState == nil) {
            // debug("building edge pipeline")
            self.edgePipelineState = try Self.buildEdgePipeline(device, library, view)
            // debug("done building edge pipeline")
        }
    }

    func teardown() {
        debug("GraphWireFrame", "teardown")
        // TODO: maybe nodePipelineState
        // TODO: maybe edgePipelineState
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    /// Runs on background thread
    func prepareUpdate<H>(_ graphHolder: H) where
        H : RenderableGraphHolder,
        E == H.GraphType.EdgeType.ValueType,
        N == H.GraphType.NodeType.ValueType {

        if  graphHolder.hasTopologyChanged(since: lastTopologyUpdate) {
            debug("GraphWireFrame", "prepareUpdate: topology has changed")
            self.lastTopologyUpdate = graphHolder.topologyUpdate
            self.lastPositionsUpdate = graphHolder.positionsUpdate
            self.lastColorsUpdate = graphHolder.colorsUpdate
            self.bufferUpdate = self.prepareTopologyUpdate(graphHolder.graph)
        }
        else {
            var newPositions: [SIMD3<Float>]? = nil
            var newColors: [NodeID : SIMD4<Float>]? = nil

            if graphHolder.havePositionsChanged(since: lastPositionsUpdate) {
                debug("GraphWireFrame", "prepareUpdate: positions have changed")
                newPositions = self.makeNodePositions(graphHolder.graph)
                self.lastPositionsUpdate = graphHolder.positionsUpdate
            }

            if graphHolder.haveColorsChanged(since: lastColorsUpdate) {
                debug("GraphWireFrame", "prepareUpdate: colors have changed")
                newColors = graphHolder.graph.makeNodeColors()
                self.lastColorsUpdate = graphHolder.colorsUpdate
            }

            if (newPositions != nil || newColors != nil) {
                self.bufferUpdate = BufferUpdate(nodeCount: self.nodeCount,
                                                 nodePositions: newPositions,
                                                 nodeColors: newColors,
                                                 edgeIndexCount: self.edgeIndexCount,
                                                 edgeIndices: nil)
            }
        }

    }

    /// Runs on rendering thread
    func applyUpdate() {

        guard
            let update = self.bufferUpdate
        else {
            return
        }

        self.bufferUpdate = nil

        if self.nodeCount != update.nodeCount {
            debug("GraphWireFrame", "updating nodeCount: \(nodeCount) -> \(update.nodeCount)")
                nodeCount = update.nodeCount
        }

        if nodeCount == 0 {
            if nodePositionBuffer != nil {
                debug("GraphWireFrame", "discarding nodePositionBuffer")
                nodePositionBuffer = nil
            }
        }
        else if let newNodePositions = update.nodePositions {
            if newNodePositions.count != nodeCount {
                fatalError("Failed sanity check: nodeCount=\(nodeCount) but newNodePositions.count=\(newNodePositions.count)")
            }

            debug("GraphWireFrame", "creating nodePositionBuffer")
            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
            nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                   length: nodePositionBufLen,
                                                   options: [])
        }

        if nodeCount == 0 {
            if nodeColorBuffer != nil {
                debug("GraphWireFrame", "discarding nodeColorBuffer")
                nodeColorBuffer = nil
            }
        }
        else if let newNodeColors = update.nodeColors {

            let defaultColor = SIMD4<Float>(Float(self.nodeColorDefault.x),
                                  Float(self.nodeColorDefault.y),
                                  Float(self.nodeColorDefault.z),
                                  Float(self.nodeColorDefault.w))
            var colorsArray = [SIMD4<Float>](repeating: defaultColor, count: nodeCount)
            for (nodeID, color) in newNodeColors {
                if let nodeIndex = nodeIndices[nodeID] {
                    colorsArray[nodeIndex] = color
                }
            }

            debug("GraphWireFrame", "creating nodeColorBuffer")
            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
            nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                length: nodeColorBufLen,
                                                options: [])
        }

        if self.edgeIndexCount != update.edgeIndexCount {
            debug("GraphWireFrame", "updating edgeIndexCount: \(edgeIndexCount) -> \(update.edgeIndexCount)")
            self.edgeIndexCount = update.edgeIndexCount
        }

        if edgeIndexCount == 0 {
            if edgeIndexBuffer != nil {
                debug("GraphWireFrame", "discarding edgeIndexBuffer")
                self.edgeIndexBuffer = nil
            }
        }
        else if let newEdgeIndices = update.edgeIndices {
            if newEdgeIndices.count != edgeIndexCount {
                fatalError("Failed sanity check: edgeIndexCount=\(edgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
            }

            debug("GraphWireFrame", "creating edgeIndexBuffer")
            let bufLen = newEdgeIndices.count * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices, length: bufLen)
        }
    }

    func draw(_ renderEncoder: MTLRenderCommandEncoder,
              _ uniformsBuffer: MTLBuffer,
              _ uniformsBufferOffset: Int) {

        _drawCount += 1
        // debug("GraphWireFrame.draw[\(_drawCount)]")

        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            debug("GraphWireFrame", "draw \(_drawCount): nodePositionBuffer = nil")
            return
        }

        guard
            let nodeColorBuffer = self.nodeColorBuffer
        else {
            debug("GraphWireFrame", "draw \(_drawCount): nodeColorBuffer = nil")
            return
        }

        // debug("GraphWireFrame", "draw \(_drawCount): starting on nodes")

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
            let edgeIndexBuffer = self.edgeIndexBuffer
        else {
            debug("GraphWireFrame", "draw \(_drawCount): edgeIndexBuffer = nil")
            return
        }

        // debug("GraphWireFrame", "draw \(_drawCount): starting on edges")


        renderEncoder.pushDebugGroup("Draw Edges")
        renderEncoder.setRenderPipelineState(edgePipelineState)
        renderEncoder.drawIndexedPrimitives(type: .line,
                                            indexCount: edgeIndexCount,
                                            indexType: RenderingConstants.edgeIndexType,
                                            indexBuffer: edgeIndexBuffer,
                                            indexBufferOffset: 0)
        renderEncoder.popDebugGroup()

    }

    private func prepareTopologyUpdate<G: Graph>(_ graph: G) -> BufferUpdate where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {

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

        // OK
        self.nodeIndices = newNodeIndices

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

        return BufferUpdate(
            nodeCount: newNodePositions.count,
            nodePositions: newNodePositions,
            nodeColors: graph.makeNodeColors(),
            edgeIndexCount: newEdgeIndexData.count,
            edgeIndices: newEdgeIndexData
        )
    }

    private func makeNodePositions<G: Graph>(_ graph: G) -> [SIMD3<Float>] where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        var newNodePositions = [SIMD3<Float>]()
        for node in graph.nodes {
            if let nodeIndex = nodeIndices[node.id],
               let nodeValue = node.value,
               !nodeValue.hidden {
                newNodePositions.insert(nodeValue.location, at: nodeIndex)
            }
        }
        return newNodePositions
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

struct BufferUpdate {
    let nodeCount: Int
    let nodePositions: [SIMD3<Float>]?
    let nodeColors: [NodeID: SIMD4<Float>]?
    let edgeIndexCount: Int
    let edgeIndices: [UInt32]?
}
