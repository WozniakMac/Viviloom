class_name CharacterAge
extends RefCounted
## Native age geometry, animation translations and inverse binds change together.
const RIG=preload('res://assets/sim/age_rig.tres')
static var rig_data: Dictionary=RIG.frames
var skeleton: Skeleton3D
var frame: String
var rests: Array[Transform3D]=[]
var global_rests: Array[Transform3D]=[]
var meshes: Array[MeshInstance3D]=[]
var skins: Array[Dictionary]=[]
var animations: Array[Dictionary]=[]
func _init(model: Node3D,body_frame: String) -> void:
    frame=body_frame
    skeleton=model.find_child('Skeleton3D',true,false)
    if skeleton==null:return
    for index in skeleton.get_bone_count():
        rests.append(skeleton.get_bone_rest(index))
        global_rests.append(skeleton.get_bone_global_rest(index))
    var skin_copies: Dictionary={}
    for item in model.find_children('*','MeshInstance3D',true,false):
        var mesh:=item as MeshInstance3D
        meshes.append(mesh)
        if mesh.skin==null:continue
        var identity:=mesh.skin.get_instance_id()
        if not skin_copies.has(identity):
            var copy:=mesh.skin.duplicate() as Skin
            var originals: Array[Transform3D]=[]
            for index in copy.get_bind_count():originals.append(copy.get_bind_pose(index))
            skins.append({'skin':copy,'poses':originals})
            skin_copies[identity]=copy
        mesh.skin=skin_copies[identity]
    var player:=model.find_child('AnimationPlayer',true,false) as AnimationPlayer
    if player==null:return
    player.stop()
    for library_name in player.get_animation_library_list():
        var original:=player.get_animation_library(library_name)
        var library:=AnimationLibrary.new()
        for name in original.get_animation_list():
            var animation:=original.get_animation(name).duplicate() as Animation
            library.add_animation(name,animation)
            for track in animation.get_track_count():
                if animation.track_get_type(track)!=Animation.TYPE_POSITION_3D:continue
                var path:=animation.track_get_path(track)
                if path.get_subname_count()==0:continue
                var bone:=skeleton.find_bone(path.get_subname(0))
                if bone<0:continue
                var keys: Array[Vector3]=[]
                for key in animation.track_get_key_count(track):keys.append(animation.track_get_key_value(track,key))
                animations.append({'animation':animation,'track':track,'bone':bone,'keys':keys})
        player.remove_animation_library(library_name)
        player.add_animation_library(library_name,library)
    player.play('idle')
func apply(stage: String) -> void:
    if skeleton==null:return
    var positions: Dictionary=rig_data.get(frame,{}).get(stage,{})
    var updated: Array[Transform3D]=[]
    for index in skeleton.get_bone_count():
        var global:=global_rests[index]
        var name:=skeleton.get_bone_name(index).replace('.','_')
        if positions.has(name):
            var point: Array=positions[name]
            global.origin=Vector3(point[0],point[1],point[2])
        updated.append(global)
        var parent:=skeleton.get_bone_parent(index)
        var local:=global if parent<0 else updated[parent].affine_inverse()*global
        skeleton.set_bone_rest(index,local)
        skeleton.set_bone_pose_position(index,local.origin)
    for binding in skins:
        var skin: Skin=binding.skin
        for index in skin.get_bind_count():
            var bone:=skeleton.find_bone(skin.get_bind_name(index))
            if bone<0:bone=skin.get_bind_bone(index)
            if bone>=0:
                skin.set_bind_pose(index,updated[bone].affine_inverse()*global_rests[bone]*binding.poses[index])
    for item in animations:
        var shift:=skeleton.get_bone_rest(item.bone).origin-rests[item.bone].origin
        for key in item.keys.size():item.animation.track_set_key_value(item.track,key,item.keys[key]+shift)
    for mesh in meshes:
        for candidate in ['toddler','child','teen','adult','elder']:
            var shape:=mesh.find_blend_shape_by_name('Age_'+candidate)
            if shape>=0:mesh.set_blend_shape_value(shape,1.0 if candidate==stage else 0.0)
func point(local: Vector3,stage: String) -> Vector3:
    # Face and camera anchors follow the native age head pivot.
    var position: Array=rig_data.get(frame,{}).get(stage,{}).get('head',[0,1.58,0])
    return local+Vector3(position[0],position[1]-1.58,position[2])
