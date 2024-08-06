////
////  ZRenderCoordinator.swift
////  GraphMetal
////
////  Created by Jim Hanson on 1/8/22.
////
//
//import simd
//import SwiftUI
//import MetalKit
//import Wacoma
//
////public enum RenderError: Error {
////    case noDevice
////    case noDefaultLibrary
////    case noDepthStencilState
////    case badVertexDescriptor
////    case bufferCreationFailed(bufferLabel: String)
////    case snapshotInProgress
////}
////
////public protocol RenderDelegate: AnyObject {
////
////    var backgroundColor: SIMD4<Float> { get }
////
////    var snapshotRequested: Bool { get }
////
////    func snapshotTaken(_ response: String)
////
////    func setup(_ mtkView: MTKView) throws
////
////    func updateViewBounds(_ viewBounds: CGRect)
////
////    func prepareToDraw(_ view: MTKView)
////
////    func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder)
////
////    func renderingIsComplete()
////}
//
//public class ZRenderCoordinator: NSObject, MTKViewDelegate {
//
//    public var backgroundColor: SIMD4<Float> { renderer.settings.backgroundColor }
//    let device: MTLDevice!
//
//    private weak var renderer: ZRenderer!
//
//    private var gestureCoordinator: GestureCoordinator
//
//    private let commandQueue: MTLCommandQueue
//
//    private let depthState: MTLDepthStencilState
//
//    public init(_ renderer: ZRenderer, _ gestureHandlers: GestureHandlers) throws {
//        if let device = MTLCreateSystemDefaultDevice() {
//            self.device = device
//        }
//        else {
//            throw RenderError.noDevice
//        }
//
//        self.renderer = renderer
//        self.gestureCoordinator = GestureCoordinator(gestureHandlers)
//        self.commandQueue = device.makeCommandQueue()!
//
//        let depthStateDesciptor = MTLDepthStencilDescriptor()
//        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
//        depthStateDesciptor.isDepthWriteEnabled = true
//        if let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) {
//            depthState = state
//        }
//        else {
//            throw RenderError.noDepthStencilState
//        }
//
//        super.init()
//    }
//
//    public func setup(_ mtkView: MTKView) {
//        do {
//            try renderer.setup(mtkView)
//        }
//        catch {
//            fatalError("Problem in RenderDelegate setup: \(error)")
//        }
//    }
//
//    public func connectGestures(_ mtkView: MTKView) {
//        gestureCoordinator.connectGestures(mtkView)
//    }
//
//    public func disconnectGestures(_ mtkView: MTKView) {
//        gestureCoordinator.disconnectGestures(mtkView)
//    }
//
//    public func mtkView(_ view: MTKView, drawableSizeWillChange newSize: CGSize) {
//
//        // print("Renderer.mtkView. view.bounds: \(view.bounds), newSize: \(newSize)")
//
//        // Docco for this method sez: "Updates the view’s contents upon receiving a change
//        // in layout, resolution, or size." And: "Use this method to recompute any view or
//        // projection matrices, or to regenerate any buffers to be compatible with the view’s
//        // new size." However, we're going to do all that in draw() because the matrices
//        // depend on user-settable properties that may change anytime, not just when something
//        // happens to trigger this method.
//        //
//        // The newSize arg is in pixels, whereas view.bounds is in "points". The latter is
//        // what we care about.
//
//        renderer.updateViewBounds(view.bounds)
//    }
//
//    //    private var drawCount: Int = 0
//
//    public func draw(in view: MTKView) {
//        //        drawCount += 1
//
//        //        if drawCount % 60 == 1 {
//        //            print("RenderCoordinator.draw #\(drawCount) entered")
//        //        }
//
//        // Swift compiler sez that the snapshot needs to be taken before the current drawable
//        // is presented. This means it will capture the figure that was drawn the in PREVIOUS
//        // call to this method.
//
//        if renderer.snapshotRequested {
//            renderer.snapshotTaken(saveSnapshot(view))
//        }
//
//        renderer.prepareToDraw(view)
//
//        //        if drawCount % 60 == 1 {
//        //            print("RenderCoordinator.draw #\(drawCount) prepareToDraw done")
//        //        }
//
//        if let commandBuffer = commandQueue.makeCommandBuffer() {
//
//            // let renderer2 = renderer!
//            commandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in
//                // renderer2.renderingIsComplete()
//                self.renderer.renderingIsComplete()
//            }
//
//            // MAYBE: put this whole thing down into the renderer, a la:
//            // renderer.draw(commandBuffer, view)
//
//
//            // Delay getting the RenderPassDescriptor until we absolutely it in order
//            // to avoid blocking the display pipeline any longer than necessary.
//            if let renderPassDescriptor = view.currentRenderPassDescriptor {
//
//
//                renderPassDescriptor.colorAttachments[0].loadAction = .clear
//                renderPassDescriptor.colorAttachments[0].storeAction = .dontCare
//
//                // TODO: pass the BUFFER to the renderer
//                // and have the renderer manage depth stencil state.
//                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
//                    renderEncoder.setDepthStencilState(depthState)
//                    renderer.encodeDrawCommands(renderEncoder)
//                    renderEncoder.endEncoding()
//                }
//
//                if let drawable = view.currentDrawable {
//                    commandBuffer.present(drawable)
//                }
//            }
//            commandBuffer.commit()
//        }
//
//        //        if drawCount % 60 == 1 {
//        //            print("RenderCoordinator.draw #\(drawCount) exiting")
//        //        }
//    }
//
//    func saveSnapshot(_ view: MTKView) -> String {
//        if let cgImage = view.takeSnapshot() {
//            let response = cgImage.save()
//
//            // Docco sez, "You are responsible for releasing this object by calling
//            // CGImageRelease" but when I do so I get a compiler error w/ message
//            // "'CGImageRelease' is unavailable: Core Foundation objects are automatically memory managed"
//            // CGImageRelease(cgImage)
//
//            return response
//        }
//        else {
//            return "Image capture failed"
//        }
//    }
//}
