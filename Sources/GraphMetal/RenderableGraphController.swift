//
//  RenderableGraphController.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import SwiftUI
import GenericGraph

public protocol RenderableGraphAccessor {

    associatedtype NodeValueType: RenderableNodeValue
    associatedtype EdgeValueType: RenderableEdgeValue

    // runs asynchronously on background thread
    func accessGraph<G: Graph>(_ holder: RenderableGraphHolder<G>) where
        G.NodeType.ValueType == NodeValueType,
        G.EdgeType.ValueType == EdgeValueType

    // runs on main thread after accessGraph completes
    func afterAccess()
}


public class RenderableGraphController<G: Graph>: ObservableObject where
    G.NodeType.ValueType: RenderableNodeValue,
    G.EdgeType.ValueType: RenderableEdgeValue {

    var graphHolder: RenderableGraphHolder<G>

    var accessQueue: DispatchQueue

    public init(_ graph: G, _ accessQueue: DispatchQueue) {
        self.graphHolder = RenderableGraphHolder<G>(graph)
        self.accessQueue = accessQueue
    }

    public func submitTask<A: RenderableGraphAccessor>(_ accessor: A) where
        A.NodeValueType == G.NodeType.ValueType,
        A.EdgeValueType == G.EdgeType.ValueType {
        accessQueue.async { [self] in
            accessor.accessGraph(graphHolder)
            DispatchQueue.main.sync {
                accessor.afterAccess()
            }
        }
    }

    public func scheduleTask<A: RenderableGraphAccessor>(_ accessor: A, _ delay: Double)  where
        A.NodeValueType == G.NodeType.ValueType,
        A.EdgeValueType == G.EdgeType.ValueType {
        accessQueue.asyncAfter(deadline: .now() + delay) {  [self] in
            accessor.accessGraph(graphHolder)
            DispatchQueue.main.sync {
                accessor.afterAccess()
            }
        }
    }
}


public struct RenderableGraphHolder<G: Graph> where
    G.NodeType.ValueType: RenderableNodeValue,
    G.EdgeType.ValueType: RenderableEdgeValue {

    /// may be replaced
    public var graph: G {
        didSet {
            _topologyUpdate += 1
            _positionsUpdate += 1
            _colorsUpdate += 1
        }
    }

    public var topologyUpdate: Int {
        return _topologyUpdate
    }

    public var positionsUpdate: Int {
        return _positionsUpdate
    }

    public var colorsUpdate: Int {
        return _colorsUpdate
    }

    private var _topologyUpdate: Int = 0

    private var _positionsUpdate: Int = 0

    private var _colorsUpdate: Int = 0

    public init(_ graph: G) {
        self.graph = graph
    }

    /// User MUST call this after every change to graph's topology
    mutating public func topologyHasChanged() {
        _topologyUpdate += 1
    }

    public func hasTopologyChanged(since update: Int) -> Bool {
        return update < _topologyUpdate
    }

    /// User MUST call this after every change to graph's node positions
    mutating func positionsHaveChanged() {
        _positionsUpdate += 1
    }

    public func havePositionsChanged(since update: Int) -> Bool {
        return update < _positionsUpdate
    }

    /// User MUST call this after every change to graph's node colors
    mutating func colorsHaveChanged() {
        _colorsUpdate += 1
    }

    public func haveColorsChanged(since update: Int) -> Bool {
        return update < _colorsUpdate
    }
}


