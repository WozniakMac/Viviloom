"""Original sculpted character geometry for OpenSims, in metres, Z up.
The AI concept in assets/references/character-concept.png guides proportions.
No reference-game mesh or texture is used.
"""
import math
import bpy
from mathutils import Vector


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name + 'Mesh')
    data.from_pydata(verts, [], faces)
    data.update()
    for p in data.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def join(name, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


def ellipsoid(name, center, radii, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radii
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def stroke(name, points, radius, mat, taper=True):
    # Continuous tapered tube: no bead seams at the lips, brows or hair.
    verts, faces = [], []
    for i, point in enumerate(points):
        t = i / (len(points) - 1)
        r = radius * (0.22 + 0.78 * math.sin(math.pi*t)**0.35) if taper else radius
        tangent = Vector(points[min(i+1,len(points)-1)]) - Vector(points[max(0,i-1)])
        tangent.normalize()
        u = tangent.cross(Vector((0,1,0)))
        if u.length < 0.01:
            u = tangent.cross(Vector((1,0,0)))
        u.normalize()
        v = tangent.cross(u).normalized()
        for j in range(10):
            a = j * 2 * math.pi / 10
            verts.append(Vector(point) + r * (math.cos(a)*u + math.sin(a)*v))
        if i:
            for j in range(10):
                a = (i-1)*10+j
                b = (i-1)*10+(j+1)%10
                faces.append((a,b,b+10,a+10))
    faces.append(tuple(reversed(range(10))))
    faces.append(tuple((len(points)-1)*10+j for j in range(10)))
    return mesh(name,verts,faces,mat)


def gauss(x, z, cx, cz, wx, wz):
    return math.exp(-((x-cx)/wx)**2-((z-cz)/wz)**2)


# Cross sections define chin, jaw angle, cheekbones, brow and cranial vault.
PROFILE = [(1.548,.029,.025,.012),(1.566,.055,.060,.048),
 (1.590,.080,.080,.065),(1.620,.093,.092,.082),
 (1.655,.102,.095,.105),(1.687,.109,.098,.122),
 (1.713,.108,.103,.127),(1.744,.104,.108,.125),
 (1.774,.104,.104,.119),(1.800,.089,.089,.102),
 (1.823,.064,.064,.074),(1.837,.029,.028,.034),(1.842,.001,.001,.001)]


def front_surface(x,z,base):
    # Integrated bridge/tip/alar wings; recessed orbits and soft cheek planes.
    y = base
    y += .014*gauss(x,z,0,1.704,.017,.040)
    y += .024*gauss(x,z,0,1.676,.020,.016)
    y += .011*(gauss(x,z,.020,1.673,.011,.010)+gauss(x,z,-.020,1.673,.011,.010))
    y -= .014*(gauss(x,z,.044,1.711,.027,.018)+gauss(x,z,-.044,1.711,.027,.018))
    y += .012*(gauss(x,z,.063,1.682,.030,.018)+gauss(x,z,-.063,1.682,.030,.018))
    y += .012*gauss(x,z,0,1.630,.043,.022)
    y += .016*gauss(x,z,0,1.577,.043,.018)
    return y


def build_head(mats):
    verts, faces = [], []
    sections = []
    for k in range(len(PROFILE)-1):
        a,b=PROFILE[k],PROFILE[k+1]
        prev=PROFILE[max(0,k-1)]; nxt=PROFILE[min(len(PROFILE)-1,k+2)]
        for j in range(6):
            t=j/6
            sections.append(tuple(0.5*((2*a[n])+(-prev[n]+b[n])*t+(2*prev[n]-5*a[n]+4*b[n]-nxt[n])*t*t+(-prev[n]+3*a[n]-3*b[n]+nxt[n])*t*t*t) for n in range(4)))
    sections.append(PROFILE[-1])
    n=96
    for z,w,f,b in sections:
        for j in range(n):
            angle=2*math.pi*j/n
            x=w*math.sin(angle)
            c=math.cos(angle)
            y=f*c if c>=0 else b*c
            if c>0:
                y += (front_surface(x,z,f)-f)*c**4
            verts.append((x,y,z))
    for k in range(len(sections)-1):
        for j in range(n):
            a=k*n+j;b=k*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple((len(sections)-1)*n+j for j in range(n)))
    verts=[(x,y,z-.045*math.exp(-((z-1.25)/.25)**2)) for x,y,z in verts]
    head=mesh('Head',verts,faces,mats['Skin'])
    # Head rings run clockwise viewed from above: orient exterior normals.
    for p in head.data.polygons:
        p.flip()
    parts=[head]
    for sx in (-1,1):
        x=.044*sx
        parts.append(ellipsoid('EyeWhite',(x,.096,1.711),(.022,.013,.011),mats['EyeWhite']))
        parts.append(ellipsoid('Iris',(x,.108,1.711),(.009,.003,.0095),mats['Iris']))
        parts.append(ellipsoid('Pupil',(x,.111,1.711),(.0045,.0015,.0055),mats['Pupil']))
        parts.append(ellipsoid('Catchlight',(x-.003,.1125,1.715),(.002,.0007,.002),mats['EyeWhite']))
        for upper in (True,False):
            points=[]
            for j in range(25):
                u=-1+2*j/24
                points.append((x+.023*u,.096+.011*(1-u*u),1.711+(.011 if upper else -.008)*(1-u*u)+.001*u*sx))
            parts.append(stroke('Lid',points,.003,mats['Skin']))
        parts.append(ellipsoid('Ear',(.111*sx,-.005,1.692),(.017,.023,.038),mats['Skin']))
        parts.append(ellipsoid('EarFold',(.122*sx,.012,1.692),(.004,.009,.022),mats['Lips']))
        parts.append(ellipsoid('Nostril',(.015*sx,.121,1.666),(.005,.002,.0025),mats['Nostril']))
    return join('Head',parts)


def build_expressions(mats):
    from native_face_parts import build_brows
    return build_brows()



def build_hair(mats):
    from mathutils.bvhtree import BVHTree
    native=bpy.data.objects.get('Head')
    surface=BVHTree.FromPolygons([v.co for v in native.data.vertices], [tuple(p.vertices) for p in native.data.polygons])
    center=Vector((0,.035,1.710))
    def conform(point,offset=.005):
        direction=(Vector(point)-center).normalized()
        hit=surface.ray_cast(center,direction)[0]
        return hit+direction*offset if hit is not None else Vector(point)
    out=[]
    for style in ['Short','Long','Bun','Ponytail','Buzz','Curly','Bob']:
        verts,faces=[],[]
        n=96;rings=28
        for k in range(rings):
            t=k/(rings-1)
            for j in range(n):
                a=2*math.pi*j/n
                front=max(0,math.cos(a))
                edge=(1.740+.045*front**2) if math.cos(a)>=0 else (1.740+.075*math.cos(a))
                if style=='Bob':edge=1.59+.195*front**4
                limit=math.acos(max(-1,min(1,(edge-1.697)/.148)))
                phi=.002+t*limit
                wave=(.0007 if style=='Buzz' else .0015)*math.sin(a*18+phi*7)*math.sin(phi)
                rx=.108 if style=='Buzz' else .116
                ry=.128 if style=='Buzz' else .139
                verts.append(((rx+wave)*math.sin(phi)*math.sin(a),.026+(ry+wave)*math.sin(phi)*math.cos(a),1.697+(.145 if style=='Buzz' else .151)*math.cos(phi)))
        for k in range(rings-1):
            for j in range(n):
                a=k*n+j;b=k*n+(j+1)%n
                faces.append((a,a+n,b+n,b))
        base=mesh('Hair_'+style,verts,faces,mats['Hair'])
        for polygon in base.data.polygons:
            polygon.flip()
        for vertex in base.data.vertices:
            vertex.co=conform(vertex.co)
        base.data.update()
        parts=[base]
        if style not in ['Buzz','Curly']:
            # Swept overlapping locks follow the cranium rather than a helmet.
            for j in range(17):
                a=-1.25+j*.16
                points=[]
                for k in range(24):
                    t=k/23
                    phi=.22+.90*t
                    az=a+.40*(1-t)
                    points.append((.118*math.sin(phi)*math.sin(az),.026+.142*math.sin(phi)*math.cos(az),1.697+.153*math.cos(phi)))
                parts.append(stroke('Lock',[conform(p,.008) for p in points],.003,mats['Hair']))
        if style=='Long':
            for sx in (-1,1):
                for j in range(7):
                    a=1.1+j*.20
                    points=[]
                    for k in range(28):
                        t=k/27
                        points.append((sx*(.113*math.sin(a)+.014*math.sin(t*5+j*.3)),-.04+.09*math.cos(a),1.73-.30*t))
                    parts.append(stroke('LongLock',points,.014,mats['Hair']))
        if style in ['Bun','Ponytail']:
            parts.append(ellipsoid('Tie',(0,-.136,1.77),(.032,.020,.025),mats['Hair']))
            if style=='Bun':
                parts.append(ellipsoid('Knot',(0,-.143,1.805),(.051,.047,.047),mats['Hair']))
            else:
                for j in range(7):
                    points=[((j-3)*.009,-.149-.037*math.sin(t*math.pi),1.775-.27*t) for t in [k/24 for k in range(25)]]
                    parts.append(stroke('Tail',points,.010,mats['Hair']))
        if style=='Curly':
            for j in range(60):
                a=j*2.39996; z=1.70+.18*(j/59)
                r=.13*math.sqrt(max(0,1-((z-1.72)/.17)**2))
                if r*math.cos(a) > .03 and z < 1.78:
                    continue
                parts.append(ellipsoid('Curl',(r*math.sin(a),-.01+r*math.cos(a),z),(.026,.028,.024),mats['Hair']))
        out.append(join('Hair_'+style,parts))
    return out


def build_hands(mats,rig):
    for sx,side in [(1,'L'),(-1,'R')]:
        parts=[ellipsoid('Palm',(.267*sx,.014, .812),(.027,.021,.039),mats['Skin'])]
        for j,length in enumerate([.060,.069,.064,.049]):
            x=(.247+j*.013)*sx
            points=[(x,.014,.803),(x+sx*.002,.019,.778),(x+sx*.003,.028,.803-length)]
            parts.append(stroke('Finger',points,.006,mats['Skin'],False))
        parts.append(stroke('Thumb',[(.247*sx,.017,.827),(.232*sx,.023,.808),(.228*sx,.032,.787)],.008,mats['Skin'],False))
        hand=join('Hand_'+side,parts)
        vg=hand.vertex_groups.new(name='hand.'+side)
        vg.add(list(range(len(hand.data.vertices))),1.0,'REPLACE')
        hand.parent=rig
        modifier=hand.modifiers.new('Armature','ARMATURE');modifier.object=rig

def build_makehuman_head(mats):
    """Use the CC0 anatomical mesh; retain only body faces above the neck."""
    from pathlib import Path
    source=Path(__file__).resolve().parent.parent/'assets/source/makehuman/base.obj'
    from anny_source import load_raw_points
    anny_points=load_raw_points()
    positions=[];polys=[];uvs=[];polys_uv=[];group=''
    for line in source.read_text().splitlines():
        if line.startswith('v '):
            positions.append(tuple(anny_points[len(positions)]) if anny_points is not None else tuple(map(float,line.split()[1:4])))
        elif line.startswith('vt '):
            uvs.append(tuple(map(float,line.split()[1:3])))
        elif line.startswith('g '):
            group=line[2:].strip()
        elif line.startswith('f ') and group=='body':
            ids=[int(token.split('/')[0])-1 for token in line.split()[1:]]
            if all(positions[i][1]>5.0 for i in ids):
                polys.append(ids)
                polys_uv.append([int(token.split('/')[1])-1 for token in line.split()[1:]])
    used=sorted({v for poly in polys for v in poly});indices={v:i for i,v in enumerate(used)}
    verts=[(positions[i][0]*.11,positions[i][2]*.11,(positions[i][1]+8.1676)*.11) for i in used]
    verts=[(x,y,z-.045*math.exp(-((z-1.25)/.25)**2)) for x,y,z in verts]
    head=mesh('Head',verts,[tuple(indices[v] for v in face) for face in polys],mats['Skin'])
    from facial_shapes import add_action_attributes
    add_action_attributes(head,used)
    uv_layer=head.data.uv_layers.new(name='MakeHumanUV')
    for polygon,uv_ids in zip(head.data.polygons,polys_uv):
        for loop_index,uv_index in zip(polygon.loop_indices,uv_ids):
            uv_layer.data[loop_index].uv=uvs[uv_index]
    # Smooth the anatomical base without losing the native eyelid and ear loops.
    bpy.context.view_layer.objects.active=head
    head.select_set(True)
    sub=head.modifiers.new('Face refinement','SUBSURF');sub.levels=1
    bpy.ops.object.modifier_apply(modifier=sub.name)
    # Close the cut neck on a horizontal plane below the clothing collar.
    bm=__import__('bmesh').new();bm.from_mesh(head.data)
    __import__('bmesh').ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,1.565),plane_no=(0,0,1),clear_inner=True,dist=.00001)
    bm.to_mesh(head.data);bm.free()
    from native_eyes import build_native_eyes
    from native_face_parts import build_lashes
    oral=bpy.data.materials.new('OralCavity');oral.diffuse_color=(.08,.018,.020,1)
    oral.use_nodes=True
    oral.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.08,.018,.020,1)
    oral.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
    cavity=ellipsoid('OralCavity',(0,.094,1.647),(.048,.010,.023),oral)
    parts=[head,build_native_eyes(),build_lashes(),cavity]
    return join('Head',parts)

# Anatomical base supersedes the procedural prototype above.
build_head = build_makehuman_head



