import MetalKit
import simd

public enum WireframeBufferIndex: NSInteger {
    case uniform = 0
}

public enum WireframeVertexAttribute: NSInteger {
    case position = 0
    case color = 1
}

public enum WireframeTextureIndex: Int {
    case color = 0
}

public struct WireframeUniforms {
    public var projectionMatrix: simd_float4x4
    public var modelViewMatrix: simd_float4x4
    public var pointSize: Float
    public var edgeColor: simd_float4
    public var fadeoutMidpoint: Float
    public var fadeoutDistance: Float
    public var pulsePhase: Float
}

public struct WireframeShaders {

    public static func makeLibrary(_ device: MTLDevice) -> MTLLibrary? {
        return try? device.makeDefaultLibrary(bundle: Bundle.module)
    }
}
