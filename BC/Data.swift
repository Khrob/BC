//
//  Data.swift
//  BC
//
//  Created by Khrob Edmonds on 2/5/21.
//

import Foundation
import simd

func load_objects (file:String) -> [Object]
{
    // Intermediates
    struct I_Vertex { let x,y,z,w:Float }
    struct I_UV { let u,v:Float }
    struct I_Face
    {
        let vertex1,texture1,normal1:Int
        let vertex2,texture2,normal2:Int
        let vertex3,texture3,normal3:Int
    }
    
    let contents = try! String(contentsOfFile: file)
    let lines = contents.split(separator: "\n")
    let parts = lines.map { $0.split(separator: " ") }
    
    var name:String = ""
    var material_library:String?
    var material:String?
    var intermediate_verts:[I_Vertex] = []
    var intermediate_normals:[I_Vertex] = []
    var intermediate_faces:[I_Face] = []
    var intermetiate_uvs:[I_UV] = []
    var vert_offset = 0
    var normal_offset = 0
    var uv_offset = 0
    
    func build () -> Object
    {
        var verts:[Object_Vertex] = []
        for f in intermediate_faces {
            verts.append(Object_Vertex(
                x: intermediate_verts[f.vertex1].x, y: intermediate_verts[f.vertex1].y, z: intermediate_verts[f.vertex1].z, w: 1.0,
                nx: intermediate_normals[f.normal1].x, ny: intermediate_normals[f.normal1].y, nz: intermediate_normals[f.normal1].z, nw: 1.0,
                            u: intermetiate_uvs[f.texture1].u, v: intermetiate_uvs[f.texture1].v, o:0, p:0))
            verts.append(Object_Vertex(
                x: intermediate_verts[f.vertex2].x, y: intermediate_verts[f.vertex2].y, z: intermediate_verts[f.vertex2].z, w: 1.0,
                nx: intermediate_normals[f.normal2].x, ny: intermediate_normals[f.normal2].y, nz: intermediate_normals[f.normal2].z, nw: 1.0,
                u: intermetiate_uvs[f.texture2].u, v: intermetiate_uvs[f.texture2].v, o:0, p:0))
            verts.append(Object_Vertex(
                x: intermediate_verts[f.vertex3].x, y: intermediate_verts[f.vertex3].y, z: intermediate_verts[f.vertex3].z, w: 1.0,
                nx: intermediate_normals[f.normal3].x, ny: intermediate_normals[f.normal3].y, nz: intermediate_normals[f.normal3].z, nw: 1.0,
                u: intermetiate_uvs[f.texture3].u, v: intermetiate_uvs[f.texture3].v, o:0, p:0))
        }
        
        let o = Object(name: name, material_library: material_library ?? "No material library", material: material ?? "No material", vertices: verts)
        
        normal_offset += intermediate_normals.count
        vert_offset += intermediate_verts.count
        uv_offset += intermetiate_uvs.count
        
        name = ""
        material_library = ""
        material = ""
        intermediate_verts.removeAll()
        intermediate_normals.removeAll()
        intermediate_faces.removeAll()
        intermetiate_uvs.removeAll()
        
        return o
    }
    
    var objects:[Object] = []
    
    parts.forEach {
        
        switch $0[0] {
        
            case "#": break
                
            case "o":
                if name != "" { print ("Adding new object"); objects.append(build()) }
                name = String($0[1])
            
            case "vn": intermediate_normals.append(I_Vertex(x: Float($0[1])!, y: Float($0[2])!, z: Float($0[3])!, w: 1.0))
                
            case "vt": intermetiate_uvs.append(I_UV(u: Float($0[1])!, v: Float($0[2])!))
                
            case "s": if $0[1] != "off" { print("Smoothing groups not implemented") }
        
            case "v": intermediate_verts.append(I_Vertex(x: Float($0[1])!, y: Float($0[2])!, z: Float($0[3])!, w: 1.0))
                
            case "usemtl": material = String($0[1])
                
            case "mtllib": material_library = String($0[1])
                
            case "f":
                let parts = $0[1...3].map {$0.split(separator: "/") }
                let face = I_Face(
                    vertex1: Int(parts[0][0])!-1-vert_offset, texture1: Int(parts[0][1])!-1-uv_offset, normal1: Int(parts[0][2])!-1-normal_offset,
                    vertex2: Int(parts[1][0])!-1-vert_offset, texture2: Int(parts[1][1])!-1-uv_offset, normal2: Int(parts[1][2])!-1-normal_offset,
                    vertex3: Int(parts[2][0])!-1-vert_offset, texture3: Int(parts[2][1])!-1-uv_offset, normal3: Int(parts[2][2])!-1-normal_offset)
                intermediate_faces.append(face)
        
            default: print("Unknown type \($0[0]) (\($0)")
        }
    }
    
    objects.append(build())
    
    return objects
}
