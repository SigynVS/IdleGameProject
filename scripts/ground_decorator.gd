extends Node2D

# ─── Ground Decorator ────────────────────────────────────────────────────────
# Spawns scattered vegetation sprites and ground colour patches
# to break up the flat uniform green ground.
# ─────────────────────────────────────────────────────────────────────────────

@export var decoration_count: int = 120
@export var seed_value: int = 42

# Play area — match your Ground TileMap bounds
@export var area_min: Vector2 = Vector2(-100, -100)
@export var area_max: Vector2 = Vector2(1100, 1800)

# Vegetation.png — 400×432, 16×16 tiles (25 cols × 27 rows)
const TILE_SIZE := 16
const VEGE_PATH  := "res://assets/Vegetation.png"

# Small grass/plant sprites — [col, row] in the 16px grid
# Row 3: leaf clusters    Row 4: tiny flowers    Row 5: small plants
const GRASS_TILES = [
	[0,3],[1,3],[2,3],[3,3],[4,3],[5,3],
	[0,4],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],
	[0,5],[1,5],[2,5],[3,5],[4,5],
	[0,6],[1,6],[2,6],[3,6],
]

# Colour tints for slight variation on the uniform green ground
const PATCH_COLOURS = [
	Color(0.28, 0.52, 0.22, 0.55),   # darker green patch
	Color(0.38, 0.65, 0.28, 0.45),   # lighter green patch
	Color(0.42, 0.38, 0.18, 0.30),   # subtle dirt hint
	Color(0.30, 0.55, 0.18, 0.40),   # olive green
]

var _vege_tex: Texture2D = null

func _ready():
	z_index = -1  # always below player / objects
	_vege_tex = load(VEGE_PATH)
	_spawn_ground_patches()
	if _vege_tex:
		_spawn_vegetation()
	else:
		push_error("GroundDecorator: Vegetation.png not found at " + VEGE_PATH)

# ─── Ground colour variation ──────────────────────────────────────────────────
func _spawn_ground_patches():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value + 1000

	# Scattered elliptical colour patches using ColorRect stand-ins via polygons
	for i in range(50):
		var cx = rng.randf_range(area_min.x, area_max.x)
		var cy = rng.randf_range(area_min.y, area_max.y)
		var rx = rng.randf_range(20.0, 80.0)
		var ry = rng.randf_range(15.0, 55.0)
		var col = PATCH_COLOURS[rng.randi() % PATCH_COLOURS.size()]

		var poly = Polygon2D.new()
		poly.color = col
		poly.position = Vector2(cx, cy)

		# Build an ellipse
		var pts: PackedVector2Array = []
		var steps := 12
		for s in range(steps):
			var angle = TAU * s / steps
			pts.append(Vector2(cos(angle) * rx, sin(angle) * ry))
		poly.polygon = pts
		add_child(poly)

# ─── Vegetation sprites ───────────────────────────────────────────────────────
func _spawn_vegetation():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in range(decoration_count):
		var pos = Vector2(
			rng.randf_range(area_min.x, area_max.x),
			rng.randf_range(area_min.y, area_max.y)
		)

		var tile = GRASS_TILES[rng.randi() % GRASS_TILES.size()]
		var sprite = Sprite2D.new()
		sprite.texture = _vege_tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			tile[0] * TILE_SIZE,
			tile[1] * TILE_SIZE,
			TILE_SIZE, TILE_SIZE
		)

		# Larger scale so they're clearly visible
		var s = rng.randf_range(1.5, 3.0)
		sprite.scale = Vector2(s, s)

		# Slight tint variation
		var g = rng.randf_range(0.7, 1.0)
		sprite.modulate = Color(g * 0.8, g, g * 0.6)

		# Tiny rotation for organic look
		sprite.rotation_degrees = rng.randf_range(-15.0, 15.0)
		sprite.position = pos
		add_child(sprite)
