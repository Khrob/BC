//
//  Renderer.swift
//  BC
//
//  Created by Khrob Edmonds on 2/5/21.
//

import MetalKit

struct Vertex
{
    var position : simd_float4 = [0,0,0,1]
    var uv       : simd_float2 = [0,0]
}

struct Uniforms
{
    // Window
    var width  : UInt16
    var height : UInt16
    
    // Camera
    var model_view_matrix : simd_float4x4
    var projection_matrix : simd_float4x4
    var colour : simd_float4
    
    // Lighting
    var ambient_intensity : simd_float1
    var light_position    : simd_float3
    var light_colour      : simd_float3
}

struct Object_Vertex
{
    let x,y,z,w:Float
    let nx,ny,nz,nw:Float
    let u,v,o,p:Float
}

struct Object
{
    let name:String
    let material_library:String
    let material:String
    let vertices:[Object_Vertex]
}

struct Level
{
    let geometry:[Geometry_Instance]
}

struct Geometry_Instance
{
    let name:String
    let orientation:simd_float4x4
}

struct Object_Address
{
    let name:String
    let start:Int
    let length:Int
}

class Instance_Uniform
{
    let m:simd_float4x4
    init (matrix:simd_float4x4) { m = matrix }
}

let Identity = simd_float4x4(1.0)

var uniforms = Uniforms(
    width: 1024, height: 1024,
    model_view_matrix: simd_float4x4(1.0), projection_matrix: simd_float4x4(1.0),
    colour: simd_float4(0,0,0,0),
    ambient_intensity: 0.15,
    light_position: simd_float3(0,10,0),
    light_colour: simd_float3(0.0,0.05,0.1))

struct Input
{
    var Up      : Bool  = false
    var Down    : Bool  = false
    var Left    : Bool  = false
    var Right   : Bool  = false
    var Action1 : Bool  = false
    var Action2 : Bool  = false
    var X       : Bool  = false
    var Y       : Bool  = false
    var A       : Bool  = false
    var B       : Bool  = false
    var dx      : Float = 0.0
    var dy      : Float = 0.0
    var mx      : Float = 0.0
    var my      : Float = 0.0
}

class Render_View : MTKView
{
    var tracking_area:NSTrackingArea? = nil
    var input = Input()
    
    var mouse_down:((CGPoint)->())?
    
    override func keyDown(with event: NSEvent)
    {
        print(#function, event.keyCode)
        
        switch event.keyCode {
        case 13, 126 : input.Up    = true
        case 00, 123 : input.Left  = true
        case 01, 125 : input.Down  = true
        case 02, 124 : input.Right = true
        default: break
        }
    }
    
    override func keyUp(with event: NSEvent)
    {
        print(#function, event.keyCode)
        
        switch event.keyCode {
        case 13, 126 : input.Up    = false
        case 00, 123 : input.Left  = false
        case 01, 125 : input.Down  = false
        case 02, 124 : input.Right = false
        default: break
        }
    }
    
    
    override func updateTrackingAreas()
    {
        if tracking_area != nil { removeTrackingArea(tracking_area!) }
        tracking_area = NSTrackingArea(rect: self.bounds, options: [.activeAlways, .mouseMoved] , owner: self, userInfo: nil)
        addTrackingArea(tracking_area!)
    }
    
    override func mouseExited(with event: NSEvent)
    {
        // print(#function)
        super.mouseExited(with: event)
    }
    
    override func mouseEntered(with event: NSEvent)
    {
        // print(#function)
        super.mouseEntered(with: event)
    }
    
    override func mouseMoved(with event: NSEvent)
    {
        // print(#function)
        super.mouseMoved(with: event)
    }
    
    override func mouseDragged(with event: NSEvent)
    {
        // print(#function)
        super.mouseDragged(with: event)
    }
    
    override func mouseDown(with event: NSEvent)
    {
        let window_size = event.window!.contentView!.bounds.size
        let point = CGPoint(x: event.locationInWindow.x / window_size.width, y: 1 - event.locationInWindow.y / window_size.height)
        mouse_down?(point)
        super.mouseDown(with: event)
    }
    
    override func mouseUp(with event: NSEvent)
    {
        // print(#function)
        super.mouseUp(with: event)
    }
    
    override var acceptsFirstResponder: Bool { return true }
}

struct Pass
{
    let descriptor:MTLRenderPassDescriptor
    let texture:MTLTexture
}

enum Pass_Load_Action  { case load, clear }
enum Pass_Store_Action { case store, clear }

class Renderer : NSObject, MTKViewDelegate
{
    let device:MTLDevice!
    var render_view:Render_View!
    let command_queue:MTLCommandQueue
    var command_buffer:MTLCommandBuffer? = nil
    let depth_stencil_state:MTLDepthStencilState
    var vertex_buffer:MTLBuffer!
    var addresses:[String:Int32] = [:]
    var object_addresses:[Int32:Object_Address] = [:]
    var geometry:[Int32:[Instance_Uniform]] = [:]
    var objects:[Object] = []
    var command_encoder:MTLRenderCommandEncoder!
    var view_matrix:simd_float4x4!
    var shaders:[String:MTLRenderPipelineState] = [:]
    var width:CGFloat!
    var height:CGFloat!
    var sampler:MTLSamplerState!
    var textures:[MTLTexture] = []
    var texture_addresses:[String:Int] = [:]
    var render:(()->())!
    var current_shader:String? = nil
    
    /// Add 3D objects to the renderer
    /// - Parameter o: An array of Object instances.
    func add (objects o:[Object])
    {
        objects.append(contentsOf: o)
        (vertex_buffer, object_addresses) = build_combined_vertex_buffer(objects: objects, device: device)
        for a in object_addresses.keys { addresses[object_addresses[a]!.name] = a }
    }
    
    func add_texture (_ path:String, name:String)
    {
        let loader = MTKTextureLoader(device: device)
        let options:[MTKTextureLoader.Option:Any] = [.generateMipmaps : true, .SRGB : true ]
        textures.append(try! loader.newTexture(URL: URL(fileURLWithPath: path), options: options))
        texture_addresses[name] = textures.count-1
    }
    
    func camera (_ matrix:simd_float4x4)
    {
        let aspect_ratio = Float(width / height)
        uniforms.projection_matrix = projection(fov: Float.pi/2, aspect: aspect_ratio, near: 0.1, far: 100)
        view_matrix = matrix
    }
    
    func draw (_ object_name:String, at model_matrix:simd_float4x4, shader:String, texture:String?=nil, colour:simd_float4? = nil)
    {
        let id = addresses[object_name]!
        let a  = object_addresses[id]!
        uniforms.model_view_matrix = view_matrix * model_matrix
        uniforms.colour = colour ?? simd_float4(0,0,0,1)
        uniforms.light_colour = simd_float3(0.8,0.1,0.1)
        if current_shader != shader {
            current_shader = shader
            command_encoder.setRenderPipelineState(shaders[shader]!)
        }
        command_encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        command_encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        if texture != nil {
            command_encoder.setFragmentTexture(textures[texture_addresses[texture!]!], index: 0)
            command_encoder.setFragmentSamplerState(sampler, index: 0)
        }
        command_encoder.drawPrimitives(type: .triangle, vertexStart: a.start, vertexCount: a.length)
    }
    
    init (view:Render_View)
    {
        device = view.device
        command_queue = device.makeCommandQueue()!
        render_view = view
        
        // Depth functions
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depth_stencil_state = device.makeDepthStencilState(descriptor: descriptor)!
        
        // Shader Pipelines
        let object_pipeline:MTLRenderPipelineState = make_pipeline(device: device, pixel_format: view.colorPixelFormat, vertex_func: "object_vertex_func", fragment_func: "object_fragment_func", depth: view.depthStencilPixelFormat)
        let colour_wheel_pipeline:MTLRenderPipelineState = make_pipeline(device: device, pixel_format: view.colorPixelFormat, vertex_func: "object_vertex_func", fragment_func: "colour_wheel_fragment_func", depth: view.depthStencilPixelFormat)
        let texture_pipeline = make_pipeline(device: device, pixel_format: view.colorPixelFormat, vertex_func: "object_vertex_func", fragment_func: "textured_fragment_func", depth: view.depthStencilPixelFormat)
        let colour_pipeline = make_pipeline(device: device, pixel_format: view.colorPixelFormat, vertex_func: "object_vertex_func", fragment_func: "colour_fragment_func", depth: view.depthStencilPixelFormat)
        
        shaders["Colour Wheel"]  = colour_wheel_pipeline
        shaders["Flat Geometry"] = object_pipeline
        shaders["Textured"]      = texture_pipeline
        shaders["Colour"]        = colour_pipeline
        
        current_shader = nil
        
        // Texture Samplers
        let sampler_descriptor = MTLSamplerDescriptor()
        sampler_descriptor.normalizedCoordinates = true
        sampler_descriptor.minFilter = .linear
        sampler_descriptor.magFilter = .linear
        sampler_descriptor.mipFilter = .linear
        sampler = device.makeSamplerState(descriptor: sampler_descriptor)
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
        uniforms.width  = UInt16(size.width)
        uniforms.height = UInt16(size.height)
    }
    
    func draw(in view: MTKView)
    {
        command_buffer = nil
        command_buffer = command_queue.makeCommandBuffer()
        if command_buffer == nil { fatalError("Couldn't create command buffer") }
        let drawable = view.currentDrawable
        if  drawable == nil { fatalError("Couldn't get a drawable") }
        let render_pass_desciptor = view.currentRenderPassDescriptor
        if  render_pass_desciptor == nil { fatalError("No valid render pass descriptor") }
        command_encoder = command_buffer!.makeRenderCommandEncoder(descriptor: render_pass_desciptor!)!
        command_encoder.setDepthStencilState(depth_stencil_state)
        command_encoder.setVertexBuffer(vertex_buffer, offset: 0, index: 0)
        if current_shader != nil { command_encoder.setRenderPipelineState(shaders[current_shader!]!) }
        width  = view.drawableSize.width
        height = view.drawableSize.height
        
        render?()
        
        command_encoder?.endEncoding()
        command_buffer?.present(drawable!)
        command_buffer?.commit()
    }
}

func make_pipeline (device:MTLDevice, pixel_format:MTLPixelFormat, vertex_func:String, fragment_func:String, depth:MTLPixelFormat) -> MTLRenderPipelineState
{
    let descriptor = MTLRenderPipelineDescriptor()
    let library = device.makeDefaultLibrary()
    if library == nil { fatalError("Couldn't initialise metal library") }
    
    descriptor.vertexFunction   = library!.makeFunction(name: vertex_func)
    descriptor.fragmentFunction = library!.makeFunction(name: fragment_func)
    descriptor.colorAttachments[0].pixelFormat = pixel_format
    descriptor.depthAttachmentPixelFormat = depth
    
    let p = try? device.makeRenderPipelineState(descriptor: descriptor)
    if p == nil { fatalError("Couldn't create metal pipeline") }
    return p!
}

func build_combined_vertex_buffer (objects:[Object], device:MTLDevice) -> (MTLBuffer, [Int32:Object_Address])
{
    var addresses:[Int32:Object_Address] = [:]
    var vertices:[Object_Vertex] = []
    var offset = 0
    var id:Int32 = 0
    
    for o in objects {
        let name = String(o.name.split(separator: ".")[0])
        addresses[id] = Object_Address(name: name, start: offset, length: o.vertices.count)
        vertices.append(contentsOf: o.vertices)
        offset += o.vertices.count
        id += 1
    }
    
    let buffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Object_Vertex>.stride * vertices.count, options: [])!
    return (buffer, addresses)
}


func instance_uniforms (_ geo:[Geometry_Instance], device:MTLDevice) -> MTLBuffer
{
    let ius = geo.map { Instance_Uniform(matrix: $0.orientation) }
    let buffer = device.makeBuffer(bytes: ius, length: MemoryLayout<Instance_Uniform>.stride * geo.count, options: [])!
    return buffer
}


func rotate_matrix (axis:simd_float3, angle: Float) -> simd_float4x4
{
    let x = axis.x, y = axis.y, z = axis.z
    let c = cosf(angle)
    let s = sinf(angle)
    let t = 1 - c
    return simd_float4x4(
        simd_float4( t * x * x + c,     t * x * y + z * s, t * x * z - y * s, 0),
        simd_float4( t * x * y - z * s, t * y * y + c,     t * y * z + x * s, 0),
        simd_float4( t * x * z + y * s, t * y * z - x * s,     t * z * z + c, 0),
        simd_float4(                 0,                 0,                 0, 1))
}

func translate_matrix (_ x:Float, _ y:Float, _ z:Float) -> simd_float4x4
{
    return simd_float4x4(
        simd_float4( 1, 0, 0, 0),
        simd_float4( 0, 1, 0, 0),
        simd_float4( 0, 0, 1, 0),
        simd_float4( x, y, z, 1))
}

func scale_matrix (_ s:Float) -> simd_float4x4
{
    return simd_float4x4(
        simd_float4(s, 0, 0, 0),
        simd_float4(0, s, 0, 0),
        simd_float4(0, 0, s, 0),
        simd_float4(0, 0, 0, 1))
}

func scale_matrix (_ x:Float, _ y:Float, _ z:Float) -> simd_float4x4
{
    return simd_float4x4(
        simd_float4(x, 0, 0, 0),
        simd_float4(0, y, 0, 0),
        simd_float4(0, 0, z, 0),
        simd_float4(0, 0, 0, 1))
}


func projection (fov:Float, aspect:Float, near:Float, far:Float) -> simd_float4x4
{
    let y_scale = 1 / tan(fov * 0.5)
    let x_scale = y_scale / aspect
    let z_range = far - near
    let z_scale = -(far + near) / z_range
    let wz_scale = -2 * far * near / z_range

    let xx = x_scale
    let yy = y_scale
    let zz = z_scale
    let zw = Float(-1)
    let wz = wz_scale

    return simd_float4x4(
        simd_float4(xx,  0,  0,  0),
        simd_float4( 0, yy,  0,  0),
        simd_float4( 0,  0, zz, zw),
        simd_float4( 0,  0, wz,  0))
}
