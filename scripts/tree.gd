extends Area2D

@export var skill_type: String = "woodcutting"
@export var xp_amount: int = 25
@export var chop_time: float = 3.0
@export var item_given: String = "Wood"

var is_chopping = false
var auto_mode = false

func _ready():
	input_pickable = true
	GameData.auto_skill_changed.connect(_on_auto_skill_changed)

func _on_auto_skill_changed(active_station):
	if active_station != self and auto_mode:
		auto_mode = false
		print("🌲 Tree auto-skill stopped - another station is active")

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player = get_tree().get_first_node_in_group("player_group")
		if not player:
			print("❌ Player not found in player_group!")
			return
		if auto_mode:
			auto_mode = false
			print("🌲 Tree auto-skill OFF")
			GameData.auto_skill_changed.emit(null)
		else:
			auto_mode = true
			print("🌲 Tree auto-skill ON")
			GameData.auto_skill_changed.emit(self)
			if not is_chopping:
				start_chopping(player)

func _effective_chop_time() -> float:
	var bonus = GameData.get_skill_speed_bonus(skill_type)
	return chop_time * (1.0 - bonus)

func start_chopping(player):
	if is_chopping:
		return
	is_chopping = true
	print("🪓 Starting to chop...")

	var duration = _effective_chop_time()
	if player.has_method("start_work_timer"):
		player.start_work_timer(duration)

	await get_tree().create_timer(duration).timeout

	if GameData:
		GameData.add_xp(skill_type, xp_amount)
		GameData.add_item(item_given, 1)
	else:
		print("❌ Error: GameData not found!")

	is_chopping = false
	print("✅ Done!")

	if auto_mode:
		var p = get_tree().get_first_node_in_group("player_group")
		if p:
			start_chopping(p)
