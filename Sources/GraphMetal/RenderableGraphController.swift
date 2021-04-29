//
//  RenderableGraphController.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import SwiftUI
import GenericGraph

//public protocol RenderableGraphAccessor {
//
//    associatedtype NodeValueType: RenderableNodeValue
//    associatedtype EdgeValueType: RenderableEdgeValue
//
//    // runs asynchronously on background thread
//    func accessGraph<G: Graph>(_ holder: RenderableGraphHolder<G>) where
//        G.NodeType.ValueType == NodeValueType,
//        G.EdgeType.ValueType == EdgeValueType
//
//    // runs on main thread after accessGraph completes
//    func afterAccess()
//}
//
//
//public class RenderableGraphController<G: Graph>: ObservableObject where
//    G.NodeType.ValueType: RenderableNodeValue,
//    G.EdgeType.ValueType: RenderableEdgeValue {
//
//    var graphHolder: RenderableGraphHolder<G>
//
//    var accessQueue: DispatchQueue
//
//    public init(_ graph: G, _ accessQueue: DispatchQueue) {
//        self.graphHolder = RenderableGraphHolder<G>(graph)
//        self.accessQueue = accessQueue
//    }
//
//    public func submitTask<A: RenderableGraphAccessor>(_ accessor: A) where
//        A.NodeValueType == G.NodeType.ValueType,
//        A.EdgeValueType == G.EdgeType.ValueType {
//        accessQueue.async { [self] in
//            accessor.accessGraph(graphHolder)
//            DispatchQueue.main.sync {
//                accessor.afterAccess()
//            }
//        }
//    }
//
//    public func scheduleTask<A: RenderableGraphAccessor>(_ accessor: A, _ delay: Double)  where
//        A.NodeValueType == G.NodeType.ValueType,
//        A.EdgeValueType == G.EdgeType.ValueType {
//        accessQueue.asyncAfter(deadline: .now() + delay) {  [self] in
//            accessor.accessGraph(graphHolder)
//            DispatchQueue.main.sync {
//                accessor.afterAccess()
//            }
//        }
//    }
//}
//
//
//public struct RenderableGraphHolder<G: Graph> where
//    G.NodeType.ValueType: RenderableNodeValue,
//    G.EdgeType.ValueType: RenderableEdgeValue {
//
//    /// may be replaced
//    public var graph: G {
//        didSet {
//            _topologyUpdate += 1
//            _positionsUpdate += 1
//            _colorsUpdate += 1
//        }
//    }
//
//    public var topologyUpdate: Int {
//        return _topologyUpdate
//    }
//
//    public var positionsUpdate: Int {
//        return _positionsUpdate
//    }
//
//    public var colorsUpdate: Int {
//        return _colorsUpdate
//    }
//
//    private var _topologyUpdate: Int = 0
//
//    private var _positionsUpdate: Int = 0
//
//    private var _colorsUpdate: Int = 0
//
//    public init(_ graph: G) {
//        self.graph = graph
//    }
//
//    /// User MUST call this after every change to graph's topology
//    mutating public func topologyHasChanged() {
//        _topologyUpdate += 1
//    }
//
//    public func hasTopologyChanged(since update: Int) -> Bool {
//        return update < _topologyUpdate
//    }
//
//    /// User MUST call this after every change to graph's node positions
//    mutating func positionsHaveChanged() {
//        _positionsUpdate += 1
//    }
//
//    public func havePositionsChanged(since update: Int) -> Bool {
//        return update < _positionsUpdate
//    }
//
//    /// User MUST call this after every change to graph's node colors
//    mutating func colorsHaveChanged() {
//        _colorsUpdate += 1
//    }
//
//    public func haveColorsChanged(since update: Int) -> Bool {
//        return update < _colorsUpdate
//    }
//}


// ==================================================================================
// MARK:- NEW VERSION
// ==================================================================================

public protocol RenderableGraphController: ObservableObject {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                  GraphType.EdgeType.ValueType: RenderableEdgeValue

    var topologyUpdate: Int { get set }

    var positionsUpdate: Int { get set }

    var colorsUpdate: Int { get set }

    var dispatchQueue: DispatchQueue { get }

    var graph: GraphType { get }

}

extension RenderableGraphController {

    public func exec(_ task: @escaping (Self) -> ()) {
        dispatchQueue.async {
            task(self)
        }
    }

    public func exec<T>(_ task: @escaping (Self) -> T, _ callback: @escaping (T) -> ()) {
        dispatchQueue.async {
            let result = task(self)
            DispatchQueue.main.sync {
                callback(result)
            }
        }
    }

    public func registerTopologyChange() {
        topologyUpdate += 1
    }

    public func hasTopologyChanged(since update: Int) -> Bool {
        return update < topologyUpdate
    }

    public func registerPositionChange() {
        positionsUpdate += 1
    }

    public func havePositionsChanged(since update: Int) -> Bool {
        return update < positionsUpdate
    }

    public func registerColorChange() {
        colorsUpdate += 1
    }

    public func haveColorsChanged(since update: Int) -> Bool {
        return update < colorsUpdate
    }
}

class TestController<G>: RenderableGraphController where
    G: Graph,
    G.NodeType.ValueType: RenderableNodeValue,
    G.EdgeType.ValueType: RenderableEdgeValue {

    typealias GraphType = G

    var topologyUpdate: Int = 0

    var positionsUpdate: Int = 0

    var colorsUpdate: Int = 0

    var dispatchQueue: DispatchQueue

    var graph: G

    init(_ graph: G, _ queue: DispatchQueue) {
        self.graph = graph
        self.dispatchQueue = queue
    }

}
