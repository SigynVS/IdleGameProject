extends Area2D

# --- Settings ---
@export var skill_type: String = "woodcutting"
@export var xp_amount: int = 25
@export var chop_time: float = 3.0 
@export var reach_distance: float = 125.0
@export var item_given: String = "Wood"

# --- State ---
var is_chopping = false

func _ready():
	# This makes sure the Area2D can actually be clicked
	input_pickable = true

func _on_input_event(_viewport, event, _shape_idx):
	# Check for Left Mouse Click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_chopping: 
			return
		
		# Locate player in the "player_group"
		var player = get_tree().get_first_node_in_group("player_group")
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < reach_distance:
				start_chopping(player)
			else:
				print("Too far from tree! Distance: ", int(dist))

func start_chopping(player):
	is_chopping = true
	print("🪓 Starting to chop...")
	
	# Visual feedback for the player
	if player.has_method("start_work_timer"):
		player.start_work_timer(chop_time)
	
	# The "Idle" wait time
	await get_tree().create_timer(chop_time).timeout
	
	# Direct Reward Logic
	if GameData:
		GameData.add_xp(skill_type, xp_amount)
		GameData.add_item(item_given, 1)
	else:
		print("❌ Error: GameData Autoload not found!")
	
	is_chopping = false
	print("✅ Tree chopped!")
