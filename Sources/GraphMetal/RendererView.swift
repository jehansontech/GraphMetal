//
//  RendererView.swift
//  GraphMetal
//
//  Created by Jim Hanson on 1/8/22.
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

    public func makeCoordinator() -> RenderCoordinator {
        // Docco sez, "Implement this method if changes to your view might affect other
        // parts of your app. In your implementation, create a custom Swift instance that
        // can communicate with other parts of your interface. For example, you might
        // provide an instance that binds its variables to SwiftUI properties, causing
        // the two to remain synchronized."

        do {
            return try RenderCoordinator(controller, gestureHandlers ?? GestureHandlers())
        }
        catch {
            fatalError("Problem creating render coordinator: \(error)")
        }
    }

    public func makeMTKView(_ coordinator: RenderCoordinator) -> MTKView {
        // print("RendererView.makeMTKView")

        // Docco sez, "Creates the view object and configures its initial state."

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

    public func updateMTKView(_ mtkView: MTKView, _ coordinator: RenderCoordinator) {
        print("RendererView.updateMTKView: entered")

        // Docco sez, "Updates the state of the specified view with
        // new information from SwiftUI." This struct gets recreated many many times,
        // and I think the system calls makeMTKView the first time this is created
        // but it calls this method all the subsequent times.
        // 
        // EMPIRICAL: I'm seeing this method called once per handful of calls to draw()

        doUpdate(mtkView, coordinator)
    }

    private func doUpdate(_ mtkView: MTKView, _ coordinator: RenderCoordinator) {
        print("RendererView.doUpdate: Entered. view bounds: \(mtkView.bounds), drawableSize: \(mtkView.drawableSize)")
        
        // NOTE mtkView's bounds are measured in points while its drawableSize is measured
        // in pixels. They need not match, e.g., on my ipad, bounds = (0.0, 0.0, 1180.0, 820.0)
        // and drawableSize =  (2360.0, 1640.0)

        // RenderController's settings MIGHT have changed. The only one we care about
        // here is backgroundColor.

        let clearColor: SIMD4<Float> = coordinator.delegate.backgroundColor
        mtkView.clearColor = MTLClearColorMake(Double(clearColor.x),
                                               Double(clearColor.y),
                                               Double(clearColor.z),
                                               Double(clearColor.w))

    }

    static public func dismantleMTKView(_ mtkView: MTKView, _ coordinator: RenderCoordinator) {
        coordinator.disconnectGestures(mtkView)
    }
}

#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension RendererView: UIViewRepresentable {

    public typealias UIViewType = MTKView
    public typealias Coordinator = RenderCoordinator

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = makeMTKView(context.coordinator)
        mtkView.isMultipleTouchEnabled = true
        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleUIView(_ mtkView: MTKView, coordinator: RenderCoordinator) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

extension RendererView: NSViewRepresentable {

    public typealias NSViewType = MTKView
    public typealias Coordinator = RenderCoordinator

    public func makeNSView(context: Context) -> MTKView {
        return makeMTKView(context.coordinator)
    }

    public func updateNSView(_ mtkView: MTKView, context: Context) {
        return updateMTKView(mtkView, context.coordinator)
    }

    static public func dismantleNSView(_ mtkView: MTKView, coordinator: RenderCoordinator) {
        dismantleMTKView(mtkView, coordinator)
    }
}

#endif // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


