//
//  ModelAccess.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import GenericGraph

public protocol Model {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                          GraphType.EdgeType.ValueType: RenderableEdgeValue

    var topologyUpdate: Int { get }

    var positionsUpdate: Int { get }

    var colorsUpdate: Int { get }

    var graph: GraphType { get }
}

extension Model {

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

public protocol ModelAccessTask: AnyObject {

    // runs on background thread
    func accessModel<M: Model>(_ model: M)

    // runs on main thread after accessModel completes
    func afterModelAccess()
}


public protocol ModelAccessController {
    associatedtype ModelType: Model

    var modelAccessQueue: DispatchQueue { get }

    var model: ModelType { get }

}

extension ModelAccessController {

    func submitTask(_ task: ModelAccessTask) {
        modelAccessQueue.async {
            task.accessModel(model)
            DispatchQueue.main.sync {
                task.afterModelAccess()
            }
        }
    }

    func scheduleTask(_ task: ModelAccessTask, _ delay: Double) {
        modelAccessQueue.asyncAfter(deadline: .now() + delay) {
            task.accessModel(model)
            DispatchQueue.main.sync {
                task.afterModelAccess()
            }
        }
    }
}
