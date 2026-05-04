extends Node

# ─────────────────────────────────────────────────────────────────────────────
# EquipmentData — item definitions, crafting recipes, and stat lookups
#
# Each item entry:
#   name         : display name
#   slot         : "helmet" | "chest" | "legs" | "boots" | "weapon" | "offhand"
#   attack       : flat attack bonus
#   defence      : flat defence bonus
#   skill_speed  : Dictionary  skill_name → speed multiplier reduction (0.0–1.0)
#                  e.g. {"woodcutting": 0.1} = 10% faster woodcutting
#   recipe       : Dictionary  item_name → amount required
#   craft_skill  : skill that gains XP when crafting
#   craft_level  : minimum skill level required
#   craft_xp     : XP awarded on craft
# ─────────────────────────────────────────────────────────────────────────────

const ITEMS: Dictionary = {

	# ── Weapons ────────────────────────────────────────────────────────────────
	"copper_sword": {
		"name": "Copper Sword",
		"slot": "weapon",
		"attack": 5, "defence": 0,
		"skill_speed": {},
		"recipe": {"Copper Ore": 5},
		"craft_skill": "smithing", "craft_level": 1, "craft_xp": 30,
	},
	"iron_sword": {
		"name": "Iron Sword",
		"slot": "weapon",
		"attack": 12, "defence": 0,
		"skill_speed": {},
		"recipe": {"Iron Ore": 5},
		"craft_skill": "smithing", "craft_level": 15, "craft_xp": 60,
	},
	"steel_sword": {
		"name": "Steel Sword",
		"slot": "weapon",
		"attack": 22, "defence": 0,
		"skill_speed": {},
		"recipe": {"Iron Ore": 3, "Coal": 3},
		"craft_skill": "smithing", "craft_level": 30, "craft_xp": 120,
	},
	"wood_staff": {
		"name": "Wooden Staff",
		"slot": "weapon",
		"attack": 3, "defence": 0,
		"skill_speed": {"magic": 0.05},
		"recipe": {"Wood": 8},
		"craft_skill": "crafting", "craft_level": 1, "craft_xp": 25,
	},
	"shortbow": {
		"name": "Shortbow",
		"slot": "weapon",
		"attack": 8, "defence": 0,
		"skill_speed": {},
		"recipe": {"Wood": 5},
		"craft_skill": "fletching", "craft_level": 5, "craft_xp": 40,
	},

	# ── Offhand ────────────────────────────────────────────────────────────────
	"wooden_shield": {
		"name": "Wooden Shield",
		"slot": "offhand",
		"attack": 0, "defence": 4,
		"skill_speed": {},
		"recipe": {"Wood": 6},
		"craft_skill": "crafting", "craft_level": 1, "craft_xp": 20,
	},
	"copper_shield": {
		"name": "Copper Shield",
		"slot": "offhand",
		"attack": 0, "defence": 8,
		"skill_speed": {},
		"recipe": {"Copper Ore": 6},
		"craft_skill": "smithing", "craft_level": 5, "craft_xp": 35,
	},

	# ── Helmets ────────────────────────────────────────────────────────────────
	"leather_helmet": {
		"name": "Leather Helmet",
		"slot": "helmet",
		"attack": 0, "defence": 2,
		"skill_speed": {"hunting": 0.05},
		"recipe": {"Leather": 3},
		"craft_skill": "crafting", "craft_level": 1, "craft_xp": 15,
	},
	"copper_helmet": {
		"name": "Copper Helmet",
		"slot": "helmet",
		"attack": 0, "defence": 5,
		"skill_speed": {},
		"recipe": {"Copper Ore": 4},
		"craft_skill": "smithing", "craft_level": 5, "craft_xp": 30,
	},
	"miner_helm": {
		"name": "Miner's Helm",
		"slot": "helmet",
		"attack": 0, "defence": 3,
		"skill_speed": {"mining": 0.10},
		"recipe": {"Copper Ore": 3, "Coal": 1},
		"craft_skill": "smithing", "craft_level": 10, "craft_xp": 40,
	},

	# ── Chest ──────────────────────────────────────────────────────────────────
	"leather_chest": {
		"name": "Leather Chest",
		"slot": "chest",
		"attack": 0, "defence": 4,
		"skill_speed": {"agility": 0.05},
		"recipe": {"Leather": 5},
		"craft_skill": "crafting", "craft_level": 1, "craft_xp": 20,
	},
	"copper_chest": {
		"name": "Copper Chestplate",
		"slot": "chest",
		"attack": 0, "defence": 10,
		"skill_speed": {},
		"recipe": {"Copper Ore": 8},
		"craft_skill": "smithing", "craft_level": 10, "craft_xp": 50,
	},
	"lumberjack_vest": {
		"name": "Lumberjack Vest",
		"slot": "chest",
		"attack": 0, "defence": 3,
		"skill_speed": {"woodcutting": 0.10},
		"recipe": {"Wood": 10, "Leather": 3},
		"craft_skill": "crafting", "craft_level": 10, "craft_xp": 45,
	},

	# ── Legs ───────────────────────────────────────────────────────────────────
	"leather_legs": {
		"name": "Leather Legs",
		"slot": "legs",
		"attack": 0, "defence": 3,
		"skill_speed": {},
		"recipe": {"Leather": 4},
		"craft_skill": "crafting", "craft_level": 1, "craft_xp": 18,
	},
	"copper_legs": {
		"name": "Copper Greaves",
		"slot": "legs",
		"attack": 0, "defence": 7,
		"skill_speed": {},
		"recipe": {"Copper Ore": 6},
		"craft_skill": "smithing", "craft_level": 8, "craft_xp": 40,
	},

	# ── Boots ──────────────────────────────────────────────────────────────────
	"leather_boots": {
		"name": "Leather Boots",
		"slot": "boots",
		"attack": 0, "defence": 2,
		"skill_speed": {"agility": 0.08},
		"recipe": {"Leather": 2},
		"craft_skill": "crafting", "craft_level": 1, "craft_xp": 12,
	},
	"copper_boots": {
		"name": "Copper Boots",
		"slot": "boots",
		"attack": 0, "defence": 4,
		"skill_speed": {},
		"recipe": {"Copper Ore": 3},
		"craft_skill": "smithing", "craft_level": 5, "craft_xp": 25,
	},
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

func get_all_ids() -> Array:
	return ITEMS.keys()

func get_items_for_slot(slot: String) -> Array:
	var result = []
	for id in ITEMS.keys():
		if ITEMS[id]["slot"] == slot:
			result.append(id)
	return result

func can_craft(item_id: String) -> bool:
	if not ITEMS.has(item_id):
		return false
	var item = ITEMS[item_id]
	# Check skill level
	if GameData.get_skill_level(item["craft_skill"]) < item["craft_level"]:
		return false
	# Check materials
	return GameData.has_items(item["recipe"])

func get_stat_summary(item_id: String) -> String:
	var item = ITEMS.get(item_id, {})
	if item.is_empty():
		return ""
	var parts = []
	if item["attack"] > 0:
		parts.append("+%d Atk" % item["attack"])
	if item["defence"] > 0:
		parts.append("+%d Def" % item["defence"])
	for skill in item["skill_speed"].keys():
		parts.append("-%d%% %s time" % [int(item["skill_speed"][skill] * 100), skill.capitalize()])
	return ", ".join(parts) if parts else "No bonuses"

func get_recipe_summary(item_id: String) -> String:
	var item = ITEMS.get(item_id, {})
	if item.is_empty():
		return ""
	var parts = []
	for mat in item["recipe"].keys():
		var have = GameData.inventory.get(mat, 0)
		var need = item["recipe"][mat]
		parts.append("%s %d/%d" % [mat, have, need])
	return ", ".join(parts)
