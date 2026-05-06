extends Control

# Simple test UI for party system

var adventurer_list: VBoxContainer
var dungeon_list: VBoxContainer

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var main_box = VBoxContainer.new()
	main_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_box.add_theme_constant_override("separation", 20)
	add_child(main_box)
	
	# Title
	var title = Label.new()
	title.text = "PARTY SYSTEM TEST"
	title.add_theme_font_size_override("font_size", 32)
	main_box.add_child(title)
	
	# Recruit buttons
	var recruit_box = HBoxContainer.new()
	recruit_box.add_theme_constant_override("separation", 10)
	main_box.add_child(recruit_box)
	
	for class_id in PartyManager.ADVENTURER_CLASSES.keys():
		var btn = Button.new()
		btn.text = "Recruit " + PartyManager.ADVENTURER_CLASSES[class_id]["name"]
		btn.pressed.connect(_on_recruit_pressed.bind(class_id))
		recruit_box.add_child(btn)
	
	# Adventurer list
	var adv_label = Label.new()
	adv_label.text = "ADVENTURERS:"
	adv_label.add_theme_font_size_override("font_size", 24)
	main_box.add_child(adv_label)
	
	adventurer_list = VBoxContainer.new()
	adventurer_list.add_theme_constant_override("separation", 5)
	main_box.add_child(adventurer_list)
	
	# Dungeon controls
	var dungeon_label = Label.new()
	dungeon_label.text = "DUNGEONS:"
	dungeon_label.add_theme_font_size_override("font_size", 24)
	main_box.add_child(dungeon_label)
	
	var dungeon_buttons = HBoxContainer.new()
	dungeon_buttons.add_theme_constant_override("separation", 10)
	main_box.add_child(dungeon_buttons)
	
	for dungeon_id in PartyManager.DUNGEON_DEFS.keys():
		var btn = Button.new()
		btn.text = "Start " + PartyManager.DUNGEON_DEFS[dungeon_id]["name"]
		btn.pressed.connect(_on_start_dungeon_pressed.bind(dungeon_id))
		dungeon_buttons.add_child(btn)
	
	dungeon_list = VBoxContainer.new()
	dungeon_list.add_theme_constant_override("separation", 10)
	main_box.add_child(dungeon_list)
	
	# Connect signals
	PartyManager.adventurer_recruited.connect(_refresh_adventurers)
	PartyManager.dungeon_started.connect(_refresh_dungeons)
	PartyManager.dungeon_progress.connect(_on_dungeon_progress)
	PartyManager.dungeon_completed.connect(_on_dungeon_completed)
	
	_refresh_adventurers("")
	_refresh_dungeons("")
	
	# Refresh timer
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh_dungeons.bind(""))
	timer.autostart = true
	add_child(timer)

func _on_recruit_pressed(class_id: String):
	PartyManager.recruit_adventurer(class_id)

func _on_start_dungeon_pressed(dungeon_id: String):
	var idle_advs = PartyManager.get_idle_adventurers()
	if idle_advs.size() == 0:
		print("No idle adventurers!")
		return
	
	# Send first idle adventurer
	PartyManager.start_dungeon(dungeon_id, [idle_advs[0]])

func _refresh_adventurers(_adv_id):
	for child in adventurer_list.get_children():
		child.queue_free()
	
	for adv_id in PartyManager.get_all_adventurer_ids():
		var adv = PartyManager.get_adventurer(adv_id)
		var label = Label.new()
		label.text = "%s (%s) Lv.%d - ATK:%d DEF:%d - %s" % [
			adv["name"],
			adv["class"],
			adv["level"],
			PartyManager.get_adventurer_total_attack(adv_id),
			PartyManager.get_adventurer_total_defence(adv_id),
			"IDLE" if adv["assigned_dungeon"] == "" else adv["assigned_dungeon"]
		]
		adventurer_list.add_child(label)

func _refresh_dungeons(_dungeon_id):
	for child in dungeon_list.get_children():
		child.queue_free()
	
	for dungeon_id in PartyManager.active_dungeons.keys():
		var state = PartyManager.get_dungeon_state(dungeon_id)
		var dungeon = PartyManager.DUNGEON_DEFS[dungeon_id]
		
		var panel = PanelContainer.new()
		var box = VBoxContainer.new()
		panel.add_child(box)
		
		var title = Label.new()
		title.text = "%s - %s" % [dungeon["name"], state["phase"].capitalize()]
		box.add_child(title)
		
		var info = Label.new()
		info.text = "Cycles: %d | Loot: %s" % [state["cycles_completed"], str(state["accumulated_loot"])]
		box.add_child(info)
		
		var stop_btn = Button.new()
		stop_btn.text = "Stop & Collect Loot"
		stop_btn.pressed.connect(func(): PartyManager.stop_dungeon(dungeon_id))
		box.add_child(stop_btn)
		
		dungeon_list.add_child(panel)

func _on_dungeon_progress(dungeon_id: String, phase: String, progress: float):
	pass # Could add progress bars here

func _on_dungeon_completed(dungeon_id: String, loot: Dictionary):
	print("Dungeon completed! Loot: %s" % str(loot))
	_refresh_adventurers("")
