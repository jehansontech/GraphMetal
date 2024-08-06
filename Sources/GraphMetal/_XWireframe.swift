////
////  XWireframe.swift
////  GraphMetal
////
////  Created by Jim Hanson on 7/30/24.
////
//
//import SwiftUI
//import MetalKit
//import Wacoma
//import GenericGraph
//
//public struct XWireframeUpdate: Codable, Sendable {
//
//    public var bbox: BoundingBox?
//
//    public var nodeCount: Int?
//
//    public var nodePositions: [SIMD3<Float>]?
//
//    public var edgeIndexCount: Int?
//
//    public var edgeIndices: [UInt32]?
//
//    private init(bbox: BoundingBox?,
//                 nodeCount: Int?,
//                 nodePositions: [SIMD3<Float>]?,
//                 edgeIndexCount: Int?,
//                 edgeIndices: [UInt32]?) {
//        self.bbox = bbox
//        self.nodeCount = nodeCount
//        self.nodePositions = nodePositions
//        self.edgeIndexCount = edgeIndexCount
//        self.edgeIndices = edgeIndices
//    }
//
//    public static func none() -> XWireframeUpdate {
//        return XWireframeUpdate(bbox: nil,
//                                nodeCount: nil,
//                                nodePositions: nil,
//                                edgeIndexCount: nil,
//                                edgeIndices: nil)
//    }
//
//    public static func nodes(bbox: BoundingBox,
//                             nodeCount: Int,
//                             nodePositions: [SIMD3<Float>]) -> XWireframeUpdate {
//        return XWireframeUpdate(bbox: bbox,
//                                nodeCount: nodeCount,
//                                nodePositions: nodePositions,
//                                edgeIndexCount: nil,
//                                edgeIndices: nil)
//    }
//
//    public static func edges(edgeIndexCount: Int,
//                             edgeIndices: [UInt32]) -> XWireframeUpdate {
//        return XWireframeUpdate(bbox: nil,
//                                nodeCount: nil,
//                                nodePositions: nil,
//                                edgeIndexCount: edgeIndexCount,
//                                edgeIndices: edgeIndices)
//    }
//
//    public static func all(bbox: BoundingBox,
//                           nodeCount: Int,
//                           nodePositions: [SIMD3<Float>],
//                           edgeIndexCount: Int,
//                           edgeIndices: [UInt32]) -> XWireframeUpdate {
//        return XWireframeUpdate(bbox: bbox,
//                                nodeCount: nodeCount,
//                                nodePositions: nodePositions,
//                                edgeIndexCount: edgeIndexCount,
//                                edgeIndices: edgeIndices)
//    }
//
//    public mutating func merge(_ updateToMerge: XWireframeUpdate) {
//        if updateToMerge.bbox != nil {
//            self.bbox = updateToMerge.bbox
//        }
//        if updateToMerge.nodeCount != nil && updateToMerge.nodePositions != nil {
//            self.nodeCount = updateToMerge.nodeCount
//            self.nodePositions = updateToMerge.nodePositions
//        }
//        if updateToMerge.edgeIndexCount != nil && updateToMerge.edgeIndices != nil {
//            self.edgeIndexCount = updateToMerge.edgeIndexCount
//            self.edgeIndices = updateToMerge.edgeIndices
//        }
//    }
//}
//
//public class XWireframe {
//
//    weak var device: MTLDevice!
//
//    weak var library: MTLLibrary!
//
//    var bbox: BoundingBox? = nil
//
//    var nodeCount: Int = 0
//
//    private var nodePositionBuffer: MTLBuffer? = nil
//
//    private var edgeIndexCount: Int = 0
//
//    private var edgeIndexBuffer: MTLBuffer? = nil
//
//    private var pendingUpdate: XWireframeUpdate? = nil
//
//    public init() {}
//
//    public func addUpdate(_ newUpdate: XWireframeUpdate) {
//        if self.pendingUpdate == nil {
//            self.pendingUpdate = newUpdate
//        }
//        else {
//            self.pendingUpdate!.merge(newUpdate)
//        }
//    }
//
//    public func semaphoreWait() {
//    }
//
//    public func semaphoreSignal() {
//    }
//
//    /// Called before the first rendering cycle.
//    public func setup(_ mtkView: MTKView, _ device: MTLDevice, _ library: MTLLibrary) throws {
//        self.device = device
//        self.library = library
//    }
//
//    /// Called at the beginning of every rendering cycle.
//    public func prepareToDraw() {
//        guard let updateToApply = self.pendingUpdate
//        else {
//            return
//        }
//        self.pendingUpdate = nil
//
//        // DEBUGGING
//        let t0 = Date()
//
//        if let bbox = updateToApply.bbox {
//            self.bbox = bbox
//        }
//
//        let oldNodeCount = nodeCount
//        let newNodeCount = updateToApply.nodeCount ?? oldNodeCount
//        self.nodeCount = newNodeCount
//
//        // =================
//        // Node positions
//
//        if newNodeCount == 0 {
//            self.nodePositionBuffer = nil
//        }
//        else if let newNodePositions = updateToApply.nodePositions {
//            //            // SAFETY
//            //            if newNodePositions.count != newNodeCount {
//            //                fatalError("Failed sanity check: newNodeCount=\(newNodeCount) but newNodePositions.count=\(newNodePositions.count)")
//            //            }
//
//            // We're going to create a new buffer rather than modifying the extant one
//            // so that we don't have to worry about sequencing the CPU vs GPU access to it.
//            let nodePositionOptions = MTLResourceOptions.storageModePrivate
//            self.nodePositionBuffer = device.makeBuffer(bytes: newNodePositions,
//                                                        length: newNodePositions.count * MemoryLayout<SIMD3<Float>>.size,
//                                                        options: nodePositionOptions)
//        }
//        //        // SAFETY
//        //        else if newNodeCount != oldNodeCount {
//        //            fatalError("Failed sanity check: nodeCount changed but newNodePositions is nil")
//        //        }
//
//        // ==================
//        // Edge indices
//
//        let oldEdgeIndexCount = edgeIndexCount
//        let newEdgeIndexCount = updateToApply.edgeIndexCount ?? oldEdgeIndexCount
//        self.edgeIndexCount = newEdgeIndexCount
//
//        if newEdgeIndexCount == 0 {
//            self.edgeIndexBuffer = nil
//        }
//        else if let newEdgeIndices = updateToApply.edgeIndices {
//            //            if newEdgeIndices.count != edgeIndexCount {
//            //                fatalError("Failed sanity check: newEdgeIndexCount=\(newEdgeIndexCount) but newEdgeIndices.count=\(newEdgeIndices.count)")
//            //            }
//
//            if self.edgeIndexBuffer == nil || newEdgeIndexCount != oldEdgeIndexCount {
//                self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
//                                                    length: newEdgeIndices.count * MemoryLayout<UInt32>.size)
//            }
//            else {
//                // 2022-11-21 I was getting segv when I did this w/ the node colors buffer, so I'm
//                // commenting it out here as well.
//                //                edgeIndexBuffer!.contents().copyMemory(from: newEdgeIndices,
//                //                                                       byteCount: newEdgeIndices.count * MemoryLayout<UInt32>.size)
//                self.edgeIndexBuffer = device.makeBuffer(bytes: newEdgeIndices,
//                                                    length: newEdgeIndices.count * MemoryLayout<UInt32>.size)
//            }
//        }
//        //        else if newEdgeIndexCount != oldEdgeIndexCount {
//        //            fatalError("Failed sanity check: edgeIndexCount changed but newEdgeIndices is nil")
//        //        }
//
//        // DEBUGGING
//        let dt = Date().timeIntervalSince(t0)
//        if dt > 0.1 {
//            print("Slow applyBufferUpdate dt: \(dt)")
//        }
//
//    }
//
//    /// Called on every rendering cycle. Should execute as quickly as possible.
//    public func encodeDrawCommands(_ encoder: MTLRenderCommandEncoder) {
//
//    }
//
//    /// Called when the renderer is destroyed
//    public func teardown() {
//        // TODO: find out whether I need to explicitly deinit the buffers
//        self.nodeCount = 0
//        self.nodePositionBuffer = nil
//        self.edgeIndexCount = 0
//        self.edgeIndexBuffer = nil
//    }
//
//}
