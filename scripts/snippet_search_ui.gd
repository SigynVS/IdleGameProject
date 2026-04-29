extends Control

@onready var search_bar: LineEdit = $Panel/VBoxContainer/SearchBar
@onready var result_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ResultList

func _ready() -> void:
	# Keep list empty on start
	update_list("")
	search_bar.text_changed.connect(_on_search_bar_text_changed)

func _on_search_bar_text_changed(new_text: String) -> void:
	update_list(new_text)

func update_list(query: String) -> void:
	# 1. Clear old search result buttons
	for child in result_list.get_children():
		child.queue_free()
	
	# 2. Exit early if the search bar is empty
	if query.strip_edges() == "":
		return
	
	# 3. Fetch from the database
	var results = SnippetDB.search(query)
	
	# 4. Create a button for each result
	for data in results:
		var btn = Button.new()
		btn.text = "[%s] %s" % [data.get("category", "General"), data["title"]]
		btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		
		# Ensure visibility on laptop screens
		btn.custom_minimum_size.y = 40
		
		# Connect the data to the click event
		btn.pressed.connect(_on_snippet_selected.bind(data))
		
		result_list.add_child(btn)

func _on_snippet_selected(data: Dictionary) -> void:
	# The magic moment: send to system clipboard
	DisplayServer.clipboard_set(data["code"])
	print("📋 Snippet '%s' copied to clipboard!" % data["title"])
