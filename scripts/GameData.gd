extends Node

# ═══════════════════════════════════════════════════════════════════════════
# GameData — Centralized game state management
# 
# This singleton manages all player progression, activities, inventory, and
# equipment. It handles both active gameplay and offline progression calculations.
# ═══════════════════════════════════════════════════════════════════════════

# ─── Signals ─────────────────────────────────────────────────────────────────
signal gold_updated
signal inventory_updated
signal equipment_updated
signal offline_earnings_ready(summary: String)
signal auto_skill_changed(active_station)
signal activity_changed(activity_id: String)
signal activity_progress_updated(activity_id: String, progress: float, seconds_left: float)
signal activity_cycle_completed(activity_id: String, reward_text: String)

# ─── Game Balance Constants ──────────────────────────────────────────────────
# These constants define core game balance values. Adjust these to tune the
# game's progression speed and feel.

const OFFLINE_PROGRESS_RATE: float = 0.5  # 50% efficiency while offline
const MAX_OFFLINE_SECONDS: int = 28800    # 8 hours maximum offline time
const MAX_SKILL_SPEED_BONUS: float = 0.75 # Cap speed bonuses at 75% reduction
const BASE_XP_TO_LEVEL: int = 100         # XP formula base value
const MINIMUM_ACTIVITY_DURATION: float = 0.2  # Fastest possible activity time

# ─── Player State ────────────────────────────────────────────────────────────
var gold: int = 0
var inventory: Dictionary = {}
var equipped: Dictionary = {}

# Item prices for selling to the market
var item_prices: Dictionary = {
	"Copper Ore": 10,
	"Wood": 5,
	"Leather": 8,
	"Iron Ore": 20,
	"Coal": 15,
}

var base_xp_to_level: int = 100

# ─── Skills System ───────────────────────────────────────────────────────────
# Each skill tracks experience points and level independently
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

# Tracks which skills have been used at least once (for UI purposes)
var skills_used: Dictionary = {}

# ─── Activity Definitions ────────────────────────────────────────────────────
# Define all available activities with their requirements, rewards, and visuals
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

# ─── Activity State ──────────────────────────────────────────────────────────
var active_activity_id: String = ""
var activity_elapsed: float = 0.0
var activity_running: bool = false

# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready():
	# Connect signal to prevent orphan signal warning
	auto_skill_changed.connect(func(_s): pass)
	
	# Wait one frame to ensure SnippetDB is ready
	await get_tree().process_frame
	load_game()

func _process(delta: float):
	"""Process active activity progress each frame"""
	if not activity_running or active_activity_id == "":
		return
	
	var activity = get_activity(active_activity_id)
	if activity.is_empty():
		stop_activity()
		return
	
	var duration = get_activity_duration(active_activity_id)
	
	# Check if we have required resources
	if not can_run_activity(active_activity_id):
		activity_progress_updated.emit(active_activity_id, 0.0, duration)
		return
	
	# Update progress
	activity_elapsed += delta
	activity_progress_updated.emit(
		active_activity_id,
		clamp(activity_elapsed / duration, 0.0, 1.0),
		max(duration - activity_elapsed, 0.0)
	)
	
	# Complete cycle when duration reached
	if activity_elapsed >= duration:
		activity_elapsed -= duration
		complete_activity_cycle(active_activity_id)

func _notification(what):
	"""Save timestamp when game closes for offline progress calculation"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SnippetDB.save_timestamp(int(Time.get_unix_time_from_system()))

# ─── Activity System ─────────────────────────────────────────────────────────

func get_activity(activity_id: String) -> Dictionary:
	"""Safely retrieve activity definition by ID"""
	return ACTIVITY_DEFS.get(activity_id, {})

func get_all_activity_ids() -> Array:
	"""Get list of all available activity IDs"""
	return ACTIVITY_DEFS.keys()

func get_activity_duration(activity_id: String) -> float:
	"""
	Calculate actual activity duration after applying skill speed bonuses.
	Returns base duration reduced by equipment bonuses, with a minimum cap.
	"""
	var activity = get_activity(activity_id)
	if activity.is_empty():
		return 0.0
	
	var skill = activity.get("skill", "")
	var bonus = get_skill_speed_bonus(skill)
	var base_duration = float(activity.get("duration", 3.0))
	
	# Apply bonus and enforce minimum duration
	return max(base_duration * (1.0 - bonus), MINIMUM_ACTIVITY_DURATION)

func can_run_activity(activity_id: String) -> bool:
	"""
	Check if an activity can currently run.
	Validates that the activity exists and all required items are available.
	"""
	var activity = get_activity(activity_id)
	if activity.is_empty():
		return false
	
	var requirements = activity.get("requires", {})
	return requirements.is_empty() or has_items(requirements)

func start_activity(activity_id: String) -> bool:
	"""
	Start a new activity.
	Returns true if successful, false if the activity doesn't exist.
	"""
	if not ACTIVITY_DEFS.has(activity_id):
		push_error("Attempted to start invalid activity: %s" % activity_id)
		return false
	
	active_activity_id = activity_id
	activity_elapsed = 0.0
	activity_running = true
	
	# Emit signals to update UI
	auto_skill_changed.emit(null)
	activity_changed.emit(active_activity_id)
	activity_progress_updated.emit(
		active_activity_id,
		0.0,
		get_activity_duration(active_activity_id)
	)
	
	# Persist state
	SnippetDB.save_state_value("active_activity_id", active_activity_id)
	save_game()
	
	return true

func stop_activity():
	"""Stop the currently running activity"""
	activity_running = false
	activity_elapsed = 0.0
	var stopped_activity = active_activity_id
	active_activity_id = ""
	
	# Emit signals to update UI
	activity_progress_updated.emit(stopped_activity, 0.0, 0.0)
	activity_changed.emit(active_activity_id)
	
	# Persist state
	SnippetDB.save_state_value("active_activity_id", active_activity_id)
	save_game()

func complete_activity_cycle(activity_id: String):
	"""
	Complete one cycle of an activity.
	Consumes required resources, awards XP and items.
	"""
	var activity = get_activity(activity_id)
	if activity.is_empty():
		push_error("Attempted to complete invalid activity: %s" % activity_id)
		return
	
	if not can_run_activity(activity_id):
		push_warning("Activity %s cannot run - missing requirements" % activity_id)
		return
	
	# Consume required materials
	for item_name in activity.get("requires", {}).keys():
		remove_item(item_name, int(activity["requires"][item_name]))
	
	# Award primary skill XP
	var skill = activity.get("skill", "")
	var xp = int(activity.get("xp", 0))
	if skill != "" and xp > 0:
		add_xp(skill, xp)
	
	# Award secondary skill XP (e.g., combat gives strength, defence, hitpoints)
	for extra_skill in activity.get("extra_xp", {}).keys():
		add_xp(extra_skill, int(activity["extra_xp"][extra_skill]))
	
	# Award items
	for item_name in activity.get("items", {}).keys():
		add_item(item_name, int(activity["items"][item_name]))
	
	# Notify UI of completion
	activity_cycle_completed.emit(activity_id, format_activity_reward(activity, 1))

func format_activity_reward(activity: Dictionary, cycles: int) -> String:
	"""Format activity rewards as a human-readable string"""
	var parts = []
	
	# Primary XP
	if activity.has("xp"):
		parts.append("+%d %s XP" % [
			int(activity["xp"]) * cycles,
			activity.get("skill", "skill").capitalize()
		])
	
	# Secondary XP
	for extra_skill in activity.get("extra_xp", {}).keys():
		parts.append("+%d %s XP" % [
			int(activity["extra_xp"][extra_skill]) * cycles,
			extra_skill.capitalize()
		])
	
	# Items
	for item_name in activity.get("items", {}).keys():
		parts.append("+%d %s" % [
			int(activity["items"][item_name]) * cycles,
			item_name
		])
	
	return ", ".join(parts)

# ─── Skills System ───────────────────────────────────────────────────────────

func add_xp(skill_name: String, amount: int):
	"""
	Add experience to a skill and handle level ups.
	Automatically levels up the skill when enough XP is accumulated.
	"""
	if not skills.has(skill_name):
		push_error("Attempted to add XP to invalid skill: %s" % skill_name)
		return
	
	skills_used[skill_name] = true
	skills[skill_name]["xp"] += amount
	
	# Handle level ups
	var xp_required = _xp_for_level(skills[skill_name]["level"])
	while skills[skill_name]["xp"] >= xp_required:
		skills[skill_name]["xp"] -= xp_required
		skills[skill_name]["level"] += 1
		xp_required = _xp_for_level(skills[skill_name]["level"])
		print("LEVEL UP: %s is now level %d" % [skill_name, skills[skill_name]["level"]])
	
	save_game()

func _xp_for_level(level: int) -> int:
	"""Calculate XP required for the next level"""
	return level * BASE_XP_TO_LEVEL

func get_skill_level(skill_name: String) -> int:
	"""Safely get the level of a skill"""
	if not skills.has(skill_name):
		push_warning("Attempted to get level of invalid skill: %s" % skill_name)
		return 0
	return skills[skill_name]["level"]

func get_total_level() -> int:
	"""Calculate sum of all skill levels"""
	var total = 0
	for skill_data in skills.values():
		total += skill_data["level"]
	return total

# ─── Inventory System ────────────────────────────────────────────────────────

func add_item(item_name: String, amount: int):
	"""Add items to inventory"""
	if amount <= 0:
		push_warning("Attempted to add non-positive amount of items: %d" % amount)
		return
	
	inventory[item_name] = inventory.get(item_name, 0) + amount
	inventory_updated.emit()
	save_game()
	print("Collected: %s | Total: %d" % [item_name, inventory[item_name]])

func remove_item(item_name: String, amount: int) -> bool:
	"""
	Remove items from inventory.
	Returns true if successful, false if not enough items.
	"""
	if amount <= 0:
		push_warning("Attempted to remove non-positive amount of items: %d" % amount)
		return false
	
	if not inventory.has(item_name) or inventory[item_name] < amount:
		return false
	
	inventory[item_name] -= amount
	if inventory[item_name] <= 0:
		inventory.erase(item_name)
	
	inventory_updated.emit()
	save_game()
	return true

func has_items(requirements: Dictionary) -> bool:
	"""Check if inventory contains all required items"""
	for item in requirements.keys():
		if inventory.get(item, 0) < requirements[item]:
			return false
	return true

# ─── Economy ─────────────────────────────────────────────────────────────────

func add_gold(amount: int):
	"""Add gold to the player's wallet"""
	if amount <= 0:
		push_warning("Attempted to add non-positive amount of gold: %d" % amount)
		return
	
	gold += amount
	gold_updated.emit()
	save_game()
	print("Gold: %d" % gold)

func sell_item(item_name: String, amount: int) -> bool:
	if not item_prices.has(item_name):
		return false
	if inventory.get(item_name, 0) < amount:
		return false
	var gain = item_prices[item_name] * amount
	remove_item(item_name, amount)
	add_gold(gain)
	return true

func sell_all_items():
	"""Sell all sellable items in inventory for gold"""
	var total_gain = 0
	
	for item in item_prices.keys():
		if inventory.has(item) and inventory[item] > 0:
			total_gain += inventory[item] * item_prices[item]
			inventory.erase(item)
	
	if total_gain > 0:
		add_gold(total_gain)
		inventory_updated.emit()
		save_game()
		print("Market: Sold items for %d gold" % total_gain)
	else:
		print("Market: No items to sell.")

# ─── Equipment System ────────────────────────────────────────────────────────

func equip_item(item_id: String) -> bool:
	"""
	Equip an item from inventory.
	Returns true if successful, false if item doesn't exist or isn't in inventory.
	"""
	var item = EquipmentData.get_item(item_id)
	if item.is_empty():
		push_error("Attempted to equip invalid item: %s" % item_id)
		return false
	
	if not inventory.has(item["name"]) or inventory[item["name"]] <= 0:
		push_warning("Cannot equip %s - not in inventory" % item["name"])
		return false
	
	var slot = item["slot"]
	
	# Unequip existing item in slot
	if equipped.has(slot):
		unequip_slot(slot)
	
	# Move item from inventory to equipment
	remove_item(item["name"], 1)
	equipped[slot] = item_id
	
	equipment_updated.emit()
	save_game()
	print("Equipped: %s" % item["name"])
	return true

func unequip_slot(slot: String) -> bool:
	"""
	Unequip an item and return it to inventory.
	Returns true if successful, false if slot is empty.
	"""
	if not equipped.has(slot):
		push_warning("Cannot unequip %s - slot is empty" % slot)
		return false
	
	var item_id = equipped[slot]
	var item = EquipmentData.get_item(item_id)
	
	equipped.erase(slot)
	add_item(item["name"], 1)
	
	equipment_updated.emit()
	save_game()
	print("Unequipped: %s" % item["name"])
	return true

func get_equipped_item(slot: String) -> Dictionary:
	"""Get the item currently equipped in a slot"""
	if equipped.has(slot):
		return EquipmentData.get_item(equipped[slot])
	return {}

func get_total_attack() -> int:
	"""Calculate total attack bonus from all equipped items"""
	var total = 0
	for slot in equipped.keys():
		total += EquipmentData.get_item(equipped[slot]).get("attack", 0)
	return total

func get_total_defence() -> int:
	"""Calculate total defence bonus from all equipped items"""
	var total = 0
	for slot in equipped.keys():
		total += EquipmentData.get_item(equipped[slot]).get("defence", 0)
	return total

func get_skill_speed_bonus(skill_name: String) -> float:
	"""
	Calculate total skill speed bonus from equipment.
	Returns a value between 0.0 and MAX_SKILL_SPEED_BONUS.
	"""
	var total = 0.0
	for slot in equipped.keys():
		var item = EquipmentData.get_item(equipped[slot])
		total += item.get("skill_speed", {}).get(skill_name, 0.0)
	
	# Cap the bonus to prevent activities from becoming instant
	return min(total, MAX_SKILL_SPEED_BONUS)

# ─── Crafting System ─────────────────────────────────────────────────────────

func craft_item(item_id: String) -> bool:
	"""
	Craft an item if requirements are met.
	Returns true if successful, false if requirements not met.
	"""
	# Validate crafting is possible BEFORE consuming resources
	if not EquipmentData.can_craft(item_id):
		push_warning("Cannot craft %s - requirements not met" % item_id)
		return false
	
	var item = EquipmentData.get_item(item_id)
	if item.is_empty():
		push_error("Attempted to craft invalid item: %s" % item_id)
		return false
	
	# Consume materials
	for mat in item["recipe"].keys():
		if not remove_item(mat, item["recipe"][mat]):
			push_error("Crafting error: Failed to remove material %s" % mat)
			return false
	
	# Award XP and item
	add_xp(item["craft_skill"], item["craft_xp"])
	add_item(item["name"], 1)
	
	print("Crafted: %s" % item["name"])
	return true

# ─── Offline Progress ────────────────────────────────────────────────────────

func calculate_offline_progress() -> String:
	"""
	Calculate rewards earned while player was offline.
	Returns a summary string for display to the player, or empty string if
	no offline time or unable to calculate.
	"""
	var last_logout = SnippetDB.load_timestamp()
	if last_logout == 0:
		return ""  # First time playing, no offline time
	
	var now = int(Time.get_unix_time_from_system())
	var elapsed = min(now - last_logout, MAX_OFFLINE_SECONDS)
	
	# Don't show popup for very short offline times
	if elapsed < 10:
		return ""
	
	# Use last active activity, or default to mining
	var activity_id = active_activity_id if active_activity_id != "" else "mining"
	var activity = get_activity(activity_id)
	if activity.is_empty():
		return ""
	
	# Calculate how many cycles could have completed
	var full_duration = get_activity_duration(activity_id)
	var cycles = int((elapsed / full_duration) * OFFLINE_PROGRESS_RATE)
	
	if cycles <= 0:
		return ""
	
	# Check if we have enough materials for all cycles
	var requirements = activity.get("requires", {})
	for item_name in requirements.keys():
		var available = inventory.get(item_name, 0)
		var needed_per_cycle = int(requirements[item_name])
		cycles = min(cycles, int(available / needed_per_cycle))
	
	if cycles <= 0:
		return ""
	
	# Process the cycles
	for item_name in requirements.keys():
		remove_item(item_name, int(requirements[item_name]) * cycles)
	
	# Award XP
	var skill = activity.get("skill", "")
	if skill != "" and activity.has("xp"):
		add_xp(skill, int(activity["xp"]) * cycles)
	
	for extra_skill in activity.get("extra_xp", {}).keys():
		add_xp(extra_skill, int(activity["extra_xp"][extra_skill]) * cycles)
	
	# Award items
	for item_name in activity.get("items", {}).keys():
		add_item(item_name, int(activity["items"][item_name]) * cycles)
	
	# Format summary message
	var hours = elapsed / 3600
	var minutes = (elapsed % 3600) / 60
	var time_str = "%dh %dm" % [hours, minutes] if hours > 0 else "%dm" % minutes
	
	return "Away for %s\n%s completed %d idle cycles.\n%s" % [
		time_str,
		activity.get("name", activity_id.capitalize()),
		cycles,
		format_activity_reward(activity, cycles)
	]

# ─── Persistence ─────────────────────────────────────────────────────────────

func save_game():
	"""Save all game state to database"""
	SnippetDB.save_player_data(gold, skills, skills_used)
	SnippetDB.save_inventory(inventory)
	SnippetDB.save_equipped(equipped)
	print("Game Saved!")

func load_game():
	"""Load game state from database"""
	var data = SnippetDB.load_player_data()
	
	if data.is_empty():
		print("No save data found, starting fresh.")
		activity_changed.emit(active_activity_id)
		return
	
	# Load player data
	gold = data.get("gold", 0)
	
	# Load skills
	for skill_name in skills.keys():
		if data.has(skill_name + "_xp"):
			skills[skill_name]["xp"] = data[skill_name + "_xp"]
		if data.has(skill_name + "_level"):
			skills[skill_name]["level"] = data[skill_name + "_level"]
	
	skills_used = SnippetDB.load_skills_used()
	inventory = SnippetDB.load_inventory()
	equipped = SnippetDB.load_equipped()
	
	# Restore active activity
	active_activity_id = SnippetDB.load_state_value("active_activity_id", "")
	activity_running = active_activity_id != ""
	
	# Emit signals to update UI
	gold_updated.emit()
	inventory_updated.emit()
	equipment_updated.emit()
	
	print("Loaded! Gold: %d | Total Level: %d" % [gold, get_total_level()])
	
	# Calculate and display offline progress
	var summary = calculate_offline_progress()
	if summary != "":
		offline_earnings_ready.emit(summary)
	
	# Update timestamp for next offline calculation
	SnippetDB.save_timestamp(int(Time.get_unix_time_from_system()))
	activity_changed.emit(active_activity_id)
