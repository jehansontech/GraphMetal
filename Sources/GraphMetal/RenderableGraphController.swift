//
//  RenderableGraphController.swift
//  
//
//  Created by Jim Hanson on 4/26/21.
//

import Foundation
import SwiftUI
import GenericGraph

public protocol GraphHolder {
    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
                                          GraphType.EdgeType.ValueType: RenderableEdgeValue

    var topologyUpdate: Int { get set }

    var positionsUpdate: Int { get set }

    var colorsUpdate: Int { get set }

    var graph: GraphType { get }
}

extension GraphHolder {

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
    associatedtype HolderType: GraphHolder

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

//public protocol RenderableGraphController: ObservableObject {
//    associatedtype GraphType: Graph where GraphType.NodeType.ValueType: RenderableNodeValue,
//                                  GraphType.EdgeType.ValueType: RenderableEdgeValue
//
//    var topologyUpdate: Int { get set }
//
//    var positionsUpdate: Int { get set }
//
//    var colorsUpdate: Int { get set }
//
//    var dispatchQueue: DispatchQueue { get }
//
//    var graph: GraphType { get }
//
//}
//
//extension RenderableGraphController {
//
//    public func exec(_ task: @escaping (Self) -> ()) {
//        dispatchQueue.async {
//            task(self)
//        }
//    }
//
//    public func exec<T>(_ task: @escaping (Self) -> T, _ callback: @escaping (T) -> ()) {
//        dispatchQueue.async {
//            let result = task(self)
//            DispatchQueue.main.sync {
//                callback(result)
//            }
//        }
//    }
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
