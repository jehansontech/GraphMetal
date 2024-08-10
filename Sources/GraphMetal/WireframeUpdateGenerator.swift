//
//  WireframeUpdate.swift
//  GraphMetal
//
//  Created by Jim Hanson on 10/24/22.
//

import Wacoma
import GenericGraph


public struct WireframeUpdateGenerator {

    /// key = nodeNumber; value = buffer index
    private var nodeIndices: [Int: Int]? = nil

    public init() {
    }

//    public init(generateNodeColors: Bool = true) {
//        self.generateNodeColors = generateNodeColors
//    }

    public mutating func makeUpdate<GraphType: Graph>(_ graph: GraphType,
                                                      _ change: RenderableGraphChange) -> WireframeUpdate?
    where GraphType.NodeType.ValueType: EmbeddedValue & ColoredValue,
          GraphType.EdgeType.ValueType: ColoredValue
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
    where GraphType.NodeType.ValueType: EmbeddedValue & ColoredValue
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
    where GraphType.NodeType.ValueType: EmbeddedValue & ColoredValue
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
    where GraphType.NodeType.ValueType: EmbeddedValue
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
    where GraphType.NodeType.ValueType: ColoredValue
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
    {
        if self.nodeIndices == nil {
            self.nodeIndices = Self.makeNodeIndices(graph)
        }
        let newEdgeIndices = Self.makeEdgeIndices(graph, nodeIndices!)
        return WireframeUpdate(edgeIndexCount: newEdgeIndices.count,
                               edgeIndices: newEdgeIndices)
    }

    private static func makeNodeIndices<GraphType: Graph>(_ graph: GraphType) -> [Int: Int]
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
    {
        var edgeIndices = [UInt32]()
        var edgeIndex: Int = 0
        for node in graph.nodes {
            for edge in node.outEdges {
                if let sourceIndex = nodeIndices[edge.source.nodeNumber],
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
