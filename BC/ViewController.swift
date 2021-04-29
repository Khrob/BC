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

struct Player
{
    var x:Float
    var y:Float
    var tx:Float
    var ty:Float
    var aim:Float
}

var player:Player!
var click_point = CGPoint.zero

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

        let cube = load_objects(file: "/Users/khrob/Desktop/cube.obj")
        let weapons = load_objects(file: "/Users/khrob/Desktop/weapons.obj")
        let characters = load_objects(file: "/Users/khrob/Desktop/characters.obj")
        let fullscreen = Object(name: "Fullscreen", material_library: "blah", material: "blah", vertices: whole_screen_verts)
        
        renderer.add(objects: cube)
        renderer.add(objects: weapons)
        renderer.add(objects: characters)
        renderer.add(objects: [fullscreen])
        
        print(renderer.object_addresses)
        
        // Build the map
        for i in 0..<map.count {
            let x = (i / Map_Width) - (Map_Width/2)
            let z = (i % Map_Width) - (Map_Width/2)
            
            if (x % 2 == 0) && (z % 2 == 0) || (x % 2 != 0) && (z % 2 != 0) { map[i] = .ground_light }
            
            let position = scale_matrix (1,0.05,1) * translate_matrix(Float(x)*2.4,-0.05,Float(z)*2.4)
            
            let colour = map[i] == .ground_dark ? simd_float4(0.5,0.5,0,1) : simd_float4(0.5,0.5,1,1)
            let o = Game_Object(model: "Cube", transform: position, colour: colour)
            objects.append(o)
        }
        
        metal_view.mouse_down = { point in
            let index = grid_index(point)
            if map[index] == .empty { map[index] = .ground_dark }
            else { map[index] = .empty }
            
            click_point.x = (point.x - 1.0) * CGFloat(Map_Width)  * 10.0
            click_point.y = (point.y - 1.0) * CGFloat(Map_Height) * 10.0
            
            print(click_point)
        }
        
        player = Player(x: 0, y: 0, tx: 0, ty: 0, aim: 0)
        
        // Start the update loop
        Timer.scheduledTimer(withTimeInterval: 1.0/FPS, repeats: true) { _ in self.update() }
    }

    func draw ()
    {
        let camera_matrix = rotate_matrix(axis: simd_float3(1,0,0), angle: Float.pi/2) * translate_matrix(0,-13.25,0)
        renderer.camera(camera_matrix)
        
        objects.forEach { o in renderer.draw(o.model, at:o.transform, shader:"Colour", colour:o.colour) }
        
        draw_player(renderer: renderer)
        
        if click_point != .zero {
            let cptx = scale_matrix(0.1) * translate_matrix(Float(click_point.x), 0.5, Float(click_point.y))
            renderer.draw("Cube", at: cptx, shader: "Colour", colour:simd_float4(1,0,0,1))
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

func draw_player (renderer:Renderer)
{
    let dx = player.tx - player.x
    let dy = player.ty - player.y
    
    let theta = atan2(dy, dx)
    
    var transform = rotate_matrix(axis: simd_float3(0,1,0), angle: theta)
    
    transform *= translate_matrix(player.x, 0.3, player.y)
    
    renderer.draw("Player_Legs", at:transform, shader:"Colour", colour: simd_float4(0.1,1,0.3,1))
    
    let weapon_transform = transform * translate_matrix(-1, 1, 0)
    renderer.draw("Launcher", at:weapon_transform, shader: "Colour", colour: simd_float4(0.6,0.1,0.1,1))
    
    let torso_transform = rotate_matrix(axis: simd_float3(0,1,0), angle: player.aim) * transform * translate_matrix(0,1,0)
    renderer.draw("Player_Torso", at:torso_transform, shader: "Colour", colour: simd_float4(0.1,1,0.1,1))
}
