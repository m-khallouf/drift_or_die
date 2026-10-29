extends Node3D

@onready var track: TrackGenerator = $Track
@onready var terrain: TerrainGenerator = $Terrain
@onready var car: DriftCar = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: CanvasLayer = $HUD

var _start_transform: Transform3D = Transform3D.IDENTITY
var _fall_limit: float = -35.0


func _ready() -> void:
	car.recovered.connect(_on_car_recovered)
	get_window().grab_focus()
	var track_info: Dictionary = track.generate()
	terrain.generate(track_info.centerline, track_info.half_width)

	_start_transform = track_info.start_transform
	car.reset_to(_start_transform)

	camera.target = car
	hud.car = car


func _process(_delta: float) -> void:
	if car.global_position.y < _fall_limit:
		car.reset_to(_start_transform)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R or key.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
		
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		print("key: ", event.as_text(), " pressed=", event.pressed)

func _on_car_recovered() -> void:
	var best: int = 0
	var best_dist: float = INF
	for i in track.centerline.size():
		var d: float = car.global_position.distance_squared_to(track.centerline[i] + Vector3.UP * 1.25)
		if d < best_dist:
			best_dist = d
			best = i

	var pos: Vector3 = track.centerline[best] + Vector3.UP * 1.25
	var t: Transform3D = Transform3D(Basis.IDENTITY, pos).looking_at(pos + track.tangents[best], Vector3.UP)
	car.place_at(t)
