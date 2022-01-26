import MetalKit
import simd

public enum WireframeBufferIndex: NSInteger {
    case nodePosition = 2
    case nodeColor = 1
    case uniforms = 0
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
    public var fadeoutOnset: Float
    public var fadeoutDistance: Float
}

public struct WireframeShaders {

    public static func makeLibrary(_ device: MTLDevice) -> MTLLibrary? {
        return try? device.makeDefaultLibrary(bundle: Bundle.module)
    }
}
