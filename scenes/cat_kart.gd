extends VehicleBody3D
## Drive script for the cat kart (Godot 4.x).
## Scene setup is described in README.md. Wheel names match the nodes in cat_kart.glb.

@export var max_engine_force: float = 900.0
@export var max_brake: float = 25.0
@export var max_steer_deg: float = 28.0
@export var steer_speed: float = 4.0

func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("ui_down", "ui_up")
	var steer_in := Input.get_axis("ui_right", "ui_left")

	# Steering eases toward the target, and tightens up at speed.
	var speed_factor := clampf(1.0 - linear_velocity.length() / 60.0, 0.35, 1.0)
	var target_steer := deg_to_rad(max_steer_deg) * steer_in * speed_factor
	steering = move_toward(steering, target_steer, steer_speed * delta)

	if throttle < 0.0 and linear_velocity.dot(-global_transform.basis.z) > 1.0:
		# Pressing back while still rolling forward = brake first, then reverse.
		engine_force = 0.0
		brake = max_brake
	else:
		brake = 0.0
		engine_force = throttle * max_engine_force

	if Input.is_key_pressed(KEY_SPACE):
		brake = max_brake
