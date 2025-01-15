//
//  ColoredNodeWireframe.swift
//
//
//  Created by Jim Hanson on 8/10/24.
//

import simd
import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public class ColoredNodeWireframe: ObservableObject, Wireframe {

    public var firstAvailableBufferIndex: Int { 3 }
    
    public let nodeShape: WireframeNodeShape

    @Published public var nodeSize: Float

    @Published public var edgeColor: SIMD4<Float>

    public var defaultColor: SIMD4<Float> { edgeColor }

    public private(set) var bbox: BoundingBox? = nil

    private var pendingUpdate: ColoredNodeWireframe.Update

    private var device: MTLDevice!

    private let nodePositionBufferIndex: Int

    private let nodeColorBufferIndex: Int

    private var nodeCount: Int = 0

    private var nodePositionBuffer: MTLBuffer? = nil

    private var edgeIndexCount: Int = 0

    private var edgeIndexBuffer: MTLBuffer? = nil

    private var nodeColorBuffer: MTLBuffer? = nil

    private var edgeColorBuffer: MTLBuffer? = nil

    private var edgePipelineState: MTLRenderPipelineState!

    private var nodePipelineState: MTLRenderPipelineState!

    public init(nodeShape: WireframeNodeShape = WireframeConstants.defaultNodeShape,
                nodeSize: Float = WireframeConstants.defaultNodeSize,
                edgeColor: SIMD4<Float> = WireframeConstants.defaultElementColor) {
        self.nodeShape = nodeShape
        self.nodeSize = nodeSize
        self.edgeColor = edgeColor
        self.pendingUpdate = ColoredNodeWireframe.Update()
        self.nodePositionBufferIndex = RenderConstants.nodePositionBufferIndex
        self.nodeColorBufferIndex = RenderConstants.nodeColorBufferIndex
    }

    public func addUpdate(_ update: ColoredNodeWireframe.Update) {
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

        if let newNodeColors =  pendingUpdate.nodeColors {
            pendingUpdate.nodeColors = nil

            // TODO: sanity check newNodeColors.count == self.nodeCount

            if self.nodeCount == 0 {
                self.nodeColorBuffer = nil
            }
            else {
                // We're replacing the buffer rather than modifying its contents
                // so that we don't have to deal with sync between CPU and GPU.

                let bufferLength = newNodeColors.count * MemoryLayout<SIMD4<Float>>.size
                let bufferOptions: MTLResourceOptions = []
                self.nodeColorBuffer = device.makeBuffer(bytes: newNodeColors,
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

                let bufferLength = newEdgeIndices.count * MemoryLayout<UInt32>.size
                let bufferOptions: MTLResourceOptions = []
                self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
                                                         length: bufferLength,
                                                         options: bufferOptions)
            }
        }
    }

    //    private var drawCount: Int = 0

    public func encodeCommands(_ encoder: MTLRenderCommandEncoder) {
        //        drawCount += 1

        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            // Messages.debug("ColoredNodeWireframe.encodeCommands", "Aborting because nodePositionBuffer is nil")
            return
        }

        guard
            let nodeColorBuffer = self.nodeColorBuffer
        else {
            // Messages.debug("ColoredNodeWireframe.encodeCommands", "Aborting because nodeColorBuffer is nil")
            return
        }

        encoder.pushDebugGroup("ColoredNodeWireframe")
        encoder.setVertexBuffer(nodePositionBuffer,
                                offset: 0,
                                index: nodePositionBufferIndex)
        encoder.setVertexBuffer(nodeColorBuffer,
                                offset: 0,
                                index: nodeColorBufferIndex)

        if let edgeIndexBuffer = self.edgeIndexBuffer {
            //        if drawCount == 1 {
            //            print("ColoredNodeWireframe.encodeCommands: doing edges")
            //        }

            encoder.setRenderPipelineState(edgePipelineState)
            encoder.drawIndexedPrimitives(type: .line,
                                          indexCount: edgeIndexCount,
                                          indexType: MTLIndexType.uint32,
                                          indexBuffer: edgeIndexBuffer,
                                          indexBufferOffset: 0)
        }

        //        if drawCount == 1 {
        //            print("ColoredNodeWireframe.encodeCommands: doing nodes")
        //        }

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
            throw RenderError.noSuchFunction(name: edgeVertexFunctionName)
        }

        guard let fragmentFunction = library.makeFunction(name: edgeFragmentFunctionName)
        else {
            throw RenderError.noSuchFunction(name: edgeFragmentFunctionName)
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
            throw RenderError.noSuchFunction(name: nodeVertexFunctionName)
        }

        guard let fragmentFunction = library.makeFunction(name: nodeFragmentFunctionName)
        else {
            throw RenderError.noSuchFunction(name: nodeFragmentFunctionName)
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

        public static func emptyGraph() -> Update {
            return Update(bbox: BoundingBox(.zero),
                          nodePositions: [],
                          edgeIndices: [],
                          nodeColors: [])
        }

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

        public mutating func clear() {
            bbox = nil
            nodePositions = nil
            edgeIndices = nil
            nodeColors = nil
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
            if let newNodeColors = other.nodeColors {
                self.nodeColors = newNodeColors
            }
        }
    }

    public struct UpdateGenerator {

        public var defaultNodePosition: SIMD3<Float>

        public var defaultNodeColor: SIMD4<Float>

        private var buildNodePositions: Bool

        private var buildEdgeIndices: Bool

        private var buildNodeColors: Bool

        private var graphID: GraphID? = nil

        /// key: nodeNumber, value: index into nodePositions and nodeColors arrays
        /// nodeIndexMap, nodePositions, and nodeColors arrays are always built together
        private var nodeIndexMap = [Int: Int]()

        /// nodeIndexMap, nodePositions, and nodeColors arrays are always built together
        private var nodePositions: [SIMD3<Float>]? = nil

        /// nodeIndexMap, nodePositions, and nodeColors arrays are always built together
        private var nodeColors: [SIMD4<Float>]? = nil

        /// key is nodeNumber
        private var nodePositionChanges = [Int: SIMD3<Float>]()

        /// key is nodeNumber
        private var nodeColorChanges = [Int: SIMD4<Float>]()

        public init(defaultNodePosition: SIMD3<Float> = .zero,
                    defaultNodeColor: SIMD4<Float> = .zero) {
            self.defaultNodePosition = defaultNodePosition
            self.defaultNodeColor = defaultNodeColor
            self.buildNodePositions = true
            self.buildEdgeIndices = true
            self.buildNodeColors = true
        }

        public mutating func graphHasChanged<G: Graph>(_ graph: G,
                                                       nodeSet: Bool = false,
                                                       edgeSet: Bool = false,
                                                       nodePositions: Bool = false,
                                                       nodeColors: Bool = false)
        where G.NodeType.ValueType : EmbeddedValue & ColoredValue
        {
            if checkForNewGraph(graph.id) {
                return
            }
            if nodeSet || nodePositions || nodeColors {
                buildNodePositions = true
                buildEdgeIndices = true
                buildNodeColors = true
                self.nodePositionChanges.removeAll()
                self.nodeColorChanges.removeAll()
            }
            if edgeSet {
                buildEdgeIndices = true
            }
        }

        /// key is nodeNumber in both maps
        public mutating func graphHasChanged<G: Graph>(_ graph: G,
                                                       nodePositionChanges: [Int: SIMD3<Float>]? = nil,
                                                       nodeColorChanges: [Int: SIMD4<Float>]? = nil)
        where G.NodeType.ValueType : EmbeddedValue & ColoredValue
        {
            if checkForNewGraph(graph.id) {
                return
            }
            if buildNodePositions {
                // We're going to be building nodePositions and nodeColors
                // arrays directly from the graph so the args are ignorable.
                return
            }
            if let nodePositionChanges {
                self.nodePositionChanges.merge(nodePositionChanges, uniquingKeysWith: { (_, new) in new })
            }
            if let nodeColorChanges {
                self.nodeColorChanges.merge(nodeColorChanges, uniquingKeysWith: { (_, new) in new })
            }
        }

        public mutating func makeUpdate<G: Graph>(_ graph: G) -> Update 
        where G.NodeType.ValueType : EmbeddedValue & ColoredValue
        {
            checkForNewGraph(graph.id)

            let nodePositionsNeeded = !nodePositionChanges.isEmpty || buildEdgeIndices
            let nodePositionsBuilt = nodePositions != nil
            let nodeColorsNeeded = !nodeColorChanges.isEmpty
            let nodeColorsBuilt = nodeColors != nil

            let newUpdate: Update
            if buildNodePositions ||
                (nodePositionsNeeded && !nodePositionsBuilt) ||
                (nodeColorsNeeded && !nodeColorsBuilt) {
                newUpdate = makeFullUpdate(graph)
            }
            else if !nodePositionChanges.isEmpty || !nodeColorChanges.isEmpty {
                newUpdate = makeNodePropertiesUpdate(graph)
            }
            else if buildEdgeIndices {
                newUpdate = makeEdgeUpdate(graph)
            }
            else {
                newUpdate = makeNullUpdate()
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
                buildNodeColors = true
                self.nodePositionChanges.removeAll()
                self.nodeColorChanges.removeAll()
                return true
            }
            return false
        }
        private mutating func makeNullUpdate() -> Update {
            return Update()
        }

        private mutating func makeFullUpdate<G: Graph>(_ graph: G) -> Update
        where G.NodeType.ValueType : EmbeddedValue & ColoredValue
        {
            var newNodeIndexMap = [Int: Int]()
            var newBBox = BoundingBox(firstNodePosition(graph))
            var newNodePositions = [SIMD3<Float>](repeating: defaultNodePosition, count: graph.nodes.count)
            var newNodeColors = [SIMD4<Float>](repeating: defaultNodeColor, count: graph.nodes.count)

            var nodeIndex = 0
            for node in graph.nodes {
                newNodeIndexMap[node.nodeNumber] = nodeIndex
                if let position = node.value?.location {
                    newBBox.cover(position)
                    newNodePositions[nodeIndex] = position
                }
                if let color = node.value?.color {
                    newNodeColors[nodeIndex] = color
                }
                nodeIndex += 1
            }
            self.nodeIndexMap = newNodeIndexMap
            self.nodePositions = newNodePositions
            self.nodeColors = newNodeColors

            let newEdgeIndices: [UInt32]? = self.buildEdgeIndices ? Self.makeEdgeIndices(graph, nodeIndexMap) : nil
            return Update(bbox: newBBox,
                          nodePositions: self.nodePositions,
                          edgeIndices: newEdgeIndices,
                          nodeColors: newNodeColors)
        }

        /// ASSUMES that nodeIndexMap is non-nil and correct
        /// ASSUMES that nodePositions is non-nil
        /// ASSUMES that nodeColors is non-nil
        private mutating func makeNodePropertiesUpdate<G: Graph>(_ graph: G) -> Update
        where G.NodeType.ValueType : EmbeddedValue & ColoredValue
        {

            let newBBox: BoundingBox?
            let newNodePositions: [SIMD3<Float>]?
            if self.nodePositionChanges.isEmpty {
                newBBox = nil
                newNodePositions = nil
            }
            else {
                for (nodeNumber, posn) in self.nodePositionChanges {
                    if let nodeIndex = nodeIndexMap[nodeNumber] {
                        nodePositions![nodeIndex] = posn
                    }
                }

                var bbox = BoundingBox(nodePositions!.first ?? .zero)
                for posn in nodePositions! {
                    bbox.cover(posn)
                }

                newBBox = bbox
                newNodePositions = self.nodePositions
            }

            let newNodeColors: [SIMD4<Float>]?
            if self.nodeColorChanges.isEmpty {
                newNodeColors = nil
            }
            else {
                for (nodeNumber, color) in self.nodeColorChanges {
                    if let nodeIndex = nodeIndexMap[nodeNumber] {
                        nodeColors![nodeIndex] = color
                    }
                }
                newNodeColors = self.nodeColors
            }

            let newEdgeIndices: [UInt32]? = self.buildEdgeIndices ? Self.makeEdgeIndices(graph, nodeIndexMap) : nil
            return Update(bbox: newBBox,
                          nodePositions: newNodePositions,
                          edgeIndices: newEdgeIndices,
                          nodeColors: newNodeColors)
        }

        /// ASSUMES that nodeIndexMap is non-nil and correct
        private mutating func makeEdgeUpdate<G: Graph>(_ graph: G) -> Update {
            let newEdgeIndices = Self.makeEdgeIndices(graph, nodeIndexMap)
            return Update(edgeIndices: newEdgeIndices)
        }

        private mutating func updateMade() {
            self.buildNodePositions = false
            self.buildEdgeIndices = false
            self.buildNodeColors = false
            self.nodePositionChanges.removeAll()
            self.nodeColorChanges.removeAll()
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
}
