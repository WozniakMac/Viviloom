"""CC0 MakeHuman data adaptation; this module contains original OpenSims code.
Graphical source and license are recorded in assets/source/makehuman.
"""
from pathlib import Path
from collections import defaultdict
import math
import bpy
import bmesh
from mathutils import Vector


def read_base(preset=None):
    positions=[];uvs=[];faces=[];group='';landmarks=defaultdict(set)
    from anny_source import load_raw_points
    anny_points=load_raw_points(preset)
    source=Path(__file__).resolve().parent.parent/'assets/source/makehuman/base.obj'
    for line in source.read_text().splitlines():
        if line.startswith('v '):
            x,y,z=anny_points[len(positions)] if anny_points is not None else map(float,line.split()[1:4]);positions.append(Vector((x*.11,z*.11,(y+8.1676)*.11)))
        elif line.startswith('vt '):
            uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith('g '):
            group=line[2:].strip()
        elif line.startswith('f '):
            tokens=[token.split('/') for token in line.split()[1:]]
            ids=[int(token[0])-1 for token in tokens]
            landmarks[group].update(ids)
            if group=='body':
                faces.append((ids,[int(token[1])-1 for token in tokens]))
    joints={name:sum((positions[i] for i in ids),Vector())/len(ids) for name,ids in landmarks.items() if name.startswith('joint-')}
    return positions,uvs,faces,joints


def make_transform(target_joints,source_joints=None):
    joints=source_joints if source_joints is not None else read_base()[3]
    chains={}
    for side,label in [('L','l'),('R','r')]:
        chains['arm'+side]=[
            (joints['joint-'+label+'-shoulder'],joints['joint-'+label+'-elbow'],Vector(target_joints['shoulder.'+side]),Vector(target_joints['elbow.'+side])),
            (joints['joint-'+label+'-elbow'],joints['joint-'+label+'-hand'],Vector(target_joints['elbow.'+side]),Vector(target_joints['wrist.'+side])),
            (joints['joint-'+label+'-hand'],joints['joint-'+label+'-hand-3'],Vector(target_joints['wrist.'+side]),Vector(target_joints['hand.'+side]))]
        chains['leg'+side]=[
            (joints['joint-'+label+'-upper-leg'],joints['joint-'+label+'-knee'],Vector(target_joints['hip.'+side]),Vector(target_joints['knee.'+side])),
            (joints['joint-'+label+'-knee'],joints['joint-'+label+'-ankle'],Vector(target_joints['knee.'+side]),Vector(target_joints['ankle.'+side])),
            (joints['joint-'+label+'-ankle'],joints['joint-'+label+'-foot-1'],Vector(target_joints['ankle.'+side]),Vector(target_joints['toe.'+side]))]
    def warp(p,chain,hand=False):
        total=Vector();weights=0
        for a,b,c,d in chain:
            source_axis=b-a;target_axis=d-c
            t=max(0,min(1,(p-a).dot(source_axis)/source_axis.length_squared))
            source_point=a+source_axis*t
            q=c+target_axis*t+source_axis.rotation_difference(target_axis)@(p-source_point)
            weight=1/max((p-source_point).length,.008)**4
            total+=q*weight;weights+=weight
        result=total/weights
        if hand:
            a,b,c,d=chain[-1]
            axis=b-a
            distance=(p-a).dot(axis.normalized())
            t=max(0.,min(1.,(distance+.035)/.040));t=t*t*(3-2*t)
            rigid=c+axis.rotation_difference(d-c)@(p-a)
            result=result.lerp(rigid,t)
        return result
    def transform(p):
        side='L' if p.x>=0 else 'R'
        shoulder=joints['joint-'+('l' if side=='L' else 'r')+'-shoulder']
        if p.z<.90 and abs(p.x)<.35:
            return warp(p,chains['leg'+side])
        # Blend shoulder repositioning into the thorax without a hard join.
        body=p.copy()
        body.z-=.045*math.exp(-((p.z-1.25)/.25)**2)
        if abs(p.x)>.13 and (p.z>1.04 or abs(p.x)>.35):
            w=max(0,min(1,(abs(p.x)-.13)/.17))
            w=w*w*(3-2*w)
            body=body.lerp(warp(p,chains['arm'+side],hand=True),w)
        if p.z<1.04 and abs(p.x)<.35:
            t=max(0,min(1,(p.z-.90)/.14));t=t*t*(3-2*t)
            body=warp(p,chains['leg'+side]).lerp(body,t)
        return body
    return transform


def build_anatomical_body(target_joints):
    points,uvs,faces,joints=read_base()
    transform=make_transform(target_joints)
    selected=[face for face in faces if all(points[i].z<1.68 for i in face[0])]
    used=sorted({i for face in selected for i in face[0]});mapping={old:i for i,old in enumerate(used)}
    data=bpy.data.meshes.new('AnatomicalBodyMesh')
    data.from_pydata([transform(points[i]) for i in used],[],[tuple(mapping[i] for i in face[0]) for face in selected]);data.update()
    for name,(variant_points,variant_transform) in body_variants(target_joints).items():
        attribute=data.attributes.new(name='Anny'+name+'Delta',type='FLOAT_VECTOR',domain='POINT')
        for index,original in enumerate(used):
            attribute.data[index].vector=variant_transform(variant_points[original])-transform(points[original])
    arm_mask=data.attributes.new(name='AnatomicalArm',type='FLOAT',domain='POINT')
    for index,original in enumerate(used):
        p=points[original]
        w=max(0.,min(1.,(abs(p.x)-.13)/.17)) if p.z>1.04 or abs(p.x)>.35 else 0.
        arm_mask.data[index].value=w*w*(3-2*w)
    hand_mask=data.attributes.new(name='AnatomicalHand',type='FLOAT',domain='POINT')
    for index,original in enumerate(used):
        p=points[original];side='l' if p.x>=0 else 'r'
        wrist=joints['joint-'+side+'-hand']
        axis=(joints['joint-'+side+'-hand-3']-wrist).normalized()
        distance=(p-wrist).dot(axis)
        w=max(0.,min(1.,(distance+.025)/.035)) if abs(p.x)>.35 else 0.
        hand_mask.data[index].value=w*w*(3-2*w)
    uv_layer=data.uv_layers.new(name='MakeHumanUV')
    for polygon,face in zip(data.polygons,selected):
        for loop_id,uv_id in zip(polygon.loop_indices,face[1]):uv_layer.data[loop_id].uv=uvs[uv_id]
        polygon.use_smooth=True
    body=bpy.data.objects.new('Body',data);bpy.context.collection.objects.link(body)
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
    sub=body.modifiers.new('Anatomy refinement','SUBSURF');sub.levels=1;bpy.ops.object.modifier_apply(modifier=sub.name)
    bm=bmesh.new();bm.from_mesh(body.data)
    for height in (.12,.50,.86,.93,1.12,1.445,1.565):
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,height),plane_no=(0,0,1),dist=.00001,clear_outer=height==1.565)
    bm.to_mesh(body.data);bm.free()
    for polygon in body.data.polygons:polygon.use_smooth=True
    print('ANATOMICAL BODY',len(body.data.vertices),'vertices',len(body.data.polygons),'faces')
    return body





def body_variants(target_joints):
    result={}
    for shape,preset in [('Heavy','heavy'),('Fit','fit'),('HeavyFit','heavy-fit')]:
        points,_,_,joints=read_base(__import__('anny_source').active_preset()+'-'+preset)
        result[shape]=(points,make_transform(target_joints,joints))
    return result
