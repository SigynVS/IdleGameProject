extends Node

# ═══════════════════════════════════════════════════════════════════════════
# PartyManager — Manages adventurers and dungeon runs with combat logging
# ═══════════════════════════════════════════════════════════════════════════

# ─── Signals ─────────────────────────────────────────────────────────────────
signal adventurer_recruited(adventurer_id: String)
signal adventurer_updated(adventurer_id: String)
signal dungeon_started(dungeon_id: String)
signal dungeon_progress(dungeon_id: String, phase: String, progress: float)
signal dungeon_completed(dungeon_id: String, loot: Dictionary)
signal combat_log_updated(dungeon_id: String, message: String, color: String)

# ─── Adventurer Classes ──────────────────────────────────────────────────────
const ADVENTURER_CLASSES = {
	"warrior": {
		"name": "Warrior",
		"base_hp": 120,
		"base_attack": 15,
		"base_defence": 12,
		"icon": "⚔️"
	},
	"mage": {
		"name": "Mage",
		"base_hp": 80,
		"base_attack": 20,
		"base_defence": 6,
		"icon": "🔮"
	},
	"ranger": {
		"name": "Ranger",
		"base_hp": 100,
		"base_attack": 18,
		"base_defence": 8,
		"icon": "🏹"
	},
	"cleric": {
		"name": "Cleric",
		"base_hp": 90,
		"base_attack": 10,
		"base_defence": 15,
		"icon": "✨"
	}
}

# ─── Enemy Definitions ───────────────────────────────────────────────────────
const ENEMY_TYPES = {
	"forest": ["Goblin", "Wolf", "Trickster", "Bear"],
	"desert": ["Bandit", "Scorpion", "Snake", "Rat"],
	"battlefield": ["Guard", "Knight", "Archer", "Soldier"]
}

# ─── Dungeon Definitions ─────────────────────────────────────────────────────
const DUNGEON_DEFS = {
	"forest": {
		"name": "Enchanted Forest",
		"difficulty": 1,
		"search_time": 5.0,
		"fight_time": 8.0,
		"loot_time": 3.0,
		"enemy_power": 10,
		"loot_pool": ["Wood", "Leather"],
		"max_adventurers": 3,
		"bg_color": "#2d5016"
	},
	"desert": {
		"name": "The Desert",
		"difficulty": 2,
		"search_time": 6.0,
		"fight_time": 10.0,
		"loot_time": 4.0,
		"enemy_power": 20,
		"loot_pool": ["Copper Ore", "Iron Ore"],
		"max_adventurers": 3,
		"bg_color": "#8b6914"
	},
	"battlefield": {
		"name": "Eternal Battlefield",
		"difficulty": 3,
		"search_time": 8.0,
		"fight_time": 12.0,
		"loot_time": 5.0,
		"enemy_power": 35,
		"loot_pool": ["Iron Ore", "Coal", "Leather"],
		"max_adventurers": 4,
		"bg_color": "#3d1414"
	}
}

# ─── Party Data ──────────────────────────────────────────────────────────────
var adventurers: Dictionary = {}
var next_adventurer_id: int = 1
var max_party_size: int = 9

# ─── Dungeon State ───────────────────────────────────────────────────────────
var active_dungeons: Dictionary = {}

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready():
	await get_tree().process_frame
	load_party_data()

func _process(delta: float):
	for dungeon_id in active_dungeons.keys():
		_update_dungeon(dungeon_id, delta)

# ─── Adventurer Management ───────────────────────────────────────────────────

func recruit_adventurer(class_id: String, adventurer_name: String = "") -> String:
	if not ADVENTURER_CLASSES.has(class_id):
		push_error("Invalid class_id: %s" % class_id)
		return ""
	
	if adventurers.size() >= max_party_size:
		push_warning("Party is full")
		return ""
	
	var class_data = ADVENTURER_CLASSES[class_id]
	var adventurer_id = "adv_%d" % next_adventurer_id
	next_adventurer_id += 1
	
	if adventurer_name == "":
		adventurer_name = "%s %d" % [class_data["name"], next_adventurer_id - 1]
	
	adventurers[adventurer_id] = {
		"name": adventurer_name,
		"class": class_id,
		"level": 1,
		"xp": 0,
		"hp": class_data["base_hp"],
		"attack": class_data["base_attack"],
		"defence": class_data["base_defence"],
		"equipped": {},
		"assigned_dungeon": ""
	}
	
	adventurer_recruited.emit(adventurer_id)
	save_party_data()
	return adventurer_id

func get_adventurer(adventurer_id: String) -> Dictionary:
	return adventurers.get(adventurer_id, {})

func get_all_adventurer_ids() -> Array:
	return adventurers.keys()

func get_idle_adventurers() -> Array:
	var idle = []
	for adv_id in adventurers.keys():
		if adventurers[adv_id]["assigned_dungeon"] == "":
			idle.append(adv_id)
	return idle

func equip_adventurer(adventurer_id: String, item_id: String) -> bool:
	if not adventurers.has(adventurer_id):
		return false
	
	var item = EquipmentData.get_item(item_id)
	if item.is_empty():
		return false
	
	if not GameData.inventory.has(item["name"]) or GameData.inventory[item["name"]] <= 0:
		return false
	
	var slot = item["slot"]
	if adventurers[adventurer_id]["equipped"].has(slot):
		unequip_adventurer(adventurer_id, slot)
	
	GameData.remove_item(item["name"], 1)
	adventurers[adventurer_id]["equipped"][slot] = item_id
	
	adventurer_updated.emit(adventurer_id)
	save_party_data()
	return true

func unequip_adventurer(adventurer_id: String, slot: String) -> bool:
	if not adventurers.has(adventurer_id):
		return false
	
	if not adventurers[adventurer_id]["equipped"].has(slot):
		return false
	
	var item_id = adventurers[adventurer_id]["equipped"][slot]
	var item = EquipmentData.get_item(item_id)
	
	adventurers[adventurer_id]["equipped"].erase(slot)
	GameData.add_item(item["name"], 1)
	
	adventurer_updated.emit(adventurer_id)
	save_party_data()
	return true

func get_adventurer_total_attack(adventurer_id: String) -> int:
	if not adventurers.has(adventurer_id):
		return 0
	
	var adv = adventurers[adventurer_id]
	var total = adv["attack"]
	
	for slot in adv["equipped"].keys():
		var item = EquipmentData.get_item(adv["equipped"][slot])
		total += item.get("attack", 0)
	
	return total

func get_adventurer_total_defence(adventurer_id: String) -> int:
	if not adventurers.has(adventurer_id):
		return 0
	
	var adv = adventurers[adventurer_id]
	var total = adv["defence"]
	
	for slot in adv["equipped"].keys():
		var item = EquipmentData.get_item(adv["equipped"][slot])
		total += item.get("defence", 0)
	
	return total

# ─── Dungeon Management ──────────────────────────────────────────────────────

func start_dungeon(dungeon_id: String, adventurer_ids: Array) -> bool:
	if not DUNGEON_DEFS.has(dungeon_id):
		return false
	
	if active_dungeons.has(dungeon_id):
		return false
	
	var dungeon_def = DUNGEON_DEFS[dungeon_id]
	
	if adventurer_ids.size() == 0:
		return false
	
	if adventurer_ids.size() > dungeon_def["max_adventurers"]:
		return false
	
	for adv_id in adventurer_ids:
		if not adventurers.has(adv_id):
			return false
		if adventurers[adv_id]["assigned_dungeon"] != "":
			return false
	
	for adv_id in adventurer_ids:
		adventurers[adv_id]["assigned_dungeon"] = dungeon_id
	
	active_dungeons[dungeon_id] = {
		"phase": "searching",
		"elapsed": 0.0,
		"adventurers": adventurer_ids.duplicate(),
		"cycles_completed": 0,
		"accumulated_loot": {},
		"combat_log": []
	}
	
	_add_log(dungeon_id, "Party entered %s" % dungeon_def["name"], "white")
	dungeon_started.emit(dungeon_id)
	save_party_data()
	return true

func stop_dungeon(dungeon_id: String) -> Dictionary:
	if not active_dungeons.has(dungeon_id):
		return {}
	
	var dungeon_state = active_dungeons[dungeon_id]
	var loot = dungeon_state["accumulated_loot"]
	
	for adv_id in dungeon_state["adventurers"]:
		if adventurers.has(adv_id):
			adventurers[adv_id]["assigned_dungeon"] = ""
	
	for item_name in loot.keys():
		GameData.add_item(item_name, loot[item_name])
	
	active_dungeons.erase(dungeon_id)
	dungeon_completed.emit(dungeon_id, loot)
	save_party_data()
	return loot

func get_dungeon_state(dungeon_id: String) -> Dictionary:
	return active_dungeons.get(dungeon_id, {})

func get_combat_log(dungeon_id: String) -> Array:
	var state = get_dungeon_state(dungeon_id)
	return state.get("combat_log", [])

func _update_dungeon(dungeon_id: String, delta: float):
	if not active_dungeons.has(dungeon_id):
		return
	
	var state = active_dungeons[dungeon_id]
	var dungeon_def = DUNGEON_DEFS[dungeon_id]
	
	state["elapsed"] += delta
	
	var phase_duration = 0.0
	match state["phase"]:
		"searching":
			phase_duration = dungeon_def["search_time"]
		"fighting":
			phase_duration = dungeon_def["fight_time"]
		"looting":
			phase_duration = dungeon_def["loot_time"]
	
	var progress = clamp(state["elapsed"] / phase_duration, 0.0, 1.0)
	dungeon_progress.emit(dungeon_id, state["phase"], progress)
	
	if state["elapsed"] >= phase_duration:
		state["elapsed"] -= phase_duration
		_advance_dungeon_phase(dungeon_id)

func _advance_dungeon_phase(dungeon_id: String):
	var state = active_dungeons[dungeon_id]
	var dungeon_def = DUNGEON_DEFS[dungeon_id]
	
	match state["phase"]:
		"searching":
			state["phase"] = "fighting"
			var enemy = _get_random_enemy(dungeon_id)
			_add_log(dungeon_id, "Encountered a %s!" % enemy, "yellow")
		
		"fighting":
			var won = _simulate_combat(dungeon_id)
			if won:
				state["phase"] = "looting"
				_add_log(dungeon_id, "Victory!", "green")
			else:
				state["phase"] = "searching"
				_add_log(dungeon_id, "Party was defeated!", "red")
		
		"looting":
			_generate_loot(dungeon_id)
			state["cycles_completed"] += 1
			state["phase"] = "searching"
	
	save_party_data()

func _simulate_combat(dungeon_id: String) -> bool:
	var state = active_dungeons[dungeon_id]
	var dungeon_def = DUNGEON_DEFS[dungeon_id]
	
	# Calculate party power
	var party_attack = 0
	var party_defence = 0
	for adv_id in state["adventurers"]:
		party_attack += get_adventurer_total_attack(adv_id)
		party_defence += get_adventurer_total_defence(adv_id)
	
	var party_power = party_attack + (party_defence * 0.5)
	var enemy_power = dungeon_def["enemy_power"]
	
	# Generate combat log
	for adv_id in state["adventurers"]:
		var adv = get_adventurer(adv_id)
		var damage = get_adventurer_total_attack(adv_id)
		_add_log(dungeon_id, "%s dealt %d damage" % [adv["name"], damage], "cyan")
	
	var enemy_name = _get_random_enemy(dungeon_id)
	_add_log(dungeon_id, "%s dealt %d damage" % [enemy_name, enemy_power], "orange")
	
	# Award XP
	var xp = dungeon_def["difficulty"] * 5
	for adv_id in state["adventurers"]:
		_add_log(dungeon_id, "%s gained +%d XP" % [adventurers[adv_id]["name"], xp], "white")
	
	var win_threshold = enemy_power * 0.8
	return party_power >= win_threshold

func _generate_loot(dungeon_id: String):
	var state = active_dungeons[dungeon_id]
	var dungeon_def = DUNGEON_DEFS[dungeon_id]
	
	var loot_pool = dungeon_def["loot_pool"]
	if loot_pool.size() > 0:
		var item_name = loot_pool[randi() % loot_pool.size()]
		var amount = randi_range(1, 3)
		
		if not state["accumulated_loot"].has(item_name):
			state["accumulated_loot"][item_name] = 0
		state["accumulated_loot"][item_name] += amount
		
		_add_log(dungeon_id, "Found +%d %s" % [amount, item_name], "green")

func _get_random_enemy(dungeon_id: String) -> String:
	if not ENEMY_TYPES.has(dungeon_id):
		return "Enemy"
	var enemies = ENEMY_TYPES[dungeon_id]
	return enemies[randi() % enemies.size()]

func _add_log(dungeon_id: String, message: String, color: String):
	if not active_dungeons.has(dungeon_id):
		return
	
	# Ensure combat_log exists
	if not active_dungeons[dungeon_id].has("combat_log"):
		active_dungeons[dungeon_id]["combat_log"] = []
	
	var log_entry = {"message": message, "color": color}
	active_dungeons[dungeon_id]["combat_log"].append(log_entry)
	
	# Keep only last 50 messages
	if active_dungeons[dungeon_id]["combat_log"].size() > 50:
		active_dungeons[dungeon_id]["combat_log"].pop_front()
	
	combat_log_updated.emit(dungeon_id, message, color)

# ─── Persistence ─────────────────────────────────────────────────────────────

func save_party_data():
	if not SnippetDB:
		return
	SnippetDB.save_adventurers(adventurers, next_adventurer_id)
	SnippetDB.save_dungeons(active_dungeons)

func load_party_data():
	if not SnippetDB:
		return
	var adv_data = SnippetDB.load_adventurers()
	adventurers = adv_data.get("adventurers", {})
	next_adventurer_id = adv_data.get("next_id", 1)
	active_dungeons = SnippetDB.load_dungeons()
	
	# Ensure loaded dungeons have combat_log initialized
	for dungeon_id in active_dungeons.keys():
		if not active_dungeons[dungeon_id].has("combat_log"):
			active_dungeons[dungeon_id]["combat_log"] = []
