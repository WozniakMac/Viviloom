"""CC0 MakeHuman eyes fitted to the Anny face, with the native texture UVs."""
from pathlib import Path
import bpy
from bound_assets import load_bound_geometry
from native_clothing import texture_material

def build_native_eyes():
    root=Path(__file__).resolve().parent.parent/'assets/source/makehuman/system-assets/eyes'
    vertices,faces,uvs,face_uvs=load_bound_geometry(root/'high-poly','high-poly')
    mesh=bpy.data.meshes.new('NativeEyesMesh')
    mesh.from_pydata(vertices,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='MakeHumanUV')
    for polygon,indices in zip(mesh.polygons,face_uvs):
        polygon.use_smooth=True
        for loop,index in zip(polygon.loop_indices,indices):uv.data[loop].uv=uvs[index]
    obj=bpy.data.objects.new('NativeEyes',mesh);bpy.context.collection.objects.link(obj)
    material=texture_material(root/'materials','NativeEyes','brown.mhmat')
    material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.23
    mesh.materials.append(material)
    return obj
