extends CanvasLayer

# --- Node References ---
@onready var gold_label = $GoldLabel
@onready var mining_label = $MiningLabel
@onready var woodcutting_label = $WoodcuttingLabel
@onready var inventory_label = $InventoryLabel
@onready var sell_label = $SellBag
@onready var sell_button = $Trade
@onready var mining_xp_bar = $MiningXPBar
@onready var woodcutting_xp_bar = $WoodcuttingXPBar

func _ready():
	# Connect to Global Data signals
	if GameData:
		GameData.gold_updated.connect(_on_gold_updated)
		GameData.inventory_updated.connect(_on_inventory_updated)
		_update_full_ui()
	
	# Connect the "Trade" button
	if sell_button:
		sell_button.pressed.connect(_on_trade_pressed)

func _on_trade_pressed():
	GameData.sell_all_items()

func _on_gold_updated():
	if gold_label:
		gold_label.text = "Gold: " + str(GameData.gold)

func _on_inventory_updated():
	# Refresh Inventory List
	if inventory_label:
		var text = "Inventory:\n"
		var has_items = false
		for item in GameData.inventory.keys():
			if GameData.inventory[item] > 0:
				text += str(item) + ": " + str(GameData.inventory[item]) + "\n"
				has_items = true
		
		if not has_items:
			text += "Empty"
			
		inventory_label.text = text
	
	# Update skill labels and XP bars
	_update_xp_bars()
	_update_trade_preview()

func _update_xp_bars():
	# Mining
	if mining_label:
		var level = GameData.skills["mining"]["level"]
		var xp = GameData.skills["mining"]["xp"]
		var xp_required = level * GameData.base_xp_to_level
		mining_label.text = "Mining Lvl: " + str(level) + "  |  XP: " + str(xp) + "/" + str(xp_required)
	
	if mining_xp_bar:
		var level = GameData.skills["mining"]["level"]
		var xp = GameData.skills["mining"]["xp"]
		var xp_required = level * GameData.base_xp_to_level
		mining_xp_bar.max_value = xp_required
		mining_xp_bar.value = xp

	# Woodcutting
	if woodcutting_label:
		var level = GameData.skills["woodcutting"]["level"]
		var xp = GameData.skills["woodcutting"]["xp"]
		var xp_required = level * GameData.base_xp_to_level
		woodcutting_label.text = "Woodcutting Lvl: " + str(level) + "  |  XP: " + str(xp) + "/" + str(xp_required)
	
	if woodcutting_xp_bar:
		var level = GameData.skills["woodcutting"]["level"]
		var xp = GameData.skills["woodcutting"]["xp"]
		var xp_required = level * GameData.base_xp_to_level
		woodcutting_xp_bar.max_value = xp_required
		woodcutting_xp_bar.value = xp

func _update_trade_preview():
	if sell_label:
		var potential_gold = 0
		for item in GameData.inventory.keys():
			if item_prices_has(item):
				potential_gold += GameData.inventory[item] * GameData.item_prices[item]
		sell_label.text = "Bag Value: " + str(potential_gold) + "g"

# Helper function to check prices safely
func item_prices_has(item_name):
	return GameData.item_prices.has(item_name)

func _update_full_ui():
	_on_gold_updated()
	_on_inventory_updated()
