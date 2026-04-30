extends Node

# --- Signals ---
signal gold_updated
signal inventory_updated
signal offline_earnings_ready(summary: String)

# --- Currency ---
var gold: int = 0

# --- Inventory ---
var inventory: Dictionary = {}

# --- Economy ---
var item_prices: Dictionary = {
	"Copper Ore": 10, 
	"Wood": 5
}

# --- Skill System ---
var base_xp_to_level: int = 100
var skills: Dictionary = {
	"mining": {
		"xp": 0,
		"level": 1
	},
	"woodcutting": {
		"xp": 0,
		"level": 1
	}
}

# --- Offline Settings ---
const OFFLINE_RATE = 0.5          # 50% of online speed
const MAX_OFFLINE_SECONDS = 28800 # 8 hours
const XP_PER_SECOND = 25.0 / 3.0 # 25 XP every 3 seconds online
const ITEMS_PER_SECOND = 1.0 / 3.0 # 1 item every 3 seconds online

func _ready():
	await get_tree().process_frame
	load_game()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SnippetDB.save_timestamp(int(Time.get_unix_time_from_system()))

func calculate_offline_progress() -> String:
	var last_logout = SnippetDB.load_timestamp()
	if last_logout == 0:
		return ""
	
	var now = int(Time.get_unix_time_from_system())
	var elapsed = min(now - last_logout, MAX_OFFLINE_SECONDS)
	
	if elapsed < 10:
		return ""
	
	# Calculate offline gains at 50% rate
	var offline_xp = int(XP_PER_SECOND * OFFLINE_RATE * elapsed)
	var offline_items = int(ITEMS_PER_SECOND * OFFLINE_RATE * elapsed)
	
	# Award gains
	add_xp("mining", offline_xp)
	add_xp("woodcutting", offline_xp)
	if offline_items > 0:
		add_item("Copper Ore", offline_items)
		add_item("Wood", offline_items)
	
	# Format time away
	var hours = elapsed / 3600
	var minutes = (elapsed % 3600) / 60
	var time_str = ""
	if hours > 0:
		time_str = str(hours) + "h " + str(minutes) + "m"
	else:
		time_str = str(minutes) + "m"
	
	return "⏰ Away for %s\n+%d Mining XP  |  +%d Woodcutting XP\n+%d Copper Ore  |  +%d Wood" % [
		time_str, offline_xp, offline_xp, offline_items, offline_items
	]

func add_xp(skill_name: String, amount: int):
	if skills.has(skill_name):
		skills[skill_name]["xp"] += amount
		var xp_required = skills[skill_name]["level"] * base_xp_to_level
		
		while skills[skill_name]["xp"] >= xp_required:
			skills[skill_name]["xp"] -= xp_required
			skills[skill_name]["level"] += 1
			xp_required = skills[skill_name]["level"] * base_xp_to_level
			print("⭐ LEVEL UP: ", skill_name, " is now level ", skills[skill_name]["level"])
		
		save_game()
	else:
		print("Error: Skill ", skill_name, " doesn't exist.")

func add_item(item_name: String, amount: int):
	if inventory.has(item_name):
		inventory[item_name] += amount
	else:
		inventory[item_name] = amount
	
	inventory_updated.emit()
	save_game()
	print("📦 Collected: ", item_name, " | Total: ", inventory[item_name])

func sell_all_items():
	var total_gain = 0
	for item in inventory.keys():
		if item_prices.has(item):
			total_gain += inventory[item] * item_prices[item]
			inventory[item] = 0
	
	if total_gain > 0:
		add_gold(total_gain)
		inventory_updated.emit()
		save_game()
	else:
		print("⚖️ Market: No items to sell.")

func add_gold(amount: int):
	gold += amount
	gold_updated.emit()
	save_game()
	print("💰 Gold: ", gold)

func save_game():
	SnippetDB.save_player_data(gold, skills)
	SnippetDB.save_inventory(inventory)
	print("💾 Game Saved!")

func load_game():
	var data = SnippetDB.load_player_data()
	if data.is_empty():
		print("📂 No save data found, starting fresh.")
		return
	gold = data["gold"]
	skills["mining"]["xp"] = data["mining_xp"]
	skills["mining"]["level"] = data["mining_level"]
	skills["woodcutting"]["xp"] = data["woodcutting_xp"]
	skills["woodcutting"]["level"] = data["woodcutting_level"]
	inventory = SnippetDB.load_inventory()
	gold_updated.emit()
	inventory_updated.emit()
	print("📂 Game Loaded! Gold: ", gold, " | Inventory items: ", inventory.size())
	
	# Calculate offline progress after loading
	var summary = calculate_offline_progress()
	if summary != "":
		print("🌙 Offline Progress:\n", summary)
		offline_earnings_ready.emit(summary)
	
	# Save new timestamp
	SnippetDB.save_timestamp(int(Time.get_unix_time_from_system()))
