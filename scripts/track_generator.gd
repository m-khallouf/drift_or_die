extends Node3D
class_name TrackGenerator

## Builds a closed, procedurally generated racing loop.
## The loop is a Catmull-Rom spline through points placed around a circle
## with a varying radius, so every run produces a different circuit.

@export var track_width: float = 14.0
@export var base_radius: float = 80.0
@export var radius_variation: float = 10.0
@export var control_point_count: int = 10
@export var samples_per_segment: int = 18
@export var seed_value: int = 1337
@export var road_height: float = 0.08

var centerline: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var half_width: float = 7.0
var start_transform: Transform3D = Transform3D.IDENTITY


func generate() -> Dictionary:
	half_width = track_width * 0.5
	_build_centerline()
	_build_tangents()
	_build_road()
	_build_edge_lines()
	_build_collision()
	start_transform = _make_start_transform()

	return {
		"centerline": centerline,
		"half_width": half_width,
		"start_transform": start_transform,
	}


func _build_centerline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var control_points: Array[Vector3] = []
	var count: int = maxi(control_point_count, 4)
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		var radius: float = base_radius + rng.randf_range(-radius_variation, radius_variation)
		control_points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))

	var samples_per_segment: int = maxi(self.samples_per_segment, 4)
	centerline = PackedVector3Array()
	var total: int = count * samples_per_segment
	for i in total:
		var segment: int = i / samples_per_segment
		var t: float = float(i % samples_per_segment) / float(samples_per_segment)
		var p0: Vector3 = control_points[(segment - 1 + count) % count]
		var p1: Vector3 = control_points[segment % count]
		var p2: Vector3 = control_points[(segment + 1) % count]
		var p3: Vector3 = control_points[(segment + 2) % count]
		centerline.append(_catmull_rom(p0, p1, p2, p3, t))


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _build_tangents() -> void:
	var n: int = centerline.size()
	tangents.resize(n)
	for i in n:
		var prev: Vector3 = centerline[(i - 1 + n) % n]
		var next: Vector3 = centerline[(i + 1) % n]
		tangents[i] = (next - prev).normalized()


func _build_road() -> void:
	var mesh: ArrayMesh = _build_ribbon(half_width, -half_width, road_height)
	mesh.surface_set_material(0, _road_material())

	var instance := MeshInstance3D.new()
	instance.name = "Road"
	instance.mesh = mesh
	add_child(instance)
	_road_mesh = mesh


var _road_mesh: ArrayMesh


func _build_edge_lines() -> void:
	var line_mesh: ArrayMesh = _build_ribbon(
		half_width - 0.15, half_width - 0.55, road_height + 0.02
	)
	line_mesh = _add_ribbon_to_mesh(
		line_mesh, -half_width + 0.55, -half_width + 0.15, road_height + 0.02
	)
	for surface in line_mesh.get_surface_count():
		line_mesh.surface_set_material(surface, _line_material())

	var instance := MeshInstance3D.new()
	instance.name = "EdgeLines"
	instance.mesh = line_mesh
	add_child(instance)


func _build_ribbon(offset_a: float, offset_b: float, y: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	return _add_ribbon_to_mesh(mesh, offset_a, offset_b, y)


func _add_ribbon_to_mesh(mesh: ArrayMesh, offset_a: float, offset_b: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = centerline.size()

	for i in n:
		var point: Vector3 = centerline[i]
		var side: Vector3 = tangents[i].cross(Vector3.UP).normalized()
		st.add_vertex(point + side * offset_a + Vector3.UP * y)
		st.add_vertex(point + side * offset_b + Vector3.UP * y)

	for i in n:
		var next: int = (i + 1) % n
		var a: int = i * 2
		var b: int = a + 1
		var c: int = next * 2
		var d: int = c + 1
		st.add_index(a)
		st.add_index(b)
		st.add_index(c)
		st.add_index(b)
		st.add_index(d)
		st.add_index(c)

	st.generate_normals()
	st.commit(mesh)
	return mesh


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TrackBody"
	var shape := CollisionShape3D.new()
	shape.name = "TrackShape"
	shape.shape = _road_mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


func _make_start_transform() -> Transform3D:
	var spawn: Vector3 = centerline[0] + Vector3.UP * 1.25
	return Transform3D(Basis.IDENTITY, spawn).looking_at(spawn + tangents[0], Vector3.UP)


func _road_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.09)
	mat.roughness = 0.9
	mat.metallic = 0.0
	return mat


func _line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.9)
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.6, 0.55)
	mat.emission_energy_multiplier = 0.4
	return mat
