"""CC0 MakeHuman textured hair fitted to the Anny head's source topology."""
from pathlib import Path
import math
import bpy
from mathutils import Vector
from bound_assets import load_bound_geometry
from native_clothing import texture_material
ROOT=Path(__file__).resolve().parent.parent/'assets/source/makehuman/system-assets/hair'
STYLES={'Short':'short02','Long':'long01','Ponytail':'ponytail01','Curly':'afro01','Bob':'bob01'}

def build_native_hair(procedural):
    result=list(procedural)
    scalp=next(o for o in procedural if o.name=='Hair_Buzz')
    styles={style:(asset,ROOT/asset) for style,asset in STYLES.items()}
    styled=ROOT.parent.parent/'hair01/hair'
    for style,asset in [('Short','culturalibre_hair_05'),('Curly','culturalibre_hair_06'),('Bun','rehmanpolanski_hair_bun_brown')]:
        folder=styled/asset
        if (folder/(asset+'.mhclo')).exists():styles[style]=(asset,folder)
    for style,(asset,folder) in styles.items():
        if not (folder/(asset+'.mhclo')).exists():continue
        bindings,faces,uvs,face_uvs=load_bound_geometry(folder,asset)
        old=next(o for o in result if o.name=='Hair_'+style)
        result.remove(old);bpy.data.objects.remove(old,do_unlink=True)
        mesh=bpy.data.meshes.new('NativeHair_'+style)
        mesh.from_pydata(bindings,[],faces);mesh.update()
        uv=mesh.uv_layers.new(name='HairUV')
        for polygon,indices in zip(mesh.polygons,face_uvs):
            polygon.use_smooth=True
            for loop,index in zip(polygon.loop_indices,indices):uv.data[loop].uv=uvs[index]
        obj=bpy.data.objects.new('Hair_'+style,mesh);bpy.context.collection.objects.link(obj)
        mesh.materials.append(texture_material(folder,'NativeHair_'+style))
        # A fitted scalp beneath separate locks closes gaps without flattening the silhouette.
        if style in ['Short','Curly']:
            from character_details import join
            cap=scalp.copy();cap.data=scalp.data.copy()
            bpy.context.collection.objects.link(cap)
            obj=join('Hair_'+style,[obj,cap])
        result.append(obj)
        print('FITTED NATIVE HAIR',style,asset,len(bindings))
    return result
