"""Fitted CC0 brow and eyelash meshes that follow Anny facial actions."""
from pathlib import Path
import bpy
from bound_assets import load_bound_geometry
from native_clothing import texture_material
from anatomical_body import read_base
from facial_shapes import ACTIONS

ROOT=Path(__file__).resolve().parent.parent/'assets/source/makehuman/system-assets'

def bound_part(folder,asset,name,material,points=None):
    vertices,faces,uvs,face_uvs=load_bound_geometry(folder,asset,source_points=points)
    data=bpy.data.meshes.new(name+'Mesh')
    data.from_pydata(vertices,[],faces);data.update()
    uv=data.uv_layers.new(name='MakeHumanUV')
    for polygon,indices in zip(data.polygons,face_uvs):
        polygon.use_smooth=True
        for loop,index in zip(polygon.loop_indices,indices):uv.data[loop].uv=uvs[index]
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    data.materials.append(material)
    return obj

def build_brows():
    asset='eyebrow002';folder=ROOT/'eyebrows'/asset
    material=texture_material(folder,'NativeHair_Brows')
    base=read_base()[0]
    result=[]
    for name,action in [('Neutral',None),('Angry','BrowAngry'),('Sad','BrowSad')]:
        points=base
        if action:
            variant=read_base(__import__('anny_source').active_preset()+'-action-'+action)[0]
            points=[p.lerp(q,.8) for p,q in zip(base,variant)]
        result.append(bound_part(folder,asset,'Brows_'+name,material,points))
    return result

def build_lashes():
    asset='eyelashes01';folder=ROOT/'eyelashes'/asset
    material=texture_material(folder,'NativeHair_Lashes')
    obj=bound_part(folder,asset,'NativeLashes',material)
    for action in ACTIONS:
        points=read_base(__import__('anny_source').active_preset()+'-action-'+action)[0]
        variant,_,_,_=load_bound_geometry(folder,asset,source_points=points)
        attribute=obj.data.attributes.new(name='AnnyAction'+action,type='FLOAT_VECTOR',domain='POINT')
        for vertex,p in zip(obj.data.vertices,variant):attribute.data[vertex.index].vector=p-vertex.co
    return obj
