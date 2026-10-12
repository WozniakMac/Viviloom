extends Node
## Body weight must update the face/hair without moving native eyes or opening the neck seam.
var failures:=0
func _ready() -> void:
    for frame in Sim.BODY_FRAMES:
        var person:=Sim.new()
        person.creator_preview=true
        person.body_frame=frame
        add_child(person)
        person.set_process(false)
        person.set_physics_process(false)
        var meshes: Array=[person._head_mesh]
        meshes.append_array(person._hair_meshes.values())
        var baseline: Array=[]
        for mesh in meshes:baseline.append(mesh.bake_mesh_from_current_blend_shape_mix())
        for settings in [[1.,0.],[0.,1.],[1.,1.],[.65,.4]]:
            person.set_body(settings[0],settings[1])
            var skin_moved:=false
            for index in meshes.size():
                var mesh: MeshInstance3D=meshes[index]
                for pair in [["Heavy",settings[0]],["Fit",settings[1]],["HeavyFit",settings[0]*settings[1]]]:
                    var shape:=mesh.find_blend_shape_by_name(pair[0])
                    expect(shape>=0,frame+" "+mesh.name+" imports "+pair[0])
                    if shape>=0:expect(is_equal_approx(mesh.get_blend_shape_value(shape),pair[1]),"runtime body setting reaches "+mesh.name)
                var baked:=mesh.bake_mesh_from_current_blend_shape_mix()
                for surface in baked.get_surface_count():
                    var a: PackedVector3Array=baseline[index].surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
                    var b: PackedVector3Array=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
                    var material: String=mesh.mesh.surface_get_material(surface).resource_name.to_lower().get_slice(".",0)
                    for vertex in a.size():
                        var distance:=a[vertex].distance_to(b[vertex])
                        if not b[vertex].is_finite() or distance>.025:
                            failures+=1;push_error("Unbounded head body response")
                        if index==0:
                            if material!="skin" or a[vertex].y>1.710 or a[vertex].y<1.575:
                                if distance>.00001:failures+=1;push_error("Eye/lash/neck boundary moved")
                            elif distance>.0001:skin_moved=true
            expect(skin_moved,frame+" body setting changes visible cheek/jaw geometry")
        person.set_face_feature("LipFullness",.3)
        person.set_body(.7,.6)
        var saved:=person.to_dict()
        person.set_body(0,0)
        person.from_dict(saved,[])
        var head:=person._head_mesh
        expect(is_equal_approx(head.get_blend_shape_value(head.find_blend_shape_by_name("Heavy")),.7),"face volume restored by save")
        expect(is_equal_approx(head.get_blend_shape_value(head.find_blend_shape_by_name("LipFullness")),.3),"body response preserves face controls")
        person._set_face_action("Blink",.8)
        expect(is_equal_approx(head.get_blend_shape_value(head.find_blend_shape_by_name("Heavy")),.7),"blink preserves face volume")
        person.queue_free()
        await get_tree().process_frame
    print("HEAD / HAIR BODY RESPONSE / EYES / NECK / SAVE CHECK: ",failures," failures")
    get_tree().quit(0 if failures==0 else 1)
func expect(ok: bool,label: String) -> void:
    if not ok:failures+=1;push_error("HEAD BODY CHECK: "+label)
