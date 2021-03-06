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

enum Draw_Mode { case wire, filled }

struct Game_Object
{
    let model     : Piece_Type
    let transform : simd_float4x4
    var colour    : simd_float4
    var draw_mode : Draw_Mode
}

var objects:[Game_Object] = []

var click_point = CGPoint.zero

enum Piece_Type : String
{
    case cube = "Cube"
    case player = "Bess"
    
    case enemy_cocoa = "Cocoa"
    case enemy_knight = "Knight"
    case enemy_pinky = "Pinky"
    case enemy_baron = "Baron"
    case enemy_imp = "Imp"
    case enemy_nasty = "Nasty"
    case enemy_skull = "Skull"
    
    case weaon_chaingun = "Chaingun"
    case weapon_chainsaw = "Chainsaw"
    case weapon_launcher = "Launcher"
    case weapon_pistol = "Pistol"
    case weapon_shotgun = "Shotgun"
    
    case projectile_bullet = "Bullet"
    case projectile_rocket = "Rocket"
    case projectile_laser = "Laser"
}

let live_objects : [Game_Object] = [
    Game_Object(model: .player,      transform: Identity, colour: simd_float4(0.1,0.8,0.05,1), draw_mode: .filled),
    Game_Object(model: .enemy_imp,   transform: translate_matrix(-5, 0, 3) * scale_matrix(2), colour: simd_float4(1,0.8,0.05,1), draw_mode: .filled),
    Game_Object(model: .enemy_cocoa, transform: translate_matrix(-3, 0, 3) * scale_matrix(2), colour: simd_float4(0,0,0.7,1),    draw_mode: .filled),
    Game_Object(model: .enemy_baron, transform: translate_matrix(-1, 0, 3) * scale_matrix(2), colour: simd_float4(1,0.2,0.5,1),  draw_mode: .filled),
    Game_Object(model: .enemy_imp,   transform: translate_matrix( 1, 0, 3) * scale_matrix(2), colour: simd_float4(1,0.8,0.05,1), draw_mode: .filled),
]

class ViewController: NSViewController
{
    // Plumbing
    @IBOutlet weak var metal_view:Render_View!
    var renderer:Renderer!
        
    // Game
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
        let bess = load_objects(file: "/Users/khrob/Desktop/BC/Test Data/Bess.obj")
        let fullscreen = Object(name: "Fullscreen", material_library: "blah", material: "blah", vertices: whole_screen_verts)
        
        renderer.add(objects: cube)
        renderer.add(objects: bess)
        renderer.add(objects: [fullscreen])
        
        print(renderer.object_addresses)
        
        // Build the map
        for i in 0..<map.count {
            let x = (i / Map_Width) - (Map_Width/2)
            let z = (i % Map_Width) - (Map_Width/2)
            
            if (x % 2 == 0) && (z % 2 == 0) || (x % 2 != 0) && (z % 2 != 0) { map[i] = .ground_light }
            
            let position = scale_matrix (1,0.05,1) * translate_matrix(Float(x)*2,-0.05,Float(z)*2)
            
            let colour = map[i] == .ground_dark ? simd_float4(0.5,0.5,0,1) : simd_float4(0.5,0.5,1,1)
            let o = Game_Object(model: .cube, transform: position, colour: colour, draw_mode: .filled)
            objects.append(o)
        }
        
        metal_view.mouse_down = { point in
            let index = grid_index(point)
            map[index] = (map[index] == .empty ? .ground_dark : .empty)
            
            click_point.x = (point.x * 2.0 - 1.0) * CGFloat(Map_Width)  * 12.0
            click_point.y = (point.y * 2.0 - 1.0) * CGFloat(Map_Height) * 12.0
            
            print(click_point)
        }
        
        // Start the update loop
        Timer.scheduledTimer(withTimeInterval: 1.0/FPS, repeats: true) { _ in self.update() }
    }

    func draw ()
    {
        let camera_matrix = rotate_matrix(axis: simd_float3(1,0,0), angle: Float.pi/4) * translate_matrix(0,-13.25,-10)
        renderer.camera(camera_matrix)
        
        objects.forEach { o in
            renderer.draw(o.model.rawValue, at:o.transform, shader:"Colour", colour:o.colour)
            // renderer.wire(o.model.rawValue, at:o.transform, colour:simd_float4(1,1,1,1))
        }
        
        for o in live_objects {
            renderer.draw(o.model.rawValue, at: o.transform, shader: "Colour", colour:o.colour)
            // renderer.wire(o.model.rawValue, at: o.transform, colour:simd_float4(1,0,0,1))
        }
        
        if click_point != .zero {
            let cptx = scale_matrix(0.1) * translate_matrix(Float(click_point.x), 0.5, Float(click_point.y))
            //renderer.draw("Cube", at: cptx, shader: "Colour", colour:simd_float4(1,0,0,1))
            renderer.wire("Cube", at: cptx, colour:simd_float4(1,1,0,1))
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
