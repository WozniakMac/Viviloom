extends Node
## Actual Sim materials, clothing and morphs across animation poses or body extremes.
func _ready() -> void:
 var args=OS.get_cmdline_user_args()
 var out=args[0] if args.size()>0 else "user://runtime-preview.png"
 var mode=args[1] if args.size()>1 else "poses"
 var yaw=float(args[2]) if args.size()>2 else 0.0
 var env=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color(0.78,0.87,0.90)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color(0.9,0.93,1.0)
 env.environment.ambient_light_energy=0.65
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 add_child(env)
 for pair in [[Vector3(-3,4,3),1.0],[Vector3(4,3,2),0.45]]:
  var light=OmniLight3D.new()
  light.position=pair[0];light.light_energy=pair[1];light.omni_range=14
  add_child(light)
 var names=["idle","walk","sit","sit_use","lie","talk","use"]
 var shapes=[[0.0,0.0],[1.0,0.0],[0.0,1.0],[1.0,1.0],[0.5,0.5],[0.25,0.75],[0.75,0.25]]
 var styles=["short","long","bun","ponytail","buzz","curly","bob"]
 if mode=="faces":names=["Neutral","Blink","Smile","Frown","BrowAngry","BrowSad","Neutral"]
 var spacing=0.38 if mode=="faces" else 0.95
 var sims=[]
 for i in names.size():
  var sim=Sim.new()
  sim.creator_preview=true;sim.autonomy_enabled=false
  sim.body_heavy=0.0 if mode=="faces" else shapes[i][0];sim.body_fit=0.0 if mode=="faces" else shapes[i][1]
  sim.long_sleeves=true
  sim.hair_style=styles[i] if mode=="hair" else "short"
  add_child(sim)
  sim.process_mode=Node.PROCESS_MODE_DISABLED
  sim._selection_ring.visible=false
  if mode=="faces":
   for action in ["Smile","Frown","BrowAngry","BrowSad","Blink"]:sim._set_face_action(action,0.0)
   if names[i]!="Neutral":sim._set_face_action(names[i],1.0)
   if names[i] in ["BrowAngry","BrowSad"]:
    sim._face_meshes["Brows_Neutral"].visible=false
    sim._face_meshes["Brows_"+names[i].trim_prefix("Brow")].visible=true
  sim.position=Vector3((i-3)*spacing,0,0);sim.rotation.y=deg_to_rad(180+yaw)
  var ap=sim._anim
  ap.play(names[i] if mode=="poses" else "idle")
  ap.seek(0.4,true);ap.pause()
  if mode=="poses" and names[i]=="lie":
   sim._body.rotation.x=PI*0.5;sim._body.position.y=0.15
  var label=Label3D.new()
  label.text=names[i] if mode in ["poses","faces"] else (styles[i] if mode=="hair" else str(shapes[i]))
  label.position=Vector3((i-3)*spacing,1.96 if mode=="faces" else 2.06,0)
  label.font_size=14 if mode=="faces" else 40;label.modulate=Color(0.15,0.2,0.3)
  add_child(label)
  sims.append(sim)
 var cam=Camera3D.new();add_child(cam)
 cam.look_at_from_position(Vector3(0,1.22,5.1),Vector3(0,0.98,0))
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=3.8
 if mode=="faces":
  cam.look_at_from_position(Vector3(0,1.70,3),Vector3(0,1.70,0));cam.size=1.55
 cam.current=true
 for k in 6:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out)
 print("RUNTIME PREVIEW ",mode," ",out)
 get_tree().quit()
