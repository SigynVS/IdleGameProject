extends Node2D

# ═══════════════════════════════════════════════════════════════════════════
# Main — Game entry point and scene initialization
#
# This script handles initial game setup, including database priming and
# transitioning from the old movement-based interface to the new idle interface.
# ═══════════════════════════════════════════════════════════════════════════

func _ready():
	"""Initialize game systems and UI"""
	_prime_snippet_db()
	_setup_idle_interface()

func _prime_snippet_db():
	"""
	Initialize the snippet database with example content.
	
	This is a development feature that adds sample code snippets to the database.
	In a production build, this would likely be removed or moved to a separate
	dev tools module.
	"""
	print("Priming snippet database...")
	
	if not SnippetDB:
		push_error("SnippetDB Autoload not found!")
		return
	
	# Example snippet demonstrating idle activity system
	var example_code = """extends Area2D

@export var skill_type: String = "woodcutting"
@export var xp_amount: int = 25
@export var chop_time: float = 3.0

func start_chopping():
	GameData.start_activity(skill_type)
"""
	
	SnippetDB.add_snippet(
		"Idle Woodcutting",
		example_code,
		"GDScript",
		"4.x",
		"Starts a station-based idle woodcutting activity",
		"Skilling"
	)
	
	print("Snippet database primed successfully!")

func _setup_idle_interface():
	"""
	Set up the idle activity interface.
	
	The game originally used a movement-based system where the player would
	walk around and interact with resource nodes. We've transitioned to an
	idle interface where activities run automatically from a menu system.
	
	This function hides the old movement-based nodes (keeping them for potential
	future use) and creates the new idle UI layer. In a future refactor, the old
	nodes should either be deleted or moved to a separate scene file.
	"""
	# Hide old movement-based gameplay nodes
	# TODO: Consider moving these to a separate scene or removing entirely
	for node_name in ["Player", "rock", "Tree", "Ground"]:
		var old_node = get_node_or_null(node_name)
		if old_node:
			old_node.visible = false
			old_node.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Create the new idle activity view
	var activity_view = CanvasLayer.new()
	activity_view.name = "IdleActivityView"
	activity_view.set_script(load("res://scripts/idle_activity_view.gd"))
	add_child(activity_view)
	
	print("Idle interface initialized")
