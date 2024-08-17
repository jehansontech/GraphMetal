////
////  XRendererView.swift
////
////
////  Created by Jim Hanson on 8/16/24.
////
//
//import SwiftUI
//import MetalKit
//import Wacoma
//
//public struct XRendererView {
//
//    @ObservedObject var controller: XRenderController
//
//    var gestureHandlers: GestureHandlers?
//
//    public init(_ controller: XRenderController,
//                _ gestureHandlers: GestureHandlers? = nil) {
//        self.controller = controller
//        self.gestureHandlers = gestureHandlers
//    }
//
//    public func makeCoordinator() -> XRenderer {
//        // Docco sez, "Implement this method if changes to your view might affect other
//        // parts of your app. In your implementation, create a custom Swift instance that
//        // can communicate with other parts of your interface. For example, you might
//        // provide an instance that binds its variables to SwiftUI properties, causing
//        // the two to remain synchronized."
//        do {
//            return try XRenderer(controller, gestureHandlers ?? GestureHandlers())
//        }
//        catch {
//            fatalError("Problem creating render coordinator: \(error)")
//        }
//    }
//
//    public func makeMTKView(_ coordinator: XRenderer) -> MTKView {
//        // "Creates the view object and configures its initial state."
//
//        // print("XRendererView.makeMTKView")
//
//        let mtkView = MTKView()
//
//        // Pause to stop it from drawing while we're setting things up
//        mtkView.enableSetNeedsDisplay = true
//        mtkView.isPaused = true
//
//        mtkView.delegate = coordinator
//        mtkView.device = coordinator.device
//        mtkView.drawableSize = mtkView.frame.size
//        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
//        mtkView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
//
//        mtkView.framebufferOnly = false // necessary for screenshots
//
//        coordinator.connectGestures(mtkView)
//
//        // Update and unpause
//        doUpdate(mtkView, coordinator)
//        mtkView.enableSetNeedsDisplay = false
//        mtkView.isPaused = false
//
//        return mtkView
//    }
//
//    public func updateMTKView(_ mtkView: MTKView, _ coordinator: XRenderer) {
//
//        // Docco for this method sez, "Updates the state of the specified view with
//        // new information from SwiftUI." This struct gets recreated many many times,
//        // and I think the system calls makeMTKView the first time this is created
//        // but it calls this method all the subsequent times.
//
//        // EMPIRICAL: I'm seeing this method called once per handful of calls to draw()
//
//        // print("XRendererView.updateMTKView")
//        doUpdate(mtkView, coordinator)
//    }
//
//    private func doUpdate(_ mtkView: MTKView, _ coordinator: XRenderer) {
//
//        // XRenderController's backgroundColor MIGHT have changed
//        mtkView.clearColor = MTLClearColorMake(coordinator.controller.backgroundColor.x,
//                                               coordinator.controller.backgroundColor.y,
//                                               coordinator.controller.backgroundColor.z,
//                                               coordinator.controller.backgroundColor.w)
//
//        // mtkView's bounds are measured in points while its drawableSize is measured in pixels.
//        // They need not match, e.g., on my ipad, bounds: (0.0, 0.0, 1180.0, 820.0), drawableSize: (2360.0, 1640.0)
//        // print("RendererView.doUpdate. view bounds: \(mtkView.bounds), drawableSize: \(mtkView.drawableSize)")
//    }
//
//    static public func dismantleMTKView(_ mtkView: MTKView, _ coordinator: XRenderer) {
//        coordinator.disconnectGestures(mtkView)
//    }
//}
//
//#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//
//extension XRendererView: UIViewRepresentable {
//
//    public typealias UIViewType = MTKView
//    public typealias Coordinator = XRenderer
//
//    public func makeUIView(context: Context) -> MTKView {
//        let mtkView = makeMTKView(context.coordinator)
//        mtkView.isMultipleTouchEnabled = true
//        return mtkView
//    }
//
//    public func updateUIView(_ mtkView: MTKView, context: Context) {
//        return updateMTKView(mtkView, context.coordinator)
//    }
//
//    static public func dismantleUIView(_ mtkView: MTKView, coordinator: XRenderer) {
//        dismantleMTKView(mtkView, coordinator)
//    }
//}
//
//#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//
//extension XRendererView: NSViewRepresentable {
//
//    public typealias NSViewType = MTKView
//    public typealias Coordinator = XRenderer
//
//    public func makeNSView(context: Context) -> MTKView {
//        return makeMTKView(context.coordinator)
//    }
//
//    public func updateNSView(_ mtkView: MTKView, context: Context) {
//        return updateMTKView(mtkView, context.coordinator)
//    }
//
//    static public func dismantleNSView(_ mtkView: MTKView, coordinator: XRenderer) {
//        dismantleMTKView(mtkView, coordinator)
//    }
//}
//
//#endif // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
