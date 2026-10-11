"""Builds the OpenSims character in Blender and exports it to assets/sim/sim.glb.

Run:  blender --background --python tools/make_sim.py

Everything is generated: a smooth body grown from a skeleton line with the Skin and
Subdivision modifiers, a head with simple features, three hairstyles, an armature
with automatic weights, and a handful of looping animations. Material names (Skin,
Shirt, Pants, Shoes, Hair, EyeWhite, Pupil, Lips) let the game recolour each part.

Blender is Z-up with the character facing +Y; the glTF exporter turns that into
Y-up facing -Z, which is the game's "forward".
"""
import math
import os
import sys

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
    J["hand." + side] = (0.27 * sx, 0.015, 0.77)

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
    sub.levels = 2
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
    bpy.ops.object.shade_smooth()
    return obj


def assign_body_materials(obj, mats):
    """Colours each face by the bone that moves it most (after rigging): short
    sleeves, bare forearms and hands, trousers below the waist, shoes on the feet."""
    for m in ("Skin", "Shirt", "Pants", "Shoes"):
        obj.data.materials.append(mats[m])
    order = {"Skin": 0, "Shirt": 1, "Pants": 2, "Shoes": 3}
    names = {g.index: g.name for g in obj.vertex_groups}
    for poly in obj.data.polygons:
        weights = {}
        for vi in poly.vertices:
            for g in obj.data.vertices[vi].groups:
                n = names.get(g.group, "")
                weights[n] = weights.get(n, 0.0) + g.weight
        bone = max(weights, key=weights.get) if weights else "spine"
        c = obj.matrix_world @ poly.center
        if bone.startswith("foot") or c.z < 0.12:
            slot = "Shoes"
        elif bone.startswith(("thigh", "shin")):
            slot = "Pants" if c.z < 0.93 else "Shirt"
        elif bone.startswith(("forearm", "hand")):
            slot = "Skin"
        elif bone.startswith("upperarm"):
            slot = "Skin" if c.z < 1.27 else "Shirt"
        elif bone in ("neck", "head"):
            slot = "Skin" if c.z > 1.44 else "Shirt"
        elif c.z < 0.93:
            slot = "Pants"
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
        brow = sphere("Brow", (0.046 * sx, 0.105, 1.74), (0.026, 0.008, 0.006), mats["Hair"], 12, 6)
        parts.append(brow)
        parts.append(sphere("Ear", (0.112 * sx, 0.0, 1.69), (0.022, 0.032, 0.04), mats["Skin"], 12, 8))
    parts.append(sphere("Nose", (0, 0.122, 1.675), (0.017, 0.022, 0.024), mats["Skin"], 12, 8))
    parts.append(sphere("Lips", (0, 0.107, 1.628), (0.03, 0.01, 0.009), mats["Lips"], 16, 8))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()
    return head


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
    return styles


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
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Head and hair follow the head bone only.
    for o in rigid:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_NAME")
        vg = o.vertex_groups.get("head") or o.vertex_groups.new(name="head")
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


def main():
    clear_scene()
    mats = {
        "Skin": material("Skin", (0.87, 0.69, 0.55), 0.6),
        "Shirt": material("Shirt", (0.22, 0.47, 0.82)),
        "Pants": material("Pants", (0.18, 0.2, 0.28)),
        "Shoes": material("Shoes", (0.12, 0.1, 0.1), 0.5),
        "Hair": material("Hair", (0.25, 0.16, 0.1), 0.55),
        "EyeWhite": material("EyeWhite", (0.97, 0.97, 0.95), 0.3),
        "Pupil": material("Pupil", (0.1, 0.07, 0.05), 0.2),
        "Lips": material("Lips", (0.72, 0.38, 0.38), 0.5),
    }
    body = build_body()
    head = build_head(mats)
    hairs = build_hair(mats)
    rig = build_armature()
    skin_to_rig(rig, body, [head] + hairs)
    assign_body_materials(body, mats)
    animations(rig)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_apply=False, export_yup=True)
    print("WROTE", os.path.abspath(OUT))


main()
