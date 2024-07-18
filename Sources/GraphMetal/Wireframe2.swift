//
//  Wireframe2.swift
//  GraphMetal
//
//  Created by Jim Hanson on 7/11/24.
//

import Foundation
import SwiftUI
import Metal
import MetalKit
import Wacoma
import GenericGraph

public struct Wireframe2Settings: Sendable {

    public init() {
        
    }
}

public struct Wireframe2Update: Sendable {

}

public class Wireframe2: Renderable {

    public var settings: Wireframe2Settings

    private let referenceDate = Date()

    private weak var device: MTLDevice!

    private var library: MTLLibrary!

    private let uniformsBufferIndex: Int

    private var uniformsBuffer: MTLBuffer!

    private var uniformsbufferOffset: Int = 0

    private var uniformsBufferRotation: Int = 0
    
    private var isSetup: Bool {
        uniformsBuffer != nil
    }

    private var pulsePhase: Float {
        let millisSinceReferenceDate = Int(Date().timeIntervalSince(referenceDate) * 1000)
        return 0.001 * Float(millisSinceReferenceDate % 1000)
    }

    private let nodePositionBufferIndex : Int

    private let nodeColorBufferIndex: Int

    private var nodeCount: Int = 0

    private var nodePositionBuffer: MTLBuffer? = nil

    private var nodeColorBuffer: MTLBuffer? = nil

    private let nodeVertexFunction: String = "wireframe2_node_vertex"

    private let nodeFragmentFunction: String = "wireframe2_node_fragment"

    private var nodePipelineState: MTLRenderPipelineState!

    private let edgeColorBufferIndex: Int

    private var edgeCount: Int = 0

    private var edgeIndexBuffer: MTLBuffer? = nil

    private var edgeColorBuffer: MTLBuffer? = nil

    private let edgeVertexFunction: String = "wireframe2_edge_vertex"

    private let edgeFragmentFunction: String = "wireframe2_edge_fragment"

    private var edgePipelineState: MTLRenderPipelineState!

    public init(uniformsBufferIndex: Int,
                nodePositionBufferIndex: Int,
                nodeColorBufferIndex: Int,
                edgeColorBufferIndex: Int,
                settings: Wireframe2Settings) {
        self.uniformsBufferIndex = uniformsBufferIndex
        self.nodePositionBufferIndex = nodePositionBufferIndex
        self.nodeColorBufferIndex = nodeColorBufferIndex
        self.edgeColorBufferIndex = edgeColorBufferIndex
        self.settings = settings
    }

    func setup(_ view: MTKView) throws {
        if isSetup {
            return
        }

        if let device = view.device {
            self.device = device
        }
        else {
            throw RenderError.noDevice
        }

        if let device = view.device,
           let library = WireframeShaders.makeLibrary(device) {
            self.library = library
            // debug("Wireframe.setup", "library functions: \(library.functionNames)")
        }
        else {
            throw RenderError.noDefaultLibrary
        }

        try buildUniforms()
        try buildNodePipeline(view)
        try buildEdgePipeline(view)
    }

    func teardown() {
        // TODO: impl
    }

    public func prepareToDraw(_ mtkView: MTKView, _ renderSettings: RenderSettings) {
        if !isSetup {
            do {
                try setup(mtkView)
            }
            catch {
                fatalError("Problem in setup: \(error)")
            }
        }

        // TODO: rotate uniforms buffer
        // TODO: update uniforms content
        // TODO: apply buffer update if present
    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
    }

    private func buildUniforms() throws {

    }

    private func buildNodePipeline(_ view: MTKView) throws {
    }

    private func buildEdgePipeline(_ view: MTKView) throws {
    }
}
