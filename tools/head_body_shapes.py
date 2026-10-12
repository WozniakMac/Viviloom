"""Original soft-tissue body responses on the native Anny face and fitted hair.

Anny's body presets leave almost all visible facial vertices unchanged. These
restrained sculpt deltas give body weight a coherent cheek/jaw response while
keeping the native eyes, eyelids, expressions and the cut neck seam intact.
"""
import math
import bpy
from mathutils import Vector
from anny_source import active_preset


def displacement(p, female=False):
    x,y,z=p
    # The cut neck is stationary; no change reaches the native eye region.
    lower=max(0.,min(1.,(z-1.575)/.035))
    upper=max(0.,min(1.,(1.710-z)/.023))
    lower=lower*lower*(3.-2.*lower)
    upper=upper*upper*(3.-2.*upper)
    front=max(0.,min(1.,(y-.018)/.055))
    mask=lower*upper*front
    cheek=math.exp(-((abs(x)-.064)/.033)**2-((z-1.656)/.038)**2)*mask
    jaw=math.exp(-((abs(x)-.070)/.040)**2-((z-1.615)/.027)**2)*mask
    chin=math.exp(-(x/.038)**4-((z-1.606)/.027)**2)*mask
    side=1. if x>=0 else -1.
    heavy=Vector((side*(.009*cheek+.005*jaw),.004*cheek+.002*chin,-.0015*chin))
    strength=.65 if female else 1.
    fit=Vector((side*.004*jaw*strength,-.0015*jaw*strength,0.))
    corrective=Vector((-side*.0015*jaw,-.001*chin,.0005*chin))
    return {'Heavy':heavy,'Fit':fit,'HeavyFit':corrective}


def add_head_body_shapes(obj, skin_only=True):
    female=active_preset().startswith('adult-female')
    skin=set()
    if skin_only:
        for face in obj.data.polygons:
            material=obj.data.materials[face.material_index]
            if material and material.name.split('.')[0]=='Skin':skin.update(face.vertices)
    else:skin=set(range(len(obj.data.vertices)))
    if obj.data.shape_keys is None:obj.shape_key_add(name='Basis')
    keys={name:obj.shape_key_add(name=name) for name in ['Heavy','Fit','HeavyFit']}
    for vertex in obj.data.vertices:
        deltas=displacement(vertex.co,female) if vertex.index in skin else {}
        for name,key in keys.items():
            key.data[vertex.index].co=vertex.co+deltas.get(name,Vector())
    print('HEAD BODY RESPONSE',obj.name,len(skin),'vertices')
