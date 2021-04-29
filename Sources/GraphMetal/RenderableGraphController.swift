//
//  RenderableGraphController.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import SwiftUI
import GenericGraph

public protocol RenderableGraphHolder {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                          GraphType.EdgeType.ValueType: RenderableEdgeValue

    var topologyUpdate: Int { get set }

    var positionsUpdate: Int { get set }

    var colorsUpdate: Int { get set }

    var graph: GraphType { get }
}

extension RenderableGraphHolder {

    public mutating func registerTopologyChange() {
        topologyUpdate += 1
    }

    public func hasTopologyChanged(since update: Int) -> Bool {
        return update < topologyUpdate
    }

    public mutating func registerPositionChange() {
        positionsUpdate += 1
    }

    public func havePositionsChanged(since update: Int) -> Bool {
        return update < positionsUpdate
    }

    public mutating func registerColorChange() {
        colorsUpdate += 1
    }

    public func haveColorsChanged(since update: Int) -> Bool {
        return update < colorsUpdate
    }
}

public protocol RenderableGraphController {
    associatedtype HolderType: RenderableGraphHolder

    var graphHolder: HolderType { get }

    var dispatchQueue: DispatchQueue { get }

}

extension RenderableGraphController {

    public func exec(_ task: @escaping (HolderType) -> ()) {
        dispatchQueue.async { [self] in
            task(graphHolder)
        }
    }

    public func exec<T>(_ task: @escaping (HolderType) -> T, _ callback: @escaping (T) -> ()) {
        dispatchQueue.async { [self] in
            let result = task(graphHolder)
            DispatchQueue.main.sync {
                callback(result)
            }
        }
    }
}

public struct BasicGraphHolder<G: Graph>: RenderableGraphHolder where
    G.NodeType.ValueType: RenderableNodeValue,
    G.EdgeType.ValueType: RenderableEdgeValue {

    public typealias GraphType = G

    public var topologyUpdate: Int = 0

    public var positionsUpdate: Int = 0

    public var colorsUpdate: Int = 0

    public var graph: G

    init(_ graph: G) {
        self.graph = graph
    }
}

public struct BasicGraphController<G: Graph>: RenderableGraphController where
    G.NodeType.ValueType: RenderableNodeValue,
    G.EdgeType.ValueType: RenderableEdgeValue {

    public typealias HolderType = BasicGraphHolder<G>

    public var graphHolder: BasicGraphHolder<G>

    public var dispatchQueue: DispatchQueue

    init(_ graph: G, _ dispatchQueue: DispatchQueue) {
        self.graphHolder = BasicGraphHolder(graph)
        self.dispatchQueue = dispatchQueue
    }
}

