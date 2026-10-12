"""Validate independent native finger deformation for both anatomical frames."""
import bpy,math
from mathutils import Quaternion,Vector,Matrix
rig=bpy.data.objects['Rig']
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()

def snapshot(body):
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=evaluated.to_mesh()
    result=[v.co.copy() for v in mesh.vertices]
    evaluated.to_mesh_clear()
    return result

failures=[]
for name in ['Masculine_Body','Feminine_Body']:
    body=bpy.data.objects[name]
    for shape in ['Basis','Heavy','Fit','HeavyFit']:
        for key in body.data.shape_keys.key_blocks:
            if key.name!='Basis':key.value=1.0 if key.name==shape or (shape=='HeavyFit' and key.name in ['Heavy','Fit']) else 0.0
        bpy.context.view_layer.update()
        baseline=snapshot(body)
        for side in ['L','R']:
            for digit in range(1,6):
                names=[f'finger{digit}-{segment}.{side}' for segment in range(1,4)]
                assert all(label in rig.data.bones for label in names)
                ownership=[sum(body.data.attributes['NativeFinger_'+label].data[i].value for label in names) for i in range(len(body.data.vertices))]
                bone=rig.pose.bones[names[0]]
                bone.rotation_mode='QUATERNION'
                bone.rotation_quaternion=Quaternion(Vector((1,0,0)),.35)
                bpy.context.view_layer.update()
                changed=snapshot(body)
                moved=0;max_delta=0.
                for index,(a,b) in enumerate(zip(baseline,changed)):
                    delta=(a-b).length
                    max_delta=max(max_delta,delta)
                    if not all(math.isfinite(x) for x in b) or delta>.10:failures.append((name,shape,names[0],'unbounded deformation',index))
                    if delta>.00001:
                        moved+=1
                        if ownership[index]<.000001:failures.append((name,shape,names[0],'unrelated anatomy moved',index))
                if moved<100 or max_delta<.002:failures.append((name,shape,names[0],'finger did not articulate',moved,max_delta))
                print('FINGER',name,shape,names[0],moved,'vertices, max delta',round(max_delta,6),flush=True)
                bone.rotation_quaternion=Quaternion()
                bpy.context.view_layer.update()
print('NATIVE FINGER DEFORMATION CHECK:',len(failures),'failures',flush=True)
if failures:
    print(failures[:20],flush=True)
    raise RuntimeError('Finger deformation failed')
