//
//  ZWireframe.swift
//  GraphMetal
//
//  Created by Jim Hanson on 8/6/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public protocol ZWireframe: ZRenderable {

    var bbox: BoundingBox? { get }

}

// ============================================================================
// MARK: - MonochromeWireframe
// ============================================================================

public class MonochromeWireframe: ZWireframe { // ¿ObservableObject

    public private(set) var bbox: BoundingBox? = nil

    private var pendingUpdate: MonochromeWireframeUpdate

    private var device: MTLDevice!

    private var nodePositionBufferIndex: Int { RenderConstants.nodePositionBufferIndex }

    private var nodeCount: Int = 0
    
    private var nodePositionBuffer: MTLBuffer? = nil

    private var nodeFragmentFunctionName: String = "node_fragment_ring"

    private var edgeIndexCount: Int = 0

    private var edgeIndexBuffer: MTLBuffer? = nil

    private var edgePipelineState: MTLRenderPipelineState!

    private var nodePipelineState: MTLRenderPipelineState!

    public init() {
        self.pendingUpdate = MonochromeWireframeUpdate()
    }

    public func addUpdate(_ update: MonochromeWireframeUpdate) {
        pendingUpdate.merge(update)
    }

    public func setup(_ view: MTKView, _ device: MTLDevice, _ defaultLibrary: MTLLibrary) throws {
        self.device = device
        self.edgePipelineState = try buildEdgePipeline(view, device, defaultLibrary)
        self.nodePipelineState = try buildNodePipeline(view, device, defaultLibrary)
    }

    public func prepareToDraw(_ date: Date) {
        if let newBBox = pendingUpdate.bbox {
            pendingUpdate.bbox = nil
            self.bbox = newBBox
        }
        if let newNodePositions = pendingUpdate.nodePositions {
            pendingUpdate.nodePositions = nil
            self.nodeCount = newNodePositions.count

            // We're replacing the buffer rather than modifying its contents
            // so that we don't have to deal with sync between CPU and GPU.

            let bufferLength = newNodePositions.count * MemoryLayout<SIMD3<Float>>.size
            let bufferOptions: MTLResourceOptions = []
            self.nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                        length: bufferLength,
                                                        options: bufferOptions)
        }
        if let newEdgeIndices = pendingUpdate.edgeIndices {
            pendingUpdate.edgeIndices = nil

            // We're replacing the buffer rather than modifying its contents
            // so that we don't have to deal with sync between CPU and GPU.

            self.edgeIndexCount = newEdgeIndices.count
            let bufferLength = newEdgeIndices.count * MemoryLayout<UInt32>.size
            let bufferOptions: MTLResourceOptions = []
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
                                                     length: bufferLength,
                                                     options: bufferOptions)
        }
    }

    public func encodeCommands(_ encoder: MTLRenderCommandEncoder) {

        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            return
        }

        guard let edgeIndexBuffer = self.edgeIndexBuffer
        else {
            return
        }

        encoder.pushDebugGroup("MonochromeWireframe")
        encoder.setRenderPipelineState(edgePipelineState)
        encoder.setVertexBuffer(nodePositionBuffer,
                                offset: 0,
                                index: nodePositionBufferIndex)
        encoder.drawIndexedPrimitives(type: .line,
                                      indexCount: edgeIndexCount,
                                      indexType: MTLIndexType.uint32,
                                      indexBuffer: edgeIndexBuffer,
                                      indexBufferOffset: 0)
        encoder.setRenderPipelineState(nodePipelineState)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
        encoder.popDebugGroup()

    }

    public func renderingIsComplete() {
        // NOP
    }

    public func teardown() {
        // NOP
    }

    private func buildEdgePipeline(_ view: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws -> MTLRenderPipelineState {

        let vertexFunctionName = "monochrome_edge_vertex"
        let fragmentFunctionName = "edge_fragment"

        guard let vertexFunction = library.makeFunction(name: vertexFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: vertexFunctionName)
        }

        guard let fragmentFunction = library.makeFunction(name: fragmentFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: fragmentFunctionName)
        }

        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = nodePositionBufferIndex

        vertexDescriptor.layouts[nodePositionBufferIndex].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[nodePositionBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodePositionBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        pipelineDescriptor.label = "EdgePipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // These are for fadeout
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        // I'm guessing that these might help with other things that get drawn on top
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func buildNodePipeline(_ view: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws -> MTLRenderPipelineState {

        let vertexFunctionName = "monochrome_node_vertex"
        let fragmentFunctionName = "node_fragment_dot"

        guard let vertexFunction = library.makeFunction(name: vertexFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: vertexFunctionName)
        }

        guard let fragmentFunction = library.makeFunction(name: fragmentFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: fragmentFunctionName)
        }

        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = nodePositionBufferIndex

        vertexDescriptor.layouts[nodePositionBufferIndex].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[nodePositionBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodePositionBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        pipelineDescriptor.label = "NodePipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // These are for fadeout
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        // I'm guessing that these might help with other things that get drawn on top
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

}

public struct MonochromeWireframeUpdate: Sendable {

    public var bbox: BoundingBox?

    public var nodePositions: [SIMD3<Float>]?

    /// Interleaved (source, target) pairs where each value is an index into nodePositions array.
    public var edgeIndices: [UInt32]?

    init(bbox: BoundingBox? = nil,
                nodePositions: [SIMD3<Float>]? = nil,
                edgeIndices: [UInt32]? = nil) {
        self.bbox = bbox
        self.nodePositions = nodePositions
        self.edgeIndices = edgeIndices
    }

    public mutating func clear() {
        bbox = nil
        nodePositions = nil
        edgeIndices = nil
    }

    public mutating func merge(_ other: MonochromeWireframeUpdate) {
        if let newBBox = other.bbox {
            self.bbox = newBBox
        }
        if let newNodePositions = other.nodePositions {
            self.nodePositions = newNodePositions
        }
        if let newEdgeIndices = other.edgeIndices {
            self.edgeIndices = newEdgeIndices
        }
    }
}

extension MonochromeWireframeUpdate {

    /// Call this if node set has changed.
    public static func makeTotalUpdate<G: Graph>(_ graph: G) -> MonochromeWireframeUpdate
    where G.NodeType.ValueType: EmbeddedValue
    {

        // key is nodeNumber in graph, value is index into self.nodePositions array
        var nodeIndexMap = [Int: Int]()

        var newBBox: BoundingBox? = nil
        var newNodePositions = [SIMD3<Float>]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            nodeIndexMap[node.nodeNumber] = nodeIndex

            if let nodePosition = node.value?.location {
                newNodePositions.insert(nodePosition, at: nodeIndex)
                if newBBox == nil {
                    newBBox = BoundingBox(nodePosition)
                }
                else {
                    newBBox!.cover(nodePosition)
                }
            }
            nodeIndex += 1
        }

        return MonochromeWireframeUpdate(bbox: graph.makeBoundingBox(),
                                         nodePositions: newNodePositions,
                                         edgeIndices: makeEdgeIndices(graph, nodeIndexMap))
    }

    /// Call this if edge set has changed but node set has not
    public static func makeEdgeSetChange<G: Graph>(_ graph: G) -> MonochromeWireframeUpdate
    where G.NodeType.ValueType: EmbeddedValue
    {
        return MonochromeWireframeUpdate(edgeIndices: makeEdgeIndices(graph, makeNodeIndexMap(graph)))
    }

    private static func makeNodeIndexMap<GraphType: Graph>(_ graph: GraphType) -> [Int: Int]
    {
        var newNodeIndices = [Int: Int]()
        var nodeIndex: Int = 0
        for node in graph.nodes {
            newNodeIndices[node.nodeNumber] = nodeIndex
            nodeIndex += 1
        }
        return newNodeIndices
    }

    private static func makeEdgeIndices<GraphType: Graph>(_ graph: GraphType, _ nodeIndices: [Int: Int]) -> [UInt32]
    {
        var edgeIndices = [UInt32]()
        var edgeIndex: Int = 0
        for node in graph.nodes {
            for edge in node.outEdges {
                if let sourceIndex = nodeIndices[edge.source.nodeNumber],
                   let targetIndex = nodeIndices[edge.target.nodeNumber] {
                    edgeIndices.insert(UInt32(sourceIndex), at: edgeIndex)
                    edgeIndex += 1
                    edgeIndices.insert(UInt32(targetIndex), at: edgeIndex)
                    edgeIndex += 1
                }
            }
        }
        return edgeIndices
    }
}
