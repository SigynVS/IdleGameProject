extends Node2D

func _ready():
	_prime_snippet_db()
	_convert_to_idle_layout()

func _prime_snippet_db():
	print("Attempting to prime database...")
	if not SnippetDB:
		print("ERROR: SnippetDB Autoload not found!")
		return

	var advanced_wood_code = """extends Area2D

@export var skill_type: String = "woodcutting"
@export var xp_amount: int = 25
@export var chop_time: float = 3.0

func start_chopping():
	GameData.start_activity(skill_type)
"""
	SnippetDB.add_snippet(
		"Idle Woodcutting",
		advanced_wood_code,
		"GDScript",
		"4.x",
		"Starts a station-based idle woodcutting activity",
		"Skilling"
	)
	print("Database primed!")

func _convert_to_idle_layout():
	for node_name in ["Player", "rock", "Tree", "Ground"]:
		var old_node = get_node_or_null(node_name)
		if old_node:
			old_node.visible = false
			old_node.process_mode = Node.PROCESS_MODE_DISABLED

	var activity_view = CanvasLayer.new()
	activity_view.name = "IdleActivityView"
	activity_view.set_script(load("res://scripts/idle_activity_view.gd"))
	add_child(activity_view)
