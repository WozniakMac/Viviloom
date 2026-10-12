extends Node

func _ready() -> void:
	call_deferred("check")

func check() -> void:
	var person := Sim.new()
	get_tree().root.add_child(person)
	await get_tree().process_frame
	var head := person._head_mesh
	var failures := 0
	for feature in person.face_features:
		var index := head.find_blend_shape_by_name(feature)
		if index < 0:
			push_error("Missing imported facial shape: " + feature)
			failures += 1
			continue
		person.set_face_feature(feature, .65)
		if not is_equal_approx(head.get_blend_shape_value(index), .65):
			failures += 1
	for action in ["Blink", "Smile", "Frown", "BrowAngry", "BrowSad"]:
		var index := head.find_blend_shape_by_name("Action" + action)
		if index < 0:
			failures += 1
			continue
		var basis := head.bake_mesh_from_current_blend_shape_mix()
		person._set_face_action(action, 1.0)
		var changed := head.bake_mesh_from_current_blend_shape_mix()
		var displacement := 0.0
		for surface in basis.get_surface_count():
			var a: PackedVector3Array = basis.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var b: PackedVector3Array = changed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var eyes := head.mesh.surface_get_material(surface).resource_name.to_lower() == "nativeeyes"
			for vertex in a.size():
				var delta := a[vertex].distance_to(b[vertex])
				if not b[vertex].is_finite() or delta > 0.05 or (eyes and delta > 0.00001):
					failures += 1
				displacement = maxf(displacement, delta)
		if displacement < 0.0001:
			failures += 1
		person._set_face_action(action, 0.0)
		print("NATIVE ACTION ", action, " max displacement ", displacement)
	var data := person.to_dict()
	for feature in person.face_features:
		person.set_face_feature(feature, -.25)
	person.from_dict(data, [])
	for feature in person.face_features:
		if not is_equal_approx(person.face_features[feature], .65):
			failures += 1
		var index := head.find_blend_shape_by_name(feature)
		if index >= 0 and not is_equal_approx(head.get_blend_shape_value(index), .65):
			failures += 1
	person.from_dict({"name": "Legacy save"}, [])
	for feature in person.face_features:
		if not is_zero_approx(person.face_features[feature]):
			failures += 1
	person.queue_free()
	await get_tree().process_frame
	print("FACIAL MORPH IMPORT / SAVE ROUNDTRIP / LEGACY DEFAULT: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

