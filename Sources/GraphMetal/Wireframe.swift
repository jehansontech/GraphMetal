//
//  Wireframe.swift
//  GraphMetal
//


import SwiftUI
import Metal
import MetalKit
import GenericGraph
import Shaders
import Wacoma

public struct WireframeSettings {

    /// EMPIRICAL
    static let nodeSizeScaleFactor: Double = 800

    public static let defaults = WireframeSettings()

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

    public mutating func reset() {
        self.nodeSizeIsAdjusted = Self.defaults.nodeSizeIsAdjusted
        self.nodeSizeDefault = Self.defaults.nodeSizeDefault
        self.nodeSizeMinimum = Self.defaults.nodeSizeMinimum
        self.nodeSizeMaximum = Self.defaults.nodeSizeMaximum
        self.nodeColorDefault = Self.defaults.nodeColorDefault
        self.edgeColor = Self.defaults.edgeColor
    }

    func nodeSize(forPOV pov: POV, bbox: BoundingBox?) -> Double {
        if let bbox = bbox, nodeSizeIsAdjusted {
            let newSize = Self.nodeSizeScaleFactor / Double(distance(pov.location, bbox.center))
            return newSize.clamp(nodeSizeMinimum, nodeSizeMaximum)
        }
        else {
            return nodeSizeDefault
        }
    }
}

public class Wireframe<Container: RenderableGraphContainer>: Renderable {

    /// The 256 byte aligned size of our uniform structure
    let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

    // ==============================================================
    // Rendering properties -- Access these only on main thread

    public var settings: WireframeSettings

    var bbox: BoundingBox? = nil

    weak var device: MTLDevice!

    var library: MTLLibrary!

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

    private var isSetup: Bool = false

    private var bufferUpdate: BufferUpdate2? = nil

    // ==============================================================
    // Graph properties -- Access only on graph-update thread (which
    // may or may not be main)

    private weak var graphContainer: Container!

    private var nodeIndices = [NodeID: Int]()

    public func findNearestNode(_ touchLocation: SIMD2<Float>,
                                _ povController: POVController,
                                _ fovController: FOVController) -> NodeID? {

        let ray0 = SIMD4<Float>(Float(touchLocation.x), touchLocation.y, 0, 1)
        var ray1 = fovController.projectionMatrix.inverse * ray0
        ray1.z = -1
        ray1.w = 0

        // modelViewMatrix == viewMatrix b/c our model matrix is the identity
        let modelViewMatrix = povController.viewMatrix
        let rayOrigin = (modelViewMatrix.inverse * SIMD4<Float>(0, 0, 0, 1)).xyz
        let rayDirection = normalize(modelViewMatrix.inverse * ray1).xyz

        var nearestNode: Container.GraphType.NodeType? = nil
        var nearestD2 = Float.greatestFiniteMagnitude
        var shortestRayDistance = Float.greatestFiniteMagnitude
        for node in graphContainer.graph.nodes {

            if let nodeLoc = node.value?.location {

                let nodeDisplacement = nodeLoc - rayOrigin

                /// distance along the ray to the point closest to the node
                let rayDistance = simd_dot(nodeDisplacement, rayDirection)

                if (rayDistance < fovController.zNear || rayDistance > fovController.zFar) {
                    // Node is not in rendered volume
                    continue
                }

                /// nodeD2 is the square of the distance from ray to the node
                let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - rayDistance * rayDistance
                // print("\(node) distance to ray: \(sqrt(nodeD2))")

                if (nodeD2 < nearestD2 || (nodeD2 == nearestD2 && rayDistance < shortestRayDistance)) {
                    shortestRayDistance = rayDistance
                    nearestD2 = nodeD2
                    nearestNode = node
                }
            }
        }
        return nearestNode?.id
    }

    // ==============================================================

    public init(_ graphContainer: Container) {
        self.graphContainer = graphContainer
        self.settings = WireframeSettings()
    }

//    public init(_ graphContainer: Container, _ settings: WireframeSettings){
//        self.graphContainer = graphContainer
//        self.settings = settings
//    }

    deinit {
        // debug("GraphWireframe", "deinit")
    }

    func setup(_ view: MTKView) throws {
        debug("GraphWireframe2.setup", "started")

        if let device = view.device {
            self.device = device
        }
        else {
            throw RenderError.noDevice
        }

        if let device = view.device,
           let library = Shaders.makeLibrary(device) {
            self.library = library
            // debug("GraphWireframe", "setup. library functions: \(library.functionNames)")
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

        updateFigure(.all)
        NotificationCenter.default.addObserver(self, selector: #selector(graphHasChanged), name: .graphHasChanged, object: nil)
        isSetup = true
    }

    func teardown() {
        // debug("GraphWireframe", "teardown")
        // TODO: maybe dynamicUniformBuffer and uniforms ... if so change declarations from ! to ?
        // TODO: maybe nodePipelineState ... ditto
        // TODO: maybe edgePipelineState ... ditto
        self.nodePositionBuffer = nil
        self.nodeColorBuffer = nil
        self.edgeIndexBuffer = nil
    }

    @objc public func graphHasChanged(_ notification: Notification) {
        if let graphChange = notification.object as? RenderableGraphChange {
            updateFigure(graphChange)
        }
    }

    public func updateFigure(_ change: RenderableGraphChange) {

        // debug("GraphWireframe", "updateFigure: started. bufferUpdate=\(String(describing: bufferUpdate))")

        var bufferUpdate: BufferUpdate2? = nil
        if change.nodes {
            bufferUpdate = self.prepareTopologyUpdate(graphContainer.graph)
        }
        else {
            var newPositions: [SIMD3<Float>]? = nil
            var newColors: [NodeID : SIMD4<Float>]? = nil
            var newBBox: BoundingBox? = nil

            if change.nodePositions {
                newPositions = self.makeNodePositions(graphContainer.graph)
                newBBox = graphContainer.graph.makeBoundingBox()
            }

            if change.nodeColors {
                newColors = graphContainer.graph.makeNodeColors()
            }

            if (newPositions != nil || newColors != nil) {
                bufferUpdate = BufferUpdate2(bbox: newBBox,
                                             nodeCount: nil,
                                            nodePositions: newPositions,
                                            nodeColors: newColors,
                                            edgeIndexCount: nil,
                                            edgeIndices: nil)
            }
        }


        // write bufferUpdate to self.bufferUpdate on the main thread
        // in order to avoid a data race
        if Thread.current.isMainThread {
            self.bufferUpdate = bufferUpdate
        }
        else {
            DispatchQueue.main.sync {
                self.bufferUpdate = bufferUpdate
            }
        }
    }

    /// Runs on the rendering thread (i.e., the main thread) once per frame
    func applyBufferUpdateIfPresent() {

        guard
            let update = self.bufferUpdate
        else {
            // debug("GraphWireframe", "No bufferUpdate to apply")
            return
        }

        // debug("GraphWireframe", "applying bufferUpdate")
        self.bufferUpdate = nil

        if let bbox = update.bbox {
            self.bbox = bbox
        }

        if let updatedNodeCount = update.nodeCount,
           self.nodeCount != updatedNodeCount {
            // debug("GraphWireframe", "updating nodeCount: \(nodeCount) -> \(updatedNodeCount)")
            nodeCount = updatedNodeCount
        }

        if nodeCount == 0 {
            if nodePositionBuffer != nil {
                // debug("GraphWireframe", "discarding nodePositionBuffer")
                nodePositionBuffer = nil
            }
        }
        else if let newNodePositions = update.nodePositions {
            if newNodePositions.count != nodeCount {
                fatalError("Failed sanity check: nodeCount=\(nodeCount) but newNodePositions.count=\(newNodePositions.count)")
            }

            // debug("GraphWireframe", "creating nodePositionBuffer")
            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
            nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
                                                   length: nodePositionBufLen,
                                                   options: [])
        }

        if nodeCount == 0 {
            if nodeColorBuffer != nil {
                // debug("GraphWireframe", "discarding nodeColorBuffer")
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

            // debug("GraphWireframe", "creating nodeColorBuffer")
            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
            nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
                                                length: nodeColorBufLen,
                                                options: [])
        }

        if let updatedEdgeIndexCount = update.edgeIndexCount,
           self.edgeIndexCount != update.edgeIndexCount {
            // debug("GraphWireframe", "updating edgeIndexCount: \(edgeIndexCount) -> \(updatedEdgeIndexCount)")
            self.edgeIndexCount = updatedEdgeIndexCount
        }

        if edgeIndexCount == 0 {
            if edgeIndexBuffer != nil {
                // debug("GraphWireframe", "discarding edgeIndexBuffer")
                self.edgeIndexBuffer = nil
            }
        }
        else if let newEdgeIndices = update.edgeIndices {
            if newEdgeIndices.count != edgeIndexCount {
                fatalError("Failed sanity check: edgeIndexCount=\(edgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
            }

            // debug("GraphWireframe", "creating edgeIndexBuffer")
            let bufLen = newEdgeIndices.count * MemoryLayout<UInt32>.size
            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices, length: bufLen)
        }
    }


    public func prepareToDraw(_ mtkView: MTKView, _ renderSettings: RenderSettings) {
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

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        // =====================================
        // Update content of current uniforms buffer
        //
        // NOTE uniforms.modelViewMatrix is equal to renderSettings.viewMatrix
        // because we are drawing the graph in world coordinates, i.e., our model
        // matrix is the identity.

        uniforms[0].projectionMatrix = renderSettings.projectionMatrix
        uniforms[0].modelViewMatrix = renderSettings.viewMatrix
        uniforms[0].pointSize = Float(self.settings.nodeSize(forPOV: renderSettings.pov, bbox: self.bbox))
        uniforms[0].edgeColor = self.settings.edgeColor
        uniforms[0].fadeoutOnset = renderSettings.fadeoutOnset
        uniforms[0].fadeoutDistance = renderSettings.fadeoutDistance

        // =====================================
        // Possibly update contents of the other buffers

        applyBufferUpdateIfPresent()

    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
        // _drawCount += 1
        // debug("GraphWireframe.encodeCommands[\(_drawCount)]")


        // If we don't have node positions we can't draw either nodes or edges.
        guard
            let nodePositionBuffer = self.nodePositionBuffer
        else {
            return
        }

        encoder.setVertexBuffer(dynamicUniformBuffer,
                                      offset:uniformBufferOffset,
                                      index: BufferIndex.uniforms.rawValue)
        encoder.setFragmentBuffer(dynamicUniformBuffer,
                                        offset:uniformBufferOffset,
                                        index: BufferIndex.uniforms.rawValue)
        encoder.setVertexBuffer(nodePositionBuffer,
                                      offset: 0,
                                      index: BufferIndex.nodePosition.rawValue)

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
                                          index: BufferIndex.nodeColor.rawValue)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
            encoder.popDebugGroup()
        }
    }

    private func prepareTopologyUpdate(_ graph: Container.GraphType) -> BufferUpdate2 {

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

        return BufferUpdate2(
            bbox: graph.makeBoundingBox(),
            nodeCount: newNodePositions.count,
            nodePositions: newNodePositions,
            nodeColors: graph.makeNodeColors(),
            edgeIndexCount: newEdgeIndexData.count,
            edgeIndices: newEdgeIndexData
        )
    }

    private func makeNodePositions(_ graph: Container.GraphType) -> [SIMD3<Float>] {
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

    private func buildUniforms() throws {
        let uniformBufferSize = alignedUniformsSize * Renderer.maxBuffersInFlight
        if let buffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
            self.dynamicUniformBuffer = buffer
            self.dynamicUniformBuffer.label = "UniformBuffer"
            self.uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        }
        else {
            throw RenderError.bufferCreationFailed
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

struct BufferUpdate2 {
    let bbox: BoundingBox?
    let nodeCount: Int?
    let nodePositions: [SIMD3<Float>]?
    let nodeColors: [NodeID: SIMD4<Float>]?
    let edgeIndexCount: Int?
    let edgeIndices: [UInt32]?
}
