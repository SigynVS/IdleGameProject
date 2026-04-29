extends Node2D

func _ready():
	print("🚀 Attempting to prime database...")
	
	if SnippetDB:
		# Using triple quotes allows us to paste the code exactly as it looks!
		var advanced_wood_code = """extends Area2D

@export var skill_type: String = "woodcutting"
@export var xp_amount: int = 25
@export var chop_time: float = 3.0 
@export var reach_distance: float = 125.0

var is_chopping = false

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		var player = get_tree().get_first_node_in_group("player_group")
		if player and global_position.distance_to(player.global_position) < reach_distance:
			start_chopping(player)
"""

		SnippetDB.add_snippet(
			"Advanced Woodcutting", 
			advanced_wood_code, 
			"GDScript", 
			"4.x", 
			"Includes distance checks and exports", 
			"Skilling"
		)
		
		print("✅ Database Primed with Advanced Logic!")
	else:
		print("❌ ERROR: SnippetDB Autoload not found!")
