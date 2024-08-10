//
//  ZRendererView.swift
//  GraphMetal
//
//  Created by Jim Hanson on 1/8/22.
//

import SwiftUI
import MetalKit
import Wacoma

public struct ZRendererView {

    @ObservedObject var renderer: ZRenderer

    var gestureHandlers: GestureHandlers?

    public init(_ renderer: ZRenderer,
                _ gestureHandlers: GestureHandlers? = nil) {
        self.renderer = renderer
        self.gestureHandlers = gestureHandlers
    }

    public func makeCoordinator() -> ZRenderCoordinator {
        // Docco sez, "Implement this method if changes to your view might affect other
        // parts of your app. In your implementation, create a custom Swift instance that
        // can communicate with other parts of your interface. For example, you might
        // provide an instance that binds its variables to SwiftUI properties, causing
        // the two to remain synchronized."

        do {
            return try ZRenderCoordinator(renderer, gestureHandlers ?? GestureHandlers())
        }
        catch {
            fatalError("Problem creating render coordinator: \(error)")
        }
    }

    public func makeMTKView(_ coordinator: ZRenderCoordinator) -> MTKView {
        // Docco sez, "Creates the view object and configures its initial state."

        // print("RendererView.makeMTKView")

        let mtkView = MTKView()

        // Pause to stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        // Configure mtkView
        mtkView.delegate = coordinator
        mtkView.device = coordinator.device
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        mtkView.framebufferOnly = false // necessary for screenshots

        // Fiddly stuff w/r/t the coordinator
        coordinator.setup(mtkView)
        coordinator.connectGestures(mtkView)

        // Update and unpause
        doUpdate(mtkView, coordinator)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        return mtkView
    }

    public func updateMTKView(_ mtkView: MTKView, _ coordinator: ZRenderCoordinator) {
        // Docco sez, "Updates the state of the specified view with
        // new information from SwiftUI." This struct gets recreated many many times,
        // and I think the system calls makeMTKView the first time this is created
        // but it calls this method all the subsequent times.
        //
        // EMPIRICAL: I'm seeing this method called once per handful of calls to draw()

        // print("RendererView.updateMTKView")
        doUpdate(mtkView, coordinator)
    }

    private func doUpdate(_ mtkView: MTKView, _ coordinator: ZRenderCoordinator) {

        // print("RendererView.doUpdate: Entered. view bounds: \(mtkView.bounds), drawableSize: \(mtkView.drawableSize)")

        // NOTE mtkView's bounds are measured in points while its drawableSize is measured
        // in pixels. They need not match, e.g., on my ipad, bounds = (0.0, 0.0, 1180.0, 820.0)
        // and drawableSize =  (2360.0, 1640.0)

        // RenderController's settings MIGHT have changed. The only one we care about
        // here is backgroundColor.

        let clearColor: SIMD4<Float> = coordinator.renderer.backgroundColor
        mtkView.clearColor = MTLClearColorMake(Double(clearColor.x),
                                               Double(clearColor.y),
                                               Double(clearColor.z),
                                               Double(clearColor.w))

    }

    static public func dismantleMTKView(_ mtkView: MTKView, _ coordinator: ZRenderCoordinator) {
        coordinator.disconnectGestures(mtkView)
    }
}

#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension ZRendererView: UIViewRepresentable {

    public typealias UIViewType = MTKView
    public typealias Coordinator = ZRenderCoordinator

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = makeMTKView(context.coordinator)
        mtkView.isMultipleTouchEnabled = true
        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleUIView(_ mtkView: MTKView, coordinator: ZRenderCoordinator) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension ZRendererView: NSViewRepresentable {

    public typealias NSViewType = MTKView
    public typealias Coordinator = ZRenderCoordinator

    public func makeNSView(context: Context) -> MTKView {
        return makeMTKView(context.coordinator)
    }

    public func updateNSView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleNSView(_ mtkView: MTKView, coordinator: ZRenderCoordinator) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#endif // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


