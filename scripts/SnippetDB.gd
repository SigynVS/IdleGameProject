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

func _exit_tree() -> void:
	if db:
		db.close_db()
