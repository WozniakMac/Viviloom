"""Fit CC0 MakeHuman garments to Anny using the supplied barycentric bindings."""
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
from anatomical_body import read_base, make_transform, body_variants
from bound_assets import load_bound_geometry
from anatomical_shapes import add_body_shapes
from anatomical_weights import bind_body

ROOT=Path(__file__).resolve().parent.parent/'assets/source/makehuman/system-assets/clothes'

def texture_material(folder, name, material_file=None):
    material=bpy.data.materials.new(name)
    material.use_nodes=True
    shader=material.node_tree.nodes['Principled BSDF']
    shader.inputs['Roughness'].default_value=.85
    values={}
    for line in (folder/material_file if material_file else next(folder.glob('*.mhmat'))).read_text().splitlines():
        parts=line.split()
        if len(parts)>1:values[parts[0]]=parts[1]
    for field,socket in [('diffuseTexture','Base Color'),('normalmapTexture','Normal')]:
        if field not in values:continue
        node=material.node_tree.nodes.new('ShaderNodeTexImage')
        node.image=bpy.data.images.load(str(folder/values[field]),check_existing=True)
        if field=='normalmapTexture':
            node.image.colorspace_settings.name='Non-Color'
            normal=material.node_tree.nodes.new('ShaderNodeNormalMap')
            material.node_tree.links.new(node.outputs['Color'],normal.inputs['Color'])
            material.node_tree.links.new(normal.outputs['Normal'],shader.inputs[socket])
        else:material.node_tree.links.new(node.outputs['Color'],shader.inputs[socket])
    return material

def fit_asset(asset, target_joints, rig, shoes=False):
    folder=ROOT/asset
    points,_,_,_=read_base()
    transform=make_transform(target_joints)
    source,faces,uvs,face_uvs=load_bound_geometry(folder,asset,source_points=points,head=False)
    variants={}
    for name,(variant_points,variant_transform) in body_variants(target_joints).items():
        fitted,_,_,_=load_bound_geometry(folder,asset,source_points=variant_points,head=False)
        variants[name]=[variant_transform(p)-transform(base) for p,base in zip(fitted,source)]
    data=bpy.data.meshes.new(asset)
    data.from_pydata([transform(p) for p in source],[],faces);data.update()
    for name,deltas in variants.items():
        attribute=data.attributes.new(name='Anny'+name+'Delta',type='FLOAT_VECTOR',domain='POINT')
        for index,delta in enumerate(deltas):attribute.data[index].vector=delta
    # Separate connected garments before cutting selectable sleeves and trouser legs.
    # A height cutoff misclassifies the sweater hem as pants and swaps its texture.
    parent=list(range(len(source)))
    def root(index):
        while parent[index]!=index:
            parent[index]=parent[parent[index]];index=parent[index]
        return index
    for face in faces:
        for index in face[1:]:parent[root(index)]=root(face[0])
    heights={}
    for index,p in enumerate(source):heights[root(index)]=max(heights.get(root(index),-100),p.z)
    region=data.attributes.new(name='GarmentTorso',type='FLOAT',domain='POINT')
    for index in range(len(source)):region.data[index].value=1.0 if heights[root(index)]>1.2 else 0.0
    layer=data.uv_layers.new(name='GarmentUV')
    for polygon,indices in zip(data.polygons,face_uvs):
        for loop,index in zip(polygon.loop_indices,indices):layer.data[loop].uv=uvs[index]
    mask=data.attributes.new(name='AnatomicalArm',type='FLOAT',domain='POINT')
    for index,p in enumerate(source):
        w=max(0.,min(1.,(abs(p.x)-.13)/.17)) if p.z>1.04 or abs(p.x)>.35 else 0.
        mask.data[index].value=w*w*(3-2*w)
    obj=bpy.data.objects.new(asset,data);bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Fabric refinement','SUBSURF');modifier.levels=1;bpy.ops.object.modifier_apply(modifier=modifier.name)
    bm=bmesh.new();bm.from_mesh(obj.data)
    if not shoes:
        for height in [.50,.93,1.12]:
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,height),plane_no=(0,0,1),dist=.00001)
    bm.to_mesh(obj.data);bm.free()
    fabric=texture_material(folder,'ShoesFabric' if shoes else 'ShirtFabric')
    pants=fabric.copy();pants.name='PantsFabric'
    generated=ROOT.parents[2]/'generated/crewneck-blue-ai.png'
    if not shoes and generated.exists():
        for node in fabric.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image.colorspace_settings.name != 'Non-Color':
                node.image=bpy.data.images.load(str(generated),check_existing=True)
    buckets={}
    values=[item.value for item in obj.data.attributes['AnatomicalArm'].data]
    torso_values=[item.value for item in obj.data.attributes['GarmentTorso'].data]
    for polygon in obj.data.polygons:
        arm=sum(values[i] for i in polygon.vertices)/len(polygon.vertices)
        if shoes:name='OutfitShoes'
        elif sum(torso_values[i] for i in polygon.vertices)/len(polygon.vertices)>.5:
            name='OutfitSleeve' if arm>.5 and polygon.center.z<1.12 else 'OutfitTop'
        elif polygon.center.z<.50:name='OutfitShin'
        else:name='OutfitPants'
        buckets.setdefault(name,[]).append(polygon)
    result=[]
    for name,polygons in buckets.items():
        used=sorted({index for polygon in polygons for index in polygon.vertices});mapping={index:i for i,index in enumerate(used)}
        mesh=bpy.data.meshes.new(name+'Mesh')
        mesh.from_pydata([obj.data.vertices[i].co.copy() for i in used],[],[tuple(mapping[i] for i in polygon.vertices) for polygon in polygons]);mesh.update()
        uv=mesh.uv_layers.new(name='GarmentUV')
        for polygon,original in zip(mesh.polygons,polygons):
            polygon.use_smooth=True
            for loop,old in zip(polygon.loop_indices,original.loop_indices):uv.data[loop].uv=obj.data.uv_layers.active.data[old].uv
        attribute=mesh.attributes.new(name='AnatomicalArm',type='FLOAT',domain='POINT')
        for i,old in enumerate(used):attribute.data[i].value=values[old]
        for shape in variants:
            attribute=mesh.attributes.new(name='Anny'+shape+'Delta',type='FLOAT_VECTOR',domain='POINT')
            for i,old in enumerate(used):attribute.data[i].vector=obj.data.attributes['Anny'+shape+'Delta'].data[old].vector
        mesh.materials.append(pants if name in ['OutfitPants','OutfitShin'] else fabric)
        part=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(part)
        add_body_shapes(part)
        bpy.ops.object.select_all(action='DESELECT');part.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
        bpy.ops.object.parent_set(type='ARMATURE_NAME');bind_body(part,rig)
        result.append(part)
    bpy.data.objects.remove(obj,do_unlink=True)
    print('FITTED GARMENT',asset,[part.name for part in result])
    return result

def build_clothing(joints,rig):
    return fit_asset('male_casualsuit02',joints,rig)+fit_asset('shoes05',joints,rig,shoes=True)
