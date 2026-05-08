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
	
	call_deferred("_refresh_adventurers", "")
	call_deferred("_refresh_dungeons", "")
	
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
	card.add_theme_stylebox_override("panel", _style(PANEL_ROW, 6))

	var is_dead: bool = adv.get("dead", false)
	var xp: int = adv.get("xp", 0)
	var current_level: int = PartyManager.level_from_xp(xp)
	var scaled = PartyManager.get_scaled_stats(adv)
	var total_atk = PartyManager.get_adventurer_total_attack(adv_id)
	var total_def = PartyManager.get_adventurer_total_defence(adv_id)
	var class_data = PartyManager.ADVENTURER_CLASSES[adv["class"]]

	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	card.add_child(outer)

	# ── Header row: portrait + identity ──────────────────────────────────────
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer.add_child(header_row)

	var portrait = PanelContainer.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.add_theme_stylebox_override("panel", _style(Color(0.06, 0.10, 0.14, 1.0), 4))
	var portrait_img = TextureRect.new()
	portrait_img.custom_minimum_size = Vector2(72, 72)
	portrait_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_map = {
		"warrior": "res://assets/Characters/Character - 128 x 128/character_002.png",
		"mage":    "res://assets/Characters/Character - 128 x 128/character_022.png",
		"rogue":   "res://assets/Characters/Character - 128 x 128/character_020.png",
		"ranger":  "res://assets/Characters/Character - 128 x 128/character_009.png",
		"cleric":  "res://assets/Characters/Character - 128 x 128/character_010.png",
	}
	var portrait_path = portrait_map.get(adv["class"], "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait_img.texture = load(portrait_path)
	else:
		var portrait_label = Label.new()
		portrait_label.text = class_data["icon"]
		portrait_label.add_theme_font_size_override("font_size", 38)
		portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.add_child(portrait_label)
	portrait.add_child(portrait_img)
	header_row.add_child(portrait)

	var id_col = VBoxContainer.new()
	id_col.add_theme_constant_override("separation", 4)
	id_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(id_col)

	var name_row = HBoxContainer.new()
	var name_lbl = _body_label(adv["name"])
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_dead:
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	name_row.add_child(name_lbl)
	if is_dead:
		var rez_time := PartyManager.get_prayer_rez_time()
		var remaining: float = max(0.0, rez_time - adv.get("rez_elapsed", 0.0))
		var dead_lbl = _small_label("💀 Rezzing in %.0fs" % remaining)
		dead_lbl.add_theme_color_override("font_color", WARNING)
		dead_lbl.autowrap_mode = 0
		name_row.add_child(dead_lbl)
	else:
		var status_text = "IN DUNGEON" if adv["assigned_dungeon"] != "" else "IDLE"
		var status_lbl = _small_label(status_text)
		status_lbl.add_theme_color_override("font_color", WARNING if adv["assigned_dungeon"] != "" else ACCENT)
		status_lbl.autowrap_mode = 0
		name_row.add_child(status_lbl)
	id_col.add_child(name_row)

	id_col.add_child(_small_label("%s  •  Level %d / %d" % [class_data["name"], current_level, PartyManager.MAX_LEVEL]))

	var xp_progress: float = PartyManager.xp_progress_in_level(xp)
	var xp_remaining: int = PartyManager.xp_to_next_level(xp)
	var xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = 100
	xp_bar.value = xp_progress * 100
	xp_bar.custom_minimum_size = Vector2(0, 10)
	xp_bar.show_percentage = false
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.56, 0.36, 0.86)
	var xp_bg = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.06, 0.06, 0.12)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	id_col.add_child(xp_bar)
	var xp_text = "MAX" if current_level >= PartyManager.MAX_LEVEL else "Exp: %d / %d" % [xp, xp + xp_remaining]
	id_col.add_child(_small_label(xp_text))

	# ── Active / Passive skill boxes ──────────────────────────────────────────
	var abilities: Array = adv.get("abilities", [])
	var active_skill = abilities[-1] if abilities.size() > 0 else "None"
	var passive_skill = abilities[-2] if abilities.size() > 1 else "None"
	var ability_row = HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	outer.add_child(ability_row)
	for pair in [["Active Skill", active_skill], ["Passive Skill", passive_skill]]:
		var skill_box = PanelContainer.new()
		skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_box.add_theme_stylebox_override("panel", _style(Color(0.08, 0.20, 0.26, 1.0), 4))
		var skill_inner = VBoxContainer.new()
		skill_inner.add_theme_constant_override("separation", 2)
		skill_box.add_child(skill_inner)
		var type_lbl = _small_label(pair[0])
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_inner.add_child(type_lbl)
		var name_l = _body_label(pair[1])
		name_l.add_theme_font_size_override("font_size", 14)
		name_l.add_theme_color_override("font_color", Color(0.80, 0.60, 1.0) if pair[1] != "None" else MUTED)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_inner.add_child(name_l)
		ability_row.add_child(skill_box)

	# ── Stats grid ────────────────────────────────────────────────────────────
	var stats_panel = PanelContainer.new()
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.14, 0.18, 1.0), 4))
	outer.add_child(stats_panel)
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 24)
	stats_grid.add_theme_constant_override("v_separation", 4)
	stats_panel.add_child(stats_grid)
	var class_attack_types = {"warrior": "Melee, Physical", "mage": "Ranged, Magical", "ranger": "Ranged, Physical", "cleric": "Melee, Holy"}
	for pair in [
		["HP", str(scaled["hp"])],
		["Attack dmg", "%d - %d" % [total_atk, int(total_atk * 1.5)]],
		["Constitution", str(int(scaled["hp"] * 0.2))],
		["Defense", str(total_def)],
		["Dexterity", str(current_level + int(total_def * 0.3))],
		["Magic Defense", str(int(total_def * 0.7))],
		["Intelligence", str(current_level)],
		["Mana gain", str(current_level * 2)],
		[class_attack_types.get(adv["class"], "Physical"), ""],
	]:
		var k = _small_label(pair[0])
		k.autowrap_mode = 0
		stats_grid.add_child(k)
		var v = _small_label(pair[1])
		v.add_theme_color_override("font_color", MUTED if pair[1] == "" else TEXT)
		v.autowrap_mode = 0
		stats_grid.add_child(v)

	# ── Equipment slots ───────────────────────────────────────────────────────
	var equip_lbl = _small_label("EQUIPMENT")
	equip_lbl.add_theme_color_override("font_color", ACCENT)
	equip_lbl.add_theme_font_size_override("font_size", 12)
	outer.add_child(equip_lbl)
	var equip_grid = GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override("h_separation", 8)
	equip_grid.add_theme_constant_override("v_separation", 4)
	equip_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(equip_grid)
	for slot in ["weapon", "offhand", "helmet", "chest", "legs", "boots"]:
		var slot_row = HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 6)
		slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip_grid.add_child(slot_row)
		var slot_lbl = _small_label(slot.capitalize() + ":")
		slot_lbl.custom_minimum_size = Vector2(56, 0)
		slot_lbl.autowrap_mode = 0
		slot_row.add_child(slot_lbl)
		if adv["equipped"].has(slot):
			var item = EquipmentData.get_item(adv["equipped"][slot])
			var item_lbl = _small_label(item.get("name", "?"))
			item_lbl.add_theme_color_override("font_color", ACCENT)
			item_lbl.autowrap_mode = 0
			item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_row.add_child(item_lbl)
			var unequip_btn = Button.new()
			unequip_btn.text = "✕"
			unequip_btn.custom_minimum_size = Vector2(28, 24)
			unequip_btn.add_theme_stylebox_override("normal", _style(WARNING, 3))
			unequip_btn.add_theme_color_override("font_color", TEXT)
			unequip_btn.add_theme_font_size_override("font_size", 11)
			unequip_btn.pressed.connect(func(): PartyManager.unequip_adventurer(adv_id, slot))
			slot_row.add_child(unequip_btn)
		else:
			var available = []
			for item_id in EquipmentData.get_items_for_slot(slot):
				var item = EquipmentData.get_item(item_id)
				if GameData.inventory.get(item.get("name", ""), 0) > 0:
					available.append(item_id)
			if available.size() > 0:
				var equip_btn = OptionButton.new()
				equip_btn.custom_minimum_size = Vector2(0, 24)
				equip_btn.add_theme_font_size_override("font_size", 11)
				equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				equip_btn.add_item("Equip...")
				for item_id in available:
					equip_btn.add_item(EquipmentData.get_item(item_id).get("name", item_id))
				equip_btn.item_selected.connect(func(idx: int):
					if idx == 0: return
					PartyManager.equip_adventurer(adv_id, available[idx - 1])
				)
				slot_row.add_child(equip_btn)
			else:
				var empty_lbl = _small_label("Empty")
				empty_lbl.autowrap_mode = 0
				empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slot_row.add_child(empty_lbl)

	# ── Description ───────────────────────────────────────────────────────────
	var class_descriptions = {
		"warrior": "A battle-hardened fighter clad in heavy armor, built to take punishment and hold the front line.",
		"mage": "A wielder of arcane forces, fragile but devastatingly powerful at range.",
		"ranger": "A swift hunter skilled in ranged combat and evasion, striking from the shadows.",
		"cleric": "A holy healer who supports allies and smites enemies with divine power.",
	}
	var desc_panel = PanelContainer.new()
	desc_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.10, 0.14, 0.8), 4))
	outer.add_child(desc_panel)
	var desc_lbl = _small_label(class_descriptions.get(adv["class"], ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_panel.add_child(desc_lbl)

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
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.color = Color(dungeon.get("bg_color", "#333333"))
	main_box.add_child(bg)

	# Dungeon scene background
	var bg_map = {
		"forest":      "res://assets/Backgrounds/dungeon_forest.png",
		"desert":      "res://assets/Backgrounds/dungeon_desert.png",
		"battlefield": "res://assets/Backgrounds/dungeon_battlefield.png",
	}
	var bg_path = bg_map.get(dungeon_id, "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var bg_img = TextureRect.new()
		bg_img.texture = load(bg_path)
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg_img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bg_img.modulate = Color(1, 1, 1, 0.55)
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_child(bg_img)

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

		# ── Side-by-side: loot left, combat log right ─────────────────────────
		var columns = HBoxContainer.new()
		columns.add_theme_constant_override("separation", 12)
		columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
		info_box.add_child(columns)

		# Left — Loot
		var loot_col = VBoxContainer.new()
		loot_col.add_theme_constant_override("separation", 4)
		loot_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loot_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columns.add_child(loot_col)

		var loot_hdr = _small_label("LOOT COLLECTED")
		loot_hdr.add_theme_color_override("font_color", ACCENT)
		loot_col.add_child(loot_hdr)

		if state["accumulated_loot"].size() > 0:
			for item_name in state["accumulated_loot"].keys():
				var amount = state["accumulated_loot"][item_name]
				var loot_lbl = _small_label("%s x%d" % [item_name, amount])
				loot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				loot_col.add_child(loot_lbl)
		else:
			loot_col.add_child(_small_label("Nothing yet..."))

		# Right — Combat log
		var log_col = VBoxContainer.new()
		log_col.add_theme_constant_override("separation", 4)
		log_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		log_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columns.add_child(log_col)

		var log_hdr = _small_label("COMBAT LOG")
		log_hdr.add_theme_color_override("font_color", Color(0.96, 0.86, 0.36))
		log_col.add_child(log_hdr)

		var log_scroll = ScrollContainer.new()
		log_scroll.custom_minimum_size = Vector2(0, 140)
		log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		log_col.add_child(log_scroll)

		var log_box = VBoxContainer.new()
		log_box.name = "CombatLog_" + dungeon_id
		log_box.add_theme_constant_override("separation", 2)
		log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		log_scroll.add_child(log_box)

		for entry in PartyManager.get_combat_log(dungeon_id):
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
