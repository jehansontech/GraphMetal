//
//  GraphWireframe.swift
//  GraphMetal
//


import SwiftUI
import Metal
import MetalKit
import GenericGraph
import Shaders
import Wacoma

public class GraphWireframeSettings: ObservableObject {

    /// EMPIRICAL
    static let nodeSizeScaleFactor: Double = 800

    public static let defaults = GraphWireframeSettings()

    /// indicates whether node size should be automatically adjusted when the POV changes
    public var nodeSizeIsAdjusted: Bool

    /// Default node size, i.e.,  width in pixels of the node's dot. Ignored if nodeSizeAutomatic is true
    public var nodeSizeDefault: Double

    /// Minimum automatic node size. Ignored if nodeSizeIsAdjusted is false
    public var nodeSizeMinimum: Double

    /// Maximum automatic node size. Ignored if nodeSizeIsAdjusted is false
    public var nodeSizeMaximum: Double

    /// Color to use when node value's color is nil.
    public var nodeColorDefault: SIMD4<Float>

    public var edgeColor: SIMD4<Float>

    public init(nodeSizeIsAdjusted: Bool = true,
                nodeSizeDefault: Double = 16,
                nodeSizeMinimum: Double = 2,
                nodeSizeMaximum: Double = 32,
                nodeColorDefault: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0),
                edgeColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1)) {
        self.nodeSizeIsAdjusted = nodeSizeIsAdjusted
        self.nodeSizeDefault = nodeSizeDefault
        self.nodeSizeMinimum = nodeSizeMinimum
        self.nodeSizeMaximum = nodeSizeMaximum
        self.nodeColorDefault = nodeColorDefault
        self.edgeColor = edgeColor
    }

    public func reset() {
        self.nodeSizeIsAdjusted = Self.defaults.nodeSizeIsAdjusted
        self.nodeSizeDefault = Self.defaults.nodeSizeDefault
        self.nodeSizeMinimum = Self.defaults.nodeSizeMinimum
        self.nodeSizeMaximum = Self.defaults.nodeSizeMaximum
        self.nodeColorDefault = Self.defaults.nodeColorDefault
        self.edgeColor = Self.defaults.edgeColor
    }

    func nodeSize(forPOV pov: POV) -> Double {
        if nodeSizeIsAdjusted {
            let newSize = Self.nodeSizeScaleFactor / Double(pov.radius)
            return newSize.clamp(nodeSizeMinimum, nodeSizeMaximum)
        }
        else {
            return nodeSizeDefault
        }
    }
}


public class GraphWireframe<N: RenderableNodeValue, E: RenderableEdgeValue> {

    typealias NodeValueType = N

    typealias EdgeValueType = E

    // ==============================================================
    // Rendering properties -- Access these only on rendering thread

    weak var settings: GraphWireframeSettings!

    var device: MTLDevice

    var library: MTLLibrary

    var nodePipelineState: MTLRenderPipelineState!

    var nodeCount: Int = 0

    var nodePositionBuffer: MTLBuffer? = nil

    var nodeColorBuffer: MTLBuffer? = nil

    var edgePipelineState: MTLRenderPipelineState!

    var edgeIndexCount: Int = 0

    var edgeIndexBuffer: MTLBuffer? = nil

    var dynamicUniformBuffer: MTLBuffer!

    var uniformBufferOffset = 0

    var uniformBufferIndex = 0

    var uniforms: UnsafeMutablePointer<Uniforms>!

    // ==============================================================
    // Derived graph properties -- Access only on graph-update thread

    private var nodeIndices = [NodeID: Int]()

    // ==========================================
    // Shared properties -- Written on graph-update thread, read on rendering thread

    private var bufferUpdate: BufferUpdate? = nil


    // ==============================================================

    init(_ device: MTLDevice, _ settings: GraphWireframeSettings) throws {
        debug("GraphWireframe.init", "started")
        if let library = Shaders.makeLibrary(device) {
            self.library = library
        }
        else {
            throw RendererError.noDefaultLibrary
        }

        self.device = device
        self.settings = settings
        debug("GraphWireframe.init", "done")
    }

    deinit {
        debug("GraphWireframe", "deinit")
    }

    func setup(_ view: MTKView) throws {
        debug("GraphWireframe", "setup. library functions: \(library.functionNames)")

        if dynamicUniformBuffer == nil {
            try buildUniforms()
        }

        if nodePipelineState == nil {
            try buildNodePipeline(view)
        }

        if edgePipelineState == nil {
            try buildEdgePipeline(view)
        }
    }

    func teardown() {
        debug("GraphWireframe", "teardown")
        // TODO: maybe dynamicUniformBuffer and uniforms ... if so change declarations from ! to ?
        // TODO: maybe nodePipelineState ... ditto
        // TODO: maybe edgePipelineState ... ditto
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    // runs on background thread
    func graphHasChanged<G: Graph>(_ graph: G, _ change: RenderableGraphChange) where
        G.NodeType.ValueType == NodeValueType,
        G.EdgeType.ValueType == EdgeValueType {

        // debug("GraphWireframe", "graphHasChanged: started. bufferUpdate=\(String(describing: bufferUpdate))")

        if change.nodes {
            self.bufferUpdate = self.prepareTopologyUpdate(graph)
        }
        else {
            var newPositions: [SIMD3<Float>]? = nil
            var newColors: [NodeID : SIMD4<Float>]? = nil

            if change.nodePositions {
                newPositions = self.makeNodePositions(graph)
            }

            if change.nodeColors {
                newColors = graph.makeNodeColors()
            }

            if (newPositions != nil || newColors != nil) {
                self.bufferUpdate = BufferUpdate(nodeCount: self.nodeCount,
                                                 nodePositions: newPositions,
                                                 nodeColors: newColors,
                                                 edgeIndexCount: self.edgeIndexCount,
                                                 edgeIndices: nil)
            }
        }

//        if self.bufferUpdate != nil {
//            debug("GraphWireframe", "graphHasChanged: done. bufferUpdate=\(String(describing: bufferUpdate))")
//        }
    }

    /// Runs on rendering thread
    func applyUpdate() {

        guard
            let update = self.bufferUpdate
        else {
            // debug("GraphWireframe", "No bufferUpdate to apply")
            return
        }

        debug("GraphWireframe", "applying bufferUpdate")
        self.bufferUpdate = nil

        if self.nodeCount != update.nodeCount {
            debug("GraphWireframe", "updating nodeCount: \(nodeCount) -> \(update.nodeCount)")
                nodeCount = update.nodeCount
        }

        if nodeCount == 0 {
            if nodePositionBuffer != nil {
                debug("GraphWireframe", "discarding nodePositionBuffer")
                nodePositionBuffer = nil
            }
        }
        else if let newNodePositions = update.nodePositions {
            if newNodePositions.count != nodeCount {
                fatalError("Failed sanity check: nodeCount=\(nodeCount) but newNodePositions.count=\(newNodePositions.count)")
            }

            debug("GraphWireframe", "creating nodePositionBuffer")
            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
            nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                   length: nodePositionBufLen,
                                                   options: [])
        }

        if nodeCount == 0 {
            if nodeColorBuffer != nil {
                debug("GraphWireframe", "discarding nodeColorBuffer")
                nodeColorBuffer = nil
            }
        }
        else if let newNodeColors = update.nodeColors {

            let defaultColor = settings.nodeColorDefault
            var colorsArray = [SIMD4<Float>](repeating: defaultColor, count: nodeCount)
            for (nodeID, color) in newNodeColors {
                if let nodeIndex = nodeIndices[nodeID] {
                    colorsArray[nodeIndex] = color
                }
            }

            debug("GraphWireframe", "creating nodeColorBuffer")
            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
            nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                length: nodeColorBufLen,
                                                options: [])
        }

        if self.edgeIndexCount != update.edgeIndexCount {
            debug("GraphWireframe", "updating edgeIndexCount: \(edgeIndexCount) -> \(update.edgeIndexCount)")
            self.edgeIndexCount = update.edgeIndexCount
        }

        if edgeIndexCount == 0 {
            if edgeIndexBuffer != nil {
                debug("GraphWireframe", "discarding edgeIndexBuffer")
                self.edgeIndexBuffer = nil
            }
        }
        else if let newEdgeIndices = update.edgeIndices {
            if newEdgeIndices.count != edgeIndexCount {
                fatalError("Failed sanity check: edgeIndexCount=\(edgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
            }

            debug("GraphWireframe", "creating edgeIndexBuffer")
            let bufLen = newEdgeIndices.count * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices, length: bufLen)
        }
    }

    func preDraw(projectionMatrix: float4x4,
                 modelViewMatrix: float4x4,
                 pov: POV,
                 fadeoutOnset: Float,
                 fadeoutDistance: Float) {

        // ======================================
        // Rotate the uniforms buffers

        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight

        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        // =====================================
        // Update content of current uniforms buffer

        uniforms[0].projectionMatrix = projectionMatrix
        uniforms[0].modelViewMatrix = modelViewMatrix
        uniforms[0].pointSize = Float(settings.nodeSize(forPOV: pov))
        uniforms[0].edgeColor = settings.edgeColor
        uniforms[0].fadeoutOnset = fadeoutOnset
        uniforms[0].fadeoutDistance = fadeoutDistance
    }

    func encodeCommands(_ renderEncoder: MTLRenderCommandEncoder) {
        // _drawCount += 1
        // debug("GraphWireframe.encodeCommands[\(_drawCount)]")

        applyUpdate()

        // If we don't have node positions we can't draw either nodes or edges.
        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            return
        }

        renderEncoder.setVertexBuffer(dynamicUniformBuffer,
                                      offset:uniformBufferOffset,
                                      index: BufferIndex.uniforms.rawValue)
        renderEncoder.setFragmentBuffer(dynamicUniformBuffer,
                                        offset:uniformBufferOffset,
                                        index: BufferIndex.uniforms.rawValue)
        renderEncoder.setVertexBuffer(nodePositionBuffer,
                                      offset: 0,
                                      index: BufferIndex.nodePosition.rawValue)

        if let nodeColorBuffer = self.nodeColorBuffer {
            renderEncoder.pushDebugGroup("Draw Nodes")
            renderEncoder.setRenderPipelineState(nodePipelineState)
            renderEncoder.setVertexBuffer(nodeColorBuffer,
                                          offset: 0,
                                          index: BufferIndex.nodeColor.rawValue)
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
            renderEncoder.popDebugGroup()
        }

        if let edgeIndexBuffer = self.edgeIndexBuffer {
            renderEncoder.pushDebugGroup("Draw Edges")
            renderEncoder.setRenderPipelineState(edgePipelineState)
            renderEncoder.drawIndexedPrimitives(type: .line,
                                                indexCount: edgeIndexCount,
                                                indexType: MTLIndexType.uint32,
                                                indexBuffer: edgeIndexBuffer,
                                                indexBufferOffset: 0)
            renderEncoder.popDebugGroup()
        }

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

    private func buildUniforms() throws {
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        if let buffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
            self.dynamicUniformBuffer = buffer
            self.dynamicUniformBuffer.label = "UniformBuffer"
            self.uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        }
        else {
            throw RendererError.bufferCreationFailed
        }
    }

    private func buildNodePipeline(_ view: MTKView) throws {

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

        // These are for fadeout of the nodes
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        // I'm guessing that these might help with other things that get drawn on top
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        self.nodePipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func buildEdgePipeline(_ view: MTKView) throws {

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

        // These are for fadeout of the edges
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

        // I'm guessing that these might help with other things that get drawn on top
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        edgePipelineState =  try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
}

struct BufferUpdate {
    let nodeCount: Int
    let nodePositions: [SIMD3<Float>]?
    let nodeColors: [NodeID: SIMD4<Float>]?
    let edgeIndexCount: Int
    let edgeIndices: [UInt32]?
}