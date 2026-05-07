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
		PartyManager.adventurer_leveled_up.connect(_on_adventurer_leveled_up)
		PartyManager.ability_unlocked.connect(_on_ability_unlocked)
		PartyManager.adventurer_died.connect(_on_adventurer_changed)
		PartyManager.adventurer_rezzed.connect(_on_adventurer_changed)
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
	card.set_meta("adventurer_id", adv_id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(PANEL_ROW, 4))
	
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	
	var is_dead: bool = adv.get("dead", false)
	
	# Header
	var header = HBoxContainer.new()
	var class_icon = PartyManager.ADVENTURER_CLASSES[adv["class"]]["icon"]
	var name_label = _body_label("%s %s (Lv.%d)" % [class_icon, adv["name"], PartyManager.level_from_xp(adv.get("xp", 0))])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_dead:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	header.add_child(name_label)
	
	if is_dead:
		var rez_time := PartyManager.get_prayer_rez_time()
		var elapsed: float = adv.get("rez_elapsed", 0.0)
		var remaining: float = max(0.0, rez_time - elapsed)
		var dead_label = _small_label("💀 Rezzing in %.0fs" % remaining)
		dead_label.add_theme_color_override("font_color", WARNING)
		dead_label.autowrap_mode = 0
		header.add_child(dead_label)
	else:
		var status_text: String = "IN DUNGEON" if adv["assigned_dungeon"] != "" else "IDLE"
		var status_label = _small_label(status_text)
		var status_color: Color = WARNING if adv["assigned_dungeon"] != "" else ACCENT
		status_label.add_theme_color_override("font_color", status_color)
		status_label.autowrap_mode = 0
		header.add_child(status_label)
	box.add_child(header)
	
	# XP bar
	var xp: int = adv.get("xp", 0)
	var progress: float = PartyManager.xp_progress_in_level(xp)
	var xp_remaining: int = PartyManager.xp_to_next_level(xp)
	var current_level: int = PartyManager.level_from_xp(xp)
	
	var xp_row = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	var xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = progress * 100
	xp_bar.custom_minimum_size = Vector2(0, 10)
	xp_bar.show_percentage = false
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(xp_bar)
	var xp_text: String
	if current_level >= PartyManager.MAX_LEVEL:
		xp_text = "MAX"
	else:
		xp_text = "%d XP to Lv.%d" % [xp_remaining, current_level + 1]
	var xp_text_label = _small_label(xp_text)
	xp_text_label.autowrap_mode = 0
	xp_row.add_child(xp_text_label)
	box.add_child(xp_row)
	
	# Stats (scaled by level)
	var scaled = PartyManager.get_scaled_stats(adv)
	var stats = _small_label("HP:%d | ATK:%d | DEF:%d" % [
		scaled["hp"],
		PartyManager.get_adventurer_total_attack(adv_id),
		PartyManager.get_adventurer_total_defence(adv_id)
	])
	box.add_child(stats)
	
	# Abilities
	var abilities: Array = adv.get("abilities", [])
	if abilities.size() > 0:
		var ability_label = _small_label("  ".join(abilities))
		ability_label.add_theme_color_override("font_color", Color(0.80, 0.60, 1.0))
		box.add_child(ability_label)
	
	# Equipment
	var slots = ["weapon", "offhand", "helmet", "chest", "legs", "boots"]
	var equip_grid = GridContainer.new()
	equip_grid.columns = 3
	equip_grid.add_theme_constant_override("h_separation", 6)
	equip_grid.add_theme_constant_override("v_separation", 4)
	equip_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(equip_grid)
	
	for slot in slots:
		var slot_box = VBoxContainer.new()
		slot_box.add_theme_constant_override("separation", 2)
		slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var slot_label = _small_label(slot.capitalize())
		slot_label.autowrap_mode = 0
		slot_box.add_child(slot_label)
		
		if adv["equipped"].has(slot):
			var item = EquipmentData.get_item(adv["equipped"][slot])
			var item_label = _small_label(item.get("name", "?"))
			item_label.add_theme_color_override("font_color", ACCENT)
			item_label.autowrap_mode = 0
			slot_box.add_child(item_label)
			
			var unequip_btn = Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(0, 28)
			unequip_btn.add_theme_stylebox_override("normal", _style(WARNING, 3))
			unequip_btn.add_theme_color_override("font_color", TEXT)
			unequip_btn.add_theme_font_size_override("font_size", 11)
			unequip_btn.pressed.connect(func():
				PartyManager.unequip_adventurer(adv_id, slot)
			)
			slot_box.add_child(unequip_btn)
		else:
			# Find items in inventory that fit this slot
			var available = []
			for item_id in EquipmentData.get_items_for_slot(slot):
				var item = EquipmentData.get_item(item_id)
				var item_name = item.get("name", "")
				if GameData.inventory.get(item_name, 0) > 0:
					available.append(item_id)
			
			if available.size() > 0:
				var equip_btn = OptionButton.new()
				equip_btn.custom_minimum_size = Vector2(0, 28)
				equip_btn.add_theme_font_size_override("font_size", 11)
				equip_btn.add_item("Equip...")
				for item_id in available:
					var item = EquipmentData.get_item(item_id)
					equip_btn.add_item(item.get("name", item_id))
				equip_btn.item_selected.connect(func(idx: int):
					if idx == 0:
						return
					PartyManager.equip_adventurer(adv_id, available[idx - 1])
				)
				slot_box.add_child(equip_btn)
			else:
				var empty_label = _small_label("Empty")
				empty_label.autowrap_mode = 0
				slot_box.add_child(empty_label)
		
		equip_grid.add_child(slot_box)
	
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
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(main_box)
	
	# ─── DUNGEON BACKGROUND ───
	var bg = ColorRect.new()
	bg.custom_minimum_size = Vector2(0, 200)
	bg.color = Color(dungeon.get("bg_color", "#333333"))
	main_box.add_child(bg)
	
	# Background content
	var bg_content = VBoxContainer.new()
	bg_content.add_theme_constant_override("separation", 8)
	bg_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_child(bg_content)
	
	# Title
	var title = _card_title(dungeon["name"])
	title.add_theme_font_size_override("font_size", 22)
	bg_content.add_child(title)
	
	# Info row with tier stars
	var tier: int = 0
	if is_active:
		tier = state.get("tier", 0)
	var tier_stars: String = ""
	for i in range(5):
		if i <= tier:
			tier_stars += "⭐"
		else:
			tier_stars += "☆"
	var current_power: float = PartyManager.get_dungeon_current_enemy_power(dungeon_id)
	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info1 = _small_label("Difficulty: %d★ | Max party: %d | Enemy power: %.0f" % [
		dungeon["difficulty"],
		dungeon["max_adventurers"],
		current_power
	])
	info1.autowrap_mode = 0
	info1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info1)
	var info2 = _small_label(tier_stars)
	info2.autowrap_mode = 0
	info_row.add_child(info2)
	bg_content.add_child(info_row)
	
	# Phase display (if active)
	if is_active:
		var phase_label = _body_label("⚔ %s" % state["phase"].to_upper())
		phase_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.36))
		bg_content.add_child(phase_label)
	
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
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_child(info_box)
	
	if is_active:
		# Cycles & tier progress
		var total_cycles: int = state.get("total_cycles", 0)
		var current_tier: int = state.get("tier", 0)
		var next_tier_cycles: int = 0
		if current_tier < 4:
			next_tier_cycles = PartyManager.DUNGEON_TIERS[current_tier + 1]["cycles"]
		var cycle_text: String
		if current_tier >= 4:
			cycle_text = "Tier 5 (Max) | Cycles: %d" % total_cycles
		else:
			cycle_text = "Tier %d | Cycles: %d | Next tier: %d" % [current_tier + 1, total_cycles, next_tier_cycles]
		info_box.add_child(_body_label(cycle_text))
		
		if state["accumulated_loot"].size() > 0:
			var loot_header = _body_label("Loot collected:")
			loot_header.add_theme_color_override("font_color", ACCENT)
			info_box.add_child(loot_header)
			
			var loot_grid = GridContainer.new()
			loot_grid.columns = 3
			loot_grid.add_theme_constant_override("h_separation", 12)
			loot_grid.add_theme_constant_override("v_separation", 4)
			loot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			for item_name in state["accumulated_loot"].keys():
				var amount = state["accumulated_loot"][item_name]
				var loot_label = _small_label("%s x%d" % [item_name, amount])
				loot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				loot_grid.add_child(loot_label)
			
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
		log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_child(log_scroll)
		
		var log_box = VBoxContainer.new()
		log_box.name = "CombatLog_" + dungeon_id
		log_box.add_theme_constant_override("separation", 2)
		log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		log_scroll.add_child(log_box)
		
		# Populate log
		var combat_log = PartyManager.get_combat_log(dungeon_id)
		for entry in combat_log:
			var log_label = _small_label(entry["message"])
			log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _on_adventurer_leveled_up(adv_id: String, _new_level: int) -> void:
	if not adventurer_list_rows or not is_instance_valid(adventurer_list_rows):
		return
	for card in adventurer_list_rows.get_children():
		if not is_instance_valid(card):
			continue
		if card.get_meta("adventurer_id", "") == adv_id:
			var tween = create_tween()
			tween.tween_property(card, "modulate", Color(1.0, 0.85, 0.1), 0.15)
			tween.tween_property(card, "modulate", Color.WHITE, 0.5)
			break
	_refresh_adventurers("")

func _on_ability_unlocked(_adv_id: String, _ability: String) -> void:
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
			log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
