"""Native anatomical finger joints and weights, carried through mesh refinement."""
from pathlib import Path
import numpy as np
from mathutils import Vector
from anatomical_body import read_base,make_transform

ROOT=Path(__file__).resolve().parent.parent

def add_finger_bones(edit_bones,target_joints):
    _,_,_,joints=read_base('adult-male')
    transform=make_transform(target_joints,joints)
    for side,label in [('L','l'),('R','r')]:
        for finger in range(1,6):
            parent=edit_bones['hand.'+side]
            for segment in range(1,4):
                bone=edit_bones.new(f'finger{finger}-{segment}.{side}')
                bone.head=transform(joints[f'joint-{label}-finger-{finger}-{segment}'])
                bone.tail=transform(joints[f'joint-{label}-finger-{finger}-{segment+1}'])
                bone.parent=parent
                bone.use_connect=segment>1
                # Local Z points toward the palm; local X closes the finger.
                bone.align_roll(Vector((0,1,0)))
                parent=bone

def add_finger_attributes(mesh,source_indices):
    data=np.load(ROOT/'assets/source/anny/native-hand-weights.npz')
    assert np.array_equal(data['base_indices'],np.arange(19158))
    for column,label in enumerate(data['labels']):
        attribute=mesh.attributes.new(name='NativeFinger_'+str(label),type='FLOAT',domain='POINT')
        attribute.data.foreach_set('value',data['weights'][source_indices,column])
