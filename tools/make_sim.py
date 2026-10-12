"""Builds the OpenSims character in Blender and exports it to assets/sim/sim.glb.

Run:  blender --background --python tools/make_sim.py

Native Anny/MakeHuman anatomy and CC0 garments are fitted to the game skeleton,
with region-aware skin weights, native body morphs, facial actions and textured
hair. AI-generated clothing detail and the editable Blender source are retained.
Material names let each Sim have independent palette colors.

Blender is Z-up with the character facing +Y; the glTF exporter turns that into
Y-up facing -Z, which is the game's "forward".
"""
import math
import os
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sim", "sim.glb")
FPS = 30


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def material(name, color, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


# --- skeleton points (metres, Z up, facing +Y) -------------------------------------
J = {
    "pelvis": (0, 0, 0.95), "spine": (0, 0, 1.12), "chest": (0, 0, 1.3), "neck": (0, 0, 1.5),
    "head": (0, 0, 1.58),
}
for side, sx in (("L", 1), ("R", -1)):
    J["hip." + side] = (0.095 * sx, 0, 0.9)
    J["knee." + side] = (0.1 * sx, 0.015, 0.5)
    J["ankle." + side] = (0.1 * sx, 0, 0.09)
    J["toe." + side] = (0.1 * sx, 0.13, 0.04)
    J["shoulder." + side] = (0.205 * sx, 0, 1.4)
    J["elbow." + side] = (0.245 * sx, -0.01, 1.12)
    J["wrist." + side] = (0.265 * sx, 0.01, 0.86)
    J["hand." + side] = (0.267 * sx, 0.015, 0.81)

# (from, to, radius at from, radius at to) for the skin modifier body.
LINKS = [
    ("pelvis", "spine", 0.155, 0.14), ("spine", "chest", 0.14, 0.17), ("chest", "neck", 0.17, 0.058),
    ("neck", "head", 0.058, 0.052),
]
for s in ("L", "R"):
    LINKS += [
        ("pelvis", "hip." + s, 0.155, 0.092), ("hip." + s, "knee." + s, 0.092, 0.062),
        ("knee." + s, "ankle." + s, 0.06, 0.042), ("ankle." + s, "toe." + s, 0.045, 0.035),
        ("chest", "shoulder." + s, 0.14, 0.062), ("shoulder." + s, "elbow." + s, 0.062, 0.047),
        ("elbow." + s, "wrist." + s, 0.046, 0.034), ("wrist." + s, "hand." + s, 0.042, 0.03),
    ]


# Body shapes for the Create a Sim sliders: radius multipliers per joint.
SHAPES = {
    "Heavy": {"pelvis": 1.35, "spine": 1.45, "chest": 1.25, "hip": 1.3, "knee": 1.2, "ankle": 1.05,
              "shoulder": 1.2, "elbow": 1.2, "wrist": 1.05, "neck": 1.15},
    "Fit": {"chest": 1.15, "shoulder": 1.3, "elbow": 1.25, "wrist": 1.05, "spine": 0.92, "pelvis": 0.95,
            "hip": 1.1, "knee": 1.12, "neck": 1.1},
}


def build_body():
    names = list(J.keys())
    index = {n: i for i, n in enumerate(names)}
    mesh = bpy.data.meshes.new("BodyMesh")
    edges = [(index[a], index[b]) for a, b, _, _ in LINKS if a in index and b in index]
    mesh.from_pydata([J[n] for n in names], edges, [])
    obj = bpy.data.objects.new("Body", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    skin = obj.modifiers.new("Skin", "SKIN")
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 3
    radii = {}
    for a, b, ra, rb in LINKS:
        radii[a] = max(radii.get(a, 0), ra)
        radii[b] = max(radii.get(b, 0), rb)
    for n, i in index.items():
        r = radii.get(n, 0.04)
        sv = mesh.skin_vertices[0].data[i]
        # Torso is wider than deep.
        if n in ("pelvis", "spine", "chest"):
            sv.radius = (r * 1.05, r * 0.72)
        else:
            sv.radius = (r, r)
    mesh.skin_vertices[0].data[index["pelvis"]].use_root = True
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    # Cut horizontal clothing seams into topology before shape keys and rigging.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for height in (0.12, 0.5, 0.93, 1.12, 1.445):
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                              plane_co=(0,0,height), plane_no=(0,0,1), dist=0.00001)
    bm.to_mesh(obj.data)
    bm.free()
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def _closest_on_links(p):
    best = None
    for a, b, _, _ in LINKS:
        pa, pb = Vector(J[a]), Vector(J[b])
        ab = pb - pa
        t = max(0.0, min(1.0, (p - pa).dot(ab) / max(ab.length_squared, 1e-9)))
        q = pa + ab * t
        d = (p - q).length
        if best is None or d < best[0]:
            best = (d, a, b, t, q)
    return best


def add_shape_keys(body):
    """Stores each slider's proportions as a shape key: every vertex is pushed
    away from (or towards) its nearest bone by that joint's radius multiplier."""
    body.shape_key_add(name="Basis")
    for name, mults in SHAPES.items():
        key = body.shape_key_add(name=name)
        for i, v in enumerate(body.data.vertices):
            _, a, b, t, q = _closest_on_links(v.co)
            ka = mults.get(a.split(".")[0], 1.0)
            kb = mults.get(b.split(".")[0], 1.0)
            k = ka + (kb - ka) * t
            key.data[i].co = q + (v.co - q) * k


def assign_body_materials(obj, mats):
    """Colours each face by the bone that moves it most (after rigging): short
    sleeves, bare forearms and hands, trousers below the waist, shoes on the feet."""
    for m in ("Skin", "Shirt", "Pants", "Shoes", "Sleeve", "Shin"):
        obj.data.materials.append(mats[m])
    order = {"Skin": 0, "Shirt": 1, "Pants": 2, "Shoes": 3, "Sleeve": 4, "Shin": 5}
    names = {g.index: g.name for g in obj.vertex_groups}
    arms=[item.value for item in obj.data.attributes['AnatomicalArm'].data]
    hands=[item.value for item in obj.data.attributes['AnatomicalHand'].data]
    for poly in obj.data.polygons:
        weights = {}
        for vi in poly.vertices:
            for g in obj.data.vertices[vi].groups:
                n = names.get(g.group, "")
                weights[n] = weights.get(n, 0.0) + g.weight
        bone = max(weights, key=weights.get) if weights else "spine"
        c = obj.matrix_world @ poly.center
        arm=sum(arms[i] for i in poly.vertices)/len(poly.vertices)
        hand=sum(hands[i] for i in poly.vertices)/len(poly.vertices)
        if hand>.25:
            slot='Skin'
        elif arm>.5:
            slot='Skin' if c.z<.86 else 'Sleeve' if c.z<1.12 else 'Shirt'
        elif c.z < 0.12:
            slot = "Shoes"
        elif c.z < 0.5 and abs(c.x) < 0.2:
            slot = "Shin"
        elif c.z < 0.93 and abs(c.x) < 0.2:
            slot = "Pants"
        elif abs(c.x) > 0.19 and c.z < 1.12:
            slot = "Sleeve" if c.z > 0.86 else "Skin"
        elif c.z > 1.51 or (c.z > 1.445 and abs(c.x) < .09):
            slot = "Skin"
        else:
            slot = "Shirt"
        poly.material_index = order[slot]


def sphere(name, loc, scale, mat, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat)
    return o


def build_head(mats):
    parts = []
    head = sphere("Head", (0, 0.0, 1.69), (0.118, 0.125, 0.142), mats["Skin"], 32, 20)
    parts.append(head)
    for sx in (1, -1):
        parts.append(sphere("EyeWhite", (0.045 * sx, 0.103, 1.705), (0.022, 0.012, 0.016), mats["EyeWhite"], 16, 10))
        parts.append(sphere("Pupil", (0.045 * sx, 0.113, 1.705), (0.011, 0.006, 0.012), mats["Pupil"], 12, 8))
        parts.append(sphere("Ear", (0.112 * sx, 0.0, 1.69), (0.022, 0.032, 0.04), mats["Skin"], 12, 8))
    parts.append(sphere("Nose", (0, 0.122, 1.675), (0.017, 0.022, 0.024), mats["Skin"], 12, 8))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()
    return head


def _dots(name, points, scale, mat):
    """A curved stroke made of small overlapping spheres, joined into one mesh."""
    objs = [sphere(name, p, scale, mat, 10, 6) for p in points]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def build_expressions(mats):
    """Separate mouths and brows the game swaps to show emotion."""
    out = []
    y_mouth = 0.108
    def arc(half, curve, z0):
        pts = []
        for k in range(-8, 9):
            u = k / 8.0
            pts.append((u * half, y_mouth - 0.004 * u * u, z0 + curve * u * u))
        return pts
    out.append(_dots("Mouth_Neutral", arc(0.026, 0.0, 1.628), (0.007, 0.006, 0.0055), mats["Lips"]))
    out.append(_dots("Mouth_Smile", arc(0.034, 0.012, 1.621), (0.007, 0.006, 0.0055), mats["Lips"]))
    out.append(_dots("Mouth_Frown", arc(0.027, -0.009, 1.632), (0.007, 0.006, 0.0055), mats["Lips"]))
    for name, tilt, lift in (("Brows_Neutral", 0.0, 0.0), ("Brows_Angry", -0.012, -0.004), ("Brows_Sad", 0.012, 0.002)):
        pts = []
        for sx in (1, -1):
            for k in range(9):
                x = 0.03 + k * 0.004
                # Tilt raises or lowers the inner ends (angry: inner ends down).
                z = 1.74 + lift + tilt * (1.0 - k / 8.0)
                pts.append((x * sx, 0.104 + 0.001 * (4 - abs(k - 4)), z))
        out.append(_dots(name, pts, (0.006, 0.006, 0.0045), mats["Hair"]))
    return out


def cut_below(obj, z_cut, keep_back_below=None, front=1.762):
    """Shapes a hairline: cut at `front` over the forehead, `z_cut` at the sides,
    and down to `keep_back_below` at the back of the head."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    kill = []
    for v in bm.verts:
        w = obj.matrix_world @ v.co
        if w.y > 0.05:
            limit = front - (0.012 if abs(w.x) > 0.06 else 0.0)
        elif w.y < -0.02 and keep_back_below is not None:
            limit = keep_back_below
        else:
            limit = z_cut
        if w.z < limit:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def build_hair(mats):
    styles = []
    short = sphere("Hair_Short", (0, -0.008, 1.705), (0.128, 0.136, 0.146), mats["Hair"], 32, 20)
    cut_below(short, 1.69, keep_back_below=1.6)
    styles.append(short)

    long = sphere("Hair_Long", (0, -0.01, 1.705), (0.132, 0.14, 0.15), mats["Hair"], 32, 20)
    cut_below(long, 1.69, keep_back_below=1.6)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1.0, depth=1.0, location=(0, -0.045, 1.55))
    back = bpy.context.active_object
    back.scale = (0.125, 0.09, 0.2)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    back.data.materials.append(mats["Hair"])
    bpy.ops.object.select_all(action="DESELECT")
    long.select_set(True)
    back.select_set(True)
    bpy.context.view_layer.objects.active = long
    bpy.ops.object.join()
    styles.append(long)

    bun = sphere("Hair_Bun", (0, -0.008, 1.705), (0.126, 0.134, 0.144), mats["Hair"], 32, 20)
    cut_below(bun, 1.7, keep_back_below=1.63)
    knot = sphere("Knot", (0, -0.1, 1.8), (0.06, 0.06, 0.06), mats["Hair"], 16, 10)
    bpy.ops.object.select_all(action="DESELECT")
    bun.select_set(True)
    knot.select_set(True)
    bpy.context.view_layer.objects.active = bun
    bpy.ops.object.join()
    styles.append(bun)

    def join_into(base, others):
        bpy.ops.object.select_all(action="DESELECT")
        base.select_set(True)
        for o in others:
            o.select_set(True)
        bpy.context.view_layer.objects.active = base
        bpy.ops.object.join()
        return base

    pony = sphere("Hair_Ponytail", (0, -0.008, 1.705), (0.127, 0.135, 0.145), mats["Hair"], 32, 20)
    cut_below(pony, 1.7, keep_back_below=1.63)
    tie = sphere("Tie", (0, -0.13, 1.74), (0.035, 0.035, 0.035), mats["Hair"], 12, 8)
    tail = sphere("Tail", (0, -0.17, 1.62), (0.04, 0.045, 0.13), mats["Hair"], 16, 10)
    styles.append(join_into(pony, [tie, tail]))

    buzz = sphere("Hair_Buzz", (0, -0.004, 1.698), (0.121, 0.129, 0.143), mats["Hair"], 32, 20)
    cut_below(buzz, 1.7, keep_back_below=1.62, front=1.775)
    styles.append(buzz)

    curly = sphere("Hair_Curly", (0, -0.015, 1.73), (0.16, 0.165, 0.165), mats["Hair"], 32, 20)
    cut_below(curly, 1.69, keep_back_below=1.58, front=1.765)
    curls = []
    for k in range(10):
        a = k * 0.63
        curls.append(sphere("Curl", (math.cos(a) * 0.13, -0.02 + math.sin(a) * 0.12, 1.78 + 0.04 * math.sin(k * 1.7)), (0.055, 0.055, 0.055), mats["Hair"], 10, 8))
    styles.append(join_into(curly, curls))

    bob = sphere("Hair_Bob", (0, -0.01, 1.705), (0.135, 0.142, 0.15), mats["Hair"], 32, 20)
    cut_below(bob, 1.62, keep_back_below=1.6)
    styles.append(bob)
    return styles


def build_skirt(mats):
    """An A-line skirt from the waist to the knee (shown instead of trousers)."""
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.24, radius2=0.155, depth=0.42, location=(0, 0, 0.72), end_fill_type="NOTHING")
    o = bpy.context.active_object
    o.name = "Skirt"
    o.scale = (1.0, 0.82, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    m = o.modifiers.new("Solid", "SOLIDIFY")
    m.thickness = 0.01
    bpy.ops.object.modifier_apply(modifier="Solid")
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mats["Pants"])
    return o


# --- armature ---------------------------------------------------------------------
BONES = [
    # name, head joint, tail joint, parent
    ("hips", "pelvis", "spine", None),
    ("spine", "spine", "chest", "hips"),
    ("chest", "chest", "neck", "spine"),
    ("neck", "neck", "head", "chest"),
    ("head", "head", None, "neck"),
]
for s in ("L", "R"):
    BONES += [
        ("thigh." + s, "hip." + s, "knee." + s, "hips"),
        ("shin." + s, "knee." + s, "ankle." + s, "thigh." + s),
        ("foot." + s, "ankle." + s, "toe." + s, "shin." + s),
        ("upperarm." + s, "shoulder." + s, "elbow." + s, "chest"),
        ("forearm." + s, "elbow." + s, "wrist." + s, "upperarm." + s),
        ("hand." + s, "wrist." + s, "hand." + s, "forearm." + s),
    ]


def build_armature():
    arm_data = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for name, a, b, parent in BONES:
        bone = eb.new(name)
        bone.head = Vector(J[a])
        bone.tail = Vector(J[b]) if b else Vector(J[a]) + Vector((0, 0, 0.22))
        if name.startswith("hand."):
            bone.tail = Vector(J["hand." + name[-1]]) + Vector((0, 0, -0.06))
        if parent:
            bone.parent = eb[parent]
            bone.use_connect = False
        # Consistent rolls so +X rotation bends limbs the same way on both sides.
        bone.roll = 0.0
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin_to_rig(rig, body, rigid):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    from anatomical_weights import bind_body
    bind_body(body, rig)
    # The shared neck boundary must follow exactly the same bone as the head.
    head_group = body.vertex_groups.get('head') or body.vertex_groups.new(name='head')
    for vertex in body.data.vertices:
        if vertex.co.z <= 1.49:
            continue
        blend = min(1.0, (vertex.co.z - 1.49) / .045)
        previous = {group.group: group.weight for group in vertex.groups}
        for group in body.vertex_groups:
            group.remove([vertex.index])
        for index, weight in previous.items():
            if index != head_group.index and weight * (1-blend) > 0:
                body.vertex_groups[index].add([vertex.index], weight * (1-blend), 'REPLACE')
        head_group.add([vertex.index], blend + previous.get(head_group.index, 0) * (1-blend), 'REPLACE')
    # Head and hair follow the head bone only; the skirt follows the hips.
    for o in rigid:
        bone = "hips" if o.name == "Skirt" else "head"
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_NAME")
        vg = o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone)
        vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")


# --- animation --------------------------------------------------------------------
def deg(x):
    return math.radians(x)


def make_action(rig, name, frames, poses):
    """poses: {frame: {bone: (rx, ry, rz) degrees, "hips_loc": (x, y, z)}}"""
    action = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = action
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    for frame, pose in sorted(poses.items()):
        for pb in rig.pose.bones:
            r = pose.get(pb.name, (0, 0, 0))
            # Poses are written with +X meaning "bend forward"; with these bone rolls
            # that is a negative rotation, so X is flipped here.
            pb.rotation_euler = (deg(-r[0]), deg(r[1]), deg(r[2]))
            pb.keyframe_insert("rotation_euler", frame=frame)
            loc = pose.get("hips_loc", (0, 0, 0)) if pb.name == "hips" else (0, 0, 0)
            pb.location = loc
            pb.keyframe_insert("location", frame=frame)
    action.frame_range = (1, frames)
    for fc in action.fcurves if hasattr(action, "fcurves") else []:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    rig.animation_data.action = None
    return action


def mirror(pose):
    """Copies .L rotations to .R with Y/Z mirrored."""
    out = dict(pose)
    for k, v in pose.items():
        if k.endswith(".L") and k[:-2] + ".R" not in pose:
            out[k[:-2] + ".R"] = (v[0], -v[1], -v[2])
    return out


ARMS_DOWN = {"upperarm.L": (0, 0, 4), "upperarm.R": (0, 0, -4)}


def animations(rig):
    # Idle: gentle breathing and weight shift.
    idle = {}
    for f, t in ((1, 0.0), (31, 1.0), (61, 0.0)):
        p = dict(ARMS_DOWN)
        p.update({"spine": (1.5 * t, 0, 0), "chest": (1.5 * t, 0, 0), "head": (-2 * t, 3 * t, 0),
                  "upperarm.L": (2 * t, 0, 4), "upperarm.R": (-2 * t, 0, -4), "hips_loc": (0, 0.0, 0.004 * t)})
        idle[f] = p
    make_action(rig, "idle", 61, idle)

    # Walk: one full stride in 30 frames.
    walk = {}
    for f in range(1, 32, 5):
        ph = (f - 1) / 30.0 * 2 * math.pi
        s = math.sin(ph)
        knee_l = max(0.0, -math.sin(ph + 0.6)) * 45
        knee_r = max(0.0, math.sin(ph + 0.6)) * 45
        walk[f] = {
            "thigh.L": (-28 * s, 0, 0), "thigh.R": (28 * s, 0, 0),
            "shin.L": (knee_l, 0, 0), "shin.R": (knee_r, 0, 0),
            "foot.L": (8 * s, 0, 0), "foot.R": (-8 * s, 0, 0),
            "upperarm.L": (22 * s, 0, 5), "upperarm.R": (-22 * s, 0, -5),
            "forearm.L": (-12 - 8 * s, 0, 0), "forearm.R": (-12 + 8 * s, 0, 0),
            "spine": (3, 4 * s, 0), "chest": (0, -6 * s, 0),
            "hips_loc": (0, abs(math.cos(ph)) * 0.025, 0),
        }
    make_action(rig, "walk", 31, walk)

    # Sit: hips and knees at right angles, hands on lap.
    def sit_pose(t=0.0):
        return {
            "thigh.L": (-88, 0, 0), "thigh.R": (-88, 0, 0), "shin.L": (88, 0, 0), "shin.R": (88, 0, 0),
            "upperarm.L": (-25, 0, 6), "upperarm.R": (-25, 0, -6), "forearm.L": (-45, 0, 0), "forearm.R": (-45, 0, 0),
            "spine": (2 * t, 0, 0), "head": (-3 * t, 0, 0),
        }
    make_action(rig, "sit", 61, {1: sit_pose(0), 31: sit_pose(1), 61: sit_pose(0)})

    # Sit and type/eat: forearms forward, hands moving.
    sit_use = {}
    for f in range(1, 32, 5):
        s = math.sin((f - 1) / 30.0 * 2 * math.pi * 2)
        p = sit_pose()
        p.update({"upperarm.L": (-40, 0, 8), "upperarm.R": (-40, 0, -8), "forearm.L": (-55 + 6 * s, 0, 0), "forearm.R": (-55 - 6 * s, 0, 0),
                  "head": (8, 0, 0)})
        sit_use[f] = p
    make_action(rig, "sit_use", 31, sit_use)

    # Lie: straight with arms by the side (the game lays the whole body down).
    lie = {}
    for f, t in ((1, 0), (46, 1), (91, 0)):
        lie[f] = {"chest": (2 * t, 0, 0), "upperarm.L": (0, 0, 8), "upperarm.R": (0, 0, -8), "head": (-4, 6, 0)}
    make_action(rig, "lie", 91, lie)

    # Talk: animated hand gestures and nods.
    talk = {}
    for f, t in ((1, 0.0), (16, 1.0), (31, 0.3), (46, 0.9), (61, 0.0)):
        talk[f] = {
            "upperarm.L": (-20 * t, 0, 10), "upperarm.R": (-35 * (1 - t) - 10, 0, -10),
            "forearm.L": (-50 * t - 10, 0, 0), "forearm.R": (-60 * (1 - t) - 20, 0, 0),
            "head": (5 * t - 2, 6 * (t - 0.5), 0), "chest": (0, 4 * (t - 0.5), 0),
        }
    make_action(rig, "talk", 61, talk)

    # Use: working with both hands at a counter or easel.
    use = {}
    for f in range(1, 32, 5):
        s = math.sin((f - 1) / 30.0 * 2 * math.pi)
        use[f] = {
            "upperarm.L": (-45 + 8 * s, 0, 8), "upperarm.R": (-50 - 8 * s, 0, -8),
            "forearm.L": (-45, 0, 0), "forearm.R": (-40 + 10 * s, 0, 0),
            "head": (10, 0, 0), "spine": (4, 0, 0),
        }
    make_action(rig, "use", 31, use)

    # Dance: bouncing knees, swaying hips and arms pumping to the beat.
    dance = {}
    for f in range(1, 62, 5):
        ph = (f - 1) / 60.0 * 2 * math.pi * 2
        s1 = math.sin(ph)
        s2 = math.sin(ph * 0.5)
        dance[f] = {
            "thigh.L": (-15 - 10 * max(0, s1), 0, 0), "thigh.R": (-15 - 10 * max(0, -s1), 0, 0),
            "shin.L": (25 + 15 * max(0, s1), 0, 0), "shin.R": (25 + 15 * max(0, -s1), 0, 0),
            "spine": (5, 12 * s2, 6 * s1), "chest": (0, -8 * s2, 0),
            "upperarm.L": (-60 - 40 * max(0, s1), 0, 25), "upperarm.R": (-60 - 40 * max(0, -s1), 0, -25),
            "forearm.L": (-70, 0, 0), "forearm.R": (-70, 0, 0),
            "head": (-5 + 8 * s1, 10 * s2, 0),
            "hips_loc": (0.04 * s2, -0.06 + 0.03 * abs(s1), 0),
        }
    make_action(rig, "dance", 61, dance)

    # Wave: a friendly greeting with the right hand.
    wave = {}
    for f in range(1, 32, 5):
        s1 = math.sin((f - 1) / 30.0 * 2 * math.pi * 2)
        wave[f] = {"upperarm.R": (-160, 0, -20), "forearm.R": (-20 + 25 * s1, 0, 0), "head": (-5, 8, 0),
                   "upperarm.L": (0, 0, 4)}
    make_action(rig, "wave", 31, wave)

    # Mood idles: body language for the current emotion.
    def mood_idle(name, base, sway):
        poses = {}
        for f, t in ((1, 0.0), (21, 1.0), (41, 0.0), (61, -1.0), (81, 0.0)):
            p = dict(base)
            for bone, amt in sway.items():
                r = p.get(bone, (0, 0, 0))
                p[bone] = (r[0] + amt[0] * t, r[1] + amt[1] * t, r[2] + amt[2] * t)
            poses[f] = p
        make_action(rig, name, 81, poses)

    mood_idle("idle_sad",
        {"spine": (12, 0, 0), "chest": (8, 0, 0), "neck": (10, 0, 0), "head": (22, 0, 0),
         "upperarm.L": (6, 0, 2), "upperarm.R": (6, 0, -2), "hips_loc": (0, -0.02, 0)},
        {"head": (3, 4, 0), "chest": (2, 0, 0)})
    mood_idle("idle_angry",
        {"chest": (-4, 0, 0), "head": (6, 0, 0), "upperarm.L": (-35, 0, 20), "upperarm.R": (-35, 0, -20),
         "forearm.L": (-110, 0, 0), "forearm.R": (-110, 0, 0)},
        {"head": (0, 10, 0), "spine": (0, 6, 0)})
    mood_idle("idle_happy",
        {"chest": (-4, 0, 0), "head": (-8, 0, 0), "upperarm.L": (-8, 0, 10), "upperarm.R": (-8, 0, -10)},
        {"spine": (0, 0, 5), "head": (0, 0, 8), "hips_loc": (0, 0.02, 0)})
    mood_idle("idle_tense",
        {"chest": (6, 0, 0), "head": (4, 0, 0), "upperarm.L": (-25, 0, 4), "upperarm.R": (-25, 0, -4),
         "forearm.L": (-60, 0, 0), "forearm.R": (-60, 0, 0)},
        {"head": (0, 18, 0), "forearm.L": (-15, 0, 0), "forearm.R": (15, 0, 0)})
    mood_idle("idle_flirty",
        {"spine": (0, 0, 6), "head": (-5, 0, 10), "upperarm.L": (0, 0, 14), "upperarm.R": (-40, 0, -10),
         "forearm.R": (-70, 0, 0)},
        {"spine": (0, 0, 4), "head": (0, 6, 4)})

    # Mood walks: slumped and slow when sad, bouncy when happy, stomping when angry.
    def mood_walk(name, extra, bounce, stride):
        walk = {}
        for f in range(1, 32, 5):
            ph = (f - 1) / 30.0 * 2 * math.pi
            sn = math.sin(ph)
            knee_l = max(0.0, -math.sin(ph + 0.6)) * 45 * stride
            knee_r = max(0.0, math.sin(ph + 0.6)) * 45 * stride
            p = {
                "thigh.L": (-28 * sn * stride, 0, 0), "thigh.R": (28 * sn * stride, 0, 0),
                "shin.L": (knee_l, 0, 0), "shin.R": (knee_r, 0, 0),
                "upperarm.L": (22 * sn * stride, 0, 5), "upperarm.R": (-22 * sn * stride, 0, -5),
                "forearm.L": (-12, 0, 0), "forearm.R": (-12, 0, 0),
                "hips_loc": (0, abs(math.cos(ph)) * bounce, 0),
            }
            p.update(extra)
            walk[f] = p
        make_action(rig, name, 31, walk)

    mood_walk("walk_sad", {"spine": (10, 0, 0), "head": (20, 0, 0)}, 0.012, 0.6)
    mood_walk("walk_happy", {"head": (-6, 0, 0), "chest": (-4, 0, 0)}, 0.05, 1.1)
    mood_walk("walk_angry", {"chest": (6, 0, 0), "head": (8, 0, 0), "forearm.L": (-80, 0, 0), "forearm.R": (-80, 0, 0)}, 0.035, 1.2)


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from character_details import build_head, build_hair, build_expressions
    from anatomical_body import build_anatomical_body
    clear_scene()
    mats = {
        "Skin": material("Skin", (0.57, 0.34, 0.22), 0.6),
        "Shirt": material("Shirt", (0.22, 0.47, 0.82)),
        "Pants": material("Pants", (0.18, 0.2, 0.28)),
        "Shoes": material("Shoes", (0.12, 0.1, 0.1), 0.5),
        "Sleeve": material("Sleeve", (0.57, 0.34, 0.22), 0.6),
        "Shin": material("Shin", (0.18, 0.2, 0.28)),
        "Hair": material("Hair", (0.08, 0.035, 0.015), 0.82),
        "EyeWhite": material("EyeWhite", (0.97, 0.97, 0.95), 0.3),
        "Pupil": material("Pupil", (0.1, 0.07, 0.05), 0.2),
        "Lips": material("Lips", (0.72, 0.38, 0.38), 0.5),
    }
    mats['Iris'] = material('Iris', (0.22, 0.37, 0.40), 0.28)
    mats['Nostril'] = material('Nostril', (0.23, 0.11, 0.08), 0.8)
    mats['Lips'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.55, 0.27, 0.22, 1)
    # Preserve the anatomical mesh's UV layout and its CC0 skin detail.
    skin_path = Path(__file__).resolve().parent.parent / 'assets/source/makehuman/system-assets/skins/young_asian_male/young_lightskinned_male_diffuse3.png'
    if skin_path.exists():
        for name in ['Skin', 'Sleeve', 'Shin']:
            skin = mats[name]
            texture = skin.node_tree.nodes.new('ShaderNodeTexImage')
            texture.image = bpy.data.images.load(str(skin_path), check_existing=True)
            skin.node_tree.links.new(texture.outputs['Color'], skin.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    body = build_anatomical_body(J)
    from anatomical_shapes import add_body_shapes
    add_body_shapes(body)
    head = build_head(mats)
    hairs = build_hair(mats)
    from native_hair import build_native_hair
    hairs = build_native_hair(hairs)
    faces = build_expressions(mats)
    from facial_shapes import add_face_shapes
    for part in [head]+[part for part in faces if part.name.startswith('Brows_')]:
        add_face_shapes(part)
    from facial_shapes import add_native_actions
    add_native_actions(head)
    faces.append(build_skirt(mats))
    rig = build_armature()
    skin_to_rig(rig, body, [head] + hairs + faces)
    assign_body_materials(body, mats)
    from native_clothing import build_clothing
    build_clothing(J, rig)
    animations(rig)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # Texture-ready UVs also let Godot generate tangents without import errors.
    for obj in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
        if obj.data.uv_layers:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.1519, island_margin=0.01)
        bpy.ops.object.mode_set(mode='OBJECT')
    source_dir=os.path.abspath(os.path.join(os.path.dirname(__file__), 'model_source'))
    for image in bpy.data.images:
        if image.filepath and image.source == 'FILE':
            image.filepath='//'+os.path.relpath(bpy.path.abspath(image.filepath),source_dir).replace(os.sep,'/')
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source_dir,'character.blend'),compress=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_apply=False, export_yup=True)
    print("WROTE", os.path.abspath(OUT))


main()
