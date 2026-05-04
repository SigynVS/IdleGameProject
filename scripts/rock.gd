extends Area2D

@export var skill_type: String = "mining"
@export var xp_amount: int = 25
@export var mine_time: float = 3.0
@export var reach_distance: float = 200.0
@export var item_given: String = "Copper Ore"

var is_mining = false
var auto_mode = false

func _ready():
	input_pickable = true
	GameData.auto_skill_changed.connect(_on_auto_skill_changed)

func _on_auto_skill_changed(active_station):
	if active_station != self and auto_mode:
		auto_mode = false
		print("🪨 Rock auto-skill stopped - another station is active")

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player = get_tree().get_first_node_in_group("player_group")
		if not player:
			return
		if global_position.distance_to(player.global_position) >= reach_distance:
			print("Too far from rock!")
			return
		if auto_mode:
			auto_mode = false
			print("🪨 Rock auto-skill OFF")
			GameData.auto_skill_changed.emit(null)
		else:
			auto_mode = true
			print("🪨 Rock auto-skill ON")
			GameData.auto_skill_changed.emit(self)
			if not is_mining:
				start_mining(player)

func _effective_mine_time() -> float:
	var bonus = GameData.get_skill_speed_bonus(skill_type)
	return mine_time * (1.0 - bonus)

func start_mining(player):
	if is_mining:
		return
	is_mining = true

	var duration = _effective_mine_time()
	if player.has_method("start_work_timer"):
		player.start_work_timer(duration)

	await get_tree().create_timer(duration).timeout

	if GameData:
		GameData.add_xp(skill_type, xp_amount)
		GameData.add_item(item_given, 1)

	is_mining = false

	if auto_mode:
		var p = get_tree().get_first_node_in_group("player_group")
		if p:
			start_mining(p)
