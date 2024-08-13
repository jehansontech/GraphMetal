////
////  ZWireframeUpdateGenerator.swift
////
////
////  Created by Jim Hanson on 8/10/24.
////
//
//import GenericGraph
//
//public struct ZWireframeUpdateGenerator<G: Graph> {
//
//    // TODO: Make this the update struct itself, not a factory for it.
//
//    // ?? var defaultNodePosition
//    // ?? var defaultNodeColor
//    // ?? var defaultEdgeColor
//
//    var graph: G
//
//    // key: nodeNumber, value: index into nodeColors and nodePositions arrays
//    var nodeIndices: [Int: Int]? = nil
//
//    var nodePositions: [SIMD3<Float>]? = nil
//    
//    var nodeColors: [SIMD4<Float>]? = nil
//
//    // key: nodeNumber, value: new position
//    var nodePositionReplacements: [Int: SIMD3<Float>]? = nil
//
//    // key: nodeNumber, value: new color
//    var nodeColorReplacements: [Int: SIMD4<Float>]? = nil
//
//    public init(_ graph: G) {
//        self.graph = graph
//    }
//
//    public mutating func setGraph(_ graph: G) {
//        self.graph = graph
//        self.nodeIndices = nil
//        self.nodePositions = nil
//        self.nodeColors = nil
//        self.nodePositionReplacements = nil
//        self.nodeColorReplacements = nil
//    }
//}
//
////extension ZWireframeUpdateGenerator {
////
////    public func makeUpdateForMonochrome(nodeSet: Bool,
////                                        edgeSet: Bool,
////                                        nodePositions: Bool) -> ZMonochromeWireframe.Update
////    where G.NodeType.ValueType: EmbeddedValue {
////
////        if nodeSet {
////            return makeNodeSetUpdateForMonochrome()
////        }
////
////        if nodePositions {
////
////        }
////
////        if edgeSet {
////
////        }
////
////        // TODO: impl
////        return ZMonochromeWireframe.Update()
////    }
////
////    private func makeNodeSetUpdateForMonochrome() -> ZMonochromeWireframe.Update {
////        // TODO: impl
////        return ZMonochromeWireframe.Update()
////    }
////}
////
////extension ZWireframeUpdateGenerator {
////
////    public func makeUpdateForColoredNodes(nodeSet: Bool,
////                                      edgeSet: Bool,
////                                      nodePositions: Bool,
////                                      nodeColors: Bool) -> ZWireframeWithColoredNodes.Update 
////    where G.NodeType.ValueType: EmbeddedValue & ColoredValue {
////
////        if nodeSet {
////            return makeNodeSetUpdateForColoredNodes()
////        }
////
////        if nodePositions && nodeColors {
////
////        }
////        else if nodePositions {
////
////        }
////        else if nodeColors {
////
////        }
////
////        if edgeSet {
////
////        }
////
////        // TODO: impl
////        return ZWireframeWithColoredNodes.Update()
////    }
////
////    private func makeNodeSetUpdateForColoredNodes() -> ZWireframeWithColoredNodes.Update {
////        // TODO: impl
////        return ZMonochromeWireframe.Update()
////    }
////
////}
