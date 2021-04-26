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

class GraphWireFrameTransfer { // }: GameAccessTask {

    var widget: GraphWireFrame

    var nodeIndices: [NodeID: Int]?

    var nodePositions: [SIMD3<Float>]?

    var edgeIndexData: [UInt32]?

    var nodeColors: [NodeID: SIMD4<Float>]?

    var topologyUpdate: Int? = nil

    var geometryUpdate: Int? = nil

    var colorUpdate: Int? = nil

    init(_ widget: GraphWireFrame) {
        self.widget = widget
    }

    func accessGame() {
//        let graph = GameController.instance.gameData.worldGraph
//
//        if GameController.instance.gameData.isTopologyStale(widget.lastTopologyUpdate) {
//            self.updateTopology(graph)
//        }
//        else {
//            if GameController.instance.gameData.isGeometryStale(widget.lastGeometryUpdate) {
//                self.updateGeometry(graph)
//            }
//            // no 'else' here
//            if GameController.instance.gameData.isColorStale(widget.lastColorUpdate) {
//                self.updateColors(graph)
//            }
//        }
    }

    func afterGameAccess() {
        if let topologyUpdate = topologyUpdate {
            widget.updateTopology(topologyUpdate,
                                  nodeIndices!,
                                  nodePositions!,
                                  edgeIndexData!,
                                  nodeColors!)
        }
        else {
            if let geometryUpdate = geometryUpdate {
                widget.updateNodePositions(geometryUpdate, nodePositions!)
            }
            // no 'else' here
            if let colorUpdate = colorUpdate {
                widget.updateNodeColors(colorUpdate, nodeColors!)
            }
        }
    }

    func updateTopology<G: Graph>(_ graph: G) where G.NodeType.ValueType: RenderableNodeValue, G.EdgeType.ValueType: RenderableEdgeValue {
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

        self.nodeIndices = newNodeIndices
        self.nodePositions = newNodePositions
        self.edgeIndexData = newEdgeIndexData
//        self.nodeColors = graph.makeStationColors()
//        self.topologyUpdate = GameController.instance.gameData.topologyUpdate
//        self.geometryUpdate = GameController.instance.gameData.geometryUpdate
//        self.colorUpdate = GameController.instance.gameData.colorUpdate
    }

    func updateGeometry<G: Graph>(_ graph: G) where G.NodeType.ValueType: RenderableNodeValue, G.EdgeType.ValueType: RenderableEdgeValue  {
        var newNodePositions = [SIMD3<Float>]()

        for node in graph.nodes {
            if let nodeIndex = widget.nodeIndices[node.id],
               let nodeValue = node.value,
               !nodeValue.hidden {
                newNodePositions.insert(nodeValue.location, at: nodeIndex)
            }
        }

        self.nodePositions = newNodePositions
//        self.geometryUpdate = GameController.instance.gameData.geometryUpdate
    }

    func updateColors<G: Graph>(_ graph: G) where G.NodeType.ValueType: RenderableNodeValue, G.EdgeType.ValueType: RenderableEdgeValue  {
//        self.nodeColors = graph.makeStationColors()
//        self.colorUpdate = GameController.instance.gameData.colorUpdate
    }

}

class GraphWireFrame: Widget {

    static let edgeColor = RenderingConstants.edgeColor

    static let edgeIndexType = MTLIndexType.uint32

    var pointSize: Float = RenderingConstants.defaultPointSize

    var device: MTLDevice

    var library: MTLLibrary

    var nodePipelineState: MTLRenderPipelineState!

    var lastTopologyUpdate: Int = -1

    var lastGeometryUpdate: Int = -1

    var lastColorUpdate: Int = -1

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

//    func makeTransferTask() -> GameAccessTask {
//        return GraphWireFrameTransfer(self)
//    }

    func initializePipelines(_ view: MTKView) throws {

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

    /// updates everything
    func updateTopology(_ update: Int,
                        _ newNodeIndices: [NodeID: Int],
                        _ newNodePositions: [SIMD3<Float>],
                        _ newEdgeIndexData: [UInt32],
                        _ newNodeColors: [NodeID: SIMD4<Float>]) {

        // print("GraphWireFrame.updateTopology")
        lastTopologyUpdate = update
        nodeCount = newNodeIndices.count
        nodeIndices = newNodeIndices

        updateNodePositions(update, newNodePositions)
        updateNodeColors(update, newNodeColors)

        self.edgeIndexCount = newEdgeIndexData.count
        if (edgeIndexCount > 0) {
            let bufLen = edgeIndexCount * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndexData, length: bufLen)
        }
        else {
            self.edgeIndexBuffer = nil
        }
    }

    func updateNodePositions(_ update: Int,
                        _ newNodePositions: [SIMD3<Float>]) {
        // print("GraphWireFrame.updateNodePositions")
        lastGeometryUpdate = update
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

    func updateNodeColors(_ update: Int,
                      _ newColors: [NodeID: SIMD4<Float>]) {
        // print("GraphWireFrame.updateNodeColors")
        lastColorUpdate = update
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
                                            indexType: GraphWireFrame.edgeIndexType,
                                            indexBuffer: edgeIndexBuffer,
                                            indexBufferOffset: 0)
        renderEncoder.popDebugGroup()

    }

//    private static func makeLibrary(_ device: MTLDevice) throws -> MTLLibrary? {
//        let metalLibURL: URL = Bundle.module.url(forResource: "Shaders", withExtension: "metallib", subdirectory: "Shaders")!
//        print("metalLibURL = \(metalLibURL)")
//        let library = try? device.makeLibrary(filepath: metalLibURL.path)
//        print("library = \(library)")
//
//
//        // let library = try? device.makeDefaultLibrary(bundle: Bundle.module)
//        // let library = device.makeDefaultLibrary()
//        return library
//
//    }

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
