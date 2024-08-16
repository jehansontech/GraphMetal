//
//  ZMonochromeWireframe.swift
//
//
//  Created by Jim Hanson on 8/10/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public class ZMonochromeWireframe: ObservableObject, ZWireframe {

    public let nodeShape: ZWireframeNodeShape

    @Published public var nodeSize: Float

    @Published public var graphColor: SIMD4<Float>

    public var defaultColor: SIMD4<Float> { graphColor }

    public private(set) var bbox: BoundingBox? = nil

    private var pendingUpdate: ZMonochromeWireframe.Update

    private var device: MTLDevice!

    private var nodePositionBufferIndex: Int { ZRenderConstants.nodePositionBufferIndex }

    private var nodeCount: Int = 0

    private var nodePositionBuffer: MTLBuffer? = nil

    private var edgeIndexCount: Int = 0

    private var edgeIndexBuffer: MTLBuffer? = nil

    private var edgePipelineState: MTLRenderPipelineState!

    private var nodePipelineState: MTLRenderPipelineState!

    public init(nodeShape: ZWireframeNodeShape = ZWireframeConstants.defaultNodeShape,
                nodeSize: Float = ZWireframeConstants.defaultNodeSize,
                graphColor: SIMD4<Float> = ZWireframeConstants.defaultElementColor) {
        self.nodeShape = nodeShape
        self.nodeSize = nodeSize
        self.graphColor = graphColor
        self.pendingUpdate = ZMonochromeWireframe.Update()
    }

    public func addUpdate(_ update: ZMonochromeWireframe.Update) {
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

            if self.nodeCount == 0 {
                self.nodePositionBuffer = nil
            }
            else {
                // We're replacing the buffer rather than modifying its contents
                // so that we don't have to deal with sync between CPU and GPU.

                let bufferLength = nodeCount * MemoryLayout<SIMD3<Float>>.size
                let bufferOptions: MTLResourceOptions = []
                self.nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                            length: bufferLength,
                                                            options: bufferOptions)
            }
        }

        if let newEdgeIndices = pendingUpdate.edgeIndices {
            pendingUpdate.edgeIndices = nil
            self.edgeIndexCount = newEdgeIndices.count

            if self.edgeIndexCount == 0 {
                self.edgeIndexBuffer = nil
            }
            else {
                // We're replacing the buffer rather than modifying its contents
                // so that we don't have to deal with sync between CPU and GPU.

                let bufferLength = edgeIndexCount * MemoryLayout<UInt32>.size
                let bufferOptions: MTLResourceOptions = []
                self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
                                                         length: bufferLength,
                                                         options: bufferOptions)
            }
        }
    }

    public func encodeCommands(_ encoder: MTLRenderCommandEncoder) {

        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            return
        }

        encoder.pushDebugGroup("MonochromeWireframe")
        encoder.setVertexBuffer(nodePositionBuffer,
                                offset: 0,
                                index: nodePositionBufferIndex)
        if let edgeIndexBuffer = self.edgeIndexBuffer {
            encoder.setRenderPipelineState(edgePipelineState)
            encoder.drawIndexedPrimitives(type: .line,
                                          indexCount: edgeIndexCount,
                                          indexType: MTLIndexType.uint32,
                                          indexBuffer: edgeIndexBuffer,
                                          indexBufferOffset: 0)
        }
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

        let nodeVertexFunctionName = "monochrome_node_vertex"
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

        public static func emptyGraph() -> Update {
            return Update(bbox: BoundingBox(.zero),
                          nodePositions: [],
                          edgeIndices: [])
        }
        
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
            self.bbox = nil
            self.nodePositions = nil
            self.edgeIndices = nil
        }

        public mutating func merge(_ other: Update) {
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

    public struct UpdateGenerator {

        public var defaultNodePosition: SIMD3<Float>

        private var buildNodePositions: Bool

        private var buildEdgeIndices: Bool

        private var graphID: GraphID? = nil

        /// key: nodeNumber, value: index in nodePositions array
        /// nodeIndexMap and nodePositions array are always built together
        private var nodeIndexMap = [Int: Int]()

        /// nodeIndexMap and nodePositions array are always built together
        private var nodePositions: [SIMD3<Float>]? = nil

        /// key is node number
        private var nodePositionChanges = [Int: SIMD3<Float>]()

        public init(defaultNodePosition: SIMD3<Float> = .zero) {
            self.defaultNodePosition = defaultNodePosition
            self.buildNodePositions = true
            self.buildEdgeIndices = true
        }

        public mutating func graphHasChanged<G: Graph>(_ graph: G,
                                                       nodeSet: Bool = false,
                                                       edgeSet: Bool = false,
                                                       nodePositions: Bool = false)
        where G.NodeType.ValueType : EmbeddedValue
        {
            if checkForNewGraph(graph.id) {
                return
            }
            if nodeSet || nodePositions {
                buildNodePositions = true
                buildEdgeIndices = true
                self.nodePositionChanges.removeAll()
            }
            if edgeSet {
                buildEdgeIndices = true
            }
        }

        /// key is nodeNumber
        public mutating func graphHasChanged<G: Graph>(_ graph: G,
                                                       nodePositionChanges: [Int: SIMD3<Float>]? = nil)
        where G.NodeType.ValueType : EmbeddedValue
        {
            if checkForNewGraph(graph.id) {
                return
            }
            if !buildNodePositions,
               let nodePositionChanges {
                self.nodePositionChanges.merge(nodePositionChanges, uniquingKeysWith: { (_, new) in new })
            }
        }

        public mutating func makeUpdate<G: Graph>(_ graph: G) -> Update
        where G.NodeType.ValueType : EmbeddedValue
        {
            checkForNewGraph(graph.id)

            let nodePositionsNeeded = !nodePositionChanges.isEmpty || buildEdgeIndices
            let nodePositionsBuilt = nodePositions != nil

            let newUpdate: Update
            if buildNodePositions || (nodePositionsNeeded && !nodePositionsBuilt) {
                newUpdate =  makeFullUpdate(graph)
            }
            else if !nodePositionChanges.isEmpty {
                newUpdate =  makeNodePositionUpdate(graph)
            }
            else if buildEdgeIndices {
                newUpdate =  makeEdgeUpdate(graph)
            }
            else {
                newUpdate =  makeNullUpdate()
            }

            updateMade()
            return newUpdate
        }

        /// If it's a new graph, sets flags for full update and returns true.
        @discardableResult private mutating func checkForNewGraph(_ graphID: GraphID) -> Bool {
            if self.graphID == nil || self.graphID != graphID {
                self.graphID = graphID
                buildNodePositions = true
                buildEdgeIndices = true
                self.nodePositionChanges.removeAll()
                return true
            }
            return false
        }

        private mutating func makeNullUpdate() -> Update {
            return Update()
        }

        private mutating func makeFullUpdate<G: Graph>(_ graph: G) -> Update
        where G.NodeType.ValueType : EmbeddedValue
        {
            var newNodeIndexMap = [Int: Int]()
            var newBBox = BoundingBox(firstNodePosition(graph))
            var newNodePositions = [SIMD3<Float>](repeating: defaultNodePosition, count: graph.nodes.count)

            var nodeIndex = 0
            for node in graph.nodes {
                newNodeIndexMap[node.nodeNumber] = nodeIndex
                if let position = node.value?.location {
                    newBBox.cover(position)
                    newNodePositions[nodeIndex] = position
                }
                nodeIndex += 1
            }
            self.nodeIndexMap = newNodeIndexMap
            self.nodePositions = newNodePositions

            let newEdgeIndices: [UInt32]? = self.buildEdgeIndices ? Self.makeEdgeIndices(graph, nodeIndexMap) : nil
            return Update(bbox: newBBox,
                          nodePositions: self.nodePositions,
                          edgeIndices: newEdgeIndices)
        }

        /// ASSUMES that nodePositions array is non-nil
        /// ASSUMES that nodeIndexMap is non-nil and correct
        private mutating func makeNodePositionUpdate<G: Graph>(_ graph: G) -> Update
        where G.NodeType.ValueType : EmbeddedValue
        {
            for (nodeNumber, posn) in self.nodePositionChanges {
                if let nodeIndex = nodeIndexMap[nodeNumber] {
                    nodePositions![nodeIndex] = posn
                }
            }

            var newBBox = BoundingBox(nodePositions!.first ?? .zero)
            for posn in nodePositions! {
                newBBox.cover(posn)
            }

            let newEdgeIndices: [UInt32]? = self.buildEdgeIndices ? Self.makeEdgeIndices(graph, nodeIndexMap) : nil
            return Update(bbox: newBBox,
                          nodePositions: self.nodePositions,
                          edgeIndices: newEdgeIndices)
        }

        /// ASSUMES that nodeIndexMap is non-nil and correct
        private mutating func makeEdgeUpdate<G: Graph>(_ graph: G) -> Update
        where G.NodeType.ValueType : EmbeddedValue
        {
            let newEdgeIndices = Self.makeEdgeIndices(graph, nodeIndexMap)
            return Update(edgeIndices: newEdgeIndices)
        }

        private mutating func updateMade() {
            self.buildNodePositions = false
            self.buildEdgeIndices = false
            self.nodePositionChanges.removeAll()
        }

        private func firstNodePosition<G: Graph>(_ graph: G) -> SIMD3<Float> 
        where G.NodeType.ValueType : EmbeddedValue
        {
            return graph.nodes.first?.value?.location ?? defaultNodePosition
        }

        private static func makeEdgeIndices<G: Graph>(_ graph: G, _ nodeIndexMap: [Int: Int]) -> [UInt32] {
            var edgeIndices = [UInt32]()
            var edgeIndex: Int = 0
            for node in graph.nodes {
                for edge in node.outEdges {
                    if let sourceIndex = nodeIndexMap[edge.source.nodeNumber],
                       let targetIndex = nodeIndexMap[edge.target.nodeNumber] {
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

    public struct BadUpdateGenerator<G: Graph> where G.NodeType.ValueType : EmbeddedValue {

        public var graph: G? {
            didSet {
                self.graphHasChanged(nodeSet: true)
            }
        }

        public var defaultNodePosition: SIMD3<Float>

        private var buildNodePositions: Bool = false

        private var buildEdgeIndices: Bool = false

        /// key: nodeNumber, value: index in nodePositions array
        /// nodeIndexMap and nodePositions array are always built together
        private var nodeIndexMap = [Int: Int]()

        /// nodeIndexMap and nodePositions array are always built together
        private var nodePositions: [SIMD3<Float>]? = nil

        /// key is node number
        private var nodePositionChanges = [Int: SIMD3<Float>]()

        public init(graph: G? = nil,
                    defaultNodePosition: SIMD3<Float> = .zero) {
            self.graph = graph
            self.defaultNodePosition = defaultNodePosition
            self.graphHasChanged(nodeSet: true)
        }

        public mutating func graphHasChanged(nodeSet: Bool = false,
                                             edgeSet: Bool = false,
                                             nodePositions: Bool = false) {
            if nodeSet || nodePositions {
                buildNodePositions = true
                buildEdgeIndices = true
                self.nodePositionChanges.removeAll()
            }
            if edgeSet {
                buildEdgeIndices = true
            }
        }

        /// key is nodeNumber
        public mutating func graphHasChanged(nodePositionChanges: [Int: SIMD3<Float>]? = nil) {
            if !buildNodePositions,
               let nodePositionChanges {
                self.nodePositionChanges.merge(nodePositionChanges, uniquingKeysWith: { (_, new) in new })
            }
        }

        public mutating func makeUpdate() -> Update {

            guard let graph = self.graph
            else {
                return makeNullUpdate()
            }

            let nodePositionsNeeded = !nodePositionChanges.isEmpty || buildEdgeIndices
            let nodePositionsBuilt = nodePositions != nil

            let newUpdate: Update
            if buildNodePositions || (nodePositionsNeeded && !nodePositionsBuilt) {
                newUpdate =  makeFullUpdate(graph)
            }
            else if !nodePositionChanges.isEmpty {
                newUpdate =  makeNodePositionUpdate(graph)
            }
            else if buildEdgeIndices {
                newUpdate =  makeEdgeUpdate(graph)
            }
            else {
                newUpdate =  makeNullUpdate()
            }

            updateMade()
            return newUpdate
        }

        private mutating func makeNullUpdate() -> Update {
            return Update()
        }

        private mutating func makeFullUpdate(_ graph: G) -> Update {
            var newNodeIndexMap = [Int: Int]()
            var newBBox = BoundingBox(firstNodePosition(graph))
            var newNodePositions = [SIMD3<Float>](repeating: defaultNodePosition, count: graph.nodes.count)

            var nodeIndex = 0
            for node in graph.nodes {
                newNodeIndexMap[node.nodeNumber] = nodeIndex
                if let position = node.value?.location {
                    newBBox.cover(position)
                    newNodePositions[nodeIndex] = position
                }
                nodeIndex += 1
            }
            self.nodeIndexMap = newNodeIndexMap
            self.nodePositions = newNodePositions

            let newEdgeIndices: [UInt32]? = self.buildEdgeIndices ? Self.makeEdgeIndices(graph, nodeIndexMap) : nil
            return Update(bbox: newBBox,
                          nodePositions: self.nodePositions,
                          edgeIndices: newEdgeIndices)
        }

        /// ASSUMES that nodePositions array is non-nil
        /// ASSUMES that nodeIndexMap is non-nil and correct
        private mutating func makeNodePositionUpdate(_ graph: G) -> Update {
            for (nodeNumber, posn) in self.nodePositionChanges {
                if let nodeIndex = nodeIndexMap[nodeNumber] {
                    nodePositions![nodeIndex] = posn
                }
            }

            var newBBox = BoundingBox(nodePositions!.first ?? .zero)
            for posn in nodePositions! {
                newBBox.cover(posn)
            }

            let newEdgeIndices: [UInt32]? = self.buildEdgeIndices ? Self.makeEdgeIndices(graph, nodeIndexMap) : nil
            return Update(bbox: newBBox,
                          nodePositions: self.nodePositions,
                          edgeIndices: newEdgeIndices)
        }

        /// ASSUMES that nodeIndexMap is non-nil and correct
        private mutating func makeEdgeUpdate(_ graph: G) -> Update {
            let newEdgeIndices = Self.makeEdgeIndices(graph, nodeIndexMap)
            return Update(edgeIndices: newEdgeIndices)
        }

        private mutating func updateMade() {
            self.buildNodePositions = false
            self.buildEdgeIndices = false
            self.nodePositionChanges.removeAll()
        }

        private func firstNodePosition(_ graph: G) -> SIMD3<Float> {
            return graph.nodes.first?.value?.location ?? defaultNodePosition
        }

        private static func makeEdgeIndices(_ graph: G, _ nodeIndexMap: [Int: Int]) -> [UInt32] {
            var edgeIndices = [UInt32]()
            var edgeIndex: Int = 0
            for node in graph.nodes {
                for edge in node.outEdges {
                    if let sourceIndex = nodeIndexMap[edge.source.nodeNumber],
                       let targetIndex = nodeIndexMap[edge.target.nodeNumber] {
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
}
