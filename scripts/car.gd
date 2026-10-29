extends RigidBody3D
class_name DriftCar

## Arcade drift car.
## The throttle is always on: the player only steers and pulls the handbrake.
## Lateral grip is modelled directly on the velocity, which keeps the car
## predictable while still allowing long slides.

signal crashed
signal recovered

@export var acceleration: float = 5.0
@export var max_speed: float = 42.0
@export var grip: float = 9.0
@export var drift_grip: float = 1.4
@export var steer_strength: float = 2.4
@export var steer_response: float = 7.0
@export var crash_duration: float = 2.0
@export var blink_interval: float = 0.12

var is_drifting: bool = false
var speed_kmh: float = 0.0

var _start_transform: Transform3D = Transform3D.IDENTITY

var is_crashed: bool = false
var _crash_time: float = 0.0


func _ready() -> void:
	_start_transform = global_transform
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if is_crashed:
		_update_crash(delta)
		return
	
	var steer: float = _read_steer()
	is_drifting = _read_drift()

	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var velocity: Vector3 = linear_velocity
	var forward_speed: float = velocity.dot(forward)
	var lateral_speed: float = velocity.dot(right)

	var speed_fraction: float = clampf(forward_speed / max_speed, 0.0, 1.0)
	var accel_now: float = acceleration * (1.0 - speed_fraction * speed_fraction)
	apply_central_force(forward * accel_now * mass)

	var speed_ratio: float = clampf(absf(forward_speed) / 18.0, 0.0, 1.0)
	var direction: float = signf(forward_speed) if absf(forward_speed) > 0.5 else 1.0
	var turn_rate: float = lerpf(
		steer_strength, steer_strength * 0.55, clampf(absf(forward_speed) / max_speed, 0.0, 1.0)
	)
	if is_drifting:
		turn_rate *= 1.35
	var target_yaw: float = -steer * turn_rate * speed_ratio * direction
	var yaw_blend: float = clampf(delta * steer_response, 0.0, 1.0)
	angular_velocity.y = lerpf(angular_velocity.y, target_yaw, yaw_blend)

	var current_grip: float = drift_grip if is_drifting else grip
	var grip_factor: float = 1.0 - exp(-current_grip * delta)
	linear_velocity -= right * lateral_speed * grip_factor

	speed_kmh = linear_velocity.length() * 3.6
	

func _read_steer() -> float:
	var steer: float = 0.0
	if InputMap.has_action("steer_left") and InputMap.has_action("steer_right"):
		steer = Input.get_axis("steer_left", "steer_right")
	if is_zero_approx(steer):
		var left: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
		var right: bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
		if left != right:
			steer = -1.0 if left else 1.0
	return steer


func _read_drift() -> bool:
	if InputMap.has_action("drift") and Input.is_action_pressed("drift"):
		return true
	return Input.is_key_pressed(KEY_SPACE)


func reset_to(spawn_transform: Transform3D) -> void:
	is_crashed = false
	_set_visuals(true)
	global_transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_start_transform = spawn_transform


func respawn() -> void:
	reset_to(_start_transform)

func _on_body_entered(body: Node) -> void:
	if is_crashed or not body.is_in_group("wall"):
		return
	is_crashed = true
	_crash_time = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	crashed.emit()


func _update_crash(delta: float) -> void:
	_crash_time += delta
	linear_velocity = Vector3(0.0, linear_velocity.y, 0.0)
	angular_velocity = Vector3.ZERO
	speed_kmh = 0.0
	is_drifting = false
	_set_visuals(int(_crash_time / blink_interval) % 2 == 0)
	if _crash_time >= crash_duration:
		is_crashed = false
		_set_visuals(true)
		recovered.emit()


func _set_visuals(on: bool) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = on


func place_at(t: Transform3D) -> void:
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
