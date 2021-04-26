//
//  File.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import GenericGraph

public class RenderingControllers<N: RenderableNodeValue, E: RenderableEdgeValue>: ObservableObject {

    let povController: POVController

    let graphController: GraphController<N, E>

    public init(_ graph: BaseGraph<N, E>, _ accessQueue: DispatchQueue) {
        self.povController = POVController()
        self.graphController = GraphController<N, E>(graph, accessQueue)
    }
}

