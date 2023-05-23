//
//  WireframeUpdate.swift
//  GraphMetal
//
//  Created by Jim Hanson on 10/24/22.
//

import Wacoma
import GenericGraph


public struct WireframeUpdateGenerator {

    // TODO: impl
    // private var generateNodeColors: Bool

    /// key = nodeNumber; value = buffer index
    private var nodeIndices: [Int: Int]? = nil

    public init() {
    }

//    public init(generateNodeColors: Bool = true) {
//        self.generateNodeColors = generateNodeColors
//    }

    public mutating func makeUpdate<GraphType: Graph>(_ graph: GraphType,
                                                      _ change: RenderableGraphChange) -> WireframeUpdate?
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        if change.nodes {
            return makeNodeSetUpdate(graph, change.edges)
        }
        else if change.nodePositions && change.nodeColors {
            return makeNodePropertiesUpdate(graph, change.edges)
        }
        else if change.nodePositions {
            return makeNodePositionUpdate(graph, change.edges)
        }
        else if change.nodeColors {
            return makeNodeColorUpdate(graph, change.edges)
        }
        else if change.edges {
            return makeEdgeSetUpdate(graph)
        }
        else {
            return nil
        }
    }

    private mutating func makeNodeSetUpdate<GraphType: Graph>(_ graph: GraphType,
                                                              _ makeEdgeIndices: Bool) -> WireframeUpdate
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        var newBBox: BoundingBox? = nil
        var newNodeIndices = [Int: Int]()
        var newNodePositions = [SIMD3<Float>]()
        var newNodeColors = [Int: SIMD4<Float>]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            newNodeIndices[node.nodeNumber] = nodeIndex
            if let nodePosition = node.value?.location {
                newNodePositions.insert(nodePosition, at: nodeIndex)
                if newBBox == nil {
                    newBBox = BoundingBox(nodePosition)
                }
                else {
                    newBBox!.cover(nodePosition)
                }
            }
            if let nodeColor = node.value?.color {
                newNodeColors[nodeIndex] = nodeColor
            }
            nodeIndex += 1
        }

        self.nodeIndices = newNodeIndices
        var update = WireframeUpdate(bbox: newBBox,
                                     nodeCount: newNodePositions.count,
                                     nodePositions: newNodePositions,
                                     nodeColors: newNodeColors)

        if  makeEdgeIndices {
            let newEdgeIndices = Self.makeEdgeIndices(graph, newNodeIndices)
            update.edgeIndexCount = newEdgeIndices.count
            update.edgeIndices = newEdgeIndices
        }
        return update
    }

    private mutating func makeNodePropertiesUpdate<GraphType: Graph>(_ graph: GraphType,
                                                                     _ makeEdgeIndices: Bool) -> WireframeUpdate
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        var newBBox: BoundingBox? = nil
        var newNodeIndices = [Int: Int]()
        var newNodePositions = [SIMD3<Float>]()
        var newNodeColors = [Int: SIMD4<Float>]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            newNodeIndices[node.nodeNumber] = nodeIndex
            if let nodePosition = node.value?.location {
                newNodePositions.insert(nodePosition, at: nodeIndex)
                if newBBox == nil {
                    newBBox = BoundingBox(nodePosition)
                }
                else {
                    newBBox!.cover(nodePosition)
                }
            }
            if let nodeColor = node.value?.color {
                newNodeColors[nodeIndex] = nodeColor
            }
            nodeIndex += 1
        }

        self.nodeIndices = newNodeIndices
        var update = WireframeUpdate(bbox: newBBox,
                                     nodePositions: newNodePositions,
                                     nodeColors: newNodeColors)

        if  makeEdgeIndices {
            let newEdgeIndices = Self.makeEdgeIndices(graph, newNodeIndices)
            update.edgeIndexCount = newEdgeIndices.count
            update.edgeIndices = newEdgeIndices
        }

        return update
    }

    private mutating func makeNodePositionUpdate<GraphType: Graph>(_ graph: GraphType,
                                                                   _ makeEdgeIndices: Bool) -> WireframeUpdate
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        var newBBox: BoundingBox? = nil
        var newNodeIndices = [Int: Int]()
        var newNodePositions = [SIMD3<Float>]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            newNodeIndices[node.nodeNumber] = nodeIndex
            if let nodePosition = node.value?.location {
                newNodePositions.insert(nodePosition, at: nodeIndex)
                if newBBox == nil {
                    newBBox = BoundingBox(nodePosition)
                }
                else {
                    newBBox!.cover(nodePosition)
                }
            }
            nodeIndex += 1
        }

        self.nodeIndices = newNodeIndices
        var update = WireframeUpdate(bbox: newBBox,
                                     nodePositions: newNodePositions)

        if  makeEdgeIndices {
            let newEdgeIndices = Self.makeEdgeIndices(graph, newNodeIndices)
            update.edgeIndexCount = newEdgeIndices.count
            update.edgeIndices = newEdgeIndices
        }

        return update
    }

    private mutating func makeNodeColorUpdate<GraphType: Graph>(_ graph: GraphType,
                                                                _ makeEdgeIndices: Bool) -> WireframeUpdate
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        var newNodeIndices = [Int: Int]()
        var newNodeColors = [Int: SIMD4<Float>]()

        var nodeIndex: Int = 0
        for node in graph.nodes {
            newNodeIndices[node.nodeNumber] = nodeIndex
            if let nodeColor = node.value?.color {
                newNodeColors[nodeIndex] = nodeColor
            }
            nodeIndex += 1
        }

        self.nodeIndices = newNodeIndices
        var update = WireframeUpdate(nodeColors: newNodeColors)

        if  makeEdgeIndices {
            let newEdgeIndices = Self.makeEdgeIndices(graph, newNodeIndices)
            update.edgeIndexCount = newEdgeIndices.count
            update.edgeIndices = newEdgeIndices
        }

        return update
    }

    private mutating func makeEdgeSetUpdate<GraphType: Graph>(_ graph: GraphType) -> WireframeUpdate
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        if self.nodeIndices == nil {
            self.nodeIndices = Self.makeNodeIndices(graph)
        }
        let newEdgeIndices = Self.makeEdgeIndices(graph, nodeIndices!)
        return WireframeUpdate(edgeIndexCount: newEdgeIndices.count,
                               edgeIndices: newEdgeIndices)
    }

    private static func makeNodeIndices<GraphType: Graph>(_ graph: GraphType) -> [Int: Int]
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        var newNodeIndices = [Int: Int]()
        var nodeIndex: Int = 0
        for node in graph.nodes {
            newNodeIndices[node.nodeNumber] = nodeIndex
            nodeIndex += 1
        }
        return newNodeIndices
    }

    private static func makeEdgeIndices<GraphType: Graph>(_ graph: GraphType, _ nodeIndices: [Int: Int]) -> [UInt32]
    where GraphType.NodeType.ValueType: RenderableNodeValue,
          GraphType.EdgeType.ValueType: RenderableEdgeValue
    {
        var edgeIndices = [UInt32]()
        var edgeIndex: Int = 0
        for node in graph.nodes {
            for edge in node.outEdges {
                if let edgeValue = edge.value,
                   !edgeValue.hidden,
                   let sourceIndex = nodeIndices[edge.source.nodeNumber],
                   let targetIndex = nodeIndices[edge.target.nodeNumber] {
                    edgeIndices.insert(UInt32(sourceIndex), at: edgeIndex)
                    edgeIndex += 1
                    edgeIndices.insert(UInt32(targetIndex), at: edgeIndex)
                    edgeIndex += 1
                }
            }
        }
        return edgeIndices
    }
}


//        if change.edges {
//            if update == nil {
//                update = WireframeUpdate()
//            }
//            if nodeIndices ==
//            let newEdgeIndices = makeEdgeIndices(graph)
//            update!.edgeIndices = newEdgeIndices
//            // Need to set edges, which will require nodeIndices.
//
//        }
//
//
//
//
//
//        if change.nodes {
//            bufferUpdate = self.prepareTopologyUpdate(graph)
//        }
//        else {
//            var newPositions: [SIMD3<Float>]? = nil
//            var newColors: [Int : SIMD4<Float>]? = nil
//            var newBBox: BoundingBox? = nil
//
//            if change.nodePositions {
//                newPositions = self.makeNodePositions(graph)
//                newBBox = graph.makeBoundingBox()
//            }
//
//            if change.nodeColors && generateNodeColors {
//                newColors = makeNodeColors(graph)
//            }
//
//            if (newPositions != nil || newColors != nil) {
//                bufferUpdate = WireframeUpdate(bbox: newBBox,
//                                               nodeCount: nil,
//                                               nodePositions: newPositions,
//                                               nodeColors: newColors,
//                                               edgeIndexCount: nil,
//                                               edgeIndices: nil)
//            }
//        }
//        return bufferUpdate
//    }
//
//
//
//    private mutating func prepareTopologyUpdate<GraphType: Graph>(_ graph: GraphType) -> WireframeUpdate
//    where GraphType.NodeType.ValueType: RenderableNodeValue,
//          GraphType.EdgeType.ValueType: RenderableEdgeValue
//    {
//
//        var newNodeIndices = [Int: Int]()
//        var newNodePositions = [SIMD3<Float>]()
//        var newEdgeIndexData = [UInt32]()
//
//        var nodeIndex: Int = 0
//        for node in graph.nodes {
//            newNodeIndices[node.id] = nodeIndex
//            if let nodeValue = node.value {
//                newNodePositions.insert(nodeValue.location, at: nodeIndex)
//                nodeIndex += 1
//            }
//        }
//
//        self.nodeIndices = newNodeIndices
//
//        var edgeIndex: Int = 0
//        for node in graph.nodes {
//            for edge in node.outEdges {
//                if let edgeValue = edge.value,
//                   !edgeValue.hidden,
//                   let sourceIndex = newNodeIndices[edge.source.id],
//                   let targetIndex = newNodeIndices[edge.target.id] {
//                    newEdgeIndexData.insert(UInt32(sourceIndex), at: edgeIndex)
//                    edgeIndex += 1
//                    newEdgeIndexData.insert(UInt32(targetIndex), at: edgeIndex)
//                    edgeIndex += 1
//                }
//            }
//        }
//
//        return WireframeUpdate(
//            bbox: graph.makeBoundingBox(),
//            nodeCount: newNodePositions.count,
//            nodePositions: newNodePositions,
//            nodeColors: generateNodeColors ? makeNodeColors(graph) : nil,
//            edgeIndexCount: newEdgeIndexData.count,
//            edgeIndices: newEdgeIndexData
//        )
//    }
//
//    private func makeNodePositions<GraphType: Graph>(_ graph: GraphType) -> [SIMD3<Float>]
//    where GraphType.NodeType.ValueType: RenderableNodeValue,
//          GraphType.EdgeType.ValueType: RenderableEdgeValue
//    {
//        var newNodePositions = [SIMD3<Float>](repeating: .zero, count: graph.nodes.count)
//        for node in graph.nodes {
//            if let nodeIndex = nodeIndices[node.id],
//               let nodeValue = node.value {
//                newNodePositions.insert(nodeValue.location, at: nodeIndex)
//            }
//        }
//        return newNodePositions
//    }
//
//    private func makeNodeColors<GraphType: Graph>(_ graph: GraphType) -> [Int: SIMD4<Float>]
//    where GraphType.NodeType.ValueType: RenderableNodeValue,
//          GraphType.EdgeType.ValueType: RenderableEdgeValue
//    {
//
//        var newNodeColors = [Int: SIMD4<Float>]()
//        for node in graph.nodes {
//            if let nodeIndex = nodeIndices[node.id],
//               let nodeColor = node.value?.color {
//                newNodeColors[nodeIndex] = nodeColor
//            }
//        }
//        return newNodeColors
//    }
