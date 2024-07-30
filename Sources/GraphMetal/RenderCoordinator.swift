//
//  Renderer.swift
//  GraphMetal
//
//  Created by Jim Hanson on 1/8/22.
//

import simd
import SwiftUI
import MetalKit
import Wacoma

public enum RenderError: Error {
    case noDevice
    case noDefaultLibrary
    case noDepthStencilState
    case badVertexDescriptor
    case bufferCreationFailed
    case snapshotInProgress
}

public protocol RenderDelegate: AnyObject {

    var backgroundColor: SIMD4<Float> { get }
    
    var snapshotRequested: Bool { get }

    func snapshotTaken(_ response: String)

    func updateViewBounds(_ viewBounds: CGRect)

    func prepareToDraw(_ view: MTKView)

    func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder)
}

public class RenderCoordinator: NSObject, MTKViewDelegate {

    let device: MTLDevice!

    private(set) weak var delegate: RenderDelegate!

    private var gestureCoordinator: GestureCoordinator

    private let inFlightSemaphore = DispatchSemaphore(value: RenderConstants.maxBuffersInFlight)

    private let commandQueue: MTLCommandQueue

    private let depthState: MTLDepthStencilState

    public init(_ delegate: RenderController, _ gestureHandlers: GestureHandlers) throws {
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
        }
        else {
            throw RenderError.noDevice
        }

        self.delegate = delegate
        self.gestureCoordinator = GestureCoordinator(gestureHandlers)
        self.commandQueue = device.makeCommandQueue()!

        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        if let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) {
            depthState = state
        }
        else {
            throw RenderError.noDepthStencilState
        }

        super.init()
    }

    public func connectGestures(_ mtkView: MTKView) {
        gestureCoordinator.connectGestures(mtkView)
    }

    public func disconnectGestures(_ mtkView: MTKView) {
        gestureCoordinator.disconnectGestures(mtkView)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange newSize: CGSize) {

        // print("Renderer.mtkView. view.bounds: \(view.bounds), newSize: \(newSize)")

        // Docco for this method sez: "Updates the view’s contents upon receiving a change
        // in layout, resolution, or size." And: "Use this method to recompute any view or
        // projection matrices, or to regenerate any buffers to be compatible with the view’s
        // new size." However, we're going to do all that in draw() because the matrices
        // depend on user-settable properties that may change anytime, not just when something
        // happens to trigger this method.
        //
        // The newSize arg is in pixels, whereas view.bounds is in "points". The latter is
        // what we care about.
        
        delegate.updateViewBounds(view.bounds)
    }

    public func draw(in view: MTKView) {

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // Swift compiler sez that the snapshot needs to be taken before the current drawable
        // is presented. This means it will capture the figure that was drawn the in PREVIOUS
        // call to this method.

        if delegate.snapshotRequested {
            delegate.snapshotTaken(saveSnapshot(view))
        }

        delegate.prepareToDraw(view)

        if let commandBuffer = commandQueue.makeCommandBuffer() {

            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in
                semaphore.signal()
            }

            // Delay getting the current Drawable and RenderPassDescriptor until we absolutely
            // them, in order to avoid holding onto the drawable and therby blocking the display
            // pipeline any longer than necessary
            if let drawable = view.currentDrawable,
               let renderPassDescriptor = view.currentRenderPassDescriptor {

                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].storeAction = .dontCare

                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    renderEncoder.setDepthStencilState(depthState)
                    delegate.encodeDrawCommands(renderEncoder)
                    renderEncoder.endEncoding()
                }

                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }
    }

    func saveSnapshot(_ view: MTKView) -> String {
        if let cgImage = view.takeSnapshot() {
            let response = cgImage.save()

            // Docco sez, "You are responsible for releasing this object by calling
            // CGImageRelease" but when I do so I get a compiler error w/ message
            // "'CGImageRelease' is unavailable: Core Foundation objects are automatically memory managed"
            // CGImageRelease(cgImage)

            return response
        }
        else {
            return "Image capture failed"
        }
    }
}
