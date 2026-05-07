extends Node

# ═══════════════════════════════════════════════════════════════════════════
# PartyManager — Manages adventurers and dungeon runs with combat logging
# ═══════════════════════════════════════════════════════════════════════════

# ─── Signals ─────────────────────────────────────────────────────────────────
signal adventurer_recruited(adventurer_id: String)
signal adventurer_updated(adventurer_id: String)
signal adventurer_leveled_up(adventurer_id: String, new_level: int)
signal ability_unlocked(adventurer_id: String, ability_name: String)
signal adventurer_died(adventurer_id: String)
signal adventurer_rezzed(adventurer_id: String)
signal dungeon_tier_up(dungeon_id: String, new_tier: int)
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

# ─── Dungeon Tier Definitions ────────────────────────────────────────────────
# Each tier: [cycles_to_unlock, enemy_power_multiplier, creep_per_5_cycles, min_loot, max_loot]
const DUNGEON_TIERS = [
	{"cycles": 0,  "power_mult": 1.0, "creep": 2,  "min_loot": 1, "max_loot": 3},
	{"cycles": 10, "power_mult": 1.5, "creep": 3,  "min_loot": 2, "max_loot": 4},
	{"cycles": 20, "power_mult": 2.5, "creep": 5,  "min_loot": 3, "max_loot": 5},
	{"cycles": 30, "power_mult": 4.0, "creep": 8,  "min_loot": 3, "max_loot": 6},
	{"cycles": 40, "power_mult": 6.0, "creep": 12, "min_loot": 4, "max_loot": 8},
]

# Loot pools per dungeon per tier
const DUNGEON_TIER_LOOT = {
	"forest": [
		["Wood", "Leather"],
		["Wood", "Leather", "Copper Ore"],
		["Wood", "Leather", "Copper Ore", "Iron Ore"],
		["Wood", "Leather", "Iron Ore", "Coal", "Magic Leaf"],
		["Iron Ore", "Coal", "Magic Leaf", "Ancient Bark", "Forest Crystal"],
	],
	"desert": [
		["Copper Ore", "Iron Ore"],
		["Copper Ore", "Iron Ore", "Coal"],
		["Iron Ore", "Coal", "Gold Dust"],
		["Iron Ore", "Coal", "Gold Dust", "Desert Glass"],
		["Coal", "Gold Dust", "Desert Glass", "Sand Ruby", "Ancient Coin"],
	],
	"battlefield": [
		["Iron Ore", "Coal", "Leather"],
		["Iron Ore", "Coal", "Leather", "Steel Shard"],
		["Coal", "Leather", "Steel Shard", "Battle Remnant"],
		["Steel Shard", "Battle Remnant", "War Trophy"],
		["Steel Shard", "War Trophy", "Soul Fragment", "Ancient Relic", "Void Essence"],
	],
}

func get_dungeon_tier(dungeon_id: String) -> int:
	var state := get_dungeon_state(dungeon_id)
	return state.get("tier", 0)

func get_dungeon_current_enemy_power(dungeon_id: String) -> float:
	var state := get_dungeon_state(dungeon_id)
	if state.is_empty():
		return DUNGEON_DEFS[dungeon_id]["enemy_power"]
	return state.get("current_enemy_power", float(DUNGEON_DEFS[dungeon_id]["enemy_power"]))

func _compute_tier_for_cycles(total_cycles: int) -> int:
	var tier := 0
	for i in range(DUNGEON_TIERS.size() - 1, -1, -1):
		if total_cycles >= DUNGEON_TIERS[i]["cycles"]:
			tier = i
			break
	return tier

func _advance_tier_if_needed(dungeon_id: String) -> void:
	var state: Dictionary = active_dungeons[dungeon_id]
	var dungeon_def: Dictionary = DUNGEON_DEFS[dungeon_id]
	var total_cycles: int = state.get("total_cycles", 0)
	var current_tier: int = state.get("tier", 0)
	var new_tier := _compute_tier_for_cycles(total_cycles)
	
	if new_tier > current_tier:
		var tier_data: Dictionary = DUNGEON_TIERS[new_tier]
		var base_power: float = dungeon_def["enemy_power"] * tier_data["power_mult"]
		var old_power: float = state.get("current_enemy_power", float(dungeon_def["enemy_power"]))
		# Reset with floor: max(tier base, 80% of old power)
		var new_power: float = max(base_power, old_power * 0.8)
		state["tier"] = new_tier
		state["current_enemy_power"] = new_power
		_add_log(dungeon_id, "⭐ Tier %d reached! Enemy power: %.0f" % [new_tier + 1, new_power], "yellow")
		dungeon_tier_up.emit(dungeon_id, new_tier + 1)

func _apply_enemy_creep(dungeon_id: String) -> void:
	var state: Dictionary = active_dungeons[dungeon_id]
	var total_cycles: int = state.get("total_cycles", 0)
	var tier: int = state.get("tier", 0)
	var tier_data: Dictionary = DUNGEON_TIERS[tier]
	# Creep every 5 cycles within a tier
	if total_cycles > 0 and total_cycles % 5 == 0:
		state["current_enemy_power"] = state.get("current_enemy_power", float(DUNGEON_DEFS[dungeon_id]["enemy_power"])) + tier_data["creep"]

func _get_tier_loot_pool(dungeon_id: String) -> Array:
	var state := get_dungeon_state(dungeon_id)
	var tier: int = state.get("tier", 0)
	if DUNGEON_TIER_LOOT.has(dungeon_id):
		return DUNGEON_TIER_LOOT[dungeon_id][tier]
	return DUNGEON_DEFS[dungeon_id]["loot_pool"]

func _get_tier_loot_amount(dungeon_id: String) -> int:
	var state := get_dungeon_state(dungeon_id)
	var tier: int = state.get("tier", 0)
	var tier_data: Dictionary = DUNGEON_TIERS[tier]
	return randi_range(tier_data["min_loot"], tier_data["max_loot"])

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

# ─── XP & Leveling ───────────────────────────────────────────────────────────
const MAX_LEVEL := 99

var _xp_table: Array[int] = []

func _build_xp_table() -> void:
	_xp_table.resize(MAX_LEVEL + 1)
	_xp_table[0] = 0
	_xp_table[1] = 0
	for lvl in range(2, MAX_LEVEL + 1):
		var total := 0
		for i in range(1, lvl):
			total += floori(float(i) + 300.0 * pow(2.0, i / 7.0)) / 4
		_xp_table[lvl] = total

func level_from_xp(xp: int) -> int:
	for lvl in range(MAX_LEVEL, 0, -1):
		if xp >= _xp_table[lvl]:
			return lvl
	return 1

func xp_to_next_level(xp: int) -> int:
	var lvl := level_from_xp(xp)
	if lvl >= MAX_LEVEL:
		return 0
	return _xp_table[lvl + 1] - xp

func xp_progress_in_level(xp: int) -> float:
	var lvl := level_from_xp(xp)
	if lvl >= MAX_LEVEL:
		return 1.0
	var xp_this_level := xp - _xp_table[lvl]
	var xp_needed := _xp_table[lvl + 1] - _xp_table[lvl]
	return float(xp_this_level) / max(xp_needed, 1)

# ─── Stat Scaling ─────────────────────────────────────────────────────────────
const STAT_GROWTH = {
	"warrior": {"hp": 12, "attack": 3,  "defence": 4},
	"mage":    {"hp": 6,  "attack": 6,  "defence": 2},
	"ranger":  {"hp": 8,  "attack": 5,  "defence": 3},
	"cleric":  {"hp": 10, "attack": 2,  "defence": 5},
}

func get_player_agility_bonus() -> float:
	var agility_level := GameData.get_skill_level("agility")
	return (float(agility_level) / 10.0) * 0.1

func get_player_hp_bonus() -> int:
	var hp_level := GameData.get_skill_level("hitpoints")
	return max(0, hp_level - 10)

func get_prayer_rez_time() -> float:
	# max(30, 300 - (prayer_level^2 / 37.0))
	# Lv1=~300s  Lv25=~283s  Lv50=~232s  Lv75=~148s  Lv99=30s
	var prayer_level: float = GameData.get_skill_level("prayer")
	return max(30.0, 300.0 - (prayer_level * prayer_level / 37.0))

func get_prayer_rez_hp_percent() -> float:
	# Lv1=~1%  Lv50=~50%  Lv99=100%
	var prayer_level := GameData.get_skill_level("prayer")
	return clamp(prayer_level / 99.0, 0.01, 1.0)

func get_scaled_stats(adv: Dictionary) -> Dictionary:
	var lvl := level_from_xp(adv.get("xp", 0))
	var base: Dictionary = ADVENTURER_CLASSES[adv["class"]].duplicate()
	var g: Dictionary = STAT_GROWTH[adv["class"]]
	var hp_bonus := get_player_hp_bonus()
	return {
		"hp":      base["base_hp"]      + g["hp"]      * (lvl - 1) + hp_bonus,
		"attack":  base["base_attack"]  + g["attack"]  * (lvl - 1),
		"defence": base["base_defence"] + g["defence"] * (lvl - 1),
	}

# ─── Abilities ────────────────────────────────────────────────────────────────
const ADVENTURER_ABILITIES = {
	"warrior": {10: "Shield Bash",  25: "Battle Cry",   50: "Whirlwind",      75: "Juggernaut",   99: "Titan's Wrath"},
	"mage":    {10: "Frost Bolt",   25: "Mana Shield",  50: "Blizzard",       75: "Arcane Surge", 99: "Meteor"},
	"ranger":  {10: "Quick Shot",   25: "Camouflage",   50: "Rain of Arrows", 75: "Eagle Eye",    99: "Deadeye"},
	"cleric":  {10: "Minor Heal",   25: "Bless",        50: "Holy Nova",      75: "Revive",       99: "Divine Intervention"},
}

func _award_xp(adv_id: String, amount: int) -> void:
	if not adventurers.has(adv_id):
		return
	var adv: Dictionary = adventurers[adv_id]
	var old_level := level_from_xp(adv.get("xp", 0))
	adv["xp"] = adv.get("xp", 0) + amount
	var new_level := level_from_xp(adv["xp"])
	if new_level > old_level:
		_on_level_up(adv_id, old_level, new_level)

func _on_level_up(adv_id: String, old_lvl: int, new_lvl: int) -> void:
	var adv: Dictionary = adventurers[adv_id]
	var adv_name: String = adv.get("name", "Adventurer")
	var dungeon_id: String = adv.get("assigned_dungeon", "")
	for lvl in range(old_lvl + 1, new_lvl + 1):
		_add_log(dungeon_id, "⭐ %s reached level %d!" % [adv_name, lvl], "yellow")
		var milestones := [10, 25, 50, 75, 99]
		if lvl in milestones:
			_unlock_ability(adv_id, lvl)
	adventurer_leveled_up.emit(adv_id, new_lvl)
	save_party_data()

func _unlock_ability(adv_id: String, level: int) -> void:
	var adv: Dictionary = adventurers[adv_id]
	var ability: String = ADVENTURER_ABILITIES[adv["class"]].get(level, "")
	if ability == "":
		return
	if not adv.has("abilities"):
		adv["abilities"] = []
	if ability in adv["abilities"]:
		return
	adv["abilities"].append(ability)
	var dungeon_id: String = adv.get("assigned_dungeon", "")
	_add_log(dungeon_id, "✨ %s unlocked %s!" % [adv.get("name", "Adventurer"), ability], "white")
	ability_unlocked.emit(adv_id, ability)

# ─── Party Data ──────────────────────────────────────────────────────────────
var adventurers: Dictionary = {}
var next_adventurer_id: int = 1
var max_party_size: int = 9

# ─── Dungeon State ───────────────────────────────────────────────────────────
var active_dungeons: Dictionary = {}

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready():
	_build_xp_table()
	await get_tree().process_frame
	load_party_data()

func _process(delta: float):
	_tick_rez_timers(delta)
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
		"abilities": [],
		"hp": class_data["base_hp"],
		"attack": class_data["base_attack"],
		"defence": class_data["base_defence"],
		"equipped": {},
		"assigned_dungeon": "",
		"dead": false,
		"rez_elapsed": 0.0,
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
		if adventurers[adv_id]["assigned_dungeon"] == "" and not adventurers[adv_id].get("dead", false):
			idle.append(adv_id)
	return idle

func _kill_adventurer(adv_id: String) -> void:
	if not adventurers.has(adv_id):
		return
	var adv: Dictionary = adventurers[adv_id]
	adv["dead"] = true
	adv["rez_elapsed"] = 0.0
	adv["assigned_dungeon"] = ""
	_add_log("", "💀 %s has fallen! Rezzing in %.0fs..." % [adv.get("name", "Adventurer"), get_prayer_rez_time()], "red")
	adventurer_died.emit(adv_id)
	save_party_data()

func _tick_rez_timers(delta: float) -> void:
	for adv_id in adventurers.keys():
		var adv: Dictionary = adventurers[adv_id]
		if not adv.get("dead", false):
			continue
		adv["rez_elapsed"] = adv.get("rez_elapsed", 0.0) + delta
		var rez_time := get_prayer_rez_time()
		if adv["rez_elapsed"] >= rez_time:
			_rez_adventurer(adv_id)

func _rez_adventurer(adv_id: String) -> void:
	if not adventurers.has(adv_id):
		return
	var adv: Dictionary = adventurers[adv_id]
	var scaled := get_scaled_stats(adv)
	var rez_hp := int(scaled["hp"] * get_prayer_rez_hp_percent())
	adv["dead"] = false
	adv["rez_elapsed"] = 0.0
	_add_log("", "✨ %s has been rezzed with %d HP!" % [adv.get("name", "Adventurer"), rez_hp], "white")
	adventurer_rezzed.emit(adv_id)
	save_party_data()

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
	var scaled: Dictionary = get_scaled_stats(adv)
	var total = scaled["attack"]
	for slot in adv["equipped"].keys():
		var item = EquipmentData.get_item(adv["equipped"][slot])
		total += item.get("attack", 0)
	return total

func get_adventurer_total_defence(adventurer_id: String) -> int:
	if not adventurers.has(adventurer_id):
		return 0
	var adv = adventurers[adventurer_id]
	var scaled: Dictionary = get_scaled_stats(adv)
	var total = scaled["defence"]
	for slot in adv["equipped"].keys():
		var item = EquipmentData.get_item(adv["equipped"][slot])
		total += item.get("defence", 0)
	return total

func get_adventurer_level(adventurer_id: String) -> int:
	if not adventurers.has(adventurer_id):
		return 1
	return level_from_xp(adventurers[adventurer_id].get("xp", 0))

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
		"total_cycles": 0,
		"tier": 0,
		"current_enemy_power": float(DUNGEON_DEFS[dungeon_id]["enemy_power"]),
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
	
	var agility_reduction := get_player_agility_bonus()
	var phase_duration = 0.0
	match state["phase"]:
		"searching":
			phase_duration = max(1.0, dungeon_def["search_time"] - agility_reduction)
		"fighting":
			phase_duration = dungeon_def["fight_time"]
		"looting":
			phase_duration = max(1.0, dungeon_def["loot_time"] - agility_reduction)
	
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
				# Kill all adventurers in the party
				for adv_id in state["adventurers"].duplicate():
					_kill_adventurer(adv_id)
				# Remove dead adventurers from dungeon party
				state["adventurers"] = state["adventurers"].filter(
					func(id): return not adventurers.get(id, {}).get("dead", false)
				)
				if state["adventurers"].is_empty():
					_add_log(dungeon_id, "All adventurers have fallen - dungeon abandoned!", "red")
					active_dungeons.erase(dungeon_id)
					dungeon_completed.emit(dungeon_id, {})
					return
		
		"looting":
			_generate_loot(dungeon_id)
			state["cycles_completed"] += 1
			state["total_cycles"] = state.get("total_cycles", 0) + 1
			state["phase"] = "searching"
			_apply_enemy_creep(dungeon_id)
			_advance_tier_if_needed(dungeon_id)
			var current_power: float = state.get("current_enemy_power", float(dungeon_def["enemy_power"]))
			var completion_xp: int = 50 + (int(current_power) * 2)
			for adv_id in state["adventurers"]:
				_award_xp(adv_id, completion_xp)
	
	save_party_data()

func _simulate_combat(dungeon_id: String) -> bool:
	var state = active_dungeons[dungeon_id]
	var dungeon_def = DUNGEON_DEFS[dungeon_id]
	var enemy_power: float = state.get("current_enemy_power", float(dungeon_def["enemy_power"]))
	
	# Calculate party power
	var party_attack = 0
	var party_defence = 0
	for adv_id in state["adventurers"]:
		party_attack += get_adventurer_total_attack(adv_id)
		party_defence += get_adventurer_total_defence(adv_id)
	
	var party_power = party_attack + (party_defence * 0.5)
	
	# Generate combat log
	for adv_id in state["adventurers"]:
		var adv = get_adventurer(adv_id)
		var damage = get_adventurer_total_attack(adv_id)
		_add_log(dungeon_id, "%s dealt %d damage" % [adv["name"], damage], "cyan")
	
	var enemy_name = _get_random_enemy(dungeon_id)
	_add_log(dungeon_id, "%s dealt %.0f damage" % [enemy_name, enemy_power], "orange")
	
	# Award XP from damage dealt
	var damage_xp: int = int(enemy_power) * 4
	for adv_id in state["adventurers"]:
		_award_xp(adv_id, damage_xp)
	
	var win_threshold = enemy_power * 0.8
	return party_power >= win_threshold

func _generate_loot(dungeon_id: String):
	var state = active_dungeons[dungeon_id]
	var loot_pool := _get_tier_loot_pool(dungeon_id)
	var amount := _get_tier_loot_amount(dungeon_id)
	if loot_pool.size() > 0:
		var item_name: String = loot_pool[randi() % loot_pool.size()]
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
	
	# Backwards compat: ensure all fields exist on loaded adventurers
	for adv_id in adventurers.keys():
		adventurers[adv_id]["xp"] = adventurers[adv_id].get("xp", 0)
		adventurers[adv_id]["abilities"] = adventurers[adv_id].get("abilities", [])
		adventurers[adv_id]["dead"] = adventurers[adv_id].get("dead", false)
		adventurers[adv_id]["rez_elapsed"] = adventurers[adv_id].get("rez_elapsed", 0.0)
	
	# Ensure loaded dungeons have combat_log initialized
	for dungeon_id in active_dungeons.keys():
		if not active_dungeons[dungeon_id].has("combat_log"):
			active_dungeons[dungeon_id]["combat_log"] = []
