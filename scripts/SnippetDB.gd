extends Node

const DB_PATH := "user://snippets.db"
const SCHEMA_PATH := "res://data/snippet_db_schema.sql"

var db: SQLite

func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.QUIET
	db.open_db()
	
	db.query("PRAGMA foreign_keys = ON;")
	_apply_schema()

func _apply_schema() -> void:
	if not FileAccess.file_exists(SCHEMA_PATH):
		push_error("SnippetDB: Schema file not found at %s" % SCHEMA_PATH)
		return
		
	var file := FileAccess.open(SCHEMA_PATH, FileAccess.READ)
	var sql_full := file.get_as_text()
	file.close()

	var lines = sql_full.split("\n")
	var current_command := ""
	var in_trigger := false

	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("--"):
			continue
		
		current_command += " " + trimmed
		
		if trimmed.to_upper().begins_with("CREATE TRIGGER"):
			in_trigger = true
		
		if trimmed.ends_with(";"):
			if not in_trigger or trimmed.to_upper() == "END;":
				db.query(current_command.strip_edges())
				current_command = ""
				in_trigger = false

func add_snippet(title: String, code: String, language := "GDScript", version := "4.x", desc := "", cat := "") -> int:
	var sql = "INSERT OR IGNORE INTO snippet (title, code, language, godot_version, description, category) VALUES (?, ?, ?, ?, ?, ?)"
	db.query_with_bindings(sql, [title, code, language, version, desc, cat])
	return db.last_insert_rowid

func search(query: String) -> Array:
	var sql := "SELECT * FROM snippet WHERE title LIKE ? OR description LIKE ? OR category LIKE ? ORDER BY use_count DESC"
	var param := "%" + query + "%"
	db.query_with_bindings(sql, [param, param, param])
	return db.query_result.duplicate()

func save_player_data(gold: int, skills: Dictionary) -> void:
	db.query("CREATE TABLE IF NOT EXISTS player_data (id INTEGER PRIMARY KEY, gold INTEGER, mining_xp INTEGER, mining_level INTEGER, woodcutting_xp INTEGER, woodcutting_level INTEGER);")
	db.query("DELETE FROM player_data;")
	var sql = "INSERT INTO player_data (id, gold, mining_xp, mining_level, woodcutting_xp, woodcutting_level) VALUES (1, ?, ?, ?, ?, ?)"
	db.query_with_bindings(sql, [
		gold,
		skills["mining"]["xp"],
		skills["mining"]["level"],
		skills["woodcutting"]["xp"],
		skills["woodcutting"]["level"]
	])

func load_player_data() -> Dictionary:
	db.query("CREATE TABLE IF NOT EXISTS player_data (id INTEGER PRIMARY KEY, gold INTEGER, mining_xp INTEGER, mining_level INTEGER, woodcutting_xp INTEGER, woodcutting_level INTEGER);")
	db.query("SELECT * FROM player_data WHERE id = 1;")
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

func save_inventory(inventory: Dictionary) -> void:
	db.query("CREATE TABLE IF NOT EXISTS inventory_data (item_name TEXT PRIMARY KEY, amount INTEGER);")
	db.query("DELETE FROM inventory_data;")
	for item in inventory.keys():
		if inventory[item] > 0:
			var sql = "INSERT INTO inventory_data (item_name, amount) VALUES (?, ?)"
			db.query_with_bindings(sql, [item, inventory[item]])

func load_inventory() -> Dictionary:
	db.query("CREATE TABLE IF NOT EXISTS inventory_data (item_name TEXT PRIMARY KEY, amount INTEGER);")
	db.query("SELECT * FROM inventory_data;")
	var result: Dictionary = {}
	for row in db.query_result:
		result[row["item_name"]] = row["amount"]
	return result

func _exit_tree() -> void:
	if db:
		db.close_db()
