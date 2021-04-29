//
//  shaders.metal
//  BC
//
//  Created by Khrob Edmonds on 12/31/20.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex
{
    float4 position [[ position ]];
    float2 uv;
};

struct Object_Vertex
{
    float4 position [[position]];
    float4 normal;
    float4 texel;
};

struct Screenspace_Vertex
{
    float4 position [[position]];
    float4 camera_normal;
    float4 camera_position;
    float2 texel;
};

struct Uniforms
{
    // Window
    uint16_t width;
    uint16_t height;
    
    // Camera
    float4x4 model_view_matrix;
    float4x4 projection_matrix;
    
    // Object
    float4 colour;
    
    // Lighting
    float3 light_ambient;
    float3 light_position;
    float3 light_colour;
};

vertex Screenspace_Vertex object_vertex_func (
    const device Object_Vertex *vertices [[ buffer(0) ]],
    constant Uniforms &uniforms [[ buffer(1) ]],
    uint id [[ vertex_id ]])
{
    Screenspace_Vertex v;
    v.position        = uniforms.projection_matrix * uniforms.model_view_matrix * vertices[id].position;
    v.camera_normal   = uniforms.model_view_matrix * vertices[id].normal;
    v.camera_position = uniforms.model_view_matrix * vertices[id].position;
    v.texel           = { vertices[id].texel.x, 1-vertices[id].texel.y };  // Compensate for blender's style
    return v;
}

fragment float4 colour_wheel_fragment_func (Screenspace_Vertex v [[stage_in]], constant Uniforms &uniforms [[ buffer(0) ]])
{
    float2 xy = v.texel;
    xy *= 1.1;
    float  d  = min(1.,sqrt(dot(xy, xy)));
    float  e  = 1-smoothstep(0.995, 1, d);
    float  a  = atan2(xy.y, xy.x) + M_PI_F;
    float  t6  = (2 * M_PI_F) / 6;
    float4 c  = {0,0,1,1};
    float  nn;

    if (a <= t6 * 6) { nn = (a-t6*5)/t6; c.r = 1;     c.b = 1-nn;  c.g = 0; }
    if (a <= t6 * 5) { nn = (a-t6*4)/t6; c.r = nn;    c.b = 1;     c.g = 0; }
    if (a <= t6 * 4) { nn = (a-t6*3)/t6; c.r = 0;     c.b = 1;     c.g = 1-nn; }
    if (a <= t6 * 3) { nn = (a-t6*2)/t6; c.r = 0;     c.b = nn;    c.g = 1; }
    if (a <= t6 * 2) { nn = (a-t6*1)/t6; c.r = 1-nn;  c.b = 0;     c.g = 1; }
    if (a <= t6 * 1) { nn = (a     )/t6; c.r = 1;     c.b = 0;     c.g = nn; }

    c = c + (1-d) * (1-c);

    return c*e;
}
 
fragment float4 object_fragment_func (
    Screenspace_Vertex v [[stage_in]],
    constant Uniforms &uniforms [[ buffer(0) ]])
{
    float height = v.position.y;
    
    float3 base(height/100.0, height/1000.0, height/100.0);
    float3 N = normalize(v.camera_normal.xyz);
    float3 L = normalize(uniforms.light_position - v.position.xyz);
    float3 diffuse_intensity = saturate(dot(N, L));
    float3 colour = saturate(uniforms.light_ambient + diffuse_intensity) * uniforms.light_colour * base;
    return float4(colour, 1);
}


fragment float4 textured_fragment_func (
    Screenspace_Vertex v [[stage_in]],
    constant Uniforms &uniforms [[ buffer(0) ]],
    sampler texture_sampler [[sampler(0)]],
    texture2d<float, access::sample> texture [[texture(0)]])
{
    float3 N = normalize(v.camera_normal.xyz);
    float3 L = normalize(uniforms.light_position - v.position.xyz);
    float3 diffuse_intensity = saturate(dot(N, L));
    float3 texture_colour = texture.sample(texture_sampler, v.texel).rgb;
    float3 colour = saturate(texture_colour + diffuse_intensity) * uniforms.light_colour;
    return float4(colour, 1);
}


fragment float4 colour_fragment_func (
    Screenspace_Vertex v [[stage_in]],
    constant Uniforms &uniforms [[ buffer(0) ]])
{
    float3 N = normalize(v.camera_normal.xyz);
    float3 L = normalize(uniforms.light_position - v.position.xyz);
    float3 diffuse_intensity = saturate(dot(N, L));
    float4 object_colour = uniforms.colour;
    float3 colour = object_colour.rgb + diffuse_intensity * uniforms.light_colour;
    return float4(colour,1);
}
