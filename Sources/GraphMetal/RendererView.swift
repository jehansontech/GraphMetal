//
//  RendererView.swift
//  ArcWorld
//
//  Created by Jim Hanson on 3/17/21.
//

import SwiftUI
import MetalKit


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


class WidgetUpdateTask: GraphAccessTask {

    var updates: [GraphAccessTask]

    init(_ updates: [GraphAccessTask]) {
        self.updates = updates
    }

    func accessGraph<N, E>(_ holder: GraphHolder<N, E>) where N : RenderableNodeValue, E : RenderableEdgeValue {
        for update in updates {
            update.accessGraph(holder)
        }
    }

    func afterAccess() {
        for update in updates {
            update.afterAccess()
        }
    }

}
///
///
///
public struct RendererView<N: RenderableNodeValue, E: RenderableEdgeValue>: UIViewRepresentable {

    public typealias UIViewType = MTKView

    @EnvironmentObject var povController: POVController

    @EnvironmentObject var graphController: GraphController<N, E>

    var projectionMatrix: float4x4 {
        return povController.projectionMatrix
    }

    var modelViewMatrix: float4x4 {
        return povController.modelViewMatrix
    }

    let tapHandler: RendererTapHandler?

    let longPressHandler: RendererLongPressHandler?

    public init(tapHandler: RendererTapHandler? = nil,
         longPressHandler: RendererLongPressHandler? = nil) {
        self.tapHandler = tapHandler
        self.longPressHandler = longPressHandler
    }

    public func makeCoordinator() -> Renderer<N, E> {
        do {
            return try Renderer<N, E>(self)
        }
        catch {
            fatalError("Problem creating renderer: \(error)")
        }
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
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

        return mtkView
    }

    public func updateUIView(_ view: MTKView, context: Context) {
        // print("RendererView.updateUIView")
    }

    func updateProjection(viewSize: CGSize) {
        povController.updateProjection(viewSize: viewSize)
    }

    func prepareToDraw(_ widgetUpdates: [GraphAccessTask]) {
        let currTime = Date()
        povController.updateModelView(currTime)
        graphController.submitTask(WidgetUpdateTask(widgetUpdates))
    }
}
