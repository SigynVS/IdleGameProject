extends CanvasLayer

const PANEL_BG = Color(0.02, 0.16, 0.20, 1.0)
const PANEL_DARK = Color(0.01, 0.10, 0.14, 1.0)
const PANEL_ROW = Color(0.04, 0.24, 0.28, 1.0)
const ACCENT = Color(0.06, 0.63, 0.50, 1.0)
const ACCENT_HOVER = Color(0.12, 0.74, 0.60, 1.0)
const ACCENT_GOLD = Color(0.82, 0.63, 0.24, 1.0)
const TEXT = Color(0.92, 0.95, 0.92, 1.0)
const MUTED = Color(0.66, 0.76, 0.74, 1.0)
const WARNING = Color(0.92, 0.34, 0.34, 1.0)

var gold_label: Label
var bag_value_label: Label
var idle_state_label: Label
var activity_title_label: Label
var activity_status_label: Label
var activity_progress_bar: ProgressBar
var activity_reward_label: Label
var total_level_label: Label
var activity_buttons: Dictionary = {}
var dashboard_panels: Dictionary = {}
var skill_grid: GridContainer
var objective_grid: GridContainer
var inventory_rows: VBoxContainer
var equipment_rows: VBoxContainer
var equipment_power_label: Label
var production_scrim: ColorRect
var crafting_rows: VBoxContainer
var production_panel: PanelContainer
var production_title_label: Label
var production_summary_label: Label
var production_tab_buttons: Dictionary = {}
var production_mode: String = "all"
var offline_popup: AcceptDialog
var party_panels_helper: Control
var inventory_sort_mode: String = "name"
var inventory_sort_buttons: Dictionary = {}

func _ready():
	layer = 50
	_hide_legacy_scene_ui()
	_build_dashboard()

	if GameData:
		GameData.gold_updated.connect(_on_gold_updated)
		GameData.inventory_updated.connect(_refresh_inventory)
		GameData.inventory_updated.connect(_refresh_full_inventory)
		GameData.equipment_updated.connect(_refresh_equipment)
		GameData.offline_earnings_ready.connect(_on_offline_earnings)
		GameData.activity_changed.connect(_on_activity_changed)
		GameData.activity_progress_updated.connect(_on_activity_progress_updated)
		GameData.activity_cycle_completed.connect(_on_activity_cycle_completed)
		_refresh_all()
		_on_activity_changed(GameData.active_activity_id)

func _hide_legacy_scene_ui():
	for path in ["TopBar", "TabMenu"]:
		var node = get_node_or_null(path)
		if node:
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED

func _build_dashboard():
	var root = Control.new()
	root.name = "IdleDashboard"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Load party panels script
	var PartyPanelsScript = load("res://scripts/party_panels.gd")
	if PartyPanelsScript:
		party_panels_helper = PartyPanelsScript.new()
		root.add_child(party_panels_helper)

	_build_sidebar(root)
	_build_top_nav(root)
	_build_user_card(root)
	_build_skills_card(root)
	_build_active_task_card(root)
	_build_inventory_card(root)
	_build_equipment_card(root)
	_build_crafting_card(root)
	_build_party_panels(root)
	_build_full_inventory_panel(root)
	_setup_offline_popup()

func _build_party_panels(root: Control):
	if not party_panels_helper:
		return
	
	# Build adventurers panel
	var adventurers_panel = party_panels_helper.build_adventurers_panel()
	adventurers_panel.visible = false
	root.add_child(adventurers_panel)
	dashboard_panels["Adventurers"] = adventurers_panel
	
	# Build dungeons panel
	var dungeons_panel = party_panels_helper.build_dungeons_panel()
	dungeons_panel.visible = false
	root.add_child(dungeons_panel)
	dashboard_panels["Dungeons"] = dungeons_panel

func _build_full_inventory_panel(root: Control):
	var panel = _panel("FullInventory", Vector2(318, 90), Vector2(738, 1820), PANEL_BG)
	panel.visible = false
	root.add_child(panel)
	var box = _card_box(panel)

	var header = HBoxContainer.new()
	var title = _card_title("Inventory")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var sell_all_btn = Button.new()
	sell_all_btn.text = "Sell All"
	sell_all_btn.custom_minimum_size = Vector2(96, 42)
	sell_all_btn.add_theme_stylebox_override("normal", _style(ACCENT, 5))
	sell_all_btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 5))
	sell_all_btn.add_theme_color_override("font_color", TEXT)
	sell_all_btn.pressed.connect(func():
		GameData.sell_all_items()
		_refresh_full_inventory()
	)
	header.add_child(sell_all_btn)
	box.add_child(header)

	# Sort bar
	var sort_row = HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	box.add_child(sort_row)
	var sort_lbl = _small_label("Sort:")
	sort_lbl.autowrap_mode = 0
	sort_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_row.add_child(sort_lbl)
	for pair in [["Name", "name"], ["Amount", "amount"], ["Value", "value"]]:
		var btn = Button.new()
		btn.text = pair[0]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(68, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("normal", _style(PANEL_ROW, 4))
		btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 4))
		btn.add_theme_color_override("font_color", TEXT)
		btn.pressed.connect(func():
			inventory_sort_mode = pair[1]
			_refresh_sort_buttons()
			_refresh_full_inventory()
		)
		inventory_sort_buttons[pair[1]] = btn
		sort_row.add_child(btn)
	_refresh_sort_buttons()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var rows = VBoxContainer.new()
	rows.name = "FullInventoryRows"
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

func _refresh_sort_buttons():
	for mode in inventory_sort_buttons.keys():
		var btn: Button = inventory_sort_buttons[mode]
		var active = mode == inventory_sort_mode
		btn.button_pressed = active
		btn.add_theme_stylebox_override("normal", _style(ACCENT_GOLD if active else PANEL_ROW, 4))

func _get_sorted_inventory_keys() -> Array:
	var keys = GameData.inventory.keys().filter(func(k): return GameData.inventory[k] > 0)
	match inventory_sort_mode:
		"amount":
			keys.sort_custom(func(a, b): return GameData.inventory[a] > GameData.inventory[b])
		"value":
			keys.sort_custom(func(a, b):
				return GameData.item_prices.get(a, 0) * GameData.inventory[a] > GameData.item_prices.get(b, 0) * GameData.inventory[b]
			)
		_:
			keys.sort()
	return keys

func _refresh_full_inventory():
	var panel = dashboard_panels.get("FullInventory")
	if not panel or not panel.visible:
		return
	var rows = panel.find_child("FullInventoryRows", true, false)
	if not rows:
		return
	for child in rows.get_children():
		child.queue_free()

	var sorted_keys = _get_sorted_inventory_keys()
	var has_items = sorted_keys.size() > 0
	for item_name in sorted_keys:
		var amount = GameData.inventory[item_name]
		var row = PanelContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("panel", _style(PANEL_ROW, 4))
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var name_lbl = _body_label(item_name)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		var amt_lbl = _body_label("x%d" % amount)
		amt_lbl.custom_minimum_size = Vector2(48, 0)
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(amt_lbl)

		var price = GameData.item_prices.get(item_name, 0)
		if price > 0:
			var price_lbl = _small_label("%dg ea" % price)
			price_lbl.custom_minimum_size = Vector2(60, 0)
			price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hbox.add_child(price_lbl)
			var sell_btn = _mini_button("Sell 1")
			sell_btn.pressed.connect(func():
				GameData.sell_item(item_name, 1)
				_refresh_full_inventory()
			)
			hbox.add_child(sell_btn)
			var sell_all_item_btn = _mini_button("Sell All")
			sell_all_item_btn.pressed.connect(func():
				GameData.sell_item(item_name, GameData.inventory.get(item_name, 0))
				_refresh_full_inventory()
			)
			hbox.add_child(sell_all_item_btn)
		else:
			var no_sale_lbl = _small_label("No value")
			no_sale_lbl.custom_minimum_size = Vector2(60, 0)
			hbox.add_child(no_sale_lbl)

		var item_id = _find_item_id_by_name(item_name)
		if item_id != "":
			var equip_btn = _mini_button("Equip")
			equip_btn.pressed.connect(func():
				GameData.equip_item(item_id)
				_refresh_full_inventory()
			)
			hbox.add_child(equip_btn)

		rows.add_child(row)

	if not has_items:
		rows.add_child(_small_label("Your inventory is empty."))

func _build_sidebar(root: Control):
	var side = _panel("Sidebar", Vector2(24, 24), Vector2(284, 1820), PANEL_DARK)
	root.add_child(side)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_top = 18
	box.offset_right = -18
	box.offset_bottom = -18
	side.add_child(box)

	box.add_child(_section_label("Account"))
	box.add_child(_sidebar_nav_button("Dashboard", "UserInfo"))
	box.add_child(_sidebar_nav_button("Inventory", "FullInventory"))

	box.add_child(_spacer(12))
	box.add_child(_section_label("Community"))
	box.add_child(_sidebar_placeholder_button("Clan"))
	box.add_child(_sidebar_placeholder_button("Local market"))
	box.add_child(_sidebar_placeholder_button("Player market"))

	box.add_child(_spacer(12))
	box.add_child(_section_label("Activities"))
	for activity_id in GameData.get_all_activity_ids():
		var activity = GameData.get_activity(activity_id)
		var btn = _sidebar_activity_button(activity.get("name", activity_id.capitalize()), activity_id)
		activity_buttons[activity_id] = btn
		box.add_child(btn)
	
	box.add_child(_spacer(12))
	box.add_child(_section_label("Party"))
	box.add_child(_sidebar_nav_button("Adventurers", "Adventurers"))
	box.add_child(_sidebar_nav_button("Dungeons", "Dungeons"))

func _build_top_nav(root: Control):
	var nav = HBoxContainer.new()
	nav.name = "TopNav"
	nav.position = Vector2(318, 24)
	nav.size = Vector2(738, 52)
	nav.custom_minimum_size = Vector2(738, 52)
	nav.add_theme_constant_override("separation", 10)
	root.add_child(nav)

	for label in ["Task stats", "Quests", "Chat", "Shop", "Menu"]:
		var btn = Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(132, 52)
		btn.add_theme_stylebox_override("normal", _style(ACCENT, 6))
		btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 6))
		btn.add_theme_color_override("font_color", TEXT)
		nav.add_child(btn)

func _build_user_card(root: Control):
	var card = _panel("UserInfo", Vector2(318, 90), Vector2(370, 380), PANEL_BG)
	root.add_child(card)
	var box = _card_box(card)

	box.add_child(_card_title("User info"))
	var username = _body_label("Username: Player")
	box.add_child(username)
	gold_label = _body_label("Gold: 0")
	box.add_child(gold_label)
	bag_value_label = _body_label("Bag value: 0g")
	box.add_child(bag_value_label)
	idle_state_label = _body_label("You are currently idle.")
	idle_state_label.add_theme_color_override("font_color", WARNING)
	box.add_child(idle_state_label)

	var reward = _body_label("Latest reward:")
	reward.add_theme_color_override("font_color", MUTED)
	box.add_child(reward)
	activity_reward_label = _body_label("Select an activity.")
	box.add_child(activity_reward_label)

func _build_skills_card(root: Control):
	var card = _panel("Skills", Vector2(714, 90), Vector2(342, 620), PANEL_BG)
	root.add_child(card)
	var box = _card_box(card)

	var header = HBoxContainer.new()
	header.add_child(_card_title("Skills"))
	var total = _body_label("Total level: 0")
	total.name = "TotalLevelLabel"
	total_level_label = total
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(total)
	box.add_child(header)

	skill_grid = GridContainer.new()
	skill_grid.columns = 2
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(skill_grid)

func _build_active_task_card(root: Control):
	var card = _panel("ActiveTask", Vector2(318, 486), Vector2(370, 350), PANEL_BG)
	root.add_child(card)
	var box = _card_box(card)

	var header = HBoxContainer.new()
	activity_title_label = _card_title("Active task")
	header.add_child(activity_title_label)
	var stop = Button.new()
	stop.text = "Stop"
	stop.custom_minimum_size = Vector2(82, 42)
	stop.add_theme_stylebox_override("normal", _style(Color(0.32, 0.10, 0.12, 0.95), 5))
	stop.add_theme_stylebox_override("hover", _style(Color(0.48, 0.13, 0.16, 1.0), 5))
	stop.pressed.connect(_on_stop_activity_pressed)
	header.add_child(stop)
	box.add_child(header)

	activity_status_label = _body_label("Choose an activity from the left.")
	box.add_child(activity_status_label)
	activity_progress_bar = ProgressBar.new()
	activity_progress_bar.min_value = 0
	activity_progress_bar.max_value = 100
	activity_progress_bar.custom_minimum_size = Vector2(0, 28)
	_style_progress(activity_progress_bar, ACCENT)
	box.add_child(activity_progress_bar)

	objective_grid = GridContainer.new()
	objective_grid.columns = 2
	objective_grid.add_theme_constant_override("h_separation", 8)
	objective_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_section_label("Objectives"))
	box.add_child(objective_grid)

func _build_inventory_card(root: Control):
	var card = _panel("Inventory", Vector2(714, 728), Vector2(342, 390), PANEL_BG)
	root.add_child(card)
	var box = _card_box(card)
	var header = HBoxContainer.new()
	header.add_child(_card_title("Inventory"))
	var sell = Button.new()
	sell.text = "Sell all"
	sell.custom_minimum_size = Vector2(96, 42)
	sell.add_theme_stylebox_override("normal", _style(ACCENT, 5))
	sell.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 5))
	sell.pressed.connect(_on_trade_pressed)
	header.add_child(sell)
	box.add_child(header)

	var summary = _small_label("Materials, drops, and crafted gear ready to equip.")
	box.add_child(summary)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 278)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	inventory_rows = VBoxContainer.new()
	inventory_rows.add_theme_constant_override("separation", 6)
	inventory_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_rows)

func _build_equipment_card(root: Control):
	var card = _panel("Equipment", Vector2(318, 852), Vector2(370, 260), PANEL_BG)
	root.add_child(card)
	var box = _card_box(card)
	var header = HBoxContainer.new()
	header.add_child(_card_title("Equipment"))
	equipment_power_label = _small_label("Atk 0 / Def 0")
	equipment_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	equipment_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(equipment_power_label)
	box.add_child(header)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 178)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	equipment_rows = VBoxContainer.new()
	equipment_rows.add_theme_constant_override("separation", 6)
	equipment_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(equipment_rows)

func _build_crafting_card(root: Control):
	production_scrim = ColorRect.new()
	production_scrim.name = "ProductionScrim"
	production_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	production_scrim.color = Color(0.0, 0.04, 0.05, 0.62)
	production_scrim.visible = false
	production_scrim.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close_production_panel()
	)
	root.add_child(production_scrim)

	production_panel = _panel("Crafting", Vector2(318, 90), Vector2(738, 1820), PANEL_BG)
	production_panel.visible = false
	root.add_child(production_panel)
	var box = _card_box(production_panel)

	var header = HBoxContainer.new()
	production_title_label = _card_title("Smithing / Crafting")
	production_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(production_title_label)
	var close_btn = Button.new()
	close_btn.text = "✕ Close"
	close_btn.custom_minimum_size = Vector2(96, 42)
	close_btn.add_theme_stylebox_override("normal", _style(Color(0.32, 0.10, 0.12, 0.95), 5))
	close_btn.add_theme_stylebox_override("hover", _style(Color(0.48, 0.13, 0.16, 1.0), 5))
	close_btn.add_theme_color_override("font_color", TEXT)
	close_btn.pressed.connect(_close_production_panel)
	header.add_child(close_btn)
	box.add_child(header)

	production_summary_label = _small_label("Choose a production discipline to inspect recipes by tier.")
	box.add_child(production_summary_label)

	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	for tab in [
		{"label": "All", "mode": "all"},
		{"label": "Smithing", "mode": "smithing"},
		{"label": "Crafting", "mode": "crafting"},
		{"label": "Fletching", "mode": "fletching"},
	]:
		var btn = _mini_button(tab["label"])
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_production_mode_pressed.bind(tab["mode"]))
		production_tab_buttons[tab["mode"]] = btn
		tabs.add_child(btn)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1480)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	crafting_rows = VBoxContainer.new()
	crafting_rows.add_theme_constant_override("separation", 8)
	crafting_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(crafting_rows)

func _setup_offline_popup():
	offline_popup = AcceptDialog.new()
	offline_popup.title = "Welcome Back"
	offline_popup.ok_button_text = "Collect"
	add_child(offline_popup)

func _refresh_all():
	_on_gold_updated()
	_refresh_inventory()
	_refresh_equipment()
	_refresh_skills()
	_refresh_crafting()
	_refresh_objectives()

func _on_activity_changed(activity_id: String):
	_refresh_activity_buttons()
	_refresh_objectives()
	if activity_id == "":
		activity_title_label.text = "Active task"
		activity_status_label.text = "Choose an activity from the left."
		idle_state_label.text = "You are currently idle."
		activity_progress_bar.value = 0
		return

	var activity = GameData.get_activity(activity_id)
	activity_title_label.text = activity.get("name", activity_id.capitalize())
	activity_status_label.text = activity.get("status", "Working")
	idle_state_label.text = "Currently running: %s" % activity.get("name", activity_id.capitalize())

func _on_activity_progress_updated(activity_id: String, progress: float, seconds_left: float):
	if activity_id != GameData.active_activity_id:
		return
	activity_progress_bar.value = progress * 100.0
	if GameData.activity_running:
		activity_status_label.text = "%s - %.1fs left" % [
			GameData.get_activity(activity_id).get("status", "Working"),
			seconds_left
		]

func _on_activity_cycle_completed(_activity_id: String, reward_text: String):
	activity_reward_label.text = reward_text
	_refresh_all()

func _on_activity_button_pressed(activity_id: String):
	GameData.start_activity(activity_id)
	if activity_id == "smithing":
		_focus_panel("ActiveTask")
		_open_production_panel("smithing")
	elif activity_id == "crafting":
		_focus_panel("ActiveTask")
		_open_production_panel("crafting")
	else:
		_focus_panel("ActiveTask")

func _on_stop_activity_pressed():
	GameData.stop_activity()

func _refresh_activity_buttons():
	for activity_id in activity_buttons.keys():
		var btn: Button = activity_buttons[activity_id]
		var active = activity_id == GameData.active_activity_id and GameData.activity_running
		btn.button_pressed = active
		btn.add_theme_stylebox_override("normal", _style(ACCENT if active else PANEL_ROW, 4))

const PARTY_PANELS = ["Adventurers", "Dungeons", "FullInventory"]
const MAIN_PANELS = ["UserInfo", "Skills", "ActiveTask", "Inventory", "Equipment"]

func _focus_panel(panel_name: String):
	_close_production_panel()
	
	var is_party_panel = panel_name in PARTY_PANELS
	
	# Hide party panels
	for key in PARTY_PANELS:
		if dashboard_panels.has(key):
			dashboard_panels[key].visible = false
	
	if is_party_panel:
		# Hide main dashboard panels, show the requested party panel
		for key in MAIN_PANELS:
			if dashboard_panels.has(key):
				dashboard_panels[key].visible = false
		if dashboard_panels.has(panel_name):
			dashboard_panels[panel_name].visible = true
			dashboard_panels[panel_name].move_to_front()
		if party_panels_helper:
			if panel_name == "Adventurers":
				party_panels_helper._refresh_adventurers("")
			elif panel_name == "Dungeons":
				party_panels_helper._refresh_dungeons("")
		if panel_name == "FullInventory":
			_refresh_full_inventory()
	else:
		# Show all main dashboard panels
		for key in MAIN_PANELS:
			if dashboard_panels.has(key):
				dashboard_panels[key].visible = true

func _open_production_panel(mode: String):
	production_mode = mode
	_refresh_production_tabs()
	if production_scrim:
		production_scrim.visible = true
		production_scrim.move_to_front()
	if production_panel:
		production_panel.visible = true
		production_panel.move_to_front()
	if production_title_label:
		production_title_label.text = _production_title_for_mode(mode)
	_refresh_crafting()

func _close_production_panel():
	if production_scrim:
		production_scrim.visible = false
	if production_panel:
		production_panel.visible = false

func _on_production_mode_pressed(mode: String):
	production_mode = mode
	if production_title_label:
		production_title_label.text = _production_title_for_mode(mode)
	_refresh_production_tabs()
	_refresh_crafting()

func _refresh_production_tabs():
	for mode in production_tab_buttons.keys():
		var btn: Button = production_tab_buttons[mode]
		var active = mode == production_mode
		btn.button_pressed = active
		btn.add_theme_stylebox_override("normal", _style(ACCENT_GOLD if active else PANEL_ROW, 4))

func _production_title_for_mode(mode: String) -> String:
	if mode == "smithing":
		return "Smithing"
	if mode == "crafting":
		return "Crafting"
	if mode == "fletching":
		return "Fletching"
	return "Production"

func _on_gold_updated():
	if gold_label:
		gold_label.text = "Gold: %d" % GameData.gold
	if bag_value_label:
		var potential_gold = 0
		for item_name in GameData.inventory.keys():
			if GameData.item_prices.has(item_name):
				potential_gold += GameData.inventory[item_name] * GameData.item_prices[item_name]
		bag_value_label.text = "Bag value: %dg" % potential_gold

func _refresh_skills():
	if not skill_grid:
		return
	for child in skill_grid.get_children():
		child.queue_free()

	var shown = ["attack", "strength", "defence", "ranged", "magic", "hitpoints", "woodcutting", "mining", "smithing", "crafting", "fletching", "fishing"]
	for skill in shown:
		skill_grid.add_child(_skill_tile(skill))

	if total_level_label:
		total_level_label.text = "Total level: %d" % GameData.get_total_level()

func _skill_tile(skill: String) -> PanelContainer:
	var tile = PanelContainer.new()
	tile.custom_minimum_size = Vector2(146, 66)
	tile.add_theme_stylebox_override("panel", _style(PANEL_ROW, 4))
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)

	var title = _body_label(skill.capitalize())
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	var level = GameData.skills[skill]["level"]
	var xp = GameData.skills[skill]["xp"]
	var req = level * GameData.base_xp_to_level
	var stat = _small_label("Lv. %d  %d/%d xp" % [level, xp, req])
	box.add_child(stat)
	var bar = ProgressBar.new()
	bar.max_value = req
	bar.value = xp
	bar.custom_minimum_size = Vector2(0, 8)
	_style_progress(bar, ACCENT)
	box.add_child(bar)
	return tile

func _refresh_objectives():
	if not objective_grid:
		return
	for child in objective_grid.get_children():
		child.queue_free()
	var activity_id = GameData.active_activity_id
	var activity = GameData.get_activity(activity_id)
	var reward = "Pick a task" if activity.is_empty() else GameData.format_activity_reward(activity, 1)
	objective_grid.add_child(_objective_tile("Gathering", "Active: %s" % (activity.get("name", "None") if not activity.is_empty() else "None")))
	objective_grid.add_child(_objective_tile("Reward", reward))
	objective_grid.add_child(_objective_tile("Inventory", "%d item types" % GameData.inventory.size()))
	objective_grid.add_child(_objective_tile("Equipment", "%d slots filled" % GameData.equipped.size()))

func _objective_tile(title: String, body: String) -> PanelContainer:
	var tile = PanelContainer.new()
	tile.custom_minimum_size = Vector2(160, 58)
	tile.add_theme_stylebox_override("panel", _style(ACCENT, 3))
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	tile.add_child(box)
	box.add_child(_small_label(title))
	box.add_child(_body_label(body))
	return tile

func _refresh_inventory():
	if not inventory_rows:
		return
	for child in inventory_rows.get_children():
		child.queue_free()
	var has_items = false
	for item_name in GameData.inventory.keys():
		var amount = GameData.inventory[item_name]
		if amount <= 0:
			continue
		has_items = true
		inventory_rows.add_child(_inventory_row(item_name, amount))
	if not has_items:
		var empty = _small_label("Empty bag. Start Mining or Woodcutting to stock materials.")
		empty.custom_minimum_size = Vector2(0, 44)
		inventory_rows.add_child(empty)
	_on_gold_updated()
	_refresh_crafting()

func _inventory_row(item_name: String, amount: int) -> PanelContainer:
	var row = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _style(PANEL_ROW, 4))
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)
	var label = _body_label("%s x%d" % [item_name, amount])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	var item_id = _find_item_id_by_name(item_name)
	if item_id != "":
		var equip = _mini_button("Equip")
		equip.pressed.connect(_on_equip_item_pressed.bind(item_id))
		box.add_child(equip)
	return row

func _refresh_equipment():
	if not equipment_rows:
		return
	for child in equipment_rows.get_children():
		child.queue_free()
	if equipment_power_label:
		equipment_power_label.text = "Atk %d / Def %d" % [GameData.get_total_attack(), GameData.get_total_defence()]
	for slot in ["helmet", "chest", "legs", "boots", "weapon", "offhand"]:
		equipment_rows.add_child(_equipment_row(slot))

func _equipment_row(slot: String) -> PanelContainer:
	var row = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _style(PANEL_ROW, 4))
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)
	var item = GameData.get_equipped_item(slot)
	var label = _body_label("%s: Empty" % slot.capitalize())
	if not item.is_empty():
		label.text = "%s: %s\n%s" % [slot.capitalize(), item["name"], EquipmentData.get_stat_summary(GameData.equipped[slot])]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	if not item.is_empty():
		var unequip = _mini_button("Unequip")
		unequip.pressed.connect(_on_unequip_slot_pressed.bind(slot))
		box.add_child(unequip)
	return row

func _refresh_crafting():
	if not crafting_rows:
		return
	for child in crafting_rows.get_children():
		child.queue_free()
	if production_panel and not production_panel.visible:
		return
	if production_summary_label:
		production_summary_label.text = "Showing %s recipes. Craftable rows are highlighted; locked rows explain what is missing." % _production_title_for_mode(production_mode).to_lower()

	var grouped: Dictionary = {}
	for item_id in EquipmentData.get_all_ids():
		var item = EquipmentData.get_item(item_id)
		var skill = item.get("craft_skill", "crafting")
		var tier = _get_item_tier(item_id, item)
		if not grouped.has(skill):
			grouped[skill] = {}
		if not grouped[skill].has(tier):
			grouped[skill][tier] = []
		grouped[skill][tier].append(item_id)

	var skills_to_show = ["smithing", "crafting", "fletching"]
	if production_mode == "smithing":
		skills_to_show = ["smithing"]
	elif production_mode == "crafting":
		skills_to_show = ["crafting"]
	elif production_mode == "fletching":
		skills_to_show = ["fletching"]

	for skill in skills_to_show:
		if not grouped.has(skill):
			continue
		crafting_rows.add_child(_production_header(skill.capitalize()))
		for tier in _ordered_tiers(grouped[skill].keys()):
			crafting_rows.add_child(_production_subheader(tier))
			for item_id in grouped[skill][tier]:
				crafting_rows.add_child(_crafting_row(item_id))

func _production_header(text: String) -> Label:
	var label = _section_label(text)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.72))
	return label

func _production_subheader(text: String) -> Label:
	var label = _small_label(text)
	label.add_theme_color_override("font_color", Color(0.50, 0.92, 0.82))
	return label

func _get_item_tier(item_id: String, item: Dictionary) -> String:
	var haystack = ("%s %s" % [item_id, item.get("name", "")]).to_lower()
	if haystack.contains("lumberjack") or haystack.contains("miner"):
		return "Skilling gear"
	if haystack.contains("copper"):
		return "Copper gear"
	if haystack.contains("iron"):
		return "Iron gear"
	if haystack.contains("steel"):
		return "Steel gear"
	if haystack.contains("leather"):
		return "Leather gear"
	if haystack.contains("wood") or haystack.contains("bow") or haystack.contains("staff") or haystack.contains("shield"):
		return "Wood gear"
	return "Other gear"

func _ordered_tiers(tiers: Array) -> Array:
	var order = ["Copper gear", "Iron gear", "Steel gear", "Leather gear", "Wood gear", "Skilling gear", "Other gear"]
	var result = []
	for tier in order:
		if tiers.has(tier):
			result.append(tier)
	for tier in tiers:
		if not result.has(tier):
			result.append(tier)
	return result

func _crafting_row(item_id: String) -> PanelContainer:
	var item = EquipmentData.get_item(item_id)
	var craftable = EquipmentData.can_craft(item_id)
	var row = PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _style(Color(0.08, 0.34, 0.28, 0.98) if craftable else PANEL_ROW, 4))
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	var info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 3)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(info_box)

	var title = _body_label("%s  -  %s" % [item["name"], item.get("slot", "gear").capitalize()])
	title.add_theme_color_override("font_color", TEXT if craftable else MUTED)
	info_box.add_child(title)

	var info = _small_label("%s\nRecipe: %s\nRequires %s Lv%d, awards %d XP" % [
		EquipmentData.get_stat_summary(item_id),
		EquipmentData.get_recipe_summary(item_id),
		item.get("craft_skill", "crafting").capitalize(),
		item.get("craft_level", 1),
		item.get("craft_xp", 0)
	])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(500, 0)
	info_box.add_child(info)

	var state = _small_label("Ready to craft" if craftable else _craft_blocker_text(item_id))
	state.add_theme_color_override("font_color", Color(0.72, 0.96, 0.80) if craftable else WARNING)
	info_box.add_child(state)

	var craft = _mini_button("Craft")
	craft.custom_minimum_size = Vector2(92, 40)
	craft.disabled = not craftable
	craft.pressed.connect(_on_craft_item_pressed.bind(item_id))
	box.add_child(craft)
	return row

func _craft_blocker_text(item_id: String) -> String:
	var item = EquipmentData.get_item(item_id)
	var blockers = []
	var skill = item.get("craft_skill", "crafting")
	var level = item.get("craft_level", 1)
	if GameData.get_skill_level(skill) < level:
		blockers.append("%s Lv%d" % [skill.capitalize(), level])
	for mat in item.get("recipe", {}).keys():
		var have = GameData.inventory.get(mat, 0)
		var need = item["recipe"][mat]
		if have < need:
			blockers.append("%s %d/%d" % [mat, have, need])
	return "Missing: %s" % ", ".join(blockers)

func _on_equip_item_pressed(item_id: String):
	GameData.equip_item(item_id)

func _on_unequip_slot_pressed(slot: String):
	GameData.unequip_slot(slot)

func _on_craft_item_pressed(item_id: String):
	GameData.craft_item(item_id)
	_refresh_all()

func _on_trade_pressed():
	GameData.sell_all_items()
	_refresh_all()

func _on_offline_earnings(summary: String):
	offline_popup.dialog_text = summary
	offline_popup.popup_centered()

func _find_item_id_by_name(item_name: String) -> String:
	for item_id in EquipmentData.get_all_ids():
		if EquipmentData.get_item(item_id)["name"] == item_name:
			return item_id
	return ""

func _panel(node_name: String, pos: Vector2, size: Vector2, color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = node_name
	panel.position = pos
	panel.size = size
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", _style(color, 6))
	dashboard_panels[node_name] = panel
	return panel

func _card_box(parent: PanelContainer) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 12
	box.offset_right = -14
	box.offset_bottom = -12
	parent.add_child(box)
	return box

func _sidebar_activity_button(label: String, activity_id: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, 48)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_stylebox_override("normal", _style(PANEL_ROW, 4))
	btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 4))
	btn.add_theme_color_override("font_color", TEXT)
	btn.pressed.connect(_on_activity_button_pressed.bind(activity_id))
	return btn

func _sidebar_nav_button(label: String, target_panel: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), 4))
	btn.add_theme_stylebox_override("hover", _style(PANEL_ROW, 4))
	btn.add_theme_color_override("font_color", TEXT)
	btn.pressed.connect(_focus_panel.bind(target_panel))
	return btn

func _sidebar_placeholder_button(label: String) -> Button:
	var btn = Button.new()
	btn.text = label + "  (soon)"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = true
	btn.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0), 4))
	btn.add_theme_stylebox_override("disabled", _style(Color(0, 0, 0, 0), 4))
	btn.add_theme_color_override("font_color", MUTED)
	btn.add_theme_color_override("font_disabled_color", Color(MUTED.r, MUTED.g, MUTED.b, 0.45))
	return btn

func _mini_button(label: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(78, 34)
	btn.add_theme_stylebox_override("normal", _style(ACCENT, 4))
	btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 4))
	btn.add_theme_stylebox_override("disabled", _style(Color(0.12, 0.16, 0.17, 0.85), 4))
	btn.add_theme_color_override("font_color", TEXT)
	return btn

func _card_title(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", TEXT)
	return label

func _section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", TEXT)
	return label

func _body_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _small_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(1, height)
	return spacer

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = Color(0.08, 0.38, 0.43, 0.65)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style

func _style_progress(bar: ProgressBar, fill: Color):
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.08, 0.10, 0.95)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", bg_style)
