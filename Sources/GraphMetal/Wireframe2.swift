//
//  Wireframe2.swift
//
//
//  Created by Jim Hanson on 9/21/22.
//

import Foundation
import SwiftUI
import Metal
import MetalKit
import Wacoma
import GenericGraph

public class Wireframe2: Renderable {

    let referenceDate = Date()

    /// The 256 byte aligned size of our uniform structure
    let alignedUniformsSize = (MemoryLayout<WireframeUniforms>.size + 0xFF) & -0x100

    public var settings: WireframeSettings

    var bbox: BoundingBox? = nil

    weak var device: MTLDevice!

    var library: MTLLibrary!

    var nodePipelineState: MTLRenderPipelineState!

    var nodeCount: Int = 0

    var nodePositionBufferIndex: Int = WireframeBufferIndex.nodePosition.rawValue

    var nodePositionBuffer: MTLBuffer? = nil

    var nodeColorBufferIndex: Int = WireframeBufferIndex.nodeColor.rawValue

    var nodeColorBuffer: MTLBuffer? = nil

    var nodeFragmentFunctionName: String {
        switch (settings.nodeStyle) {
        case .dot:
            return "node_fragment_dot"
        case .ring:
            return "node_fragment_ring"
        case .square:
            return "node_fragment_square"
        case .diamond:
            return "node_fragment_diamond"
        default:
            return "node_fragment_square"
        }
    }

    var edgePipelineState: MTLRenderPipelineState!

    var edgeIndexCount: Int = 0

    var edgeIndexBuffer: MTLBuffer? = nil

    var dynamicUniformBufferIndex: Int = WireframeBufferIndex.uniforms.rawValue

    var dynamicUniformBuffer: MTLBuffer!

    var uniformBufferOffset = 0

    var uniformBufferIndex = 0

    var uniforms: UnsafeMutablePointer<WireframeUniforms>!

    private var isSetup: Bool = false

    private var bufferUpdate: WireframeUpdate2? = nil

    private var pulsePhase: Float {
        let millisSinceReferenceDate = Int(Date().timeIntervalSince(referenceDate) * 1000)
        return 0.001 * Float(millisSinceReferenceDate % 1000)
    }

    public init() {
        self.settings = WireframeSettings()
    }

    public init(_ initialSettings: WireframeSettings) {
        self.settings = initialSettings
    }

    deinit {
        // debug("Wireframe2.deinit", "started")
    }

    func setup(_ view: MTKView) throws {
        // debug("Wireframe2.setup", "started")

        if let device = view.device {
            self.device = device
        }
        else {
            throw RenderError.noDevice
        }

        if let device = view.device,
           let library = WireframeShaders.makeLibrary(device) {
            self.library = library
            // debug("Wireframe2.setup", "library functions: \(library.functionNames)")
        }
        else {
            throw RenderError.noDefaultLibrary
        }

        if dynamicUniformBuffer == nil {
            try buildUniforms()
        }

        if nodePipelineState == nil {
            try buildNodePipeline(view)
        }

        if edgePipelineState == nil {
            try buildEdgePipeline(view)
        }

        //        updateFigure(.all)
        //        NotificationCenter.default.addObserver(self, selector: #selector(graphHasChanged), name: .graphHasChanged, object: nil)
        isSetup = true
    }

    func teardown() {
        // debug("Wireframe2.teardown", "started")
        // TODO: maybe dynamicUniformBuffer and uniforms ... if so change declarations from ! to ?
        // TODO: maybe nodePipelineState ... ditto
        // TODO: maybe edgePipelineState ... ditto
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    public func addBufferUpdate(_ bufferUpdate: WireframeUpdate2?) {
        if self.bufferUpdate == nil {
            // print("Wireframe2.updateBuffers: replacing bufferUpdate")
            self.bufferUpdate = bufferUpdate
        }
        else if let bufferUpdate {
            // print("Wireframe2.updateBuffers: merging bufferUpdate")
            self.bufferUpdate!.merge(bufferUpdate)
        }
    }
    
    public func updateBuffers(_ bufferUpdate: WireframeUpdate2) {
        if self.bufferUpdate == nil {
            // print("Wireframe2.updateBuffers: replacing bufferUpdate")
            self.bufferUpdate = bufferUpdate
        }
        else {
            // print("Wireframe2.updateBuffers: merging bufferUpdate")
            self.bufferUpdate!.merge(bufferUpdate)
        }
    }

    public func prepareToDraw(_ mtkView: MTKView, _ renderSettings: Wacoma.RenderSettings) {
        // print("prepareToDraw -- started. renderSettings=\(renderSettings)")
        if !isSetup {
            do {
                try setup(mtkView)
            }
            catch {
                fatalError("Problem in setup: \(error)")
            }
        }

        // ======================================
        // Rotate the uniforms buffers

        uniformBufferIndex = (uniformBufferIndex + 1) % Renderer.maxBuffersInFlight

        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:WireframeUniforms.self, capacity:1)

        // =====================================
        // Update content of current uniforms buffer
        //
        // NOTE uniforms.modelViewMatrix is equal to renderSettings.viewMatrix
        // because we are drawing the graph in world coordinates, i.e., our model
        // matrix is the identity.

        uniforms[0].projectionMatrix = renderSettings.projectionMatrix
        uniforms[0].modelViewMatrix = renderSettings.viewMatrix
        uniforms[0].pointSize = Float(self.settings.getNodeSize(forPOV: renderSettings.pov, bbox: self.bbox))
        uniforms[0].edgeColor = self.settings.edgeColor
        uniforms[0].fadeoutMidpoint = renderSettings.fadeoutMidpoint
        uniforms[0].fadeoutDistance = renderSettings.fadeoutDistance
        uniforms[0].pulsePhase = pulsePhase

        // =====================================
        // Possibly update contents of the other buffers

        applyBufferUpdateIfPresent()
    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
        // _drawCount += 1
        // debug("Wireframe2.encodeDrawCommands[\(_drawCount)]")

        // Do the uniforms no matter what.

        encoder.setVertexBuffer(dynamicUniformBuffer,
                                offset:uniformBufferOffset,
                                index: dynamicUniformBufferIndex)
        encoder.setFragmentBuffer(dynamicUniformBuffer,
                                  offset:uniformBufferOffset,
                                  index: dynamicUniformBufferIndex)

        // If we don't have node positions we can't draw either nodes or edges
        // so we should return early.
        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            return
        }

        encoder.setVertexBuffer(nodePositionBuffer,
                                offset: 0,
                                index: nodePositionBufferIndex)

        if let edgeIndexBuffer = self.edgeIndexBuffer {
            encoder.pushDebugGroup("Edges")
            encoder.setRenderPipelineState(edgePipelineState)
            encoder.drawIndexedPrimitives(type: .line,
                                          indexCount: edgeIndexCount,
                                          indexType: MTLIndexType.uint32,
                                          indexBuffer: edgeIndexBuffer,
                                          indexBufferOffset: 0)
            encoder.popDebugGroup()
        }

        if let nodeColorBuffer = self.nodeColorBuffer {
            encoder.pushDebugGroup("Nodes")
            encoder.setRenderPipelineState(nodePipelineState)
            encoder.setVertexBuffer(nodeColorBuffer,
                                    offset: 0,
                                    index: nodeColorBufferIndex)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
            encoder.popDebugGroup()
        }
    }

    /// Runs on the rendering thread (i.e., the main thread) once per frame
    private func applyBufferUpdateIfPresent() {

        guard
            let update = self.bufferUpdate
        else {
            // debug("Wireframe2.applyBufferUpdateIfPresent", "No bufferUpdate to apply")
            return
        }

        // print("Wireframe2.applyBufferUpdateIfPresent: applying bufferUpdate")
        self.bufferUpdate = nil

        let t0 = Date()

        if let bbox = update.bbox {
            self.bbox = bbox
        }

        let oldNodeCount = nodeCount
        let newNodeCount = update.nodeCount ?? oldNodeCount
        nodeCount = newNodeCount

        // =================
        // Node positions

        if newNodeCount == 0 {
            nodePositionBuffer = nil
        }
        else if let newNodePositions = update.nodePositions {
//            if newNodePositions.count != newNodeCount {
//                fatalError("Failed sanity check: newNodeCount=\(newNodeCount) but newNodePositions.count=\(newNodePositions.count)")
//            }

            if nodePositionBuffer == nil || newNodeCount != oldNodeCount {
                nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                       length: newNodePositions.count * MemoryLayout<SIMD3<Float>>.size,
                                                       options: [])
            }
            else {
                nodePositionBuffer!.contents().copyMemory(from: newNodePositions,
                                                          byteCount: newNodePositions.count * MemoryLayout<SIMD3<Float>>.size)
            }
        }
//        else if newNodeCount != oldNodeCount {
//            fatalError("Failed sanity check: nodeCount changed but newNodePositions is nil")
//        }


        // ====================
        // Node colors

        if newNodeCount == 0 {
            nodeColorBuffer = nil
        }
        else if let newNodeColors = update.nodeColors {

            // TODO: MAYBE either keep colorsArray in memory or stop using it altogether.
            let defaultColor = settings.nodeColorDefault
            var colorsArray = [SIMD4<Float>](repeating: defaultColor, count: nodeCount)
            for (nodeIndex, color) in newNodeColors {
                colorsArray[nodeIndex] = color
            }

            if nodeColorBuffer == nil || nodeCount != oldNodeCount {
                 nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                     length: nodeCount * MemoryLayout<SIMD4<Float>>.size,
                                                     options: [])
            }
            else {
                nodeColorBuffer!.contents().copyMemory(from: colorsArray,
                                                       byteCount: nodeCount * MemoryLayout<SIMD4<Float>>.size)
            }
        }

        // ==================
        // Edge indices

        let oldEdgeIndexCount = edgeIndexCount
        let newEdgeIndexCount = update.edgeIndexCount ?? oldEdgeIndexCount
        edgeIndexCount = newEdgeIndexCount

        if newEdgeIndexCount == 0 {
            self.edgeIndexBuffer = nil
        }
        else if let newEdgeIndices = update.edgeIndices {
//            if newEdgeIndices.count != edgeIndexCount {
//                fatalError("Failed sanity check: newEdgeIndexCount=\(newEdgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
//            }

            if edgeIndexBuffer == nil || newEdgeIndexCount != oldEdgeIndexCount {
                edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
                                                    length: newEdgeIndices.count * MemoryLayout<UInt32>.size)
            }
            else {
                edgeIndexBuffer!.contents().copyMemory(from: newEdgeIndices,
                                                       byteCount: newEdgeIndices.count * MemoryLayout<UInt32>.size)
            }
        }
//        else if newEdgeIndexCount != oldEdgeIndexCount {
//            fatalError("Failed sanity check: edgeIndexCount changed but newEdgeIndices is nil")
//        }

        let dt = Date().timeIntervalSince(t0)
        if dt > 0.1 {
            print("Slow applyBufferUpdate dt: \(dt)")
        }
    }

    private func buildUniforms() throws {
        let uniformBufferSize = alignedUniformsSize * Renderer.maxBuffersInFlight
        if let buffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
            self.dynamicUniformBuffer = buffer
            self.dynamicUniformBuffer.label = "UniformBuffer"
            self.uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:WireframeUniforms.self, capacity:1)
        }
        else {
            throw RenderError.bufferCreationFailed
        }
    }

    private func buildNodePipeline(_ view: MTKView) throws {

        let vertexFunction = library.makeFunction(name: "node_vertex")
        let fragmentFunction = library.makeFunction(name: nodeFragmentFunctionName)
        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = WireframeBufferIndex.nodePosition.rawValue

        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].format = MTLVertexFormat.float4
        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].bufferIndex = WireframeBufferIndex.nodeColor.rawValue

        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepRate = 1
        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stepRate = 1
        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        pipelineDescriptor.label = "NodePipeline"
        // pipelineDescriptor.sampleCount = view.sampleCount
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

        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = WireframeBufferIndex.nodePosition.rawValue

        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepRate = 1
        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "EdgePipeline"
        // pipelineDescriptor.sampleCount = view.sampleCount
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

public struct WireframeUpdateGenerator2 {

    var generateNodeColors: Bool

    private var nodeIndices = [NodeID: Int]()

    public init(_ generateNodeColors: Bool = true) {
        self.generateNodeColors = generateNodeColors
    }

    public mutating func makeUpdate<GraphType: Graph>(_ graph: GraphType, _ change: RenderableGraphChange) -> WireframeUpdate2?
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue {

        var bufferUpdate: WireframeUpdate2? = nil

        if change.nodes {
            bufferUpdate = self.prepareTopologyUpdate(graph)
        }
        else {

            // TODO: deal with the case where nodeIndicies has not been populated

            var newPositions: [SIMD3<Float>]? = nil
            var newColors: [Int : SIMD4<Float>]? = nil
            var newBBox: BoundingBox? = nil

            if change.nodePositions {
                newPositions = self.makeNodePositions(graph)
                newBBox = graph.makeBoundingBox()
            }

            if change.nodeColors && generateNodeColors {
                newColors = makeNodeColors(graph)
            }

            if (newPositions != nil || newColors != nil) {
                bufferUpdate = WireframeUpdate2(bbox: newBBox,
                                                      nodeCount: nil,
                                                      nodePositions: newPositions,
                                                      nodeColors: newColors,
                                                      edgeIndexCount: nil,
                                                      edgeIndices: nil)
            }
        }
        return bufferUpdate
    }

    private mutating func prepareTopologyUpdate<GraphType: Graph>(_ graph: GraphType) -> WireframeUpdate2
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue {

        var newNodeIndices = [NodeID: Int]()
        var newNodePositions = [SIMD3<Float>]()
        var newEdgeIndexData = [UInt32]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            if let nodeValue = node.value {
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

        return WireframeUpdate2(
            bbox: graph.makeBoundingBox(),
            nodeCount: newNodePositions.count,
            nodePositions: newNodePositions,
            nodeColors: generateNodeColors ? makeNodeColors(graph) : nil,
            edgeIndexCount: newEdgeIndexData.count,
            edgeIndices: newEdgeIndexData
        )
    }

    private func makeNodePositions<GraphType: Graph>(_ graph: GraphType) -> [SIMD3<Float>]
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue {
        //    private func makeNodePositions<G: Graph>(_ graph: G) -> [SIMD3<Float>] where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
        var newNodePositions = [SIMD3<Float>]()
        for node in graph.nodes {
            if let nodeIndex = nodeIndices[node.id],
               let nodeValue = node.value {
                newNodePositions.insert(nodeValue.location, at: nodeIndex)
            }
        }
        return newNodePositions
    }

    private func makeNodeColors<GraphType: Graph>(_ graph: GraphType) -> [Int: SIMD4<Float>]
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue {

        var newNodeColors = [Int: SIMD4<Float>]()
        for node in graph.nodes {
            if let nodeIndex = nodeIndices[node.id],
               let nodeColor = node.value?.color {
                newNodeColors[nodeIndex] = nodeColor
            }
        }
        return newNodeColors
    }
}

public struct WireframeUpdate2: Sendable, Codable {
    public var bbox: BoundingBox?
    public var nodeCount: Int?
    public var nodePositions: [SIMD3<Float>]?
    public var nodeColors: [Int: SIMD4<Float>]?
    public var edgeIndexCount: Int?
    public var edgeIndices: [UInt32]?

    public var isNodesetChange: Bool {
        return nodeCount != nil
    }

    public static func emptyGraph() -> WireframeUpdate2 {
        return WireframeUpdate2(bbox: BoundingBox.centeredCube(1),
                                      nodeCount: 0,
                                      nodePositions: nil,
                                      nodeColors: nil,
                                      edgeIndexCount: 0,
                                      edgeIndices: nil)
    }

    public mutating func merge(_ update: WireframeUpdate2) {

        if update.isNodesetChange {
            self.bbox = update.bbox
            self.nodeCount = update.nodeCount
            self.nodePositions = update.nodePositions
            self.nodeColors = update.nodeColors
            self.edgeIndexCount = update.edgeIndexCount
            self.edgeIndices = update.edgeIndices
        }
        else {
            if let newBBox = update.bbox {
                self.bbox = newBBox
            }
            if let newNodePositions = update.nodePositions {
                self.nodePositions = newNodePositions
            }
            if self.nodeColors == nil {
                self.nodeColors = update.nodeColors
            }
            else if let updateNodeColors = update.nodeColors {
                self.nodeColors!.merge(updateNodeColors, uniquingKeysWith: { _, b in b })
            }
        }
    }
}

