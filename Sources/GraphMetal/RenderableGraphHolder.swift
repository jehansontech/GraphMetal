//
//  RenderableGraphController.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
// import SwiftUI
import GenericGraph

extension Notification.Name {
    static var graphHasChanged: Notification.Name { return .init("graphHasChanged") }
}

public protocol RenderableGraphHolder: AnyObject {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                          GraphType.EdgeType.ValueType: RenderableEdgeValue

    var graph: GraphType { get set }
}

extension RenderableGraphHolder {

    public func fireGraphChange(_ change: RenderableGraphChange) {
        NotificationCenter.default.post(name: .graphHasChanged, object: change)
    }
}

public struct RenderableGraphChange {

    public static let ALL = RenderableGraphChange(nodes: true,
                                                  nodeColors: true,
                                                  nodePositions: true,
                                                  edges: true,
                                                  edgeColors: true)

    /// indicates whether nodes have been added and/or removed
    public var nodes: Bool

    /// indicates whether one or more nodes have changed color
    public var nodeColors: Bool

    /// indicates whether one or more nodes have changed position
    public var nodePositions: Bool

    /// indicates whether edges have been added and/or removed
    public var edges: Bool

    /// indicates whether one or more edges have changed color
    public var edgeColors: Bool

    public init(nodes: Bool = false,
                nodeColors: Bool = false,
                nodePositions: Bool = false,
                edges: Bool = false,
                edgeColors: Bool = false) {
        self.nodes = nodes
        self.nodeColors = nodeColors
        self.nodePositions = nodePositions
        self.edges = edges
        self.edgeColors = edgeColors
    }
}

//public protocol RenderableGraphHolder: RenderSource {
//    
//    var topologyUpdate: Int { get set }
//
//    var positionsUpdate: Int { get set }
//
//    var colorsUpdate: Int { get set }
//}
//
//extension RenderableGraphHolder {
//
//    public func registerTopologyChange() {
//        topologyUpdate += 1
//    }
//
//    public func hasTopologyChanged(since update: Int) -> Bool {
//        return update < topologyUpdate
//    }
//
//    public func registerPositionChange() {
//        positionsUpdate += 1
//    }
//
//    public func havePositionsChanged(since update: Int) -> Bool {
//        return update < positionsUpdate
//    }
//
//    public func registerColorChange() {
//        colorsUpdate += 1
//    }
//
//    public func haveColorsChanged(since update: Int) -> Bool {
//        return update < colorsUpdate
//    }
//}
//
//public protocol RenderableGraphController {
//    associatedtype HolderType: RenderableGraphHolder
//
//    var graphHolder: HolderType { get }
//
//    var dispatchQueue: DispatchQueue { get }
//
//}
//
//extension RenderableGraphController {
//
//    public func exec(_ task: @escaping (HolderType) -> ()) {
//        dispatchQueue.async { [self] in
//            task(graphHolder)
//        }
//    }
//
//    public func exec<T>(_ task: @escaping (HolderType) -> T, _ callback: @escaping (T) -> ()) {
//        dispatchQueue.async { [self] in
//            let result = task(graphHolder)
//            DispatchQueue.main.sync {
//                callback(result)
//            }
//        }
//    }
//
//    public func schedule(_ task: @escaping (HolderType) -> (), _ delay: Double) {
//        dispatchQueue.asyncAfter(deadline: .now() + delay) { [self] in
//            task(graphHolder)
//        }
//    }
//
//    public func schedule<T>(_ task: @escaping (HolderType) -> T, _ delay: Double, _ callback: @escaping (T) -> ()) {
//        dispatchQueue.asyncAfter(deadline: .now() + delay) { [self] in
//            let result = task(graphHolder)
//            DispatchQueue.main.sync {
//                callback(result)
//            }
//        }
//    }
//}
//
//public class BasicGraphHolder<G: Graph>: RenderableGraphHolder where
//    G.NodeType.ValueType: RenderableNodeValue,
//    G.EdgeType.ValueType: RenderableEdgeValue {
//
//    public typealias GraphType = G
//
//    public var topologyUpdate: Int = 0
//
//    public var positionsUpdate: Int = 0
//
//    public var colorsUpdate: Int = 0
//
//    public var graph: G
//
//    public init(_ graph: G) {
//        self.graph = graph
//    }
//}
//
//public struct BasicGraphController<G: Graph>: RenderableGraphController where
//    G.NodeType.ValueType: RenderableNodeValue,
//    G.EdgeType.ValueType: RenderableEdgeValue {
//
//    public typealias HolderType = BasicGraphHolder<G>
//
//    public var graphHolder: BasicGraphHolder<G>
//
//    public var dispatchQueue: DispatchQueue
//
//    public init(_ graph: G, _ dispatchQueue: DispatchQueue) {
//        self.graphHolder = BasicGraphHolder(graph)
//        self.dispatchQueue = dispatchQueue
//    }
//}

