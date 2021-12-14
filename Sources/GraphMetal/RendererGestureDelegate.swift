//
//  RendererGestures.swift
//  
//
//  Created by Jim Hanson on 12/14/21.
//

import SwiftUI
import Wacoma
import MetalKit

public enum GestureMode {
    case normal
    case option
}

public protocol RendererTapHandler {

    /// location is in clip space: (-1, -1) to (+1, +1)
    mutating func tap(mode: GestureMode, at location: SIMD2<Float>)

}

public protocol RendererLongPressHandler {

    /// location is in clip space: (-1, -1) to (+1, +1)
    mutating func longPressBegan(mode: GestureMode, at location: SIMD2<Float>)

    mutating func longPressEnded()
}


public protocol RendererDragHandler {

    /// location is in clip space: (-1, -1) to (+1, +1)
    mutating func dragBegan(mode: GestureMode, at location: SIMD2<Float>)

    /// pan is fraction of view width; negative means "to the left"
    /// scroll is fraction of view height; negative means "down"
    mutating func dragChanged(pan: Float, scroll: Float)

    mutating func dragEnded()

}

public protocol RendererPinchHandler {

    /// center is midpoint between two fingers
    mutating func pinchBegan(mode: GestureMode, at center: SIMD2<Float>)

    /// scale goes like 1 -> 0.1 when squeezing,  1 -> 10 when stretching
    mutating func pinchChanged(by scale: Float)

    mutating func pinchEnded()

}


public protocol RendererRotationHandler {

    /// center is midpoint between two fingers
    mutating func rotationBegan(mode: GestureMode, at center: SIMD2<Float>)

    /// increases as the fingers rotate counterclockwise
    mutating func rotationChanged(by radians: Float)

    mutating func rotationEnded()
}


#if os(iOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

public class RendererGestureDelegate: NSObject, UIGestureRecognizerDelegate {

    var tapHandler: RendererTapHandler? = nil

    var longPressHandler: RendererLongPressHandler? = nil

    var dragHandler: RendererDragHandler? = nil

    var pinchHandler: RendererPinchHandler? = nil

    var rotationHandler: RendererRotationHandler? = nil

    func connectGestures(_ mtkView: MTKView) {

        if tapHandler != nil {
            mtkView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
        }

        if longPressHandler != nil {
            mtkView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPress)))
        }

        if dragHandler != nil {
            mtkView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag)))
        }

        if pinchHandler != nil {
            mtkView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch)))
        }

        if rotationHandler != nil {
            mtkView.addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(rotate)))
        }
    }

    @objc func tap(_ gesture: UITapGestureRecognizer) {
        if var tapHandler = self.tapHandler,
           let view = gesture.view,
           gesture.numberOfTouches > 0 {

            debug("RendererGestureDelegate(iOS)", "tap at \(gesture.location(ofTouch: 0, in: view)) -> \(clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds).prettyString)")

            switch gesture.state {
            case .possible:
                break
            case .began:
                break
            case .changed:
                break
            case .ended:
                tapHandler.tap(mode: getMode(forGesture: gesture),
                               at: clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func longPress(_ gesture: UILongPressGestureRecognizer) {
        if var longPressHandler = self.longPressHandler,
           let view = gesture.view,
           gesture.numberOfTouches > 0  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                longPressHandler.longPressBegan(mode: getMode(forGesture: gesture),
                                                at: clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))
            case .changed:
                longPressHandler.longPressEnded()
                break
            case .ended:
                longPressHandler.longPressEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func drag(_ gesture: UIPanGestureRecognizer) {
        if var dragHandler = self.dragHandler,
           let view  = gesture.view,
           gesture.numberOfTouches > 0  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                dragHandler.dragBegan(mode: getMode(forGesture: gesture),
                                      at: clipPoint(gesture.location(ofTouch: 0, in: view), view.bounds))
            case .changed:
                let translation = gesture.translation(in: view)
                // NOTE that factor on -1 on scroll
                dragHandler.dragChanged(pan: Float(translation.x / view.bounds.width),
                                        scroll: Float(-translation.y / view.bounds.height))
            case .ended:
                dragHandler.dragEnded()
            case .cancelled:
                dragHandler.dragEnded()
            case .failed:
                dragHandler.dragEnded()
            @unknown default:
                break
            }
        }
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        if var pinchHandler = self.pinchHandler,
           let view  = gesture.view,
           gesture.numberOfTouches > 1  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                pinchHandler.pinchBegan(mode: getMode(forGesture: gesture),
                                        at: clipPoint(gesture.location(ofTouch: 0, in: view),
                                                      gesture.location(ofTouch: 1, in: view),
                                                      view.bounds))
            case .changed:
                pinchHandler.pinchChanged(by: Float(gesture.scale))
            case .ended:
                pinchHandler.pinchEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func rotate(_ gesture: UIRotationGestureRecognizer) {
        if var rotationHandler = rotationHandler,
           let view  = gesture.view,
           gesture.numberOfTouches > 1  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                rotationHandler.rotationBegan(mode: getMode(forGesture: gesture),
                                              at: clipPoint(gesture.location(ofTouch: 0, in: view),
                                                            gesture.location(ofTouch: 1, in: view),
                                                            view.bounds))
            case .changed:
                rotationHandler.rotationChanged(by: Float(gesture.rotation))
            case .ended:
                rotationHandler.rotationEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    /// needed in order to do simultaneous gestures
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer || shouldRecognizeSimultaneouslyWith is UIPanGestureRecognizer {
            return false
        }

        return true
    }
    private func getMode(forGesture gesture: UIGestureRecognizer) -> GestureMode {
        switch gesture.numberOfTouches {
        case 1:
            return .normal
        default:
            return .option
        }
    }

    private func clipPoint(_ viewPt: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
        return SIMD2<Float>(clipX(viewPt.x, viewSize.width), clipY(viewPt.y, viewSize.height))
    }

    private func clipPoint(_ viewPt0: CGPoint, _ viewPt1: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
        return SIMD2<Float>(clipX((viewPt0.x + viewPt1.x)/2, viewSize.width),
                            clipY((viewPt0.y + viewPt1.y)/2, viewSize.height))
    }

    private func clipX(_ viewX: CGFloat, _ viewWidth: CGFloat) -> Float {
        return Float(2 * viewX / viewWidth - 1)
    }

    private func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
        // In iOS, viewY increases toward the TOP of the screen
        return Float(1 - 2 * viewY / viewHeight)
    }
}

#elseif os(macOS) // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

class RendererGestureDelegate: NSObject, NSGestureRecognizerDelegate {

    var tapHandler: RendererTapHandler? = nil

    var longPressHandler: RendererLongPressHandler? = nil

    var dragHandler: RendererDragHandler? = nil

    var pinchHandler: RendererPinchHandler? = nil

    var rotationHandler: RendererRotationHandler? = nil

    func connectGestures(_ mtkView: MTKView) {

        if tapHandler != nil {
            mtkView.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(tap)))
        }

        if longPressHandler != nil {
            mtkView.addGestureRecognizer(NSPressGestureRecognizer(target: self, action: #selector(longPress)))
        }

        if dragHandler != nil {
            mtkView.addGestureRecognizer(NSPanGestureRecognizer(target: self, action: #selector(drag)))
        }

        if pinchHandler != nil {
            mtkView.addGestureRecognizer(NSMagnificationGestureRecognizer(target: self, action: #selector(pinch)))
        }

        if rotationHandler != nil {
            mtkView.addGestureRecognizer(NSRotationGestureRecognizer(target: self, action: #selector(rotate)))
        }
    }

    @objc func tap(_ gesture: NSClickGestureRecognizer) {
        if var tapHandler = self.tapHandler,
           let view = gesture.view {
            switch gesture.state {
            case .possible:
                break
            case .began:
                break
            case .changed:
                break
            case .ended:
                tapHandler.tap(mode: getMode(forGesture: gesture),
                               at: clipPoint(gesture.location(in: view), view.bounds))
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func longPress(_ gesture: NSPressGestureRecognizer) {
        if var longPressHandler = self.longPressHandler,
           let view = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                longPressHandler.longPressBegan(mode: getMode(forGesture: gesture),
                                                at: clipPoint(gesture.location(in: view), view.bounds))
            case .changed:
                longPressHandler.longPressEnded()
                break
            case .ended:
                longPressHandler.longPressEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func drag(_ gesture: NSPanGestureRecognizer) {
        if var dragHandler = self.dragHandler,
           let view  = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                dragHandler.dragBegan(mode: getMode(forGesture: gesture),
                                      at: clipPoint(gesture.location(in: view), view.bounds))
            case .changed:
                let translation = gesture.translation(in: view)
                // macOS uses upside-down clip coords, so the scroll value is the opposite of that on iOS
                dragHandler.dragChanged(pan: Float(translation.x / view.bounds.width),
                                        scroll: Float(translation.y / view.bounds.height))
            case .ended:
                dragHandler.dragEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func pinch(_ gesture: NSMagnificationGestureRecognizer) {
        if var pinchHandler = self.pinchHandler,
           let view  = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                pinchHandler.pinchBegan(mode: getMode(forGesture: gesture),
                                        at: clipPoint(gesture.location(in: view),
                                                      view.bounds))
            case .changed:
                // macOS gesture's magnification=0 corresponds to iOS gesture's scale=1
                pinchHandler.pinchChanged(by: Float(1 + gesture.magnification))
            case .ended:
                pinchHandler.pinchEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    @objc func rotate(_ gesture: NSRotationGestureRecognizer) {
        if var rotationHandler = self.rotationHandler,
           let view  = gesture.view  {

            switch gesture.state {
            case .possible:
                break
            case .began:
                rotationHandler.rotationBegan(mode: getMode(forGesture: gesture),
                                              at: clipPoint(gesture.location(in: view),
                                                            view.bounds))
            case .changed:
                // multiply by -1 because macOS gestures use upside-down clip space
                rotationHandler.rotationChanged(by: Float(-gesture.rotation))
            case .ended:
                rotationHandler.rotationEnded()
            case .cancelled:
                break
            case .failed:
                break
            @unknown default:
                break
            }
        }
    }

    /// needed in order to do simultaneous gestures
    public func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith: NSGestureRecognizer) -> Bool {
        if gestureRecognizer is NSPanGestureRecognizer || shouldRecognizeSimultaneouslyWith is NSPanGestureRecognizer {
            return false
        }

        return true
    }

    private func getMode(forGesture gesture: NSGestureRecognizer) -> GestureMode {
        //        switch gesture.numberOfTouches {
        //        case 1:
        return .normal
        //        default:
        //            return .option
        //        }
    }

    private func clipPoint(_ viewPt: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
        return SIMD2<Float>(clipX(viewPt.x, viewSize.width), clipY(viewPt.y, viewSize.height))
    }

    private func clipPoint(_ viewPt0: CGPoint, _ viewPt1: CGPoint, _ viewSize: CGRect) -> SIMD2<Float> {
        return SIMD2<Float>(clipX((viewPt0.x + viewPt1.x)/2, viewSize.width),
                            clipY((viewPt0.y + viewPt1.y)/2, viewSize.height))
    }

    private func clipX(_ viewX: CGFloat, _ viewWidth: CGFloat) -> Float {
        return Float(2 * viewX / viewWidth - 1)
    }

    private func clipY(_ viewY: CGFloat, _ viewHeight: CGFloat) -> Float {
        // In macOS, viewY increaases toward the BOTTOM of the screen
        return Float(2 * viewY / viewHeight - 1)
    }
}

#endif  // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

