extends CanvasLayer

# --- Top Bar ---
@onready var gold_label = $TopBar/TopBarContent/GoldLabel
@onready var bag_value_label = $TopBar/TopBarContent/BagValueLabel

# --- Skills Tab ---
@onready var mining_label = $TabMenu/Skills/SkillsContent/MiningLabel
@onready var mining_xp_bar = $TabMenu/Skills/SkillsContent/MiningXPBar
@onready var woodcutting_label = $TabMenu/Skills/SkillsContent/WoodcuttingLabel
@onready var woodcutting_xp_bar = $TabMenu/Skills/SkillsContent/WoodcuttingXPBar

# --- Inventory Tab ---
@onready var inventory_label = $TabMenu/Inventory/InventoryContent/InventoryLabel
@onready var trade_button = $TabMenu/Inventory/InventoryContent/TradeButton

# --- Equipment Tab ---
@onready var helmet_slot = $TabMenu/Equipment/EquipmentContent/HelmetSlot
@onready var chest_slot = $TabMenu/Equipment/EquipmentContent/ChestSlot
@onready var legs_slot = $TabMenu/Equipment/EquipmentContent/LegsSlot
@onready var boots_slot = $TabMenu/Equipment/EquipmentContent/BootsSlot
@onready var weapon_slot = $TabMenu/Equipment/EquipmentContent/WeaponSlot
@onready var offhand_slot = $TabMenu/Equipment/EquipmentContent/OffhandSlot

# --- Tab Menu ---
@onready var tab_menu = $TabMenu

# --- Offline Popup ---
var offline_popup: AcceptDialog

func _ready():
	_style_xp_bars()
	_setup_offline_popup()
	_setup_equipment_slots()
	
	if GameData:
		GameData.gold_updated.connect(_on_gold_updated)
		GameData.inventory_updated.connect(_on_inventory_updated)
		GameData.offline_earnings_ready.connect(_on_offline_earnings)
		_update_full_ui()
	
	if trade_button:
		trade_button.pressed.connect(_on_trade_pressed)
	
	# Refresh UI whenever tab is switched
	if tab_menu:
		tab_menu.tab_changed.connect(_on_tab_changed)

func _on_tab_changed(_tab: int):
	_update_full_ui()

func _setup_offline_popup():
	offline_popup = AcceptDialog.new()
	offline_popup.title = "Welcome Back!"
	offline_popup.ok_button_text = "Collect!"
	add_child(offline_popup)

func _setup_equipment_slots():
	if helmet_slot:
		helmet_slot.text = "🪖 Helmet: Empty"
	if chest_slot:
		chest_slot.text = "🛡️ Chest: Empty"
	if legs_slot:
		legs_slot.text = "👖 Legs: Empty"
	if boots_slot:
		boots_slot.text = "👢 Boots: Empty"
	if weapon_slot:
		weapon_slot.text = "⚔️ Weapon: Empty"
	if offhand_slot:
		offhand_slot.text = "🛡️ Offhand: Empty"

func _on_offline_earnings(summary: String):
	offline_popup.dialog_text = summary
	offline_popup.popup_centered()

func _style_xp_bars():
	if mining_xp_bar:
		var mining_style = StyleBoxFlat.new()
		mining_style.bg_color = Color(0.2, 0.5, 1.0)
		mining_style.corner_radius_top_left = 4
		mining_style.corner_radius_top_right = 4
		mining_style.corner_radius_bottom_left = 4
		mining_style.corner_radius_bottom_right = 4
		mining_xp_bar.add_theme_stylebox_override("fill", mining_style)
		var mining_bg = StyleBoxFlat.new()
		mining_bg.bg_color = Color(0.1, 0.1, 0.2)
		mining_bg.corner_radius_top_left = 4
		mining_bg.corner_radius_top_right = 4
		mining_bg.corner_radius_bottom_left = 4
		mining_bg.corner_radius_bottom_right = 4
		mining_xp_bar.add_theme_stylebox_override("background", mining_bg)

	if woodcutting_xp_bar:
		var wc_style = StyleBoxFlat.new()
		wc_style.bg_color = Color(0.2, 0.8, 0.3)
		wc_style.corner_radius_top_left = 4
		wc_style.corner_radius_top_right = 4
		wc_style.corner_radius_bottom_left = 4
		wc_style.corner_radius_bottom_right = 4
		woodcutting_xp_bar.add_theme_stylebox_override("fill", wc_style)
		var wc_bg = StyleBoxFlat.new()
		wc_bg.bg_color = Color(0.05, 0.15, 0.05)
		wc_bg.corner_radius_top_left = 4
		wc_bg.corner_radius_top_right = 4
		wc_bg.corner_radius_bottom_left = 4
		wc_bg.corner_radius_bottom_right = 4
		woodcutting_xp_bar.add_theme_stylebox_override("background", wc_bg)

func _on_trade_pressed():
	GameData.sell_all_items()

func _on_gold_updated():
	if gold_label:
		gold_label.text = "Gold: " + str(GameData.gold)

func _on_inventory_updated():
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
	
	_update_xp_bars()
	_update_bag_value()

func _update_xp_bars():
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

func _update_bag_value():
	if bag_value_label:
		var potential_gold = 0
		for item in GameData.inventory.keys():
			if GameData.item_prices.has(item):
				potential_gold += GameData.inventory[item] * GameData.item_prices[item]
		bag_value_label.text = "Bag: " + str(potential_gold) + "g"

func _update_full_ui():
	_on_gold_updated()
	_on_inventory_updated()
