class_name HandPose
extends SkeletonModifier3D
## Finger closure is applied after AnimationMixer, with Skeleton3D blending it.
const PROFILES := {
    "book": [[12,24,16],[16,30,18],[25,35,20],[28,38,22],[32,42,24]],
    "drink": [[18,28,16],[35,45,26],[38,48,28],[42,52,30],[45,55,32]],
    "rod": [[30,35,22],[50,55,35],[53,58,35],[56,60,38],[58,62,40]],
}
var held_kind := ""
var _bones: Array[int] = []
var _last_kind := ""
var _angles: Array[float] = []

func _validate_bone_names() -> void:
    _bones.clear()
    var skeleton := get_skeleton()
    if skeleton == null:
        return
    for finger in range(1,6):
        for segment in range(1,4):
            _bones.append(skeleton.find_bone("finger%d-%d.R" % [finger,segment]))

func _process_modification_with_delta(delta: float) -> void:
    var skeleton := get_skeleton()
    if skeleton == null:
        return
    if _bones.is_empty():
        _validate_bone_names()
    var wanted := 1.0 if PROFILES.has(held_kind) else 0.0
    influence = move_toward(influence,wanted,delta*7.0)
    if PROFILES.has(held_kind):
        _last_kind = held_kind
    if is_zero_approx(influence) or not PROFILES.has(_last_kind):
        return
    var profile: Array = PROFILES[_last_kind]
    if _angles.is_empty():
        for finger in profile:
            for angle in finger:
                _angles.append(float(angle))
    for index in _bones.size():
        if _bones[index] >= 0:
            var angle: float = profile[index/3][index%3]
            _angles[index] = move_toward(_angles[index],angle,delta*180.0)
            skeleton.set_bone_pose_rotation(_bones[index],Quaternion(Vector3.RIGHT,deg_to_rad(_angles[index])))
