////
////  Wireframe2.swift
////  GraphMetal
////
////  Created by Jim Hanson on 8/1/24.
////
//
//import simd
//import MetalKit
//import Wacoma
//
//public struct Wireframe2Update: Sendable {
//
//    public private(set) var bbox: BoundingBox? = nil
//
//    // Q: do we need this?
//    public private(set) var nodeCount: Int? = nil
//
//    public private(set) var nodePositionsArray: [SIMD3<Float>]? = nil
//
//    // MAYBE: nodePositionsByArrayIndex: [Int: SIMD3<Float>]? = nil
//
//    public func merge(_ otherUpdate: Wireframe2Update) {
//        // TODO: impl
//    }
//}
//
//public struct Wireframe2 /*: Renderable*/ {
//
//    private var bbox: BoundingBox? = nil
//
//    private var nodeCount: Int = 0
//
//    private var nodePositionBuffer: MTLBuffer? = nil
//
//    private var pendingUpdate: Wireframe2Update? = nil
//
//    public init() {
//
//    }
//
//    public mutating func addUpdate(_ update: Wireframe2Update) {
//
//    }
//
//    /// Called before the first rendering cycle.
//    public mutating func setup(_ mtkView: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws {
//
//    }
//
//    /// Called at the beginning of every rendering cycle.
//    public mutating func prepareToDraw() {
//
//    }
//
//    /// Called on every rendering cycle. Should execute as quickly as possible.
//    public mutating func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
//
//    }
//
//    /// Called when the GPU finishes its work at end of every rendering cycle.
//    public mutating func renderingIsComplete() {
//
//    }
//
//    /// Called when the renderer is destroyed
//    public mutating func teardown() {
//
//    }
//
//}
