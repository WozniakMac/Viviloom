"""Validate the deformation regressions found in the anatomical model.
Run Blender in background with the saved character.blend and this script.
"""
import bpy
import math
body=bpy.data.objects['Body']
region=body.data.attributes['AnatomicalArm']
names={group.index:group.name for group in body.vertex_groups}
errors=[]
for vertex in body.data.vertices:
    weights={names[g.group]:g.weight for g in vertex.groups if g.weight>0.00001}
    if not weights or not math.isclose(sum(weights.values()),1.0,abs_tol=0.0001):
        errors.append(('normalization',vertex.index))
    opposite='.R' if vertex.co.x>0 else '.L'
    if any(name.endswith(opposite) for name in weights):
        errors.append(('opposite limb',vertex.index))
    value=region.data[vertex.index].value
    non_arm=sum(weight for name,weight in weights.items() if not name.startswith(('upperarm.','forearm.','hand.')))
    if value>=.5 and non_arm > 1-value+.001:
        errors.append(('arm bound to torso/leg',vertex.index))
    hand=body.data.attributes['AnatomicalHand'].data[vertex.index].value
    if hand>=.999 and sum(weight for name,weight in weights.items() if not name.startswith('hand.')) > 1-hand+.001:
        errors.append(('hand bound outside hand bone',vertex.index))
    if value<=.001 and vertex.co.z<.7 and any(name.startswith(('upperarm.','forearm.','hand.')) for name in weights):
        errors.append(('leg bound to arm',vertex.index))
for polygon in body.data.polygons:
    hand=sum(body.data.attributes['AnatomicalHand'].data[i].value for i in polygon.vertices)/len(polygon.vertices)
    if hand>.25 and body.data.materials[polygon.material_index].name!='Skin':
        errors.append(('hand hidden by clothing mask',polygon.index))
print('ANATOMICAL BINDING CHECK:',len(body.data.vertices),'vertices,',len(errors),'errors')
if errors:
    print(errors[:20])
    raise RuntimeError('Anatomical binding verification failed')
