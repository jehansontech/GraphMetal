//
//  GraphRenderer.swift
//  GraphMetal
//

import Metal
import MetalKit
import simd
import GenericGraph
import Shaders
import Wacoma

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case noDevice
    case noDefaultLibrary
    case noDepthStencilState
    case badVertexDescriptor
    case bufferCreationFailed
}

/// This protocol exists so that we can extend it, e.g., in Snapshots.swift
protocol GraphRendererProtocol: MTKViewDelegate {
}

fileprivate var rendererInstanceCount: Int = 0

///
///
///
public class GraphRenderer<S: RenderableGraphHolder>: NSObject, GraphRendererProtocol, RenderControllerDelegate {

    public typealias NodeValueType = S.GraphType.NodeType.ValueType

    public typealias EdgeValueType = S.GraphType.EdgeType.ValueType

    let graphHolder: S

    weak var renderController: RenderController!

    weak var povController: POVController!

    private let _defaultRenderController: RenderController?

    private let _defaultPOVController: POVController?

    private let _defaultWireframeSettings: GraphWireframeSettings?

    var viewSize: CGSize

    var projectionMatrix: float4x4

    var modelViewMatrix: float4x4

    var screenshotRequested: Bool = false

    var gestureDelegate: RendererGestureDelegate
    
    let device: MTLDevice!

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    let commandQueue: MTLCommandQueue

    var depthState: MTLDepthStencilState

    var wireFrame: GraphWireframe<NodeValueType, EdgeValueType>
    
    // private var _drawCount: Int = 0

    public init(_ graphHolder: S,
                renderController: RenderController?,
                povController: POVController?,
                wireframeSettings: GraphWireframeSettings?) throws {

        rendererInstanceCount += 1
        debug("GraphRenderer.init", "instanceCount=\(rendererInstanceCount)")

        self.graphHolder = graphHolder

        if let renderController = renderController {
            self._defaultRenderController = nil
            self.renderController = renderController
        }
        else {
            debug("GraphRenderer.init", "Creating default render controller")
            let renderController = RenderController()
            self._defaultRenderController = renderController
            self.renderController = renderController
        }

        if let povController = povController {
            self._defaultPOVController = nil
            self.povController = povController
        }
        else {
            debug("GraphRender.init", "Creating default POV controller")
            let povController = POVController()
            self._defaultPOVController = povController
            self.povController = povController
        }

        // NOTE the pov gesture handlers could be replaced later by GraphView
        self.gestureDelegate = RendererGestureDelegate()
        self.gestureDelegate.dragHandler = self.povController
        self.gestureDelegate.pinchHandler = self.povController
        self.gestureDelegate.rotationHandler = self.povController

        // Dummy values
        self.viewSize = CGSize(width: 100, height: 100) // dummy nonzero values
        self.projectionMatrix = Self.makeProjectionMatrix(viewSize, self.renderController!)
        self.modelViewMatrix = Self.makeModelViewMatrix(POV())

        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        else {
            throw RendererError.noDevice
        }

        self.commandQueue = device.makeCommandQueue()!
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true

        if let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) {
            depthState = state
        }
        else {
            throw RendererError.noDepthStencilState
        }

        if let wireframeSettings = wireframeSettings {
            self._defaultWireframeSettings = nil
            wireFrame = try GraphWireframe(device, wireframeSettings)
        }
        else {
            debug("GraphRenderer.init", "Creating default wireframe settings")
            let wireframeSettings = GraphWireframeSettings()
            self._defaultWireframeSettings = wireframeSettings
            wireFrame = try GraphWireframe(device, wireframeSettings)
        }

        super.init()

        self.renderController!.delegate = self

        self.graphHasChanged(RenderableGraphChange.ALL)
        NotificationCenter.default.addObserver(self, selector: #selector(notifyGraphHasChanged), name: .graphHasChanged, object: nil)
    }

    deinit {
        debug("GraphRenderer", "deinit")
        // MAYBE remove observer at some point -- but doesn't it need to be BEFORE deinitialization?
        // . . . unless it automagically gets removed under the covers.
    }

    static func makeProjectionMatrix(_ viewSize: CGSize, _ settings: RenderController) -> float4x4 {
        let aspectRatio = (viewSize.height > 0) ? Float(viewSize.width) / Float(viewSize.height) : 1
        return float4x4(perspectiveProjectionRHFovY: settings.yFOV,
                        aspectRatio: aspectRatio,
                        nearZ: settings.zNear,
                        farZ: settings.zFar)
    }

    static func makeModelViewMatrix(_ pov: POV) -> float4x4 {
        return float4x4(lookAt: pov.center, eye: pov.location, up: pov.up)
    }

    public func requestScreenshot() {
        self.screenshotRequested = true
    }
    
    public func findNearestNode(_ clipLocation: SIMD2<Float>) -> NodeID? {

        if let (nn, _) = graphHolder.graph.findNearestNode(clipLocation,
                                                           projectionMatrix: self.projectionMatrix,
                                                           modelViewMatrix: self.modelViewMatrix,
                                                           zNear: self.renderController.zNear,
                                                           zFar: self.renderController.zFar) {
            return nn.id
        }
        else {
            return nil
        }
    }

    @objc public func notifyGraphHasChanged(_ notification: Notification) {
        if let graphChange = notification.object as? RenderableGraphChange {
            graphHasChanged(graphChange)
        }
    }

    public func graphHasChanged(_ graphChange: RenderableGraphChange) {
        let t0 = Date()
        debug("GraphRenderer.graphHasChanged", "starting.")

        // We expect this method to be called on the background thread, i.e, the thread
        // on which the changes
        // to the graph were made. But the render controller's updateInProgress has to be
        // modified on the main thread. Otherwise we get this runtime issue:
        // "Publishing changes from background threads is not allowed; make sure to publish values
        // from the main thread (via operators like receive(on:)) on model updates."

        // Use async because it does sometimes get called on the main thread.
        DispatchQueue.main.async {
            self.renderController.updateStarted()
        }
        
        wireFrame.graphHasChanged(graphHolder.graph, graphChange)
        let dt = Date().timeIntervalSince(t0)
        debug("GraphRenderer.graphHasChanged", "done. dt=\(dt)")
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        debug("GraphRenderer.mtkView(size)", "started. size=\(size)")

        self.viewSize = size
        // let projectionMatrix = Self.makeProjectionMatrix(viewSize, settings)

        do {
            try wireFrame.setup(view)
        }
        catch {
            // TODO log it
            print("Problem initializing graph rendering pipelines: \(error)")
        }
    }

    public func draw(in view: MTKView) {
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // _drawCount += 1
        // let t0 = Date()

        // FIXME: what's this doing here?
        if renderController.updateInProgress {
            debug("GraphRenderer.draw", "starting. update is currently in progress.")
        }

        // snapshot is before the update -- i.e., it shows the results of prev. draw
        // Q: what if I do it LAST?
        if screenshotRequested {
            saveSnapshot(view)
            screenshotRequested = false
        }

        self.preDraw(view)

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in
                semaphore.signal()
            }

            // Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            //   holding onto the drawable and blocking the display pipeline any longer than necessary
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor,
               let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
               let drawable = view.currentDrawable {

                // My background is opaque and I'm not doing multipass rendering
                // so therefore I don't care about load actions or store actions
                // renderPassDescriptor.colorAttachments[0].loadAction = .clear
                // renderPassDescriptor.colorAttachments[0].storeAction = .store

                renderEncoder.setDepthStencilState(depthState)
                wireFrame.encodeCommands(renderEncoder)
                renderEncoder.endEncoding()
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }

        // FIXME: why the if statement?
        if renderController.updateInProgress {
            renderController.updateCompleted()
        }

        //        let dt = Date().timeIntervalSince(t0)
        //        debug("GraphRenderer.draw", "done. dt=\(dt)")
    }
    
    
    private func preDraw(_ view: MTKView) {

        // Update POV here in case it's moving.
        let pov = povController.updatePOV(Date())
        // debug("GraphRenderer.preDraw", "new POV = \(pov)")
        
        self.projectionMatrix = Self.makeProjectionMatrix(viewSize, renderController)
        self.modelViewMatrix = Self.makeModelViewMatrix(pov)

        wireFrame.preDraw(projectionMatrix: projectionMatrix,
                          modelViewMatrix: modelViewMatrix,
                          pov: pov,
                          fadeoutOnset: renderController.fadeoutOnset,
                          fadeoutDistance: renderController.fadeoutDistance)


        //        let dt = Date().timeIntervalSince(t0)
        //        if (dt > 1/30) {
        //            debug("Renderer", "predraw: elapsed time \(dt)")
        //        }

    }

    func saveSnapshot(_ view: MTKView) {
        if let cgImage = view.takeSnapshot() {
            self.saveImage(cgImage)
        }
    }
}
