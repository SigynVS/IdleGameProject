extends Node

const DB_PATH := "user://snippets.db"
const SCHEMA_PATH := "res://data/snippet_db_schema.sql"

var db: SQLite

const ALL_SKILLS = [
	"woodcutting", "mining", "fishing", "farming", "hunting",
	"smithing", "crafting", "fletching", "herblore", "cooking", "firemaking",
	"thieving", "agility", "slayer", "prayer", "magic",
	"attack", "strength", "defence", "hitpoints", "ranged"
]

func _ready() -> void:
	db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.QUIET
	db.open_db()
	db.query("PRAGMA foreign_keys = ON;")
	_apply_schema()
	_migrate_db()

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

func _migrate_db() -> void:
	# Player data — one row, columns for every skill
	var columns = "id INTEGER PRIMARY KEY, gold INTEGER"
	for skill in ALL_SKILLS:
		columns += ", %s_xp INTEGER DEFAULT 0, %s_level INTEGER DEFAULT 1" % [skill, skill]
	db.query("CREATE TABLE IF NOT EXISTS player_data (%s);" % columns)

	db.query("CREATE TABLE IF NOT EXISTS skills_used (skill_name TEXT PRIMARY KEY);")
	db.query("CREATE TABLE IF NOT EXISTS inventory_data (item_name TEXT PRIMARY KEY, amount INTEGER);")
	db.query("CREATE TABLE IF NOT EXISTS session_data (id INTEGER PRIMARY KEY, last_logout INTEGER);")
	db.query("CREATE TABLE IF NOT EXISTS equipped_data (slot TEXT PRIMARY KEY, item_id TEXT);")
	db.query("CREATE TABLE IF NOT EXISTS game_state (key TEXT PRIMARY KEY, value TEXT);")

# ─── Player Data ─────────────────────────────────────────────────────────────

func save_player_data(gold: int, skills: Dictionary, skills_used: Dictionary) -> void:
	db.query("DELETE FROM player_data;")
	var cols = "id, gold"
	var vals = "1, " + str(gold)
	for skill in ALL_SKILLS:
		cols += ", %s_xp, %s_level" % [skill, skill]
		var xp  = skills[skill]["xp"]    if skills.has(skill) else 0
		var lvl = skills[skill]["level"] if skills.has(skill) else 1
		vals += ", %d, %d" % [xp, lvl]
	db.query("INSERT INTO player_data (%s) VALUES (%s);" % [cols, vals])

	db.query("DELETE FROM skills_used;")
	for skill_name in skills_used.keys():
		db.query_with_bindings("INSERT OR IGNORE INTO skills_used (skill_name) VALUES (?);", [skill_name])

func load_player_data() -> Dictionary:
	db.query("SELECT * FROM player_data WHERE id = 1;")
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

func load_skills_used() -> Dictionary:
	db.query("SELECT * FROM skills_used;")
	var result = {}
	for row in db.query_result:
		result[row["skill_name"]] = true
	return result

# ─── Inventory ───────────────────────────────────────────────────────────────

func save_inventory(inventory: Dictionary) -> void:
	db.query("DELETE FROM inventory_data;")
	for item in inventory.keys():
		if inventory[item] > 0:
			db.query_with_bindings(
				"INSERT INTO inventory_data (item_name, amount) VALUES (?, ?);",
				[item, inventory[item]]
			)

func load_inventory() -> Dictionary:
	db.query("SELECT * FROM inventory_data;")
	var result: Dictionary = {}
	for row in db.query_result:
		result[row["item_name"]] = row["amount"]
	return result

# ─── Equipment ───────────────────────────────────────────────────────────────

func save_equipped(equipped: Dictionary) -> void:
	db.query("DELETE FROM equipped_data;")
	for slot in equipped.keys():
		db.query_with_bindings(
			"INSERT INTO equipped_data (slot, item_id) VALUES (?, ?);",
			[slot, equipped[slot]]
		)

func load_equipped() -> Dictionary:
	db.query("SELECT * FROM equipped_data;")
	var result: Dictionary = {}
	for row in db.query_result:
		result[row["slot"]] = row["item_id"]
	return result

# ─── Timestamps ──────────────────────────────────────────────────────────────

func save_timestamp(timestamp: int) -> void:
	db.query("DELETE FROM session_data;")
	db.query_with_bindings("INSERT INTO session_data (id, last_logout) VALUES (1, ?);", [timestamp])

func load_timestamp() -> int:
	db.query("SELECT * FROM session_data WHERE id = 1;")
	if db.query_result.size() > 0:
		return db.query_result[0]["last_logout"]
	return 0

func save_state_value(key: String, value: String) -> void:
	db.query_with_bindings(
		"INSERT OR REPLACE INTO game_state (key, value) VALUES (?, ?);",
		[key, value]
	)

func load_state_value(key: String, default_value := "") -> String:
	db.query_with_bindings("SELECT value FROM game_state WHERE key = ?;", [key])
	if db.query_result.size() > 0:
		return str(db.query_result[0]["value"])
	return default_value

# ─── Snippets ────────────────────────────────────────────────────────────────

func add_snippet(title: String, code: String, language := "GDScript", version := "4.x", desc := "", cat := "") -> int:
	db.query_with_bindings(
		"INSERT OR IGNORE INTO snippet (title, code, language, godot_version, description, category) VALUES (?, ?, ?, ?, ?, ?)",
		[title, code, language, version, desc, cat]
	)
	return db.last_insert_rowid

func search(query: String) -> Array:
	var param := "%" + query + "%"
	db.query_with_bindings(
		"SELECT * FROM snippet WHERE title LIKE ? OR description LIKE ? OR category LIKE ? ORDER BY use_count DESC",
		[param, param, param]
	)
	return db.query_result.duplicate()

func _exit_tree() -> void:
	if db:
		db.close_db()
