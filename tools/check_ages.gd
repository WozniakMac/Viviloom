extends Node
var failures:=0
var checks:=0
func expect(ok: bool,detail: String) -> void:
    checks+=1
    if not ok:failures+=1;push_error('AGE CHECK: '+detail)
func _ready() -> void:
    var camera:=Camera3D.new();add_child(camera);camera.position=Vector3(0,1.2,4);camera.current=true
    for frame in Sim.BODY_FRAMES:
        var sim:=Sim.new()
        sim.body_frame=frame
        sim.creator_preview=true
        sim.autonomy_enabled=false
        add_child(sim)
        sim.set_process(false);sim.set_physics_process(false)
        sim.set_part_color('hair',Color(.25,.16,.1))
        var base_color:=sim.hair_color
        sim.set_face_feature('LipFullness',.3)
        sim.set_body(.4,.25)
        var baseline:=sim._head_mesh.bake_mesh_from_current_blend_shape_mix().get_aabb()
        var skeleton:=sim._character_age.skeleton
        for stage in Ages.ORDER:
            sim._set_prop('book')
            sim.set_age(stage)
            expect(sim._prop!=null and sim._prop.get_parent()==sim._hand,stage+' keeps held prop on updated wrist')
            expect(sim.age_stage==stage,frame+' stage changes')
            expect(sim.hair_color.to_html()==base_color.to_html(),stage+' preserves chosen hair color')
            var material:=sim._materials['nativehair_brows'] as ShaderMaterial
            expect(material.get_shader_parameter('hair_color')==sim.hair_display_color(),stage+' hair display matches stage')
            expect(sim._body.scale==Vector3.ONE*sim.size_scale(),stage+' physical height')
            for mesh in sim._character_age.meshes:
                for candidate in ['toddler','child','teen','adult','elder']:
                    var index:=mesh.find_blend_shape_by_name('Age_'+candidate)
                    expect(index>=0,mesh.name+' native age imported')
                    if index>=0:expect(is_equal_approx(mesh.get_blend_shape_value(index),1. if stage==candidate else 0.),stage+' only selected native age active')
            expect(is_equal_approx(sim._head_mesh.get_blend_shape_value(sim._head_mesh.find_blend_shape_by_name('LipFullness')),.3),stage+' face editing retained')
            expect(is_equal_approx(sim.body_heavy,.4) and is_equal_approx(sim.body_fit,.25),stage+' body settings retained')
            var positions: Dictionary=CharacterAge.rig_data[frame][stage]
            for bone in skeleton.get_bone_count():
                var point: Array=positions[skeleton.get_bone_name(bone).replace('.','_')]
                expect(skeleton.get_bone_global_rest(bone).origin.distance_to(Vector3(point[0],point[1],point[2]))<.00001,stage+' rig matches native anatomy')
            for binding in sim._character_age.skins:
                var skin: Skin=binding.skin
                for index in skin.get_bind_count():
                    var bone:=skeleton.find_bone(skin.get_bind_name(index))
                    if bone<0:bone=skin.get_bind_bone(index)
                    if bone<0:continue
                    var actual:=skeleton.get_bone_global_rest(bone)*skin.get_bind_pose(index)
                    var original: Transform3D=sim._character_age.global_rests[bone]*binding.poses[index]
                    expect(actual.origin.distance_to(original.origin)<.00001 and actual.basis.is_equal_approx(original.basis),stage+' inverse bind prevents double deformation')
            sim._anim.play('walk');sim._anim.seek(.4,true);sim._anim.pause()
            for tick in 2:await get_tree().process_frame
            for mesh in [sim._body_mesh,sim._head_mesh]+sim._clothing_meshes.values():
                var baked: ArrayMesh=mesh.bake_mesh_from_current_skeleton_pose()
                expect(baked!=null,stage+" posed mesh is available in renderer")
                if baked==null:continue
                var bounds:=baked.get_aabb()
                expect(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()<2.5,stage+' posed '+mesh.name+' bounded')
            var box:=sim._head_mesh.bake_mesh_from_current_blend_shape_mix().get_aabb()
            if stage in ['toddler','child','elder']:expect(not box.is_equal_approx(baseline),stage+' changes anatomy beyond uniform scale')
            var saved:=sim.to_dict()
            sim.set_age('young_adult');sim.from_dict(saved,[])
            expect(sim.age_stage==stage and sim.hair_color.to_html()==base_color.to_html(),stage+' save roundtrip preserves age/base hair')
        sim.set_age('elder');sim.set_age('young_adult')
        expect(sim.hair_display_color()==sim.hair_color,frame+' elder color reverses')
        sim.set_age('invalid')
        expect(sim.age_stage=='young_adult','invalid stage ignored')
        sim.queue_free();await get_tree().process_frame
    var person:=Sim.new();add_child(person);person.set_process(false);person.set_physics_process(false)
    person.set_body_frame('feminine')
    expect(person.hair_style=='bob','first Female selection has feminine default hair')
    person.set_hair_style('long');person.set_body_frame('masculine');person.set_body_frame('feminine')
    expect(person.hair_style=='long','frame switches restore custom hair')
    var saved:=person.to_dict();person.set_body_frame('masculine');person.from_dict(saved,[])
    expect(person.hair_style=='long','custom female hair saved')
    person.set_body_frame('masculine');person.set_body_frame('feminine')
    expect(person.hair_style=='long','frame hair cache survives loading')
    person.queue_free();await get_tree().process_frame
    print('NATIVE AGE ANATOMY / RIG / BIND / POSE / HAIR / SAVE: ',checks,' checks, ',failures,' failures')
    get_tree().quit(0 if failures==0 else 1)
