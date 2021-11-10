//
//  GraphView.swift
//  GraphMetal
//

import SwiftUI
import MetalKit
import Wacoma
import GenericGraph

// https://stackoverflow.com/questions/65461516/how-do-i-trigger-updateuiview-of-a-uiviewrepresentable#:~:text=1%20Answer&text=You%20need%20to%20create%20UIKit,should%20update%20your%20UIKit%20view.
// sez
// @Binding var backgroundColor in my UIViewRepresentable
//
// https://github.com/nalexn/ViewInspector/issues/6
// sez
// "For UIViewRepresentable, you have to wrap that into a standalone native SwiftUI view,
// using a @State to pass to the actual test view's @Binding. And it should have a closure
// that receive Self and send it outside. Because the structure is copied or you'll lost
// the @State status."
//
// which suggests to me that I can create a @State in view containing this guy
// and pass it in to this guy's init as a Binding.

public struct GraphView<S: RenderableGraphHolder> {

    @Binding var rendererSettings: RendererSettings

    var graphHolder: S

    var povController: POVController

    var projectionMatrix: float4x4 {
        return povController.projectionMatrix
    }

    var modelViewMatrix: float4x4 {
        return povController.modelViewMatrix
    }

    let tapHandler: RendererTapHandler?

    let longPressHandler: RendererLongPressHandler?


    public init(_ settings: Binding<RendererSettings>,
                _ graphHolder: S,
                _ povController: POVController,
                tapHandler: RendererTapHandler? = nil,
                longPressHandler: RendererLongPressHandler? = nil) {
        self._rendererSettings = settings
        self.graphHolder = graphHolder
        self.povController = povController
        self.tapHandler = tapHandler
        self.longPressHandler = longPressHandler
    }

    public func makeCoordinator() -> GraphRenderer<S> {
        do {
            let renderer = try GraphRenderer<S>(self)
            povController.rendererControls = renderer
            return renderer
        }
        catch {
            fatalError("Problem creating renderer: \(error)")
        }
    }


    func updateProjection(viewSize: CGSize) {
        povController.updateProjection(viewSize: viewSize)
    }

    func updatePOV() {
        povController.updateModelView(Date())
    }
}

#if os(iOS)
extension GraphView: UIViewRepresentable {

    public typealias UIViewType = MTKView

    public func makeUIView(context: Context) -> MTKView {
        debug("GraphView", "makeUIView")
        debug("GraphView", "rendererSettings.backgroundColor = \(rendererSettings.backgroundColor)")

        let mtkView = MTKView()

        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.device = context.coordinator.device
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        mtkView.enableSetNeedsDisplay = true

        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

        mtkView.isPaused = false

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

        context.coordinator.dragHandler = povController
        context.coordinator.pinchHandler = povController
        context.coordinator.rotationHandler = povController

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

        self.updateUIView(mtkView, context: context)
        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        debug("GraphView", "updateUIView")

        mtkView.clearColor = MTLClearColorMake(rendererSettings.backgroundColor.x,
                                               rendererSettings.backgroundColor.y,
                                               rendererSettings.backgroundColor.z,
                                               rendererSettings.backgroundColor.w)

        context.coordinator.applySettings(rendererSettings)
    }

}
#elseif os(macOS)
extension GraphView: NSViewRepresentable {

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

    mutating func rotationChanged(by radians: Float)

    mutating func rotationEnded()
}
