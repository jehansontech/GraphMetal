////
////  Stringify.swift
////  ArcWorld
////
////  Created by Jim Hanson on 4/10/21.
////
//
//import Foundation
//import simd
//
//fileprivate func makeDecimalFormatter() -> NumberFormatter {
//    let formatter = NumberFormatter()
//    // formatter.positivePrefix = "+"
//    // formatter.minimumIntegerDigits = 1
//    // formatter.minimumFractionDigits = 3
//    formatter.minimumSignificantDigits = 2
//    formatter.maximumSignificantDigits = 3
//    return formatter
//}
//
//fileprivate let decimalFormatter = makeDecimalFormatter()
//
//func stringify(_ x: Float) -> String {
//    return decimalFormatter.string(from: NSNumber(value: x))!
//}
//
//func stringify(_ point: SIMD2<Float>) -> String {
//    let x = decimalFormatter.string(from: NSNumber(value: point.x))!
//    let y = decimalFormatter.string(from: NSNumber(value: point.y))!
//    return "(\(x), \(y)"
//}
//
//func stringify(_ point: SIMD3<Float>) -> String {
//    let x = decimalFormatter.string(from: NSNumber(value: point.x))!
//    let y = decimalFormatter.string(from: NSNumber(value: point.y))!
//    let z = decimalFormatter.string(from: NSNumber(value: point.z))!
//    return "(\(x), \(y), \(z))"
//}
//
//func stringify(_ point: SIMD4<Float>) -> String {
//    let x = decimalFormatter.string(from: NSNumber(value: point.x))!
//    let y = decimalFormatter.string(from: NSNumber(value: point.y))!
//    let z = decimalFormatter.string(from: NSNumber(value: point.z))!
//    let w = decimalFormatter.string(from: NSNumber(value: point.w))!
//    return "(\(x), \(y), \(z), \(w)"
//}
//
//func stringify(_ x: Double) -> String {
//    return decimalFormatter.string(from: NSNumber(value: x))!
//}
//
//func stringify(_ point: SIMD2<Double>) -> String {
//    let x = decimalFormatter.string(from: NSNumber(value: point.x))!
//    let y = decimalFormatter.string(from: NSNumber(value: point.y))!
//    return "(\(x), \(y)"
//}
//
//func stringify(_ point: SIMD3<Double>) -> String {
//    let x = decimalFormatter.string(from: NSNumber(value: point.x))!
//    let y = decimalFormatter.string(from: NSNumber(value: point.y))!
//    let z = decimalFormatter.string(from: NSNumber(value: point.z))!
//    return "(\(x), \(y), \(z))"
//}
//
//func stringify(_ point: SIMD4<Double>) -> String {
//    let x = decimalFormatter.string(from: NSNumber(value: point.x))!
//    let y = decimalFormatter.string(from: NSNumber(value: point.y))!
//    let z = decimalFormatter.string(from: NSNumber(value: point.z))!
//    let w = decimalFormatter.string(from: NSNumber(value: point.w))!
//    return "(\(x), \(y), \(z), \(w)"
//}
//
//
//
//
