extends CanvasLayer

@export var car: DriftCar

@onready var speed_label: Label = $SpeedLabel
@onready var drift_label: Label = $DriftLabel
@onready var controls_label: Label = $ControlsLabel


func _ready() -> void:
	drift_label.modulate.a = 0.0
	controls_label.text = "A / D or Arrows: steer     Space: drift     R: restart"


func _process(_delta: float) -> void:
	if car == null:
		return
	speed_label.text = "%d km/h" % roundi(car.speed_kmh)
	drift_label.modulate.a = 1.0 if car.is_drifting else 0.0
