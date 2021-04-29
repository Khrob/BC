# exports each selected object into its own file

import bpy
import os

# export to blend file location
basedir = os.path.dirname(bpy.data.filepath)
if not basedir: raise Exception("Blend file is not saved")
# Uncomment and change if you want to export into a specific folder
basedir = "/Users/khrob/Downloads/ddd"

filename = bpy.data.filepath.split("/")[-1]
# Uncomment and change this if you want a different filename to the blender file.
# filename = "/test3.out"
path = basedir+"/"+filename

print (basedir)
print (filename)
print (path)

file = open(path, "w")

object_list = bpy.context.scene.objects

for object in object_list:
    
    if not object.hide_get():
        
        original = object.location
        
        x = object.location[0]
        y = object.location[1]
        z = object.location[2]
        
        object.location = (x, z, -y)
        
        m = object.matrix_basis
        
        file.write("%s\n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n%f %f %f %f\n\n" % (
            object.name, 
            m[0][0], m[1][0], m[2][0], m[3][0],   
            m[0][1], m[1][1], m[2][1], m[3][1],   
            m[0][2], m[1][2], m[2][2], m[3][2],   
            m[0][3], m[1][3], m[2][3], m[3][3]))
            
        object.location = (x, y, z)
        
if file: file.close()

print("done")