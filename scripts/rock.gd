extends Area2D

@export var skill_type: String = "mining"
@export var xp_amount: int = 25
@export var mine_time: float = 3.0 
@export var reach_distance: float = 200.0
@export var item_given: String = "Copper Ore"

var is_mining = false

func _ready():
	input_pickable = true

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mining: return
		
		var player = get_tree().get_first_node_in_group("player_group")
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < reach_distance:
				start_mining(player)
			else:
				print("Too far from rock! Distance: ", dist)

func start_mining(player):
	is_mining = true
	if player.has_method("start_work_timer"):
		player.start_work_timer(mine_time)
	
	await get_tree().create_timer(mine_time).timeout
	
	if typeof(GameData) != TYPE_NIL:
		GameData.add_xp(skill_type, xp_amount)
		GameData.add_item(item_given, 1)
	
	is_mining = false
