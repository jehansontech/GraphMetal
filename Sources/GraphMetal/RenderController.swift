//
//  RenderController.swift
//  
//
//  Created by Jim Hanson on 12/11/21.
//

import SwiftUI
import Wacoma
import GenericGraph

public class RenderController: ObservableObject, RenderControllerDelegate {

    @Published public private(set) var updateInProgress: Bool

    @Published public var yFOV: Float

    @Published public var zNear: Float

    @Published public var zFar: Float

    @Published public var fadeoutOnset: Float

    @Published public var fadeoutDistance: Float

    @Published public private(set) var backgroundColor: SIMD4<Double>

    private var updateStartedCount: Int = 0

    private var updateCompletedCount: Int = 0

    weak var delegate: RenderControllerDelegate? = nil

    public init(yFOV: Float = .piOverFour,
                zNear: Float = 0.01,
                zFar: Float = 1000,
                fadeoutOnset: Float = 0,
                fadeoutDistance: Float = 1000,
                backgroundColor: SIMD4<Double> = SIMD4<Double>(0.02, 0.02, 0.02, 1)) {
        self.updateInProgress = false
        self.yFOV = yFOV
        self.zNear = zNear
        self.zFar = zFar
        self.fadeoutOnset = fadeoutOnset
        self.fadeoutDistance = fadeoutDistance
        self.backgroundColor = backgroundColor
    }

    public func requestScreenshot() {
        delegate?.requestScreenshot()
    }

    public func findNearestNode(_ clipLocation: SIMD2<Float>) -> NodeID? {
        return delegate?.findNearestNode(clipLocation)
    }

    func updateStarted() {
        updateStartedCount += 1
        debug("RenderController", "updateStated. new updateStartedCount=\(updateStartedCount), updateCompletedCount=\(updateCompletedCount)")

        // FIXME: this needs to be executed on main thread!
        self.updateInProgress = (updateStartedCount > updateCompletedCount)
    }

    func updateCompleted() {
        updateCompletedCount += 1
        debug("RenderController", "updateCompleted. updateStartedCount=\(updateStartedCount), new updateCompletedCount=\(updateCompletedCount)")
        self.updateInProgress = (updateStartedCount > updateCompletedCount)
    }
}

protocol RenderControllerDelegate: AnyObject {

    func requestScreenshot()

    func findNearestNode(_ clipLocation: SIMD2<Float>) -> NodeID?
}

