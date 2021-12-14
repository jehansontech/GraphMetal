//
//  GraphView.swift
//  GraphMetal
//

import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

fileprivate var graphViewInstanceCount: Int = 0

public struct GraphView<S: RenderableGraphHolder> {

    var graphHolder: S

    private var renderController: RenderController?

    private var povController: POVController?

    private var wireframeSettings: GraphWireframeSettings?

    let tapHandler: RendererTapHandler?

    let longPressHandler: RendererLongPressHandler?

    public init(_ graphHolder: S,
                renderController: RenderController? = nil,
                povController: POVController? = nil,
                wireframeSettings: GraphWireframeSettings? = nil,
                tapHandler: RendererTapHandler? = nil,
                longPressHandler: RendererLongPressHandler? = nil) {

        graphViewInstanceCount += 1
        debug("GraphView.init", "instanceCount=\(graphViewInstanceCount)")
        
        self.graphHolder = graphHolder
        self.renderController = renderController
        self.povController = povController
        self.wireframeSettings = wireframeSettings
        self.tapHandler = tapHandler
        self.longPressHandler = longPressHandler
    }

    public func makeCoordinator() -> GraphRenderer<S> {
        do {
            debug("GraphView.makeCoordinator", "creating GraphRenderer")
            return try GraphRenderer<S>(self.graphHolder,
                                        renderController: self.renderController,
                                        povController: self.povController,
                                        wireframeSettings: self.wireframeSettings)
        }
        catch {
            fatalError("Problem creating coordinator: \(error)")
        }
    }
}

#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension GraphView: UIViewRepresentable {

    public typealias UIViewType = MTKView

    public func makeUIView(context: Context) -> MTKView {
        debug("GraphView (iOS) makeUIView", "started")

        let mtkView = MTKView()

        // Stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        // Basic configuration
        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.device
        mtkView.framebufferOnly = false // necessary for screenshots
        mtkView.preferredFramesPerSecond = 60
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

        mtkView.clearColor = MTLClearColorMake(context.coordinator.renderController.backgroundColor.x,
                                               context.coordinator.renderController.backgroundColor.y,
                                               context.coordinator.renderController.backgroundColor.z,
                                               context.coordinator.renderController.backgroundColor.w)

        // POV gestures

        let panGR = UIPanGestureRecognizer(target: context.coordinator,
                                           action: #selector(context.coordinator.pan))
        panGR.delegate = context.coordinator
        mtkView.addGestureRecognizer(panGR)

        let pinchGR = UIPinchGestureRecognizer(target: context.coordinator,
                                               action: #selector(context.coordinator.pinch))
        pinchGR.delegate = context.coordinator
        mtkView.addGestureRecognizer(pinchGR)

        let rotationGR = UIRotationGestureRecognizer(target: context.coordinator,
                                                     action: #selector(context.coordinator.rotate))
        rotationGR.delegate = context.coordinator
        mtkView.addGestureRecognizer(rotationGR)


        // Other gestures

        if let tapHandler = self.tapHandler {
            context.coordinator.tapHandler = tapHandler
            let tapGR = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(context.coordinator.tap))
            mtkView.addGestureRecognizer(tapGR)
        }

        if let longPressHandler = self.longPressHandler {
            context.coordinator.longPressHandler = longPressHandler
            let longPressGR = UILongPressGestureRecognizer(target: context.coordinator,
                                                           action: #selector(context.coordinator.longPress))
            mtkView.addGestureRecognizer(longPressGR)
        }

        // Finally, update and unpause
        self.updateUIView(mtkView, context: context)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        debug("GraphView (iOS) updateUIView", "NOP")
    }

}

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension GraphView: NSViewRepresentable {
    public typealias NSViewType = MTKView

    public func makeNSView(context: Context) -> MTKView {
        debug("GraphView (macOS) makeNSView", "started")

        let mtkView = MTKView()

        // Stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        // Basic configuration
        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.device
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false // necessary for screenshots
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

        mtkView.clearColor = MTLClearColorMake(context.coordinator.renderController.backgroundColor.x,
                                               context.coordinator.renderController.backgroundColor.y,
                                               context.coordinator.renderController.backgroundColor.z,
                                               context.coordinator.renderController.backgroundColor.w)
        // POV gestures

        let panGR = NSPanGestureRecognizer(target: context.coordinator,
                                           action: #selector(context.coordinator.pan))
        panGR.delegate = context.coordinator
        mtkView.addGestureRecognizer(panGR)

        let pinchGR = NSMagnificationGestureRecognizer(target: context.coordinator,
                                                       action: #selector(context.coordinator.pinch))
        pinchGR.delegate = context.coordinator
        mtkView.addGestureRecognizer(pinchGR)

        let rotationGR = NSRotationGestureRecognizer(target: context.coordinator,
                                                     action: #selector(context.coordinator.rotate))
        rotationGR.delegate = context.coordinator
        mtkView.addGestureRecognizer(rotationGR)

        // Other gestures

        if let tapHandler = self.tapHandler {
            context.coordinator.tapHandler = tapHandler
            let tapGR = NSClickGestureRecognizer(target: context.coordinator,
                                                 action: #selector(context.coordinator.tap))
            mtkView.addGestureRecognizer(tapGR)
        }

        if let longPressHandler = self.longPressHandler {
            context.coordinator.longPressHandler = longPressHandler
            let longPressGR = NSPressGestureRecognizer(target: context.coordinator,
                                                       action: #selector(context.coordinator.longPress))
            mtkView.addGestureRecognizer(longPressGR)
        }


        // Finally, update and unpause
        self.updateNSView(mtkView, context: context)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        return mtkView
    }

    public func updateNSView(_ mtkView: MTKView, context: Context) {
        debug("GraphView (macOS) updateNSView", "NOP")
    }
}

#endif // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


