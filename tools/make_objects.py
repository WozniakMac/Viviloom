"""Builds the OpenSims furniture models in Blender and exports one .glb per object
to assets/objects/<kind>.glb.

Run:  blender --background --python tools/make_objects.py

Shapes are written in the game's coordinates (metres, Y up, the object's front
towards +Z, origin at the centre of its footprint on the floor) and converted to
Blender's Z-up axes here, so the glTF export lands back in game space.
"""
import math
import os

import bpy

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "objects")
MATS = {}


def mat(name, color, rough=0.6, metal=0.0, alpha=1.0, emission=None):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    if emission:
        b.inputs["Emission Color"].default_value = (*emission, 1.0)
        b.inputs["Emission Strength"].default_value = 0.0
    MATS[name] = m
    return m


def palette():
    return {
        "wood": mat("Wood", (0.55, 0.36, 0.22), 0.55),
        "wood_dark": mat("WoodDark", (0.32, 0.2, 0.12), 0.5),
        "wood_light": mat("WoodLight", (0.78, 0.62, 0.42), 0.55),
        "white": mat("White", (0.93, 0.93, 0.9), 0.35),
        "ceramic": mat("Ceramic", (0.97, 0.97, 0.96), 0.15),
        "metal": mat("Metal", (0.72, 0.73, 0.76), 0.25, 0.9),
        "dark": mat("Dark", (0.08, 0.08, 0.09), 0.3),
        "screen": mat("Screen", (0.06, 0.12, 0.2), 0.1),
        "glass": mat("Glass", (0.75, 0.88, 0.95), 0.05, 0.0, 0.3),
        "fabric_blue": mat("FabricBlue", (0.26, 0.42, 0.7), 0.9),
        "fabric_grey": mat("FabricGrey", (0.55, 0.57, 0.6), 0.9),
        "fabric_teal": mat("FabricTeal", (0.2, 0.52, 0.55), 0.9),
        "linen": mat("Linen", (0.95, 0.94, 0.9), 0.85),
        "shade": mat("Shade", (0.97, 0.9, 0.76), 0.8),
        "leaf": mat("Leaf", (0.2, 0.5, 0.22), 0.7),
        "pot": mat("Pot", (0.75, 0.42, 0.3), 0.6),
        "counter_top": mat("CounterTop", (0.88, 0.86, 0.82), 0.3),
        "cabinet": mat("Cabinet", (0.92, 0.9, 0.84), 0.45),
        "red": mat("Red", (0.75, 0.2, 0.2), 0.5),
        "blue": mat("Blue", (0.2, 0.38, 0.72), 0.5),
        "yellow": mat("Yellow", (0.9, 0.72, 0.22), 0.5),
        "green": mat("Green", (0.25, 0.55, 0.3), 0.5),
        "canvas": mat("Canvas", (0.97, 0.96, 0.92), 0.8),
        "mail": mat("Mailbox", (0.88, 0.88, 0.9), 0.4, 0.4),
    }


def to_blender(p):
    x, y, z = p
    return (x, -z, y)


def size_blender(s):
    x, y, z = s
    return (x, z, y)


def box(size, center, material, bevel=0.015, name="Part"):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=to_blender(center))
    o = bpy.context.active_object
    o.name = name
    o.scale = size_blender(size)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = min(bevel, min(size) * 0.45)
        m.segments = 3
        bpy.ops.object.modifier_apply(modifier="Bevel")
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.data.set_sharp_from_angle(angle=math.radians(40))
    return o


def cylinder(radius, height, center, material, verts=24, radius_top=None, name="Part", axis="y"):
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height, location=to_blender(center))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius_top, depth=height, location=to_blender(center))
    o = bpy.context.active_object
    o.name = name
    if axis == "x":
        o.rotation_euler = (0, math.radians(90), 0)
    elif axis == "z":
        o.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.data.set_sharp_from_angle(angle=math.radians(40))
    return o


def sphere(scale, center, material, name="Part"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0, location=to_blender(center))
    o = bpy.context.active_object
    o.name = name
    o.scale = size_blender(scale)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def tilted(o, x_deg=0.0, z_deg=0.0):
    """Tilts a part about the game's X (lean forward/back) or Z (lean sideways) axis."""
    o.rotation_euler = (math.radians(x_deg), math.radians(z_deg), 0)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(rotation=True)
    return o


# --- objects ----------------------------------------------------------------------
def fridge(M):
    box((0.84, 1.88, 0.72), (0, 0.94, -0.06), M["white"], 0.05)
    box((0.82, 0.012, 0.02), (0, 1.25, 0.31), M["dark"], 0.0)
    cylinder(0.018, 0.42, (0.33, 1.55, 0.35), M["metal"])
    cylinder(0.018, 0.36, (0.33, 0.9, 0.35), M["metal"])
    for x in (-0.33, 0.33):
        box((0.06, 0.04, 0.06), (x, 0.02, 0.2), M["dark"], 0.01)


def bed(M):
    box((1.9, 0.28, 1.96), (0, 0.22, 0), M["wood"], 0.03)
    for x in (-0.88, 0.88):
        for z in (-0.88, 0.88):
            box((0.08, 0.1, 0.08), (x, 0.05, z), M["wood_dark"], 0.01)
    box((1.8, 0.2, 1.86), (0, 0.45, 0.02), M["linen"], 0.07)
    box((1.84, 0.08, 1.25), (0, 0.55, 0.34), M["fabric_blue"], 0.04)
    box((1.86, 0.18, 0.06), (0, 0.48, 0.97), M["fabric_blue"], 0.03)
    for x in (-0.45, 0.45):
        box((0.62, 0.14, 0.38), (x, 0.6, -0.68), M["linen"], 0.06)
    box((1.98, 1.0, 0.1), (0, 0.5, -0.96), M["wood"], 0.03)
    for x in (-0.6, 0.0, 0.6):
        box((0.5, 0.5, 0.02), (x, 0.66, -0.905), M["wood_dark"], 0.015)


def toilet(M):
    cylinder(0.15, 0.36, (0, 0.18, 0.08), M["ceramic"], 24, 0.2)
    sphere((0.21, 0.08, 0.27), (0, 0.4, 0.1), M["ceramic"])
    cylinder(0.215, 0.025, (0, 0.44, 0.1), M["white"], 32)
    box((0.42, 0.42, 0.18), (0, 0.62, -0.3), M["ceramic"], 0.04)
    box((0.44, 0.03, 0.2), (0, 0.84, -0.3), M["ceramic"], 0.015)
    cylinder(0.02, 0.06, (0.15, 0.88, -0.3), M["metal"])


def shower(M):
    box((0.95, 0.08, 0.95), (0, 0.04, 0), M["ceramic"], 0.02)
    box((0.95, 2.05, 0.04), (0, 1.07, -0.455), M["ceramic"], 0.01)
    box((0.04, 2.05, 0.95), (-0.455, 1.07, 0), M["ceramic"], 0.01)
    box((0.02, 1.9, 0.9), (0.46, 1.03, 0), M["glass"], 0.0)
    box((0.9, 1.9, 0.02), (0.0, 1.03, 0.46), M["glass"], 0.0)
    cylinder(0.02, 2.0, (0.46, 1.04, 0.46), M["metal"])
    cylinder(0.012, 0.4, (0, 1.85, -0.42), M["metal"], 12, None, "Part", "z")
    cylinder(0.08, 0.03, (0, 2.0, -0.25), M["metal"], 24, 0.06)


def tv(M):
    box((1.6, 0.48, 0.48), (0, 0.26, 0), M["wood"], 0.03)
    for x in (-0.4, 0.4):
        box((0.74, 0.36, 0.02), (x, 0.26, 0.24), M["wood_dark"], 0.01)
        cylinder(0.012, 0.12, (x, 0.3, 0.26), M["metal"], 12, None, "Part", "x")
    box((0.3, 0.04, 0.2), (0, 0.52, -0.05), M["dark"], 0.01)
    box((0.05, 0.12, 0.05), (0, 0.6, -0.05), M["dark"], 0.01)
    box((1.48, 0.84, 0.06), (0, 1.06, -0.06), M["dark"], 0.02)
    box((1.4, 0.76, 0.01), (0, 1.06, -0.027), M["screen"], 0.0)


def desk(M):
    box((1.8, 0.05, 0.8), (0, 0.74, -0.5), M["wood_light"], 0.02)
    for x in (-0.84, 0.84):
        box((0.05, 0.72, 0.72), (x, 0.36, -0.5), M["wood_light"], 0.01)
    box((0.45, 0.5, 0.7), (0.58, 0.45, -0.5), M["wood_light"], 0.02)
    for y in (0.3, 0.55):
        box((0.4, 0.02, 0.01), (0.58, y, -0.145), M["wood_dark"], 0.0)
    box((0.62, 0.38, 0.03), (0, 1.05, -0.72), M["dark"], 0.01)
    box((0.58, 0.34, 0.005), (0, 1.05, -0.703), M["screen"], 0.0)
    box((0.04, 0.2, 0.04), (0, 0.86, -0.74), M["dark"], 0.01)
    box((0.2, 0.015, 0.14), (0, 0.77, -0.74), M["dark"], 0.005)
    box((0.42, 0.015, 0.14), (0, 0.775, -0.36), M["dark"], 0.005)
    # Office chair.
    cylinder(0.24, 0.07, (0, 0.46, 0.35), M["fabric_grey"], 24)
    box((0.42, 0.42, 0.06), (0, 0.76, 0.58), M["fabric_grey"], 0.03)
    cylinder(0.025, 0.36, (0, 0.24, 0.35), M["metal"])
    for k in range(5):
        a = k * 2 * math.pi / 5
        leg = box((0.04, 0.03, 0.26), (math.sin(a) * 0.13, 0.05, 0.35 + math.cos(a) * 0.13), M["dark"], 0.01)
        leg.rotation_euler = (0, 0, a)
        bpy.ops.object.select_all(action="DESELECT")


def bookshelf(M):
    box((0.9, 2.0, 0.38), (0, 1.0, -0.29), M["wood"], 0.02)
    box((0.82, 1.9, 0.02), (0, 1.0, -0.46), M["wood_dark"], 0.0)
    colors = [M["red"], M["blue"], M["yellow"], M["green"], M["linen"]]
    for shelf in range(4):
        y = 0.15 + shelf * 0.46
        box((0.82, 0.025, 0.34), (0, y, -0.27), M["wood_dark"], 0.005)
        x = -0.36
        k = shelf
        while x < 0.33:
            w = 0.05 + 0.03 * ((k * 7) % 3)
            h = 0.26 + 0.05 * ((k * 5) % 4)
            box((w, h, 0.25), (x + w / 2, y + h / 2 + 0.013, -0.25), colors[k % len(colors)], 0.008)
            x += w + 0.008
            k += 1


def easel(M):
    for x in (-0.24, 0.24):
        tilted(box((0.04, 1.72, 0.04), (x, 0.86, -0.08), M["wood"], 0.008), -6, -x * 18)
    tilted(box((0.04, 1.62, 0.04), (0, 0.8, -0.38), M["wood"], 0.008), 17)
    box((0.7, 0.04, 0.1), (0, 0.72, -0.02), M["wood"], 0.01)
    box((0.62, 0.74, 0.03), (0, 1.12, -0.06), M["canvas"], 0.005)
    box((0.3, 0.25, 0.005), (-0.1, 1.17, -0.04), M["blue"], 0.0)
    box((0.18, 0.3, 0.005), (0.14, 1.04, -0.04), M["yellow"], 0.0)


def chess(M):
    cylinder(0.32, 0.04, (0, 0.72, -0.15), M["wood"], 32)
    cylinder(0.05, 0.68, (0, 0.36, -0.15), M["wood_dark"])
    cylinder(0.2, 0.03, (0, 0.02, -0.15), M["wood_dark"], 24)
    for i in range(64):
        light = (i % 8 + i // 8) % 2 == 0
        box((0.048, 0.006, 0.048), (-0.168 + (i % 8) * 0.048, 0.743, -0.318 + (i // 8) * 0.048), M["linen"] if light else M["dark"], 0.0)
    for i in range(8):
        cylinder(0.012, 0.03, (-0.168 + i * 0.048, 0.762, -0.318), M["linen"], 10)
        cylinder(0.012, 0.03, (-0.168 + i * 0.048, 0.762, 0.018), M["dark"], 10)
    cylinder(0.17, 0.05, (0, 0.46, 0.3), M["fabric_teal"], 24)
    for x in (-0.11, 0.11):
        for z in (0.2, 0.4):
            cylinder(0.018, 0.44, (x, 0.22, z), M["wood_dark"], 10)


def lamp(M):
    cylinder(0.17, 0.035, (0, 0.018, 0), M["dark"], 32)
    cylinder(0.018, 1.45, (0, 0.74, 0), M["metal"], 12)
    shade = cylinder(0.24, 0.3, (0, 1.5, 0), M["shade"], 32, 0.14, "Shade")
    return shade


def sofa(M):
    box((2.8, 0.3, 0.86), (0, 0.27, 0), M["fabric_teal"], 0.06)
    for x in (-0.92, 0.0, 0.92):
        box((0.9, 0.16, 0.66), (x, 0.49, 0.08), M["fabric_teal"], 0.07)
        box((0.88, 0.5, 0.2), (x, 0.74, -0.32), M["fabric_teal"], 0.08)
    for x in (-1.38, 1.38):
        box((0.2, 0.58, 0.86), (x, 0.42, 0), M["fabric_teal"], 0.07)
    box((2.8, 0.66, 0.16), (0, 0.6, -0.36), M["fabric_teal"], 0.05)
    for x in (-1.3, 1.3):
        for z in (-0.35, 0.35):
            cylinder(0.025, 0.12, (x, 0.06, z), M["wood_dark"], 12)


def dining_table(M):
    box((1.8, 0.05, 0.9), (0, 0.75, 0), M["wood"], 0.02)
    box((1.66, 0.08, 0.76), (0, 0.69, 0), M["wood_dark"], 0.01)
    for x in (-0.8, 0.8):
        for z in (-0.36, 0.36):
            box((0.06, 0.72, 0.06), (x, 0.36, z), M["wood_dark"], 0.01)


def chair(M):
    box((0.44, 0.05, 0.44), (0, 0.46, 0.05), M["wood"], 0.015)
    box((0.42, 0.04, 0.4), (0, 0.5, 0.05), M["fabric_blue"], 0.02)
    for x in (-0.19, 0.19):
        for z in (-0.14, 0.24):
            box((0.04, 0.46, 0.04), (x, 0.23, z), M["wood"], 0.008)
        box((0.04, 0.5, 0.04), (x, 0.74, -0.15), M["wood"], 0.008)
    for y in (0.75, 0.92):
        box((0.42, 0.05, 0.03), (0, y, -0.15), M["wood"], 0.01)


def counter(M):
    box((0.96, 0.86, 0.6), (0, 0.45, -0.18), M["cabinet"], 0.015)
    box((1.0, 0.05, 0.66), (0, 0.9, -0.16), M["counter_top"], 0.01)
    box((0.9, 0.08, 0.02), (0, 0.04, 0.13), M["dark"], 0.0)
    for x in (-0.24, 0.24):
        box((0.44, 0.66, 0.02), (x, 0.45, 0.13), M["cabinet"], 0.01)
        cylinder(0.01, 0.12, (x + (0.16 if x < 0 else -0.16), 0.7, 0.15), M["metal"], 10)


def stove(M):
    box((0.96, 0.86, 0.6), (0, 0.45, -0.18), M["white"], 0.015)
    box((1.0, 0.05, 0.66), (0, 0.9, -0.16), M["dark"], 0.01)
    for x in (-0.22, 0.22):
        for z in (-0.3, -0.04):
            cylinder(0.09, 0.015, (x, 0.93, z), M["metal"], 24)
    box((0.8, 0.45, 0.02), (0, 0.42, 0.13), M["dark"], 0.01)
    box((0.7, 0.02, 0.03), (0, 0.7, 0.15), M["metal"], 0.005)
    for x in (-0.3, -0.1, 0.1, 0.3):
        cylinder(0.025, 0.03, (x, 0.8, 0.14), M["dark"], 12, None, "Part", "z")


def sink(M):
    counter(M)
    box((0.5, 0.06, 0.36), (0, 0.9, -0.16), M["metal"], 0.01)
    box((0.44, 0.02, 0.3), (0, 0.885, -0.16), M["dark"], 0.0)
    cylinder(0.015, 0.25, (0, 1.04, -0.38), M["metal"], 12)
    cylinder(0.012, 0.18, (0, 1.16, -0.3), M["metal"], 12, None, "Part", "z")


def plant(M):
    cylinder(0.17, 0.32, (0, 0.16, 0), M["pot"], 24, 0.21)
    cylinder(0.19, 0.02, (0, 0.31, 0), M["dark"], 24)
    for k in range(9):
        a = k * 2.4
        r = 0.08 + 0.02 * (k % 3)
        leaf = sphere((0.08, 0.2, 0.035), (math.sin(a) * r, 0.5 + 0.06 * (k % 4), math.cos(a) * r), M["leaf"])
        leaf.rotation_euler = (math.radians(25) * math.cos(a), math.radians(25) * math.sin(a), a)
        bpy.ops.object.select_all(action="DESELECT")


def mailbox(M):
    box((0.07, 1.0, 0.07), (0, 0.5, 0), M["wood_dark"], 0.01)
    box((0.26, 0.24, 0.48), (0, 1.08, 0), M["mail"], 0.04)
    cylinder(0.13, 0.48, (0, 1.2, 0), M["mail"], 24, None, "Part", "z")
    box((0.02, 0.14, 0.04), (0.14, 1.18, 0.12), M["red"], 0.005)


def bench(M):
    for x in (-0.75, 0.75):
        box((0.08, 0.42, 0.42), (x, 0.21, 0.0), M["metal"], 0.01)
        box((0.08, 0.5, 0.06), (x, 0.65, -0.2), M["metal"], 0.01)
    for k in range(4):
        box((1.7, 0.035, 0.09), (0, 0.44, -0.15 + k * 0.1), M["wood_light"], 0.008)
    for k in range(3):
        box((1.7, 0.08, 0.03), (0, 0.6 + k * 0.11, -0.22), M["wood_light"], 0.008)


def tree(M):
    cylinder(0.12, 1.8, (0, 0.9, 0), M["wood_dark"], 12, 0.08)
    for (x, y, z, r) in ((0, 2.3, 0, 0.9), (0.45, 2.0, 0.2, 0.6), (-0.4, 2.05, -0.15, 0.62), (0.1, 2.75, -0.1, 0.6), (-0.2, 1.9, 0.4, 0.5)):
        sphere((r, r * 0.85, r), (x, y, z), M["leaf"])


def bush(M):
    for (x, y, z, r) in ((0, 0.35, 0, 0.42), (0.25, 0.3, 0.15, 0.3), (-0.25, 0.28, -0.1, 0.32)):
        sphere((r, r * 0.8, r), (x, y, z), M["leaf"])


def grill(M):
    for x in (-0.25, 0.25):
        for z in (-0.18, 0.18):
            cylinder(0.02, 0.75, (x, 0.37, z), M["metal"], 8)
    box((0.7, 0.2, 0.45), (0, 0.82, 0), M["dark"], 0.04)
    box((0.66, 0.02, 0.41), (0, 0.93, 0), M["metal"], 0.0)
    box((0.7, 0.04, 0.3), (0, 0.5, 0), M["wood"], 0.01)


def picnic_table(M):
    box((1.6, 0.05, 0.7), (0, 0.74, 0), M["wood_light"], 0.01)
    for z in (-0.6, 0.6):
        box((1.6, 0.04, 0.26), (0, 0.44, z), M["wood_light"], 0.01)
    for x in (-0.6, 0.6):
        tilted(box((0.06, 0.95, 0.06), (x, 0.38, 0.3), M["wood"], 0.008), 32)
        tilted(box((0.06, 0.95, 0.06), (x, 0.38, -0.3), M["wood"], 0.008), -32)
        box((0.06, 0.06, 1.5), (x, 0.4, 0), M["wood"], 0.008)


def fountain(M):
    cylinder(1.0, 0.4, (0, 0.2, 0), M["counter_top"], 40)
    cylinder(0.85, 0.05, (0, 0.38, 0), M["glass"], 40)
    cylinder(0.12, 0.9, (0, 0.65, 0), M["counter_top"], 16)
    cylinder(0.4, 0.12, (0, 1.1, 0), M["counter_top"], 24, 0.32)
    cylinder(0.3, 0.04, (0, 1.15, 0), M["glass"], 24)


def treadmill(M):
    box((0.7, 0.14, 1.7), (0, 0.07, -0.05), M["dark"], 0.03)
    box((0.56, 0.02, 1.5), (0, 0.15, -0.05), M["fabric_grey"], 0.0)
    for x in (-0.33, 0.33):
        tilted(box((0.05, 1.2, 0.05), (x, 0.65, -0.78), M["metal"], 0.01), -12)
    box((0.72, 0.06, 0.08), (0, 1.15, -0.62), M["metal"], 0.02)
    box((0.5, 0.25, 0.08), (0, 1.25, -0.72), M["dark"], 0.03)
    box((0.36, 0.14, 0.01), (0, 1.27, -0.675), M["screen"], 0.0)


def mirror(M):
    box((0.7, 1.75, 0.06), (0, 0.98, -0.42), M["wood_light"], 0.02)
    box((0.6, 1.6, 0.01), (0, 0.98, -0.385), M["glass"], 0.0)
    box((0.12, 0.1, 0.35), (-0.25, 0.05, -0.3), M["wood_light"], 0.01)
    box((0.12, 0.1, 0.35), (0.25, 0.05, -0.3), M["wood_light"], 0.01)


def guitar(M):
    # A guitar resting on its stand.
    for x in (-0.12, 0.12):
        tilted(box((0.03, 0.6, 0.03), (x, 0.3, -0.05), M["dark"], 0.005), 10)
    body = sphere((0.19, 0.24, 0.06), (0, 0.42, -0.1), M["wood"])
    sphere((0.15, 0.17, 0.062), (0, 0.66, -0.1), M["wood"])
    cylinder(0.05, 0.005, (0, 0.55, -0.04), M["dark"], 16, None, "Part", "z")
    box((0.05, 0.62, 0.03), (0, 1.05, -0.1), M["wood_dark"], 0.005)
    box((0.08, 0.14, 0.035), (0, 1.42, -0.1), M["wood_dark"], 0.01)


def bar(M):
    box((1.9, 1.05, 0.6), (0, 0.52, -0.1), M["wood_dark"], 0.03)
    box((2.0, 0.06, 0.75), (0, 1.07, -0.05), M["counter_top"], 0.015)
    box((1.8, 0.04, 0.1), (0, 0.15, 0.22), M["metal"], 0.01)
    for k, col in enumerate([M["green"], M["red"], M["yellow"], M["blue"], M["green"]]):
        cylinder(0.04, 0.26, (-0.6 + k * 0.3, 1.23, -0.32), col, 12, 0.025)
    for x in (-0.6, 0.0, 0.6):
        cylinder(0.17, 0.05, (x, 0.75, 0.62), M["fabric_teal"], 20)
        cylinder(0.03, 0.72, (x, 0.37, 0.62), M["metal"], 10)


def pizza(M):
    box((0.42, 0.05, 0.42), (0, 0.025, 0), M["canvas"], 0.005)
    box((0.42, 0.012, 0.42), (0, 0.06, 0), M["red"], 0.003)
    cylinder(0.18, 0.02, (0, 0.07, 0), M["yellow"], 24)


def stereo(M):
    box((0.9, 0.55, 0.38), (0, 0.3, -0.12), M["wood_dark"], 0.03)
    for x in (-0.3, 0.3):
        cylinder(0.12, 0.02, (x, 0.32, 0.075), M["dark"], 24, None, "Part", "z")
        cylinder(0.05, 0.025, (x, 0.32, 0.085), M["metal"], 16, None, "Part", "z")
    box((0.3, 0.12, 0.02), (0, 0.48, 0.075), M["screen"], 0.005)
    box((0.86, 0.04, 0.34), (0, 0.6, -0.12), M["metal"], 0.01)


def car(M):
    body = mat("CarBody", (0.85, 0.25, 0.2), 0.3, 0.3)
    box((4.2, 0.75, 1.8), (0, 0.65, 0), body, 0.12)
    box((2.4, 0.65, 1.66), (-0.2, 1.3, 0), body, 0.15)
    box((2.3, 0.55, 1.68), (-0.2, 1.32, 0), M["glass"], 0.1)
    for x in (-1.35, 1.35):
        for z in (-0.88, 0.88):
            cylinder(0.36, 0.25, (x, 0.36, z), M["dark"], 20, None, "Part", "z")
    for z in (-0.6, 0.6):
        box((0.06, 0.15, 0.3), (2.1, 0.75, z), M["yellow"], 0.02)


OBJECTS = {
    "fridge": fridge, "bed": bed, "toilet": toilet, "shower": shower, "tv": tv, "desk": desk,
    "bookshelf": bookshelf, "easel": easel, "chess": chess, "lamp": lamp, "sofa": sofa,
    "dining_table": dining_table, "chair": chair, "counter": counter, "stove": stove,
    "sink": sink, "plant": plant, "mailbox": mailbox, "bench": bench, "tree": tree, "bush": bush,
    "grill": grill, "picnic_table": picnic_table, "fountain": fountain,
    "treadmill": treadmill, "mirror": mirror, "guitar": guitar, "bar": bar, "pizza": pizza, "stereo": stereo, "car": car,
}


def export(kind, builder, M):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    builder(M)
    shade = bpy.data.objects.get("Shade")
    # Join everything but a lamp shade (which glows separately) into one mesh.
    parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "Shade"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    parts[0].name = kind.capitalize()
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT_DIR, kind + ".glb")
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(path), export_format="GLB", use_selection=True, export_yup=True)
    print("WROTE", kind)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    M = palette()
    for kind, builder in OBJECTS.items():
        export(kind, builder, M)


main()
