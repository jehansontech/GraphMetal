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

    var text = "Hello, World!"

    public var metalDevice: MTLDevice!

    public var packageMetalLibrary: MTLLibrary!
    
    public init() {
        metalDevice = MTLCreateSystemDefaultDevice()
        packageMetalLibrary = try? metalDevice.makeDefaultLibrary(bundle: Bundle.module)
    }
}
