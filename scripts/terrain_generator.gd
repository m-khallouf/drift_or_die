extends Node3D
class_name TerrainGenerator

## Generates a Perlin-noise landscape around the track.
## The ground is flattened under and next to the road, then blends
## smoothly into the surrounding hills.

@export var terrain_size: float = 520.0
@export var resolution: int = 160
@export var noise_seed: int = 42
@export var noise_frequency: float = 0.006
@export var noise_amplitude: float = 20.0
@export var shoulder_width: float = 10.0
@export var blend_width: float = 22.0
@export var base_height: float = -0.05

var _noise := FastNoiseLite.new()


func generate(centerline: PackedVector3Array, track_half_width: float) -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.5

	var flat_radius: float = track_half_width + shoulder_width
	var blend_end: float = flat_radius + blend_width

	var cells: int = maxi(resolution, 8)
	var spacing: float = terrain_size / float(cells)
	var half_size: float = terrain_size * 0.5
	var verts_per_row: int = cells + 1

	var heights := PackedFloat32Array()
	heights.resize(verts_per_row * verts_per_row)

	var min_distance := _build_distance_field(centerline, cells, spacing, half_size)

	for z in verts_per_row:
		for x in verts_per_row:
			var world_x: float = -half_size + float(x) * spacing
			var world_z: float = -half_size + float(z) * spacing
			var noise_value: float = _noise.get_noise_2d(world_x, world_z) * 0.5 + 0.5
			var hills: float = base_height + clampf(noise_value, 0.0, 1.0) * noise_amplitude
			var distance: float = min_distance[z * verts_per_row + x]
			var blend: float = smoothstep(flat_radius, blend_end, distance)
			heights[z * verts_per_row + x] = lerpf(base_height, hills, blend)

	_build_mesh(heights, cells, spacing, half_size, verts_per_row)


func _build_distance_field(
	centerline: PackedVector3Array, cells: int, spacing: float, half_size: float
) -> PackedFloat32Array:
	var verts_per_row: int = cells + 1
	var distances := PackedFloat32Array()
	distances.resize(verts_per_row * verts_per_row)

	var step: int = maxi(1, centerline.size() / 96)
	for z in verts_per_row:
		var world_z: float = -half_size + float(z) * spacing
		for x in verts_per_row:
			var world_x: float = -half_size + float(x) * spacing
			var closest := INF
			for i in range(0, centerline.size(), step):
				var p: Vector3 = centerline[i]
				var dx: float = p.x - world_x
				var dz: float = p.z - world_z
				var d2: float = dx * dx + dz * dz
				if d2 < closest:
					closest = d2
			distances[z * verts_per_row + x] = sqrt(closest)
	return distances


func _build_mesh(
	heights: PackedFloat32Array,
	cells: int,
	spacing: float,
	half_size: float,
	verts_per_row: int
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in verts_per_row:
		for x in verts_per_row:
			var height: float = heights[z * verts_per_row + x]
			var world_x: float = -half_size + float(x) * spacing
			var world_z: float = -half_size + float(z) * spacing
			var color: Color = _color_for(height)
			st.set_color(color)
			st.set_uv(Vector2(float(x) / float(cells), float(z) / float(cells)))
			st.add_vertex(Vector3(world_x, height, world_z))

	for z in cells:
		for x in cells:
			var i: int = z * verts_per_row + x
			var right: int = i + 1
			var down: int = i + verts_per_row
			var down_right: int = down + 1
			st.add_index(i)
			st.add_index(right)
			st.add_index(down)
			st.add_index(right)
			st.add_index(down_right)
			st.add_index(down)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic = 0.0
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.name = "TerrainMesh"
	instance.mesh = mesh
	add_child(instance)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var collision := CollisionShape3D.new()
	collision.name = "TerrainShape"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)


func _color_for(height: float) -> Color:
	var t: float = clampf((height - base_height) / maxf(noise_amplitude, 0.001), 0.0, 1.0)
	var grass := Color(0.24, 0.42, 0.18)
	var rock := Color(0.42, 0.38, 0.32)
	return grass.lerp(rock, t * t)
