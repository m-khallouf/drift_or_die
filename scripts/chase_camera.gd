extends Camera3D
class_name ChaseCamera

@export var target: Node3D
@export var distance: float = 9.5
@export var height: float = 4.2
@export var look_height: float = 1.2
@export var position_smoothing: float = 5.0
@export var rotation_smoothing: float = 4.0

var _yaw: float = 0.0


func _ready() -> void:
	if target != null:
		_snap_to_target()


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var target_yaw: float = target.global_transform.basis.get_euler().y
	_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * rotation_smoothing, 0.0, 1.0))

	var offset: Vector3 = Vector3(0.0, height, distance).rotated(Vector3.UP, _yaw)
	var desired_position: Vector3 = target.global_position + offset
	var blend: float = clampf(delta * position_smoothing, 0.0, 1.0)
	global_position = global_position.lerp(desired_position, blend)
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func _snap_to_target() -> void:
	_yaw = target.global_transform.basis.get_euler().y
	var offset: Vector3 = Vector3(0.0, height, distance).rotated(Vector3.UP, _yaw)
	global_position = target.global_position + offset
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)
