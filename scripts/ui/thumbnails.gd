class_name Thumbnails
extends Node
## Renders a small picture of every catalogue object once, in a private 3D world,
## so the build-mode catalogue can show real thumbnails.

signal ready_for(kind: String, texture: Texture2D)

const SIZE := 128

var textures := {}


func render_all(kinds: Array[String]) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true

	for kind in kinds:
		var f := Catalog.create(kind)
		vp.add_child(f)
		var extent := maxf(maxf(f.footprint.x, f.footprint.y), f.height)
		var target := Vector3(0, f.height * 0.45, 0)
		var dir := Vector3(0.75, 0.6, 1.0).normalized()
		cam.look_at_from_position(target + dir * (extent * 2.4 + 0.8), target, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var tex := ImageTexture.create_from_image(vp.get_texture().get_image())
		textures[kind] = tex
		ready_for.emit(kind, tex)
		f.queue_free()
		await get_tree().process_frame
	vp.queue_free()
