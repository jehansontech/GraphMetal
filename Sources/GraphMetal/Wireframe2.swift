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

    private var bufferUpdate: WireframeBufferUpdate2? = nil

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
        // debug("Wireframe", "deinit")
    }

    func setup(_ view: MTKView) throws {
        // debug("Wireframe.setup", "started")

        if let device = view.device {
            self.device = device
        }
        else {
            throw RenderError.noDevice
        }

        if let device = view.device,
           let library = WireframeShaders.makeLibrary(device) {
            self.library = library
            // debug("Wireframe", "setup. library functions: \(library.functionNames)")
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
        // debug("Wireframe", "teardown")
        // TODO: maybe dynamicUniformBuffer and uniforms ... if so change declarations from ! to ?
        // TODO: maybe nodePipelineState ... ditto
        // TODO: maybe edgePipelineState ... ditto
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
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
        // debug("Wireframe.encodeCommands[\(_drawCount)]")

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
            // debug("Wireframe", "No bufferUpdate to apply")
            return
        }

        // debug("Wireframe", "applying bufferUpdate")
        self.bufferUpdate = nil

        if let bbox = update.bbox {
            self.bbox = bbox
        }

        if let updatedNodeCount = update.nodeCount,
           self.nodeCount != updatedNodeCount {
            // debug("Wireframe", "updating nodeCount: \(nodeCount) -> \(updatedNodeCount)")
            nodeCount = updatedNodeCount
        }

        if nodeCount == 0 {
            if nodePositionBuffer != nil {
                // debug("Wireframe", "discarding nodePositionBuffer")
                nodePositionBuffer = nil
            }
        }
        else if let newNodePositions = update.nodePositions {
            if newNodePositions.count != nodeCount {
                fatalError("Failed sanity check: nodeCount=\(nodeCount) but newNodePositions.count=\(newNodePositions.count)")
            }

            // debug("Wireframe", "creating nodePositionBuffer")
            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
            nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                   length: nodePositionBufLen,
                                                   options: [])
        }

        if nodeCount == 0 {
            if nodeColorBuffer != nil {
                // debug("Wireframe", "discarding nodeColorBuffer")
                nodeColorBuffer = nil
            }
        }
        else if let newNodeColors = update.nodeColors {

            let defaultColor = settings.nodeColorDefault
            var colorsArray = [SIMD4<Float>](repeating: defaultColor, count: nodeCount)
            for (nodeIndex, color) in newNodeColors {
                colorsArray[nodeIndex] = color
            }

            // debug("Wireframe", "creating nodeColorBuffer")
            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
            nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                length: nodeColorBufLen,
                                                options: [])
        }

        if let updatedEdgeIndexCount = update.edgeIndexCount,
           self.edgeIndexCount != update.edgeIndexCount {
            // debug("Wireframe", "updating edgeIndexCount: \(edgeIndexCount) -> \(updatedEdgeIndexCount)")
            self.edgeIndexCount = updatedEdgeIndexCount
        }

        if edgeIndexCount == 0 {
            if edgeIndexBuffer != nil {
                // debug("Wireframe", "discarding edgeIndexBuffer")
                self.edgeIndexBuffer = nil
            }
        }
        else if let newEdgeIndices = update.edgeIndices {
            if newEdgeIndices.count != edgeIndexCount {
                fatalError("Failed sanity check: edgeIndexCount=\(edgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
            }

            // debug("Wireframe", "creating edgeIndexBuffer")
            let bufLen = newEdgeIndices.count * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices, length: bufLen)
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

public struct WireframeBufferUpdate2 {
    public let bbox: BoundingBox?
    public let nodeCount: Int?
    public let nodePositions: [SIMD3<Float>]?
    public let nodeColors: [Int: SIMD4<Float>]?
    public let edgeIndexCount: Int?
    public let edgeIndices: [UInt32]?
}
