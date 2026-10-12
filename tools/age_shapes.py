"""Native Anny age anatomy fitted coherently to the animated OpenSims rig.
The same continuous field deforms skin, eyes, hair and clothes. Bone rest origins
and inverse binds follow each stage; runtime height remains a separate measure.
"""
from pathlib import Path
import json
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree
from anatomical_body import read_base,make_transform
from anny_source import active_preset
STAGES=['toddler','child','teen','adult','elder']
ROOT=Path(__file__).resolve().parent.parent
class AgeShapes:
    def __init__(self,joints,rig,bones):
        points,_,faces,source=read_base()
        transform=make_transform(joints,source)
        used=sorted({i for face,_ in faces for i in face})
        self.base=[transform(points[i]) for i in used]
        self.tree=KDTree(len(used))
        for index,p in enumerate(self.base):self.tree.insert(p,index)
        self.tree.balance()
        self.deltas={};self.rests={};self.cache={}
        self.base_joints=joints
        self.bone_joints={bone:joint for bone,joint,_,_ in bones}
        for stage in STAGES:
            age_points,_,_,age_source=read_base(active_preset()+'-age-'+stage)
            target={name:Vector(p) for name,p in joints.items()}
            for name,helper in [('pelvis','pelvis'),('spine','spine-3'),('chest','spine-1'),('neck','neck'),('head','head')]:
                target[name]+=age_source['joint-'+helper]-source['joint-'+helper]
            for side,label in [('L','l'),('R','r')]:
                for name,helper in [('hip','upper-leg'),('knee','knee'),('ankle','ankle'),('toe','foot-1')]:
                    target[name+'.'+side]+=age_source['joint-'+label+'-'+helper]-source['joint-'+label+'-'+helper]
                target['shoulder.'+side]+=age_source['joint-'+label+'-shoulder']-source['joint-'+label+'-shoulder']
                for name,prev,a,b in [('elbow','shoulder','shoulder','elbow'),('wrist','elbow','elbow','hand'),('hand','wrist','hand','hand-3')]:
                    factor=(age_source['joint-'+label+'-'+b]-age_source['joint-'+label+'-'+a]).length/(source['joint-'+label+'-'+b]-source['joint-'+label+'-'+a]).length
                    target[name+'.'+side]=target[prev+'.'+side]+(Vector(joints[name+'.'+side])-Vector(joints[prev+'.'+side]))*factor
            age_transform=make_transform(target,age_source)
            self.deltas[stage]=[age_transform(age_points[i])-self.base[index] for index,i in enumerate(used)]
            rests={}
            for bone in rig.data.bones:
                if bone.name in self.bone_joints:position=target[self.bone_joints[bone.name]]
                else:
                    side=bone.name[-1]
                    base=bone.head_local+Vector(joints['wrist.'+side])-rig.data.bones['hand.'+side].head_local
                    position=base+self.offset(base,stage)
                # Blender Z-up to glTF / Godot Y-up.
                rests[bone.name.replace('.','_')]=[position.x,position.z,-position.y]
            self.rests[stage]=rests
        self.rests['young_adult']={}
        for bone in rig.data.bones:
            if bone.name in self.bone_joints:position=Vector(joints[self.bone_joints[bone.name]])
            else:
                side=bone.name[-1]
                position=bone.head_local+Vector(joints['wrist.'+side])-rig.data.bones['hand.'+side].head_local
            self.rests['young_adult'][bone.name.replace('.','_')]=[position.x,position.z,-position.y]
    def offset(self,p,stage):
        neighbors=self.tree.find_n(p,8)
        total=Vector();weight_sum=0.
        for _,index,distance in neighbors:
            weight=1./max(distance,.002)**2
            total+=self.deltas[stage][index]*weight;weight_sum+=weight
        return total/weight_sum
    def add(self,obj):
        if obj.data.shape_keys is None:obj.shape_key_add(name='Basis')
        positions=np.empty((len(obj.data.vertices),3),dtype=np.float32)
        obj.data.vertices.foreach_get('co',positions.ravel())
        for stage in STAGES:
            result=positions.copy()
            for index,p in enumerate(positions):
                key=(stage,*np.round(p,5))
                delta=self.cache.get(key)
                if delta is None:
                    delta=tuple(self.offset(Vector(p),stage));self.cache[key]=delta
                result[index]+=delta
            shape=obj.shape_key_add(name='Age_'+stage)
            shape.data.foreach_set('co',result.ravel())
        print('NATIVE AGE SHAPES',obj.name,flush=True)
    def save(self,label):
        path=ROOT/'assets/sim/age-rig.json'
        data=json.loads(path.read_text()) if path.exists() else {}
        data[label.lower()]=self.rests
        path.write_text(json.dumps(data,indent=2))
        header='[gd_resource type="Resource" script_class="CharacterAgeRig" load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/character_age_rig.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nframes = '
        (ROOT/'assets/sim/age_rig.tres').write_text(header+json.dumps(data,indent=2)+'\n')
