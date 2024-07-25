//
//  File.swift
//  
//
//  Created by Jim Hanson on 7/25/24.
//

import SwiftUI
import MetalKit
import Wacoma

public struct RendererView {

    @ObservedObject var controller: RenderController

    var gestureHandlers: GestureHandlers?

    public init(_ controller: RenderController,
                _ gestureHandlers: GestureHandlers? = nil) {
        self.controller = controller
        self.gestureHandlers = gestureHandlers
    }

    public func makeCoordinator() -> Renderer {
        // Docco sez, "Implement this method if changes to your view might affect other
        // parts of your app. In your implementation, create a custom Swift instance that
        // can communicate with other parts of your interface. For example, you might
        // provide an instance that binds its variables to SwiftUI properties, causing
        // the two to remain synchronized."
        do {
            return try Renderer(controller, gestureHandlers ?? GestureHandlers())
        }
        catch {
            fatalError("Problem creating render coordinator: \(error)")
        }
    }

    public func makeMTKView(_ coordinator: Renderer) -> MTKView {
        // "Creates the view object and configures its initial state."

        // print("RendererView.makeMTKView")

        let mtkView = MTKView()

        // Pause to stop it from drawing while we're setting things up
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true

        mtkView.delegate = coordinator
        mtkView.device = coordinator.device
        mtkView.drawableSize = mtkView.frame.size
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb

        mtkView.framebufferOnly = false // necessary for screenshots

        coordinator.connectGestures(mtkView)

        // Update and unpause
        doUpdate(mtkView, coordinator)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        return mtkView
    }

    public func updateMTKView(_ mtkView: MTKView, _ coordinator: Renderer) {

        // Docco for this method sez, "Updates the state of the specified view with
        // new information from SwiftUI." This struct gets recreated many many times,
        // and I think the system calls makeMTKView the first time this is created
        // but it calls this method all the subsequent times.

        // EMPIRICAL: I'm seeing this method called once per handful of calls to draw()

        // print("RendererView.updateMTKView")
        doUpdate(mtkView, coordinator)
    }

    private func doUpdate(_ mtkView: MTKView, _ coordinator: Renderer) {

        let clearColor: SIMD4<Double>
        if let delegate = coordinator.delegate {
            clearColor = delegate.backgroundColor
        }
        else {
            clearColor = .zero
        }
        // RenderController's backgroundColor MIGHT have changed
        mtkView.clearColor = MTLClearColorMake(clearColor.x,
                                               clearColor.y,
                                               clearColor.z,
                                               clearColor.w)

        // mtkView's bounds are measured in points while its drawableSize is measured in pixels.
        // They need not match, e.g., on my ipad, bounds: (0.0, 0.0, 1180.0, 820.0), drawableSize: (2360.0, 1640.0)
        // print("RendererView.doUpdate. view bounds: \(mtkView.bounds), drawableSize: \(mtkView.drawableSize)")
    }

    static public func dismantleMTKView(_ mtkView: MTKView, _ coordinator: Renderer) {
        coordinator.disconnectGestures(mtkView)
    }
}

#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension RendererView: UIViewRepresentable {

    public typealias UIViewType = MTKView
    public typealias Coordinator = Renderer

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = makeMTKView(context.coordinator)
        mtkView.isMultipleTouchEnabled = true
        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleUIView(_ mtkView: MTKView, coordinator: Renderer) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension RendererView: NSViewRepresentable {

    public typealias NSViewType = MTKView
    public typealias Coordinator = Renderer

    public func makeNSView(context: Context) -> MTKView {
        return makeMTKView(context.coordinator)
    }

    public func updateNSView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleNSView(_ mtkView: MTKView, coordinator: Renderer) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#endif // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


