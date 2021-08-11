import MetalKit
import simd

public enum BufferIndex: NSInteger {
    case nodePosition = 0
    case nodeColor = 1
    case uniforms = 2
}

public enum VertexAttribute: NSInteger {
    case position = 0
    case color = 1
}

public enum TextureIndex: Int {
    case color = 0
}

public struct Uniforms {
    public var projectionMatrix: simd_float4x4
    public var modelViewMatrix: simd_float4x4
    public var pointSize: Float
    public var edgeColor: simd_float4
}

public struct Shaders {

//    public var defaultDevice: MTLDevice!
//
//    public var defaultLibrary: MTLLibrary!
//    
//    public init() {
//        defaultDevice = MTLCreateSystemDefaultDevice()
//        defaultLibrary = try? defaultDevice.makeDefaultLibrary(bundle: Bundle.module)
//    }

    public static func makeDefaultLibrary(_ device: MTLDevice) -> MTLLibrary? {
        return try? device.makeDefaultLibrary(bundle: Bundle.module)
    }
}
