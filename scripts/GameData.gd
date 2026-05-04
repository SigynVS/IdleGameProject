extends Node

signal gold_updated
signal inventory_updated
signal equipment_updated
signal offline_earnings_ready(summary: String)
signal auto_skill_changed(active_station)
signal activity_changed(activity_id: String)
signal activity_progress_updated(activity_id: String, progress: float, seconds_left: float)
signal activity_cycle_completed(activity_id: String, reward_text: String)

var gold: int = 0
var inventory: Dictionary = {}
var equipped: Dictionary = {}

var item_prices: Dictionary = {
	"Copper Ore": 10,
	"Wood": 5,
	"Leather": 8,
	"Iron Ore": 20,
	"Coal": 15,
}

var base_xp_to_level: int = 100

var skills: Dictionary = {
	"woodcutting": {"xp": 0, "level": 1},
	"mining": {"xp": 0, "level": 1},
	"fishing": {"xp": 0, "level": 1},
	"farming": {"xp": 0, "level": 1},
	"hunting": {"xp": 0, "level": 1},
	"smithing": {"xp": 0, "level": 1},
	"crafting": {"xp": 0, "level": 1},
	"fletching": {"xp": 0, "level": 1},
	"herblore": {"xp": 0, "level": 1},
	"cooking": {"xp": 0, "level": 1},
	"firemaking": {"xp": 0, "level": 1},
	"thieving": {"xp": 0, "level": 1},
	"agility": {"xp": 0, "level": 1},
	"slayer": {"xp": 0, "level": 1},
	"prayer": {"xp": 0, "level": 1},
	"magic": {"xp": 0, "level": 1},
	"attack": {"xp": 0, "level": 1},
	"strength": {"xp": 0, "level": 1},
	"defence": {"xp": 0, "level": 1},
	"hitpoints": {"xp": 0, "level": 10},
	"ranged": {"xp": 0, "level": 1},
}

const OFFLINE_RATE = 0.5
const MAX_OFFLINE_SECONDS = 28800

const ACTIVITY_DEFS: Dictionary = {
	"mining": {
		"name": "Mining",
		"skill": "mining",
		"duration": 3.0,
		"xp": 25,
		"items": {"Copper Ore": 1},
		"background": Color(0.12, 0.13, 0.16),
		"accent": Color(0.42, 0.64, 0.86),
		"node_label": "Copper Vein",
		"status": "Mining ore",
	},
	"woodcutting": {
		"name": "Woodcutting",
		"skill": "woodcutting",
		"duration": 3.0,
		"xp": 25,
		"items": {"Wood": 1},
		"background": Color(0.08, 0.18, 0.11),
		"accent": Color(0.34, 0.72, 0.36),
		"node_label": "Oak Tree",
		"status": "Chopping wood",
	},
	"crafting": {
		"name": "Crafting",
		"skill": "crafting",
		"duration": 5.0,
		"xp": 20,
		"requires": {"Wood": 2},
		"items": {"Leather": 1},
		"background": Color(0.18, 0.12, 0.08),
		"accent": Color(0.9, 0.58, 0.24),
		"node_label": "Crafting Bench",
		"status": "Working materials",
	},
	"smithing": {
		"name": "Smithing",
		"skill": "smithing",
		"duration": 4.5,
		"xp": 18,
		"requires": {"Copper Ore": 2},
		"items": {"Iron Ore": 1},
		"background": Color(0.18, 0.13, 0.10),
		"accent": Color(0.84, 0.48, 0.22),
		"node_label": "Anvil",
		"status": "Smelting and hammering",
	},
	"combat": {
		"name": "Combat",
		"skill": "attack",
		"duration": 4.0,
		"xp": 20,
		"extra_xp": {"strength": 10, "defence": 10, "hitpoints": 8},
		"items": {"Leather": 1},
		"background": Color(0.17, 0.07, 0.07),
		"accent": Color(0.85, 0.28, 0.22),
		"node_label": "Training Dummy",
		"status": "Auto battling",
	},
}

var skills_used: Dictionary = {}
var active_activity_id: String = ""
var activity_elapsed: float = 0.0
var activity_running: bool = false

func _ready():
	auto_skill_changed.connect(func(_s): pass)
	await get_tree().process_frame
	load_game()

func _process(delta: float):
	if not activity_running or active_activity_id == "":
		return
	var activity = get_activity(active_activity_id)
	if activity.is_empty():
		stop_activity()
		return
	var duration = get_activity_duration(active_activity_id)
	if not can_run_activity(active_activity_id):
		activity_progress_updated.emit(active_activity_id, 0.0, duration)
		return
	activity_elapsed += delta
	activity_progress_updated.emit(active_activity_id, clamp(activity_elapsed / duration, 0.0, 1.0), max(duration - activity_elapsed, 0.0))
	if activity_elapsed >= duration:
		activity_elapsed -= duration
		complete_activity_cycle(active_activity_id)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SnippetDB.save_timestamp(int(Time.get_unix_time_from_system()))

func get_activity(activity_id: String) -> Dictionary:
	return ACTIVITY_DEFS.get(activity_id, {})

func get_all_activity_ids() -> Array:
	return ACTIVITY_DEFS.keys()

func get_activity_duration(activity_id: String) -> float:
	var activity = get_activity(activity_id)
	if activity.is_empty():
		return 0.0
	var skill = activity.get("skill", "")
	var bonus = get_skill_speed_bonus(skill)
	return max(float(activity.get("duration", 3.0)) * (1.0 - bonus), 0.2)

func can_run_activity(activity_id: String) -> bool:
	var requirements = get_activity(activity_id).get("requires", {})
	return requirements.is_empty() or has_items(requirements)

func start_activity(activity_id: String) -> bool:
	if not ACTIVITY_DEFS.has(activity_id):
		return false
	active_activity_id = activity_id
	activity_elapsed = 0.0
	activity_running = true
	auto_skill_changed.emit(null)
	activity_changed.emit(active_activity_id)
	activity_progress_updated.emit(active_activity_id, 0.0, get_activity_duration(active_activity_id))
	SnippetDB.save_state_value("active_activity_id", active_activity_id)
	save_game()
	return true

func stop_activity():
	activity_running = false
	activity_elapsed = 0.0
	var stopped_activity = active_activity_id
	active_activity_id = ""
	activity_progress_updated.emit(stopped_activity, 0.0, 0.0)
	activity_changed.emit(active_activity_id)
	SnippetDB.save_state_value("active_activity_id", active_activity_id)
	save_game()

func complete_activity_cycle(activity_id: String):
	var activity = get_activity(activity_id)
	if activity.is_empty() or not can_run_activity(activity_id):
		return

	for item_name in activity.get("requires", {}).keys():
		remove_item(item_name, int(activity["requires"][item_name]))

	var skill = activity.get("skill", "")
	var xp = int(activity.get("xp", 0))
	if skill != "" and xp > 0:
		add_xp(skill, xp)

	for extra_skill in activity.get("extra_xp", {}).keys():
		add_xp(extra_skill, int(activity["extra_xp"][extra_skill]))

	for item_name in activity.get("items", {}).keys():
		add_item(item_name, int(activity["items"][item_name]))

	activity_cycle_completed.emit(activity_id, format_activity_reward(activity, 1))

func format_activity_reward(activity: Dictionary, cycles: int) -> String:
	var parts = []
	if activity.has("xp"):
		parts.append("+%d %s XP" % [int(activity["xp"]) * cycles, activity.get("skill", "skill").capitalize()])
	for extra_skill in activity.get("extra_xp", {}).keys():
		parts.append("+%d %s XP" % [int(activity["extra_xp"][extra_skill]) * cycles, extra_skill.capitalize()])
	for item_name in activity.get("items", {}).keys():
		parts.append("+%d %s" % [int(activity["items"][item_name]) * cycles, item_name])
	return ", ".join(parts)

func add_xp(skill_name: String, amount: int):
	if not skills.has(skill_name):
		print("Error: Skill '", skill_name, "' doesn't exist.")
		return
	skills_used[skill_name] = true
	skills[skill_name]["xp"] += amount
	var xp_required = _xp_for_level(skills[skill_name]["level"])
	while skills[skill_name]["xp"] >= xp_required:
		skills[skill_name]["xp"] -= xp_required
		skills[skill_name]["level"] += 1
		xp_required = _xp_for_level(skills[skill_name]["level"])
		print("LEVEL UP: ", skill_name, " is now level ", skills[skill_name]["level"])
	save_game()

func _xp_for_level(level: int) -> int:
	return level * base_xp_to_level

func get_skill_level(skill_name: String) -> int:
	return skills[skill_name]["level"] if skills.has(skill_name) else 0

func get_total_level() -> int:
	var total = 0
	for s in skills.values():
		total += s["level"]
	return total

func add_item(item_name: String, amount: int):
	inventory[item_name] = inventory.get(item_name, 0) + amount
	inventory_updated.emit()
	save_game()
	print("Collected: ", item_name, " | Total: ", inventory[item_name])

func remove_item(item_name: String, amount: int) -> bool:
	if not inventory.has(item_name) or inventory[item_name] < amount:
		return false
	inventory[item_name] -= amount
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	inventory_updated.emit()
	save_game()
	return true

func has_items(requirements: Dictionary) -> bool:
	for item in requirements.keys():
		if inventory.get(item, 0) < requirements[item]:
			return false
	return true

func add_gold(amount: int):
	gold += amount
	gold_updated.emit()
	save_game()
	print("Gold: ", gold)

func sell_all_items():
	var total_gain = 0
	for item in item_prices.keys():
		if inventory.has(item) and inventory[item] > 0:
			total_gain += inventory[item] * item_prices[item]
			inventory.erase(item)
	if total_gain > 0:
		add_gold(total_gain)
		inventory_updated.emit()
		save_game()
	else:
		print("Market: No items to sell.")

func equip_item(item_id: String) -> bool:
	var item = EquipmentData.get_item(item_id)
	if item.is_empty():
		return false
	if not inventory.has(item["name"]) or inventory[item["name"]] <= 0:
		return false
	var slot = item["slot"]
	if equipped.has(slot):
		unequip_slot(slot)
	remove_item(item["name"], 1)
	equipped[slot] = item_id
	equipment_updated.emit()
	save_game()
	print("Equipped: ", item["name"])
	return true

func unequip_slot(slot: String) -> bool:
	if not equipped.has(slot):
		return false
	var item_id = equipped[slot]
	var item = EquipmentData.get_item(item_id)
	equipped.erase(slot)
	add_item(item["name"], 1)
	equipment_updated.emit()
	save_game()
	print("Unequipped: ", item["name"])
	return true

func get_equipped_item(slot: String) -> Dictionary:
	if equipped.has(slot):
		return EquipmentData.get_item(equipped[slot])
	return {}

func get_total_attack() -> int:
	var total = 0
	for slot in equipped.keys():
		total += EquipmentData.get_item(equipped[slot]).get("attack", 0)
	return total

func get_total_defence() -> int:
	var total = 0
	for slot in equipped.keys():
		total += EquipmentData.get_item(equipped[slot]).get("defence", 0)
	return total

func get_skill_speed_bonus(skill_name: String) -> float:
	var total = 0.0
	for slot in equipped.keys():
		var item = EquipmentData.get_item(equipped[slot])
		total += item.get("skill_speed", {}).get(skill_name, 0.0)
	return min(total, 0.75)

func craft_item(item_id: String) -> bool:
	if not EquipmentData.can_craft(item_id):
		print("Cannot craft: ", item_id)
		return false
	var item = EquipmentData.get_item(item_id)
	for mat in item["recipe"].keys():
		remove_item(mat, item["recipe"][mat])
	add_xp(item["craft_skill"], item["craft_xp"])
	add_item(item["name"], 1)
	print("Crafted: ", item["name"])
	return true

func calculate_offline_progress() -> String:
	var last_logout = SnippetDB.load_timestamp()
	if last_logout == 0:
		return ""
	var now = int(Time.get_unix_time_from_system())
	var elapsed = min(now - last_logout, MAX_OFFLINE_SECONDS)
	if elapsed < 10:
		return ""

	var activity_id = active_activity_id if active_activity_id != "" else "mining"
	var activity = get_activity(activity_id)
	if activity.is_empty():
		return ""

	var cycles = int(elapsed / get_activity_duration(activity_id) * OFFLINE_RATE)
	if cycles <= 0:
		return ""

	var requirements = activity.get("requires", {})
	for item_name in requirements.keys():
		cycles = min(cycles, int(inventory.get(item_name, 0) / int(requirements[item_name])))
	if cycles <= 0:
		return ""

	for item_name in requirements.keys():
		remove_item(item_name, int(requirements[item_name]) * cycles)

	var skill = activity.get("skill", "")
	if skill != "" and activity.has("xp"):
		add_xp(skill, int(activity["xp"]) * cycles)
	for extra_skill in activity.get("extra_xp", {}).keys():
		add_xp(extra_skill, int(activity["extra_xp"][extra_skill]) * cycles)
	for item_name in activity.get("items", {}).keys():
		add_item(item_name, int(activity["items"][item_name]) * cycles)

	var hours = elapsed / 3600
	var minutes = (elapsed % 3600) / 60
	var time_str = "%dh %dm" % [hours, minutes] if hours > 0 else "%dm" % minutes

	return "Away for %s\n%s completed %d idle cycles.\n%s" % [
		time_str,
		activity.get("name", activity_id.capitalize()),
		cycles,
		format_activity_reward(activity, cycles)
	]

func save_game():
	SnippetDB.save_player_data(gold, skills, skills_used)
	SnippetDB.save_inventory(inventory)
	SnippetDB.save_equipped(equipped)
	print("Game Saved!")

func load_game():
	var data = SnippetDB.load_player_data()
	if data.is_empty():
		print("No save data found, starting fresh.")
		activity_changed.emit(active_activity_id)
		return
	gold = data.get("gold", 0)
	for skill_name in skills.keys():
		if data.has(skill_name + "_xp"):
			skills[skill_name]["xp"] = data[skill_name + "_xp"]
		if data.has(skill_name + "_level"):
			skills[skill_name]["level"] = data[skill_name + "_level"]
	skills_used = SnippetDB.load_skills_used()
	inventory = SnippetDB.load_inventory()
	equipped = SnippetDB.load_equipped()
	active_activity_id = SnippetDB.load_state_value("active_activity_id", "")
	activity_running = active_activity_id != ""
	gold_updated.emit()
	inventory_updated.emit()
	equipment_updated.emit()
	print("Loaded! Gold: %d | Total Level: %d" % [gold, get_total_level()])

	var summary = calculate_offline_progress()
	if summary != "":
		offline_earnings_ready.emit(summary)
	SnippetDB.save_timestamp(int(Time.get_unix_time_from_system()))
	activity_changed.emit(active_activity_id)
