//
//  ZWireframeWithColoredNodes.swift
//  
//
//  Created by Jim Hanson on 8/10/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public class ZWireframeWithColoredNodes: ObservableObject, ZWireframe {

    public let nodeShape: ZWireframeNodeShape

    @Published public var nodeSize: Float

    @Published public var defaultElementColor: SIMD4<Float>

    public private(set) var bbox: BoundingBox? = nil

    private var pendingUpdate: ZWireframeWithColoredNodes.Update

    private var device: MTLDevice!

    private var nodePositionBufferIndex: Int { ZRenderConstants.nodePositionBufferIndex }

    private var nodeColorBufferIndex: Int { ZRenderConstants.nodeColorBufferIndex }

    private var edgeColorBufferIndex: Int { ZRenderConstants.edgeColorBufferIndex }

    private var nodeCount: Int = 0

    private var nodePositionBuffer: MTLBuffer? = nil

    private var edgeIndexCount: Int = 0

    private var edgeIndexBuffer: MTLBuffer? = nil

    private var nodeColorBuffer: MTLBuffer? = nil

    private var edgeColorBuffer: MTLBuffer? = nil

    private var edgePipelineState: MTLRenderPipelineState!

    private var nodePipelineState: MTLRenderPipelineState!

    public init(nodeShape: ZWireframeNodeShape = ZWireframeConstants.defaultNodeShape,
                nodeSize: Float = ZWireframeConstants.defaultNodeSize,
                defaultElementColor: SIMD4<Float> = ZWireframeConstants.defaultElementColor) {
        self.nodeShape = nodeShape
        self.nodeSize = nodeSize
        self.defaultElementColor = defaultElementColor
        self.pendingUpdate = ZWireframeWithColoredNodes.Update()
    }

    public func addUpdate(_ update: ZWireframeWithColoredNodes.Update) {
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

            let bufferLength = nodeCount * MemoryLayout<SIMD3<Float>>.size
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

        if let newNodeColors =  pendingUpdate.nodeColors {
            pendingUpdate.nodeColors = nil

            // TODO: sanity check newNodeColors.count == self.nodeCount

            let bufferLength = newNodeColors.count * MemoryLayout<SIMD4<Float>>.size
            let bufferOptions: MTLResourceOptions = []
            self.nodeColorBuffer = device.makeBuffer(bytes: newNodeColors,
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

        encoder.pushDebugGroup("ZWireframeWithColoredNodes")
        encoder.setVertexBuffer(nodePositionBuffer,
                                offset: 0,
                                index: nodePositionBufferIndex)
        encoder.setVertexBuffer(nodeColorBuffer,
                                offset: 0,
                                index: nodeColorBufferIndex)
        encoder.setRenderPipelineState(edgePipelineState)
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

        let edgeVertexFunctionName = "monochrome_edge_vertex"
        let edgeFragmentFunctionName = "edge_fragment"

        guard let vertexFunction = library.makeFunction(name: edgeVertexFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: edgeVertexFunctionName)
        }

        guard let fragmentFunction = library.makeFunction(name: edgeFragmentFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: edgeFragmentFunctionName)
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

        let nodeVertexFunctionName = "colored_node_vertex"
        let nodeFragmentFunctionName = nodeShape.fragmentFunctionName

        guard let vertexFunction = library.makeFunction(name: nodeVertexFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: nodeVertexFunctionName)
        }

        guard let fragmentFunction = library.makeFunction(name: nodeFragmentFunctionName)
        else {
            throw ZRenderError.noSuchFunction(name: nodeFragmentFunctionName)
        }

        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = nodePositionBufferIndex

        vertexDescriptor.layouts[nodePositionBufferIndex].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[nodePositionBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodePositionBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].format = MTLVertexFormat.float4
        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].bufferIndex = nodeColorBufferIndex

        vertexDescriptor.layouts[nodeColorBufferIndex].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[nodeColorBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodeColorBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

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

    public struct Update: Sendable {

        public var bbox: BoundingBox?

        public var nodePositions: [SIMD3<Float>]?

        /// Interleaved (source, target) pairs where each value is an index into nodePositions array.
        public var edgeIndices: [UInt32]?

        public var nodeColors: [SIMD4<Float>]?

        init(bbox: BoundingBox? = nil,
             nodePositions: [SIMD3<Float>]? = nil,
             edgeIndices: [UInt32]? = nil,
             nodeColors: [SIMD4<Float>]? = nil) {
            self.bbox = bbox
            self.nodePositions = nodePositions
            self.edgeIndices = edgeIndices
            self.nodeColors = nodeColors
        }
    }
}

extension ZWireframeWithColoredNodes.Update {

    public mutating func clear() {
        bbox = nil
        nodePositions = nil
        edgeIndices = nil
        nodeColors = nil
    }

    public mutating func merge(_ other: ZWireframeWithColoredNodes.Update) {
        if let newBBox = other.bbox {
            self.bbox = newBBox
        }
        if let newNodePositions = other.nodePositions {
            self.nodePositions = newNodePositions
        }
        if let newEdgeIndices = other.edgeIndices {
            self.edgeIndices = newEdgeIndices
        }
        if let newNodeColors = other.nodeColors {
            self.nodeColors = newNodeColors
        }
    }

    /// Call this if node set has changed.
    public static func makeTotalUpdate<G: Graph>(_ graph: G) -> ZWireframeWithColoredNodes.Update
    where G.NodeType.ValueType: EmbeddedValue & ColoredValue
    {

        // key is nodeNumber in graph, value is index into self.nodePositions array
        var nodeIndexMap = [Int: Int]()

        var newBBox: BoundingBox? = nil
        var newNodePositions = [SIMD3<Float>]()
        var newNodeColors = [SIMD4<Float>]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            nodeIndexMap[node.nodeNumber] = nodeIndex

            let nodePosition = node.value?.location ?? .zero
            newNodePositions.insert(nodePosition, at: nodeIndex)

            let nodeColor = node.value?.color ?? ZWireframeConstants.defaultElementColor
            newNodeColors.insert(nodeColor, at: nodeIndex)

            if newBBox == nil {
                newBBox = BoundingBox(nodePosition)
            }
            else {
                newBBox!.cover(nodePosition)
            }

            nodeIndex += 1
        }

        var newEdgeIndices = [UInt32]()
        var edgeIndicesIndex: Int = 0 // index into newEdgeIndices array
        for node in graph.nodes {
            for edge in node.outEdges {
                if let sourceIndex = nodeIndexMap[edge.source.nodeNumber],
                   let targetIndex = nodeIndexMap[edge.target.nodeNumber] {
                    newEdgeIndices.insert(UInt32(sourceIndex), at: edgeIndicesIndex)
                    edgeIndicesIndex += 1
                    newEdgeIndices.insert(UInt32(targetIndex), at: edgeIndicesIndex)
                    edgeIndicesIndex += 1
                }
            }
        }

        return ZWireframeWithColoredNodes.Update(bbox: newBBox,
                                                nodePositions: newNodePositions,
                                                edgeIndices: newEdgeIndices,
                                                nodeColors: newNodeColors)
    }
}
