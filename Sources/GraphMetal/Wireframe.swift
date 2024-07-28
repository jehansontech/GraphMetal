//
//  Wireframe.swift
//  GraphMetal
//
//  Created by Jim Hanson on 9/21/22.
//

import Foundation
import SwiftUI
import Metal
import MetalKit
import Wacoma
import GenericGraph

public struct WireframeSettings {

    /// EMPIRICAL
    // WAS: public static let nodeSizeScaleFactor: Double = 40
    public static let nodeSizeScaleFactor: Double = 400

    public static let defaults = WireframeSettings()

    public var nodeStyle: NodeStyle

    /// indicates whether node size should be automatically adjusted when the POV changes
    public var nodeSizeIsAdjusted: Bool

    /// Size of a node sprite.
    /// if nodeSizeIsAdjusted is false, equal to the node's width in pixels.
    /// if nodeSizeIsAdjusted is true, used as  a scaling factor on the width
    public var nodeSize: Double

    /// Minimum automatic node size. Ignored if nodeSizeIsAdjusted is false
    public var nodeSizeMinimum: Double

    /// Maximum automatic node size. Ignored if nodeSizeIsAdjusted is false
    public var nodeSizeMaximum: Double

    /// Color to use when node value's color is nil.
    public var nodeColorDefault: SIMD4<Float>

    public var edgeColor: SIMD4<Float>

    public init(nodeStyle: NodeStyle = .dot,
                nodeSizeIsAdjusted: Bool = true,
                nodeSize: Double = 16,
                nodeSizeMinimum: Double = 2,
                nodeSizeMaximum: Double = 64,
                nodeColorDefault: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0),
                edgeColor: SIMD4<Float> = SIMD4<Float>(0.2, 0.2, 0.2, 1)) {
        self.nodeStyle = nodeStyle
        self.nodeSizeIsAdjusted = nodeSizeIsAdjusted
        self.nodeSize = nodeSize
        self.nodeSizeMinimum = nodeSizeMinimum
        self.nodeSizeMaximum = nodeSizeMaximum
        self.nodeColorDefault = nodeColorDefault
        self.edgeColor = edgeColor
    }

    public mutating func reset() {
        self.nodeSizeIsAdjusted = Self.defaults.nodeSizeIsAdjusted
        self.nodeSize = Self.defaults.nodeSize
        self.nodeSizeMinimum = Self.defaults.nodeSizeMinimum
        self.nodeSizeMaximum = Self.defaults.nodeSizeMaximum
        self.nodeColorDefault = Self.defaults.nodeColorDefault
        self.edgeColor = Self.defaults.edgeColor
    }

    public func getNodeSize(forPOV pov: POV, bbox: BoundingBox?) -> Double {
        if let bbox = bbox, nodeSizeIsAdjusted {
            let newSize = Self.nodeSizeScaleFactor  * nodeSize / Double(distance(pov.location, bbox.center))
            return newSize.clamp(nodeSizeMinimum, nodeSizeMaximum)
        }
        else {
            return nodeSize
        }
    }

    public enum NodeStyle {
        case dot
        case ring
        case square
        case diamond
        case none
    }
}

public struct WireframeUpdate: Codable, Sendable {

    public static var emptyGraph: WireframeUpdate {
        WireframeUpdate(nodeCount: 0, edgeIndexCount: 0)
    }

    public var bbox: BoundingBox?

    public var nodeCount: Int?

    public var nodePositions: [SIMD3<Float>]?

    public var nodeColors: [Int: SIMD4<Float>]?

    public var edgeIndexCount: Int?

    public var edgeIndices: [UInt32]?

    public var isNodesetChange: Bool {
        return nodeCount != nil
    }

    public mutating func merge(_ update: WireframeUpdate) {

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

public class Wireframe: Renderable {

    public var settings: WireframeSettings

    var bbox: BoundingBox? = nil

    weak var device: MTLDevice!

    var library: MTLLibrary!

    var nodePipelineState: MTLRenderPipelineState!

    var nodeCount: Int = 0

    let nodePositionBufferIndex: Int // = WireframeBufferIndex.nodePosition.rawValue

    var nodePositionBuffer: MTLBuffer? = nil

    let nodeColorBufferIndex: Int // = WireframeBufferIndex.nodeColor.rawValue

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

    private var bufferUpdate: WireframeUpdate? = nil

    public init(nodePositionBufferIndex: Int,
                nodeColorBufferIndex: Int) {
        self.settings = WireframeSettings()
        self.nodePositionBufferIndex = nodePositionBufferIndex
        self.nodeColorBufferIndex = nodeColorBufferIndex
    }

    public init(settings: WireframeSettings,
                nodePositionBufferIndex: Int,
                nodeColorBufferIndex: Int) {
        self.settings = settings
        self.nodePositionBufferIndex = nodePositionBufferIndex
        self.nodeColorBufferIndex = nodeColorBufferIndex
    }

    deinit {
        // debug("Wireframe.deinit", "started")
    }

    public func setup(_ view: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws {
        self.device = device
        self.library = library
        try buildNodePipeline(view)
        try buildEdgePipeline(view)
    }

    func teardown() {
        // debug("Wireframe.teardown", "started")
        // TODO: maybe dynamicUniformBuffer and uniforms ... if so change declarations from ! to ?
        // TODO: maybe nodePipelineState ... ditto
        // TODO: maybe edgePipelineState ... ditto
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    public func addBufferUpdate(_ bufferUpdate: WireframeUpdate?) {
        if self.bufferUpdate == nil {
            // print("Wireframe.updateBuffers: replacing bufferUpdate")
            self.bufferUpdate = bufferUpdate
        }
        else if let bufferUpdate {
            // print("Wireframe.updateBuffers: merging bufferUpdate")
            self.bufferUpdate!.merge(bufferUpdate)
        }
    }
    
    public func updateBuffers(_ bufferUpdate: WireframeUpdate) {
        if self.bufferUpdate == nil {
            // print("Wireframe.updateBuffers: replacing bufferUpdate")
            self.bufferUpdate = bufferUpdate
        }
        else {
            // print("Wireframe.updateBuffers: merging bufferUpdate")
            self.bufferUpdate!.merge(bufferUpdate)
        }
    }

    public func prepareToDraw() { // _ mtkView: MTKView, _ renderSettings: RenderSettings1) {
        applyBufferUpdateIfPresent()
    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
        // _drawCount += 1
        // debug("Wireframe.encodeDrawCommands[\(_drawCount)]")

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
            // debug("Wireframe.applyBufferUpdateIfPresent", "No bufferUpdate to apply")
            return
        }

        // print("Wireframe.applyBufferUpdateIfPresent: applying bufferUpdate")
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
                // 2022-11-21 I was getting segv when I did this w/ the node colors buffer, so I'm
                // commenting it out here as well.
                //                nodePositionBuffer!.contents().copyMemory(from: newNodePositions,
                //                                                          byteCount: newNodePositions.count * MemoryLayout<SIMD3<Float>>.size)
                nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                       length: newNodePositions.count * MemoryLayout<SIMD3<Float>>.size,
                                                       options: [])
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
                // 2024-07-26 TRY THIS:
                // - explicitly set options to "shared"
                // - then "manually synchronize", i.e., ensure these changes are completed
                //   before GPU gets it; and also ensure GPU operations are completed before
                //   this method gets it.
                // 
                // 2022-11-20 SOMETIMES CRASHES HERE w/ segv. I only started seeing crashes after I
                // changed xcode 'scheme' to run the 'Release' version. This is CONSISTENT with the
                // crashes I'm seeing in the TestFlight version of the app.
                //                nodeColorBuffer!.contents().copyMemory(from: colorsArray,
                //                                                       byteCount: nodeCount * MemoryLayout<SIMD4<Float>>.size)
                nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                    length: nodeCount * MemoryLayout<SIMD4<Float>>.size,
                                                    options: [])
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
                // 2022-11-21 I was getting segv when I did this w/ the node colors buffer, so I'm
                // commenting it out here as well.
                //                edgeIndexBuffer!.contents().copyMemory(from: newEdgeIndices,
                //                                                       byteCount: newEdgeIndices.count * MemoryLayout<UInt32>.size)
                edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
                                                    length: newEdgeIndices.count * MemoryLayout<UInt32>.size)
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

    private func buildNodePipeline(_ view: MTKView) throws {

        let vertexFunction = library.makeFunction(name: "node_vertex")
        let fragmentFunction = library.makeFunction(name: nodeFragmentFunctionName)
        let vertexDescriptor = MTLVertexDescriptor()

        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = nodePositionBufferIndex
        // vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = WireframeBufferIndex.nodePosition.rawValue

        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].format = MTLVertexFormat.float4
        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].offset = 0
        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].bufferIndex = nodeColorBufferIndex
        // vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].bufferIndex = WireframeBufferIndex.nodeColor.rawValue

        vertexDescriptor.layouts[nodePositionBufferIndex].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[nodePositionBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodePositionBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

        vertexDescriptor.layouts[nodeColorBufferIndex].stride = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.layouts[nodeColorBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodeColorBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepRate = 1
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex
//
//        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stride = MemoryLayout<SIMD4<Float>>.stride
//        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stepRate = 1
//        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()

        pipelineDescriptor.label = "NodePipeline"
        // pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
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
        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = nodePositionBufferIndex
        // vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = WireframeBufferIndex.nodePosition.rawValue

        vertexDescriptor.layouts[nodePositionBufferIndex].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[nodePositionBufferIndex].stepRate = 1
        vertexDescriptor.layouts[nodePositionBufferIndex].stepFunction = MTLVertexStepFunction.perVertex

//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepRate = 1
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex

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

