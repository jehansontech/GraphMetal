//
//  RenderableGraphController.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
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


public class RenderableGraphController<G: Graph> where
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

    var topologyUpdate: Int = 0

    var positionsUpdate: Int = 0

    var colorsUpdate: Int = 0

    public var graph: G

    public init(_ graph: G) {
        self.graph = graph
    }

    mutating public func topologyHasChanged() {
        topologyUpdate += 1
    }

    public func hasTopologyChanged(since update: Int) -> Bool {
        return update < topologyUpdate
    }

    mutating func positionsHaveChanged() {
        positionsUpdate += 1
    }

    public func havePositionsChanged(since update: Int) -> Bool {
        return update < positionsUpdate
    }

    mutating func colorsHaveChanged() {
        colorsUpdate += 1
    }

    public func haveColorsChanged(since update: Int) -> Bool {
        return update < colorsUpdate
    }
}


