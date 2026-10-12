extends Node
## Frame switching must preserve gameplay identity, settings, saved data and studio layers.
func _ready() -> void:
 call_deferred("check")

func check() -> void:
 var sim=Sim.new()
 sim.creator_preview=true;sim.autonomy_enabled=false
 add_child(sim);sim.process_mode=Node.PROCESS_MODE_DISABLED
 sim.position=Vector3(4,0,7)
 sim.set_body(0.7,0.4);sim.set_outfit(true,true)
 sim.set_hair_style("bun");sim.set_face_feature("LipFullness",0.35)
 sim.set_part_color("shirt",Color(0.8,0.25,0.5))
 sim._set_prop("book")
 var body_id=sim._body.get_instance_id()
 var ring_id=sim._selection_ring.get_instance_id()
 var voice_id=sim._voice.get_instance_id()
 var failures=0
 var meshes={}
 for frame in ["feminine","masculine","feminine"]:
  var expected_color=sim.shirt_color
  sim.set_body_frame(frame)
  meshes[frame]=sim._body_mesh.mesh
  if sim._body.get_instance_id()!=body_id or sim._selection_ring.get_instance_id()!=ring_id or sim._voice.get_instance_id()!=voice_id:failures+=1;print("FRAME CHECK FAILURE 23")
  if sim.position!=Vector3(4,0,7) or not sim.long_sleeves or not sim.shorts or sim.hair_style!="bun" or not is_equal_approx(sim.body_heavy,0.7) or not is_equal_approx(sim.body_fit,0.4):failures+=1;print("FRAME CHECK FAILURE 24")
  if sim._prop_kind!="book" or not is_instance_valid(sim._prop) or sim._prop.get_parent()!=sim._hand:failures+=1;print("FRAME CHECK FAILURE 25")
  if sim.shirt_color!=expected_color or not is_equal_approx(sim.face_features.LipFullness,0.35):failures+=1;print("FRAME CHECK FAILURE 26")
  for mesh in sim._model.find_children("*","MeshInstance3D",true,false):
   if mesh.name.begins_with("Masculine_") or mesh.name.begins_with("Feminine_"):failures+=1;print("FRAME CHECK FAILURE 28")
   if mesh.layers != 8 | Sim.PORTRAIT_LAYER or not mesh.has_meta("cas_original_layers"):failures+=1;print("FRAME CHECK FAILURE 29")
  for mesh in [sim._body_mesh]+sim._clothing_meshes.values():
   var index=mesh.find_blend_shape_by_name("HeavyFit")
   if index<0 or not is_equal_approx(mesh.get_blend_shape_value(index),0.28):failures+=1;print("FRAME CHECK FAILURE 32")
  var saved=sim.to_dict()
  if saved.get("body_frame")!=frame:failures+=1;print("FRAME CHECK FAILURE 34")
  sim.set_body_frame("masculine" if frame=="feminine" else "feminine")
  sim.from_dict(saved,[])
  if sim.body_frame!=frame:failures+=1;print("FRAME CHECK FAILURE 37")
 if meshes.masculine==meshes.feminine:failures+=1;print("FRAME CHECK FAILURE 38")
 sim.set_body_frame("invalid")
 if sim.body_frame!="feminine":failures+=1;print("FRAME CHECK FAILURE 40")
 sim.from_dict({"name":"Legacy"},[])
 if sim.body_frame!="masculine":failures+=1;print("FRAME CHECK FAILURE 42")
 sim.queue_free();await get_tree().process_frame
 print("BODY FRAME IDENTITY / MORPHS / PROPS / STUDIO / SAVE CHECK: ",failures," failures")
 get_tree().quit(0 if failures==0 else 1)
