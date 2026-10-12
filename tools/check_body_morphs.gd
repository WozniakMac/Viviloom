extends SceneTree
## Imported body/clothing morphs must preserve height and bounded, nonzero deformation.
func _initialize():
 var model=load("res://assets/sim/sim.glb").instantiate()
 root.add_child(model)
 var failures=0
 var checked=0
 for part in model.find_children("*", "MeshInstance3D",true,false):
  if part.name=="Body" or part.name.begins_with("Outfit"):
   checked+=1
   var original=part.bake_mesh_from_current_blend_shape_mix()
   for name in ["Heavy","Fit","HeavyFit"]:
    var index=part.find_blend_shape_by_name(name)
    if index<0:failures+=1
    else:part.set_blend_shape_value(index,1)
   var baked=part.bake_mesh_from_current_blend_shape_mix()
   var max_height=0.0
   var max_delta=0.0
   for surface in original.get_surface_count():
    var basis=original.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    var changed=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in basis.size():
     if not changed[vertex].is_finite():failures+=1
     max_height=max(max_height,abs(basis[vertex].y-changed[vertex].y))
     max_delta=max(max_delta,basis[vertex].distance_to(changed[vertex]))
   if max_height>.10 or max_delta>.20 or max_delta<.001:failures+=1
   print(part.name," morph height error ",max_height," displacement ",max_delta)
 if checked!=6:failures+=1
 model.queue_free()
 await process_frame
 print("BODY/CLOTHING IMPORTED MORPH CHECK: ",failures," failures")
 quit(0 if failures==0 else 1)
