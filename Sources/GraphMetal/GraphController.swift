//
//  File.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import GenericGraph

public struct GraphHolder<N: RenderableNodeValue, E: RenderableEdgeValue> {

    var topologyUpdate: Int = 0

    var positionsUpdate: Int = 0

    var colorsUpdate: Int = 0

    var graph: BaseGraph<N, E>

    public init(_ graph: BaseGraph<N, E>) {
        self.graph = graph
    }

    func hasTopologyChanged(since update: Int) -> Bool {
        return update < topologyUpdate
    }

    func havePositionsChanged(since update: Int) -> Bool {
        return update < positionsUpdate
    }

    func haveColorsChanged(since update: Int) -> Bool {
        return update < colorsUpdate
    }
}

public protocol GraphAccessTask: AnyObject {

    // runs on background thread
    func accessGraph<N, E>(_ holder: GraphHolder<N, E>)

    // runs on main thread after accessModel completes
    func afterAccess()
}

public class GraphController<N: RenderableNodeValue, E: RenderableEdgeValue>: ObservableObject {

    var graphHolder: GraphHolder<N, E>

    var accessQueue: DispatchQueue

    public init(_ graph: BaseGraph<N, E>, _ accessQueue: DispatchQueue) {
        self.graphHolder = GraphHolder<N, E>(graph)
        self.accessQueue = accessQueue
    }

    public func submitTask(_ task: GraphAccessTask) {
        accessQueue.async { [self] in
            task.accessGraph(graphHolder)
            DispatchQueue.main.sync {
                task.afterAccess()
            }
        }
    }

    public func scheduleTask(_ task: GraphAccessTask, _ delay: Double) {
        accessQueue.asyncAfter(deadline: .now() + delay) {  [self] in
            task.accessGraph(graphHolder)
            DispatchQueue.main.sync {
                task.afterAccess()
            }
        }
    }
}
