"""Fit CC0 .mhclo barycentric geometry to the active Anny base, retaining UVs."""
import math
from mathutils import Vector
from anatomical_body import read_base

def load_bound_geometry(folder,asset,source_points=None,head=True):
    points=source_points if source_points is not None else read_base()[0]
    bindings=[];scale={'x':1.,'y':1.,'z':1.};reading=False;obj_file=asset+'.obj'
    for line in (folder/(asset+'.mhclo')).read_text().splitlines():
        tokens=line.split()
        if not tokens or tokens[0].startswith('#'):continue
        if tokens[0]=='obj_file':obj_file=tokens[1]
        if tokens[0] in ['x_scale','y_scale','z_scale']:
            axis=tokens[0][0];component={'x':0,'y':2,'z':1}[axis]
            scale[axis]=abs(points[int(tokens[1])][component]-points[int(tokens[2])][component])/(.11*float(tokens[3]))
        elif tokens[0]=='verts':reading=True
        elif tokens[0]=='delete_verts':break
        elif reading and tokens[0][0].isdigit():
            if len(tokens)==1:p=points[int(tokens[0])].copy()
            elif len(tokens)>=9:
                ids=list(map(int,tokens[:3]));weights=list(map(float,tokens[3:6]));delta=list(map(float,tokens[6:9]))
                p=sum((points[i]*w/sum(weights) for i,w in zip(ids,weights)),Vector())
                p+=Vector((delta[0]*scale['x']*.11,delta[2]*scale['z']*.11,delta[1]*scale['y']*.11))
            else:continue
            if head:p.z-=.045*math.exp(-((p.z-1.25)/.25)**2)
            bindings.append(p)
    faces=[];uvs=[];face_uvs=[];count=0
    for line in (folder/obj_file).read_text().splitlines():
        if line.startswith('v '):count+=1
        elif line.startswith('vt '):uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith('f '):
            tokens=[token.split('/') for token in line.split()[1:]]
            faces.append(tuple(int(token[0])-1 for token in tokens));face_uvs.append([int(token[1])-1 for token in tokens])
    if count!=len(bindings):raise ValueError('Hair binding count mismatch: '+asset)
    return bindings,faces,uvs,face_uvs
