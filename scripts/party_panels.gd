extends Control

# Visual dungeon UI with Idle Guild Master style

var adventurer_list_rows: VBoxContainer
var dungeon_cards_container: VBoxContainer

const PANEL_BG = Color(0.02, 0.16, 0.20, 1.0)
const PANEL_ROW = Color(0.04, 0.24, 0.28, 1.0)
const ACCENT = Color(0.06, 0.63, 0.50, 1.0)
const ACCENT_HOVER = Color(0.12, 0.74, 0.60, 1.0)
const TEXT = Color(0.92, 0.95, 0.92, 1.0)
const MUTED = Color(0.66, 0.76, 0.74, 1.0)
const WARNING = Color(0.92, 0.34, 0.34, 1.0)

# Color map for combat log
const LOG_COLORS = {
	"white": Color(0.92, 0.95, 0.92),
	"green": Color(0.36, 0.86, 0.56),
	"red": Color(0.92, 0.34, 0.34),
	"cyan": Color(0.36, 0.76, 0.86),
	"orange": Color(0.96, 0.64, 0.24),
	"yellow": Color(0.96, 0.86, 0.36)
}

func _ready():
	if PartyManager:
		PartyManager.adventurer_recruited.connect(_on_adventurer_changed)
		PartyManager.adventurer_updated.connect(_on_adventurer_changed)
		PartyManager.dungeon_started.connect(_on_dungeon_changed)
		PartyManager.dungeon_completed.connect(_on_dungeon_changed)
		PartyManager.combat_log_updated.connect(_on_combat_log_updated)
	
	_refresh_adventurers("")
	_refresh_dungeons("")
	
	# Refresh dungeons regularly for progress
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(func(): _refresh_dungeons(""))
	timer.autostart = true
	add_child(timer)

func build_adventurers_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "Adventurers"
	panel.position = Vector2(318, 90)
	panel.size = Vector2(738, 1050)
	panel.custom_minimum_size = Vector2(738, 1050)
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, 6))
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 12
	box.offset_right = -14
	box.offset_bottom = -12
	panel.add_child(box)
	
	box.add_child(_card_title("Adventurers"))
	
	# Recruit buttons
	var recruit_box = HBoxContainer.new()
	recruit_box.add_theme_constant_override("separation", 8)
	for class_id in PartyManager.ADVENTURER_CLASSES.keys():
		var class_data = PartyManager.ADVENTURER_CLASSES[class_id]
		var btn = _mini_button(class_data["icon"] + " " + class_data["name"])
		btn.pressed.connect(func(): PartyManager.recruit_adventurer(class_id))
		recruit_box.add_child(btn)
	box.add_child(recruit_box)
	
	box.add_child(_small_label("Recruit adventurers and equip them with crafted gear from your inventory."))
	
	# Adventurer list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 900)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	
	adventurer_list_rows = VBoxContainer.new()
	adventurer_list_rows.add_theme_constant_override("separation", 8)
	adventurer_list_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(adventurer_list_rows)
	
	return panel

func build_dungeons_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "Dungeons"
	panel.position = Vector2(318, 90)
	panel.size = Vector2(738, 1728)
	panel.custom_minimum_size = Vector2(738, 1728)
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, 6))
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 12
	box.offset_right = -14
	box.offset_bottom = -12
	panel.add_child(box)
	
	box.add_child(_card_title("Dungeons"))
	box.add_child(_small_label("Send your adventurers into dangerous dungeons to fight monsters and collect loot!"))
	
	# Dungeon cards
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	
	dungeon_cards_container = VBoxContainer.new()
	dungeon_cards_container.add_theme_constant_override("separation", 16)
	dungeon_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(dungeon_cards_container)
	
	return panel

func _refresh_adventurers(_adv_id):
	if not adventurer_list_rows:
		return
	
	for child in adventurer_list_rows.get_children():
		child.queue_free()
	
	var advs = PartyManager.get_all_adventurer_ids()
	if advs.size() == 0:
		var empty = _small_label("No adventurers yet! Recruit your first warrior, mage, ranger, or cleric above.")
		empty.custom_minimum_size = Vector2(0, 100)
		adventurer_list_rows.add_child(empty)
		return
	
	for adv_id in advs:
		adventurer_list_rows.add_child(_adventurer_card(adv_id))

func _adventurer_card(adv_id: String) -> PanelContainer:
	var adv = PartyManager.get_adventurer(adv_id)
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(PANEL_ROW, 4))
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	
	# Header
	var header = HBoxContainer.new()
	var class_icon = PartyManager.ADVENTURER_CLASSES[adv["class"]]["icon"]
	var name_label = _body_label("%s %s (Lv.%d)" % [class_icon, adv["name"], adv["level"]])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	
	var status_label = _small_label("IN DUNGEON" if adv["assigned_dungeon"] != "" else "IDLE")
	status_label.add_theme_color_override("font_color", WARNING if adv["assigned_dungeon"] != "" else ACCENT)
	header.add_child(status_label)
	box.add_child(header)
	
	# Stats
	var stats = _small_label("HP:%d | ATK:%d | DEF:%d" % [
		adv["hp"],
		PartyManager.get_adventurer_total_attack(adv_id),
		PartyManager.get_adventurer_total_defence(adv_id)
	])
	box.add_child(stats)
	
	# Equipment
	if adv["equipped"].size() > 0:
		var equip_text = "Equipped: "
		var items = []
		for slot in adv["equipped"].keys():
			var item = EquipmentData.get_item(adv["equipped"][slot])
			items.append(item["name"])
		equip_text += ", ".join(items)
		box.add_child(_small_label(equip_text))
	else:
		box.add_child(_small_label("No equipment - craft gear and equip from inventory!"))
	
	return card

func _refresh_dungeons(_dungeon_id):
	if not dungeon_cards_container:
		return
	
	for child in dungeon_cards_container.get_children():
		child.queue_free()
	
	for dungeon_id in PartyManager.DUNGEON_DEFS.keys():
		dungeon_cards_container.add_child(_dungeon_visual_card(dungeon_id))

func _dungeon_visual_card(dungeon_id: String) -> PanelContainer:
	var dungeon = PartyManager.DUNGEON_DEFS[dungeon_id]
	var state = PartyManager.get_dungeon_state(dungeon_id)
	var is_active = state.size() > 0
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 480)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(PANEL_ROW, 6))
	
	var main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 0)
	main_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(main_box)
	
	# ─── DUNGEON BACKGROUND ───
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(0, 200)
	bg.color = Color(dungeon.get("bg_color", "#333333"))
	main_box.add_child(bg)
	
	# Background content
	var bg_content = VBoxContainer.new()
	bg_content.add_theme_constant_override("separation", 8)
	bg_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_content.offset_left = 16
	bg_content.offset_top = 12
	bg_content.offset_right = -16
	bg_content.offset_bottom = -12
	bg.add_child(bg_content)
	
	# Title
	var title = _card_title(dungeon["name"])
	title.add_theme_font_size_override("font_size", 22)
	bg_content.add_child(title)
	
	# Info row
	var info = _small_label("Difficulty: %d★ | Max party: %d | Enemy power: %d" % [
		dungeon["difficulty"],
		dungeon["max_adventurers"],
		dungeon["enemy_power"]
	])
	bg_content.add_child(info)
	
	# Phase display (if active)
	if is_active:
		var phase_label = _body_label("⚔ %s" % state["phase"].to_upper())
		phase_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.36))
		bg_content.add_child(phase_label)
	
	bg_content.add_child(_spacer(40))
	
	# Party sprites placeholder (if active)
	if is_active:
		var party_row = HBoxContainer.new()
		party_row.add_theme_constant_override("separation", 12)
		for adv_id in state["adventurers"]:
			var adv = PartyManager.get_adventurer(adv_id)
			var sprite = _adventurer_sprite(adv)
			party_row.add_child(sprite)
		bg_content.add_child(party_row)
	
	# ─── INFO SECTION ───
	var info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	info_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	info_box.offset_left = 16
	info_box.offset_top = 12
	info_box.offset_right = -16
	info_box.offset_bottom = -12
	main_box.add_child(info_box)
	
	if is_active:
		# Cycles & loot
		info_box.add_child(_body_label("Cycles: %d" % state["cycles_completed"]))
		
		if state["accumulated_loot"].size() > 0:
			var loot_label = _body_label("Loot collected:")
			loot_label.add_theme_color_override("font_color", ACCENT)
			info_box.add_child(loot_label)
			
			var loot_grid = GridContainer.new()
			loot_grid.columns = 3
			loot_grid.add_theme_constant_override("h_separation", 12)
			loot_grid.add_theme_constant_override("v_separation", 4)
			
			for item_name in state["accumulated_loot"].keys():
				var amount = state["accumulated_loot"][item_name]
				loot_grid.add_child(_small_label("%s x%d" % [item_name, amount]))
			
			info_box.add_child(loot_grid)
		else:
			info_box.add_child(_small_label("No loot yet..."))
		
		# Combat log
		var log_header = _section_label("Combat Log")
		log_header.add_theme_font_size_override("font_size", 14)
		info_box.add_child(log_header)
		
		var log_scroll = ScrollContainer.new()
		log_scroll.custom_minimum_size = Vector2(0, 120)
		log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		info_box.add_child(log_scroll)
		
		var log_box = VBoxContainer.new()
		log_box.name = "CombatLog_" + dungeon_id
		log_box.add_theme_constant_override("separation", 2)
		log_scroll.add_child(log_box)
		
		# Populate log
		var combat_log = PartyManager.get_combat_log(dungeon_id)
		for entry in combat_log:
			var log_label = _small_label(entry["message"])
			log_label.add_theme_color_override("font_color", LOG_COLORS.get(entry["color"], Color.WHITE))
			log_box.add_child(log_label)
		
		# Stop button
		var stop_btn = Button.new()
		stop_btn.text = "🛑 Stop & Collect Loot"
		stop_btn.custom_minimum_size = Vector2(0, 46)
		stop_btn.add_theme_stylebox_override("normal", _style(WARNING, 4))
		stop_btn.add_theme_stylebox_override("hover", _style(Color(0.72, 0.20, 0.20), 4))
		stop_btn.add_theme_color_override("font_color", TEXT)
		stop_btn.pressed.connect(func(): 
			PartyManager.stop_dungeon(dungeon_id)
		)
		info_box.add_child(stop_btn)
	else:
		# Not active - show start UI
		info_box.add_child(_small_label("Dungeon not active. Select idle adventurers to start!"))
		
		var idle_advs = PartyManager.get_idle_adventurers()
		if idle_advs.size() == 0:
			info_box.add_child(_small_label("❌ All adventurers are busy! Recruit more or wait for them to return."))
		else:
			info_box.add_child(_body_label("✓ %d adventurers available" % idle_advs.size()))
			
			var start_btn = Button.new()
			start_btn.text = "⚔ Start Dungeon"
			start_btn.custom_minimum_size = Vector2(0, 46)
			start_btn.add_theme_stylebox_override("normal", _style(ACCENT, 4))
			start_btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 4))
			start_btn.add_theme_color_override("font_color", TEXT)
			start_btn.pressed.connect(func():
				var party = []
				var max_party = min(dungeon["max_adventurers"], idle_advs.size())
				for i in range(max_party):
					party.append(idle_advs[i])
				PartyManager.start_dungeon(dungeon_id, party)
			)
			info_box.add_child(start_btn)
	
	return card

func _adventurer_sprite(adv: Dictionary) -> PanelContainer:
	"""Create a visual sprite representation of an adventurer"""
	var sprite_panel = PanelContainer.new()
	sprite_panel.custom_minimum_size = Vector2(64, 80)
	sprite_panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.1, 0.1, 0.7), 4))
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	sprite_panel.add_child(box)
	
	# Icon
	var icon = Label.new()
	icon.text = PartyManager.ADVENTURER_CLASSES[adv["class"]]["icon"]
	icon.add_theme_font_size_override("font_size", 32)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(icon)
	
	# Name
	var name_label = _small_label(adv["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	box.add_child(name_label)
	
	return sprite_panel

func _on_adventurer_changed(_id):
	_refresh_adventurers("")

func _on_dungeon_changed(_id, _loot = {}):
	_refresh_dungeons("")

func _on_combat_log_updated(dungeon_id: String, message: String, color: String):
	# Don't try to update during refresh
	if not dungeon_cards_container or not is_instance_valid(dungeon_cards_container):
		return
	
	# Find the combat log for this dungeon and append
	for card in dungeon_cards_container.get_children():
		if not is_instance_valid(card):
			continue
			
		var log_container = card.find_child("CombatLog_" + dungeon_id, true, false)
		if log_container and is_instance_valid(log_container):
			var log_label = _small_label(message)
			log_label.add_theme_color_override("font_color", LOG_COLORS.get(color, Color.WHITE))
			log_container.add_child(log_label)
			
			# Scroll to bottom safely
			var scroll = log_container.get_parent()
			if scroll and is_instance_valid(scroll) and scroll is ScrollContainer:
				# Defer scrolling to next frame
				call_deferred("_scroll_log_to_bottom", scroll)

func _scroll_log_to_bottom(scroll: ScrollContainer):
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 999999

# ─── UI Helper Functions ─────────────────────────────────────────────────────

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

func _mini_button(label: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(100, 34)
	btn.add_theme_stylebox_override("normal", _style(ACCENT, 4))
	btn.add_theme_stylebox_override("hover", _style(ACCENT_HOVER, 4))
	btn.add_theme_color_override("font_color", TEXT)
	return btn

func _spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(1, height)
	return spacer
