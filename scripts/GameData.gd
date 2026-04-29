extends Node

# --- Signals ---
signal gold_updated
signal inventory_updated

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

func _ready():
	await get_tree().process_frame
	load_game()

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
	else:
		print("⚖️ Market: No items to sell.")

func add_gold(amount: int):
	gold += amount
	gold_updated.emit()
	save_game()
	print("💰 Gold: ", gold)

func save_game():
	SnippetDB.save_player_data(gold, skills)
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
	gold_updated.emit()
	inventory_updated.emit()
	print("📂 Game Loaded! Gold: ", gold)
