//
//  GraphView.swift
//  GraphMetal
//

import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

public struct GraphView<S: RenderableGraphHolder> {

//     @Binding var rendererSettings: RendererSettings

    var graphHolder: S

    weak var povController: POVController!

    private var _fallbackPOVController: POVController? = nil

    //    // NOT USED
    //    var projectionMatrix: float4x4 {
    //        return povController.projectionMatrix
    //    }
    //
    //    // NOT USED
    //    var modelViewMatrix: float4x4 {
    //        return povController.modelViewMatrix
    //    }

    let tapHandler: RendererTapHandler?

    let longPressHandler: RendererLongPressHandler?

    // weak?
    var graphRendererSettings: GraphRendererSettings?

    // weak?
    var wireframeSettings: GraphWireFrameSettings?

    public init(_ graphHolder: S,
                _ povController: POVController,
                rendererSettings: GraphRendererSettings? = nil,
                wireframeSettings: GraphWireFrameSettings? = nil,
                tapHandler: RendererTapHandler? = nil,
                longPressHandler: RendererLongPressHandler? = nil) {
        // self._rendererSettings = oldStyleSettings

        self.graphHolder = graphHolder
        self.povController = povController
        self.graphRendererSettings = rendererSettings
        self.wireframeSettings = wireframeSettings

        self.tapHandler = tapHandler
        self.longPressHandler = longPressHandler
    }

    public func makeCoordinator() -> GraphRenderer<S> {
        do {
            let renderer = try GraphRenderer<S>(self, graphRendererSettings, wireframeSettings)
            // povController.rendererControls = renderer
            return renderer
        }
        catch {
            fatalError("Problem creating renderer: \(error)")
        }
    }

    //    // NOT USED
    //    func updateProjection(viewSize: CGSize) {
    //        povController.updateProjection(viewSize: viewSize)
    //    }
    //
    //    // NOT USED
    //    func updatePOV() {
    //        povController.updateModelView(Date())
    //    }

}

#if os(iOS)
extension GraphView: UIViewRepresentable {

    public typealias UIViewType = MTKView

    public func makeUIView(context: Context) -> MTKView {
        debug("GraphView (iOS) makeUIView", "started")

        let mtkView = MTKView()

        // Stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.device
        mtkView.preferredFramesPerSecond = 60
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        mtkView.clearColor = MTLClearColorMake(context.coordinator.settings.backgroundColor.x,
                                               context.coordinator.settings.backgroundColor.y,
                                               context.coordinator.settings.backgroundColor.z,
                                               context.coordinator.settings.backgroundColor.w)

        // Gestures

        context.coordinator.dragHandler = povController
        context.coordinator.pinchHandler = povController
        context.coordinator.rotationHandler = povController

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
#elseif os(macOS)
extension GraphView: NSViewRepresentable {
    public typealias NSViewType = MTKView

    public func makeNSView(context: Context) -> MTKView {
        debug("GraphView (macOS) makeNSView", "started")

        let mtkView = MTKView()

        // Stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        mtkView.delegate = context.coordinator
        mtkView.device = context.coordinator.device
        mtkView.preferredFramesPerSecond = 60
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

        mtkView.clearColor = MTLClearColorMake(context.coordinator.settings.backgroundColor.x,
                                               context.coordinator.settings.backgroundColor.y,
                                               context.coordinator.settings.backgroundColor.z,
                                               context.coordinator.settings.backgroundColor.w)
        // Gestures

        context.coordinator.dragHandler = povController
        context.coordinator.pinchHandler = povController
        context.coordinator.rotationHandler = povController

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
#endif



public protocol RendererTapHandler {

    /// location is in clip space: (-1, -1) to (+1, +1)
    mutating func tap(at location: SIMD2<Float>)

}


public protocol RendererLongPressHandler {

    /// location is in clip space: (-1, -1) to (+1, +1)
    mutating func longPressBegan(at location: SIMD2<Float>)

    mutating func longPressEnded()
}


public protocol RendererDragHandler {

    /// location is in clip space: (-1, -1) to (+1, +1)
    mutating func dragBegan(at location: SIMD2<Float>)

    /// pan is fraction of view width; negative means "to the left"
    /// scroll is fraction of view height; negative means "down"
    mutating func dragChanged(pan: Float, scroll: Float)

    mutating func dragEnded()

}


public protocol RendererPinchHandler {

    /// center is midpoint between two fingers
    mutating func pinchBegan(at center: SIMD2<Float>)

    /// scale goes like 1 -> 0.1 when squeezing,  1 -> 10 when stretching
    mutating func pinchChanged(by scale: Float)

    mutating func pinchEnded()

}


public protocol RendererRotationHandler {

    /// center is midpoint between two fingers
    mutating func rotationBegan(at center: SIMD2<Float>)

    /// increases as the fingers rotate counterclockwise
    mutating func rotationChanged(by radians: Float)

    mutating func rotationEnded()
}
