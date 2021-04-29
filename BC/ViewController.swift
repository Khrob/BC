//
//  ViewController.swift
//  BC
//
//  Created by Khrob Edmonds on 12/31/20.
//

import Cocoa
import MetalKit

enum Tile { case empty, ground_dark, ground_light }
let Map_Width  = 11
let Map_Height = 11
var map : [Tile] = Array(repeating: .ground_dark, count: Map_Width * Map_Height)

struct Game_Object
{
    let model     : String
    let transform : simd_float4x4
    var colour    : simd_float4
}

var objects:[Game_Object] = []

class ViewController: NSViewController
{
    // Plumbing
    @IBOutlet weak var metal_view:Render_View!
    var renderer:Renderer!
        
    // Game
    var level:Level!
    var t:Float = 0
    var FPS:Double = 120.0
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        metal_view.device = MTLCreateSystemDefaultDevice()
        metal_view.colorPixelFormat = .bgra8Unorm_srgb
        metal_view.depthStencilPixelFormat = .depth32Float
        renderer = Renderer(view: metal_view)
        renderer.render = self.draw
        metal_view.delegate = renderer
        setup()
    }

    func setup ()
    {
        let whole_screen_verts:[Object_Vertex] = [
            Object_Vertex(x: -1, y:  1, z: 1, w: 1, nx: 0, ny: 0, nz: -1, nw: 1, u: 0, v: 0, o: 0, p: 0),
            Object_Vertex(x:  1, y:  1, z: 1, w: 1, nx: 0, ny: 0, nz: -1, nw: 1, u: 1, v: 0, o: 0, p: 0),
            Object_Vertex(x: -1, y: -1, z: 1, w: 1, nx: 0, ny: 0, nz: -1, nw: 1, u: 0, v: 1, o: 0, p: 0),
            Object_Vertex(x: -1, y: -1, z: 1, w: 1, nx: 0, ny: 0, nz: -1, nw: 1, u: 0, v: 1, o: 0, p: 0),
            Object_Vertex(x:  1, y:  1, z: 1, w: 1, nx: 0, ny: 0, nz: -1, nw: 1, u: 1, v: 0, o: 0, p: 0),
            Object_Vertex(x:  1, y: -1, z: 1, w: 1, nx: 0, ny: 0, nz: -1, nw: 1, u: 1, v: 1, o: 0, p: 0),
        ]

        let fullscreen = Object(name: "Fullscreen", material_library: "blah", material: "blah", vertices: whole_screen_verts)
        let cube = load_objects(file: "/Users/khrob/Desktop/cube.obj")
        
        renderer.add(objects: cube)
        renderer.add(objects: [fullscreen])
        
        print(renderer.object_addresses)
        
        // Build the map
        for i in 0..<map.count {
            let x = i / Map_Width
            let z = i % Map_Width
            
            if (x % 2 == 0) && (z % 2 == 0) || (x % 2 != 0) && (z % 2 != 0) { map[i] = .ground_light }
            
            var position_matrix = Identity
            position_matrix *= scale_matrix (1,6.05,1)
            
            position_matrix *= translate_matrix(Float(x)*2.4,-0.05,Float(z)*2.4)
            
            let colour = map[i] == .ground_dark ? simd_float4(0.5,0.5,0,1) : simd_float4(0.5,0.5,1,1)
            let o = Game_Object(model: "Cube", transform: position_matrix, colour: colour)
            objects.append(o)
        }
        
        metal_view.mouse_down = { point in
            let index = grid_index(point)
            if map[index] == .empty { map[index] = .ground_dark }
            else { map[index] = .empty }
        }
        
        // Start the update loop
        Timer.scheduledTimer(withTimeInterval: 1.0/FPS, repeats: true) { _ in self.update() }
    }

    func draw ()
    {
        let camera_matrix = rotate_matrix(axis: simd_float3(1,0,0), angle: Float.pi/2) * translate_matrix(0,-13.25,0)
        renderer.camera(camera_matrix)
        
        objects.forEach { o in
            renderer.draw(o.model, at:o.transform, with:"Colour", colour:o.colour)
        }
    }
    
    func update ()
    {
        let start = Date()
        defer { if abs(start.timeIntervalSinceNow) > 0.2 / FPS { print ("WARNING: MISSED TICK UPDATE TIME") } }
        t += 1.0 / Float(FPS)
    }
}

func grid_point (_ point:CGPoint) -> (Int,Int)
{
    let dx = 1.0 / CGFloat(Map_Width)
    let dz = 1.0 / CGFloat(Map_Height)
    let x = Int(point.x / dx)
    let z = Int(point.y / dz)
    return (x,z)
}

func grid_index (_ point:CGPoint) -> Int
{
    let p = grid_point(point)
    return p.0 * Map_Width + p.1
}
