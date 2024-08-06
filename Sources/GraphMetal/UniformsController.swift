//
//  UniformsController.swift
//  GraphMetal
//
//  Created by Jim Hanson on 7/31/24.
//

import simd
import MetalKit

struct UniformsController {

    private let maxBuffersInFlight = 3

    private let inFlightSemaphore: DispatchSemaphore

    private var uniformsBuffer: MTLBuffer!

    private var uniformsBufferOffset = 0

    private var uniformsBufferRotation = 0

    private var uniforms: UnsafeMutablePointer<Uniforms>!

    public init() {
        self.inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    }
    
    /// Called before the first rendering cycle.
    // mutating func setup(_ mtkView: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws

    mutating func setup(_ device: MTLDevice) throws {
        // print("UniformsController.setup entered")

        let bufferLabel = "Uniforms"
        let bufferSize = Uniforms.alignedSize * maxBuffersInFlight
        let bufferOptions = MTLResourceOptions.storageModeShared
        if let buffer = device.makeBuffer(length: bufferSize, options: bufferOptions) {
            self.uniformsBuffer = buffer
            self.uniformsBuffer.label = bufferLabel
            self.uniformsBufferRotation = 0
            self.uniformsBufferOffset = 0
            self.uniforms = UnsafeMutableRawPointer(uniformsBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        }
        else {
            throw RenderError.bufferCreationFailed(bufferLabel: bufferLabel)
        }

        // print("UniformsController.setup exiting")
    }

    // In order to make this a Renderable I'll have to put newUniforms into a var and have
    // prepareToDraw() use it. RenderController will need to pass the new uniforms to that var
    // before it calls prepareToDraw()
    // mutating func prepareToDraw()

    //    private var updateCount: Int = 0

    mutating func update(_ newUniforms: Uniforms) {
//        updateCount += 1
//        if updateCount % 60 == 1 {
//            print("UniformsController.update #\(updateCount) entered")
//        }

        // Wait for GPU to tell us it's done with the part of the buffer we're about to write to

        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // ======================================
        // Rotate

        uniformsBufferRotation = (uniformsBufferRotation + 1) % maxBuffersInFlight
        uniformsBufferOffset = Uniforms.alignedSize * uniformsBufferRotation
        uniforms = UnsafeMutableRawPointer(uniformsBuffer.contents() + uniformsBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
        
        // =====================================
        // Replace content

        uniforms[0].projectionMatrix = newUniforms.projectionMatrix
        uniforms[0].modelViewMatrix = newUniforms.modelViewMatrix
        uniforms[0].pointSize = newUniforms.pointSize
        uniforms[0].edgeColor = newUniforms.edgeColor
        uniforms[0].fadeoutMidpoint = newUniforms.fadeoutMidpoint
        uniforms[0].fadeoutDistance = newUniforms.fadeoutDistance
        uniforms[0].pulsePhase = newUniforms.pulsePhase

//        if updateCount % 60 == 1 {
//            print("UniformsController.update #\(updateCount) exiting")
//        }

    }

    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(uniformsBuffer,
                                offset:uniformsBufferOffset,
                                index: RenderConstants.uniformsBufferIndex)
        encoder.setFragmentBuffer(uniformsBuffer,
                                  offset:uniformsBufferOffset,
                                  index:  RenderConstants.uniformsBufferIndex)
    }

    func renderingIsComplete() {
        inFlightSemaphore.signal()
    }
    
    func teardown() {
    }
}
