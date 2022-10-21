////
////  Wireframe.swift
////  GraphMetal
////
//
//
//import SwiftUI
//import Metal
//import MetalKit
//import GenericGraph
////import Shaders
//import Wacoma
//
//
//public class Wireframe<Container: RenderableGraphContainer>: Renderable {
//
//    let referenceDate = Date()
//
//    /// The 256 byte aligned size of our uniform structure
//    let alignedUniformsSize = (MemoryLayout<WireframeUniforms>.size + 0xFF) & -0x100
//
//    // ==============================================================
//    // Rendering properties -- Access these only on main thread
//
//    public var settings: WireframeSettings
//
//    var bbox: BoundingBox? = nil
//
//    weak var device: MTLDevice!
//
//    var library: MTLLibrary!
//
//    var nodePipelineState: MTLRenderPipelineState!
//
//    var nodeCount: Int = 0
//
//    var nodePositionBufferIndex: Int = WireframeBufferIndex.nodePosition.rawValue
//
//    var nodePositionBuffer: MTLBuffer? = nil
//
//    var nodeColorBufferIndex: Int = WireframeBufferIndex.nodeColor.rawValue
//
//    var nodeColorBuffer: MTLBuffer? = nil
//
//    var nodeFragmentFunctionName: String {
//        switch (settings.nodeStyle) {
//        case .dot:
//            return "node_fragment_dot"
//        case .ring:
//            return "node_fragment_ring"
//        case .square:
//            return "node_fragment_square"
//        case .diamond:
//            return "node_fragment_diamond"
//        default:
//            return "node_fragment_square"
//        }
//    }
//
//    var edgePipelineState: MTLRenderPipelineState!
//
//    var edgeIndexCount: Int = 0
//
//    var edgeIndexBuffer: MTLBuffer? = nil
//
//    var dynamicUniformBufferIndex: Int = WireframeBufferIndex.uniforms.rawValue
//
//    var dynamicUniformBuffer: MTLBuffer!
//
//    var uniformBufferOffset = 0
//
//    var uniformBufferIndex = 0
//
//    var uniforms: UnsafeMutablePointer<WireframeUniforms>!
//
//    private var isSetup: Bool = false
//
//    private var bufferUpdate: WireframeBufferUpdate? = nil
//
//    private var pulsePhase: Float {
//        let millisSinceReferenceDate = Int(Date().timeIntervalSince(referenceDate) * 1000)
//        return 0.001 * Float(millisSinceReferenceDate % 1000)
//    }
//
//    // ==============================================================
//    // Graph properties -- Access only on graph-update thread (which
//    // may or may not be main)
//
//    private weak var graphContainer: Container!
//
//    private var nodeIndices = [NodeID: Int]()
//
//    /// touchLocation and touchBounds are in pick coordinates, i.e., x and y in [-1, 1]
//    public func findNearestNode(_ touchLocation: SIMD2<Float>,
//                                _ touchBounds: CGSize,
//                                _ povController: POVController,
//                                _ fovController: FOVController) -> NodeID? {
//
//        print("findNearestNode. touchLocation: \(touchLocation.prettyString), touchBounds: \(touchBounds.width)x\(touchBounds.height)")
//        let ray0 = SIMD4<Float>(Float(touchLocation.x), touchLocation.y, 0, 1)
//        var ray1 = fovController.projectionMatrix.inverse * ray0
//
//        ray1.z = -1
//        ray1.w = 0
//
//        // modelViewMatrix == viewMatrix b/c our model matrix is the identity
//        let modelViewMatrix = povController.viewMatrix
//        let rayOrigin = (modelViewMatrix.inverse * SIMD4<Float>(0, 0, 0, 1)).xyz
//        let rayDirection = normalize(modelViewMatrix.inverse * ray1).xyz
//
//        var nearestNode: Container.GraphType.NodeType? = nil
//        var nearestD2 = Float.greatestFiniteMagnitude
//        var shortestRayDistance = Float.greatestFiniteMagnitude
//        for node in graphContainer.graph.nodes {
//
//            if let nodeLoc = node.value?.location {
//
//                let nodeDisplacement = nodeLoc - rayOrigin
//
//                /// z-distance along the ray to the point closest to the node
//                let rayDistance = simd_dot(nodeDisplacement, rayDirection)
//                // print("\(node) rayDistance: \(rayDistance)")
//
//                if !fovController.isInVisibleSlice(z: rayDistance) {
//                    continue
//                }
//
//                /// nodeD2 is the square of the distance from ray to the node
//                let nodeD2 = simd_dot(nodeDisplacement, nodeDisplacement) - rayDistance * rayDistance
////                print("\(node) distance to ray: \(sqrt(nodeD2))")
//
//                // TODO: apply touchRadius.
//                // In world coordinates, the selection bounds form a squashed cone with the ray as its axis.
//                // I need to calculate the perpendicular distance from the ray to the cone along the line
//                // that passes through node.
//
//                if (nodeD2 < nearestD2 || (nodeD2 == nearestD2 && rayDistance < shortestRayDistance)) {
//                    shortestRayDistance = rayDistance
//                    nearestD2 = nodeD2
//                    nearestNode = node
//                }
//            }
//        }
//
//        print("nearestNode perpendicular distance from ray: \(sqrt(nearestD2))")
//
//        return nearestNode?.id
//    }
//
//    // ==============================================================
//
//    public init(_ graphContainer: Container) {
//        self.graphContainer = graphContainer
//        self.settings = WireframeSettings()
//    }
//
//    public init(_ graphContainer: Container, _ initialSettings: WireframeSettings) {
//        self.graphContainer = graphContainer
//        self.settings = initialSettings
//    }
//
//    //    public init(_ graphContainer: Container, _ settings: WireframeSettings){
//    //        self.graphContainer = graphContainer
//    //        self.settings = settings
//    //    }
//
//    deinit {
//        // debug("Wireframe", "deinit")
//    }
//
//    func setup(_ view: MTKView) throws {
//        // debug("Wireframe.setup", "started")
//
//        if let device = view.device {
//            self.device = device
//        }
//        else {
//            throw RenderError.noDevice
//        }
//
//        if let device = view.device,
//           let library = WireframeShaders.makeLibrary(device) {
//            self.library = library
//            // debug("Wireframe", "setup. library functions: \(library.functionNames)")
//        }
//        else {
//            throw RenderError.noDefaultLibrary
//        }
//
//        if dynamicUniformBuffer == nil {
//            try buildUniforms()
//        }
//
//        if nodePipelineState == nil {
//            try buildNodePipeline(view)
//        }
//
//        if edgePipelineState == nil {
//            try buildEdgePipeline(view)
//        }
//
//        updateFigure(.all)
//        NotificationCenter.default.addObserver(self, selector: #selector(graphHasChanged), name: .graphHasChanged, object: nil)
//        isSetup = true
//    }
//
//    func teardown() {
//        // debug("Wireframe", "teardown")
//        // TODO: maybe dynamicUniformBuffer and uniforms ... if so change declarations from ! to ?
//        // TODO: maybe nodePipelineState ... ditto
//        // TODO: maybe edgePipelineState ... ditto
//        self.nodePositionBuffer = nil
//        self.nodeColorBuffer = nil
//        self.edgeIndexBuffer = nil
//    }
//
//    @objc public func graphHasChanged(_ notification: Notification) {
//        if let graphChange = notification.object as? RenderableGraphChange {
//            updateFigure(graphChange)
//        }
//    }
//
//    /// Expect this to be called on the thread that made the change to the graph, which  may or may not be the main thread
//    public func updateFigure(_ change: RenderableGraphChange) {
//        // debug("Wireframe", "updateFigure: started. change=\(change)")
//
//        var bufferUpdate: WireframeBufferUpdate? = nil
//        if change.nodes {
//            bufferUpdate = self.prepareTopologyUpdate(graphContainer.graph)
//        }
//        else {
//            var newPositions: [SIMD3<Float>]? = nil
//            var newColors: [NodeID : SIMD4<Float>]? = nil
//            var newBBox: BoundingBox? = nil
//
//            if change.nodePositions {
//                newPositions = self.makeNodePositions(graphContainer.graph)
//                newBBox = graphContainer.graph.makeBoundingBox()
//            }
//
//            if change.nodeColors && settings.nodeStyle != .none {
//                newColors = graphContainer.graph.makeNodeColors()
//            }
//
//            if (newPositions != nil || newColors != nil) {
//                bufferUpdate = WireframeBufferUpdate(bbox: newBBox,
//                                             nodeCount: nil,
//                                             nodePositions: newPositions,
//                                             nodeColors: newColors,
//                                             edgeIndexCount: nil,
//                                             edgeIndices: nil)
//            }
//        }
//
//
//        // Gotta write bufferUpdate to self.bufferUpdate on the main thread
//        // in order to avoid a data race
//        if Thread.current.isMainThread {
//            self.bufferUpdate = bufferUpdate
//        }
//        else {
//            DispatchQueue.main.sync {
//                self.bufferUpdate = bufferUpdate
//            }
//        }
//    }
//
//    /// Runs on the rendering thread (i.e., the main thread) once per frame
//    func applyBufferUpdateIfPresent() {
//
//        guard
//            let update = self.bufferUpdate
//        else {
//            // debug("Wireframe", "No bufferUpdate to apply")
//            return
//        }
//
//        // debug("Wireframe", "applying bufferUpdate")
//        self.bufferUpdate = nil
//
//        if let bbox = update.bbox {
//            self.bbox = bbox
//        }
//
//        if let updatedNodeCount = update.nodeCount,
//           self.nodeCount != updatedNodeCount {
//            // debug("Wireframe", "updating nodeCount: \(nodeCount) -> \(updatedNodeCount)")
//            nodeCount = updatedNodeCount
//        }
//
//        if nodeCount == 0 {
//            if nodePositionBuffer != nil {
//                // debug("Wireframe", "discarding nodePositionBuffer")
//                nodePositionBuffer = nil
//            }
//        }
//        else if let newNodePositions = update.nodePositions {
//            if newNodePositions.count != nodeCount {
//                fatalError("Failed sanity check: nodeCount=\(nodeCount) but newNodePositions.count=\(newNodePositions.count)")
//            }
//
//            // debug("Wireframe", "creating nodePositionBuffer")
//            let nodePositionBufLen = nodeCount * MemoryLayout<SIMD3<Float>>.size
//            nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
//                                                   length: nodePositionBufLen,
//                                                   options: [])
//        }
//
//        if nodeCount == 0 {
//            if nodeColorBuffer != nil {
//                // debug("Wireframe", "discarding nodeColorBuffer")
//                nodeColorBuffer = nil
//            }
//        }
//        else if let newNodeColors = update.nodeColors {
//
//            let defaultColor = settings.nodeColorDefault
//            var colorsArray = [SIMD4<Float>](repeating: defaultColor, count: nodeCount)
//            for (nodeID, color) in newNodeColors {
//                if let nodeIndex = nodeIndices[nodeID] {
//                    colorsArray[nodeIndex] = color
//                }
//            }
//
//            // debug("Wireframe", "creating nodeColorBuffer")
//            let nodeColorBufLen = nodeCount * MemoryLayout<SIMD4<Float>>.size
//            nodeColorBuffer = device.makeBuffer(bytes: colorsArray,
//                                                length: nodeColorBufLen,
//                                                options: [])
//        }
//
//        if let updatedEdgeIndexCount = update.edgeIndexCount,
//           self.edgeIndexCount != update.edgeIndexCount {
//            // debug("Wireframe", "updating edgeIndexCount: \(edgeIndexCount) -> \(updatedEdgeIndexCount)")
//            self.edgeIndexCount = updatedEdgeIndexCount
//        }
//
//        if edgeIndexCount == 0 {
//            if edgeIndexBuffer != nil {
//                // debug("Wireframe", "discarding edgeIndexBuffer")
//                self.edgeIndexBuffer = nil
//            }
//        }
//        else if let newEdgeIndices = update.edgeIndices {
//            if newEdgeIndices.count != edgeIndexCount {
//                fatalError("Failed sanity check: edgeIndexCount=\(edgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
//            }
//
//            // debug("Wireframe", "creating edgeIndexBuffer")
//            let bufLen = newEdgeIndices.count * MemoryLayout<UInt32>.size
//            self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices, length: bufLen)
//        }
//    }
//
//
//    public func prepareToDraw(_ mtkView: MTKView, _ renderSettings: RenderSettings) {
//        // print("prepareToDraw -- started. renderSettings=\(renderSettings)")
//        if !isSetup {
//            do {
//                try setup(mtkView)
//            }
//            catch {
//                fatalError("Problem in setup: \(error)")
//            }
//        }
//
//        // ======================================
//        // Rotate the uniforms buffers
//
//        uniformBufferIndex = (uniformBufferIndex + 1) % Renderer.maxBuffersInFlight
//
//        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
//
//        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:WireframeUniforms.self, capacity:1)
//
//        // =====================================
//        // Update content of current uniforms buffer
//        //
//        // NOTE uniforms.modelViewMatrix is equal to renderSettings.viewMatrix
//        // because we are drawing the graph in world coordinates, i.e., our model
//        // matrix is the identity.
//
//        uniforms[0].projectionMatrix = renderSettings.projectionMatrix
//        uniforms[0].modelViewMatrix = renderSettings.viewMatrix
//        uniforms[0].pointSize = Float(self.settings.getNodeSize(forPOV: renderSettings.pov, bbox: self.bbox))
//        uniforms[0].edgeColor = self.settings.edgeColor
//        uniforms[0].fadeoutMidpoint = renderSettings.fadeoutMidpoint
//        uniforms[0].fadeoutDistance = renderSettings.fadeoutDistance
//        uniforms[0].pulsePhase = pulsePhase
//
//        // =====================================
//        // Possibly update contents of the other buffers
//
//        applyBufferUpdateIfPresent()
//
//    }
//
//    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
//        // _drawCount += 1
//        // debug("Wireframe.encodeCommands[\(_drawCount)]")
//
//        // Do the uniforms no matter what.
//
//        encoder.setVertexBuffer(dynamicUniformBuffer,
//                                offset:uniformBufferOffset,
//                                index: dynamicUniformBufferIndex)
//        encoder.setFragmentBuffer(dynamicUniformBuffer,
//                                  offset:uniformBufferOffset,
//                                  index: dynamicUniformBufferIndex)
//
//        // If we don't have node positions we can't draw either nodes or edges
//        // so we should return early.
//        guard
//            let nodePositionBuffer = self.nodePositionBuffer
//        else {
//            return
//        }
//
//        encoder.setVertexBuffer(nodePositionBuffer,
//                                offset: 0,
//                                index: nodePositionBufferIndex)
//
//        if let edgeIndexBuffer = self.edgeIndexBuffer {
//            encoder.pushDebugGroup("Edges")
//            encoder.setRenderPipelineState(edgePipelineState)
//            encoder.drawIndexedPrimitives(type: .line,
//                                          indexCount: edgeIndexCount,
//                                          indexType: MTLIndexType.uint32,
//                                          indexBuffer: edgeIndexBuffer,
//                                          indexBufferOffset: 0)
//            encoder.popDebugGroup()
//        }
//
//        if let nodeColorBuffer = self.nodeColorBuffer {
//            encoder.pushDebugGroup("Nodes")
//            encoder.setRenderPipelineState(nodePipelineState)
//            encoder.setVertexBuffer(nodeColorBuffer,
//                                    offset: 0,
//                                    index: nodeColorBufferIndex)
//            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
//            encoder.popDebugGroup()
//        }
//    }
//
//    private func prepareTopologyUpdate(_ graph: Container.GraphType) -> WireframeBufferUpdate {
//
//        var newNodeIndices = [NodeID: Int]()
//        var newNodePositions = [SIMD3<Float>]()
//        var newEdgeIndexData = [UInt32]()
//
//        var nodeIndex: Int = 0
//        for node in graph.nodes {
//            if let nodeValue = node.value {
//                newNodeIndices[node.id] = nodeIndex
//                newNodePositions.insert(nodeValue.location, at: nodeIndex)
//                nodeIndex += 1
//            }
//        }
//
//        // OK
//        self.nodeIndices = newNodeIndices
//
//        var edgeIndex: Int = 0
//        for node in graph.nodes {
//            for edge in node.outEdges {
//                if let edgeValue = edge.value,
//                   !edgeValue.hidden,
//                   let sourceIndex = newNodeIndices[edge.source.id],
//                   let targetIndex = newNodeIndices[edge.target.id] {
//                    newEdgeIndexData.insert(UInt32(sourceIndex), at: edgeIndex)
//                    edgeIndex += 1
//                    newEdgeIndexData.insert(UInt32(targetIndex), at: edgeIndex)
//                    edgeIndex += 1
//                }
//            }
//        }
//
//        return WireframeBufferUpdate(
//            bbox: graph.makeBoundingBox(),
//            nodeCount: newNodePositions.count,
//            nodePositions: newNodePositions,
//            nodeColors: settings.nodeStyle == .none ? nil : graph.makeNodeColors(),
//            edgeIndexCount: newEdgeIndexData.count,
//            edgeIndices: newEdgeIndexData
//        )
//    }
//
//    private func makeNodePositions(_ graph: Container.GraphType) -> [SIMD3<Float>] {
//        //    private func makeNodePositions<G: Graph>(_ graph: G) -> [SIMD3<Float>] where E == G.EdgeType.ValueType, N == G.NodeType.ValueType {
//        var newNodePositions = [SIMD3<Float>]()
//        for node in graph.nodes {
//            if let nodeIndex = nodeIndices[node.id],
//               let nodeValue = node.value {
//                newNodePositions.insert(nodeValue.location, at: nodeIndex)
//            }
//        }
//        return newNodePositions
//    }
//
//    private func buildUniforms() throws {
//        let uniformBufferSize = alignedUniformsSize * Renderer.maxBuffersInFlight
//        if let buffer = device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) {
//            self.dynamicUniformBuffer = buffer
//            self.dynamicUniformBuffer.label = "UniformBuffer"
//            self.uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:WireframeUniforms.self, capacity:1)
//        }
//        else {
//            throw RenderError.bufferCreationFailed
//        }
//    }
//
//    private func buildNodePipeline(_ view: MTKView) throws {
//
//        let vertexFunction = library.makeFunction(name: "node_vertex")
//        let fragmentFunction = library.makeFunction(name: nodeFragmentFunctionName)
//        let vertexDescriptor = MTLVertexDescriptor()
//
//        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
//        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
//        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = WireframeBufferIndex.nodePosition.rawValue
//
//        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].format = MTLVertexFormat.float4
//        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].offset = 0
//        vertexDescriptor.attributes[WireframeVertexAttribute.color.rawValue].bufferIndex = WireframeBufferIndex.nodeColor.rawValue
//
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepRate = 1
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex
//
//        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stride = MemoryLayout<SIMD4<Float>>.stride
//        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stepRate = 1
//        vertexDescriptor.layouts[WireframeBufferIndex.nodeColor.rawValue].stepFunction = MTLVertexStepFunction.perVertex
//
//        let pipelineDescriptor = MTLRenderPipelineDescriptor()
//
//        pipelineDescriptor.label = "NodePipeline"
//        pipelineDescriptor.sampleCount = view.sampleCount
//        pipelineDescriptor.vertexFunction = vertexFunction
//        pipelineDescriptor.fragmentFunction = fragmentFunction
//        pipelineDescriptor.vertexDescriptor = vertexDescriptor
//
//        // These are for fadeout of the nodes
//        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
//        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
//
//        // I'm guessing that these might help with other things that get drawn on top
//        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
//        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
//
//        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
//        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
//        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat
//
//        self.nodePipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
//    }
//
//    private func buildEdgePipeline(_ view: MTKView) throws {
//
//        let vertexFunction = library.makeFunction(name: "net_vertex")
//        let fragmentFunction = library.makeFunction(name: "net_fragment")
//
//        let vertexDescriptor = MTLVertexDescriptor()
//
//        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].format = MTLVertexFormat.float3
//        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].offset = 0
//        vertexDescriptor.attributes[WireframeVertexAttribute.position.rawValue].bufferIndex = WireframeBufferIndex.nodePosition.rawValue
//
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stride = MemoryLayout<SIMD3<Float>>.stride
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepRate = 1
//        vertexDescriptor.layouts[WireframeBufferIndex.nodePosition.rawValue].stepFunction = MTLVertexStepFunction.perVertex
//
//        let pipelineDescriptor = MTLRenderPipelineDescriptor()
//        pipelineDescriptor.label = "EdgePipeline"
//        pipelineDescriptor.sampleCount = view.sampleCount
//        pipelineDescriptor.vertexFunction = vertexFunction
//        pipelineDescriptor.fragmentFunction = fragmentFunction
//        pipelineDescriptor.vertexDescriptor = vertexDescriptor
//
//        // These are for fadeout of the edges
//        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
//        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
//        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
//
//        // I'm guessing that these might help with other things that get drawn on top
//        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
//        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
//
//        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
//        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
//        pipelineDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat
//
//        edgePipelineState =  try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
//    }
//}
//
//public struct WireframeBufferUpdate {
//    public let bbox: BoundingBox?
//    public let nodeCount: Int?
//    public let nodePositions: [SIMD3<Float>]?
//    public let nodeColors: [NodeID: SIMD4<Float>]?
//    public let edgeIndexCount: Int?
//    public let edgeIndices: [UInt32]?
//}
/////
/////
/////
//extension Notification.Name {
//    public static var graphHasChanged: Notification.Name { return .init("graphHasChanged") }
//}
//
//
/////
/////
/////
//public protocol RenderableGraphContainer: AnyObject {
//    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
//                                          GraphType.EdgeType.ValueType: RenderableEdgeValue
//
//    var graph: GraphType { get set }
//
//    func fireGraphChange(_ change: RenderableGraphChange)
//}
//
/////
/////
/////
//extension RenderableGraphContainer {
//
//    public func fireGraphChange(_ change: RenderableGraphChange) {
//        NotificationCenter.default.post(name: .graphHasChanged, object: change)
//    }
//}

