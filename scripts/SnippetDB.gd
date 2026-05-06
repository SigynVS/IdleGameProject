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
	
	print("=== SnippetDB Initializing ===")
	print("Database path: %s" % DB_PATH)
	
	if not db.open_db():
		push_error("FAILED TO OPEN DATABASE!")
		return
	
	print("Database opened successfully")
	db.query("PRAGMA foreign_keys = ON;")
	db.query("PRAGMA synchronous = FULL;")  # Force immediate writes to disk
	_apply_schema()
	_migrate_db()
	print("=== SnippetDB Ready ===")

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
	print("Running database migration...")
	
	# Player data — one row, columns for every skill
	var columns = "id INTEGER PRIMARY KEY, gold INTEGER"
	for skill in ALL_SKILLS:
		columns += ", %s_xp INTEGER DEFAULT 0, %s_level INTEGER DEFAULT 1" % [skill, skill]
	db.query("CREATE TABLE IF NOT EXISTS player_data (%s);" % columns)
	print("Created/verified player_data table")
	
	# Add any missing skill columns to existing table
	_add_missing_skill_columns()

	db.query("CREATE TABLE IF NOT EXISTS skills_used (skill_name TEXT PRIMARY KEY);")
	db.query("CREATE TABLE IF NOT EXISTS inventory_data (item_name TEXT PRIMARY KEY, amount INTEGER);")
	db.query("CREATE TABLE IF NOT EXISTS session_data (id INTEGER PRIMARY KEY, last_logout INTEGER);")
	db.query("CREATE TABLE IF NOT EXISTS equipped_data (slot TEXT PRIMARY KEY, item_id TEXT);")
	db.query("CREATE TABLE IF NOT EXISTS game_state (key TEXT PRIMARY KEY, value TEXT);")
	
	# Party system tables
	db.query("CREATE TABLE IF NOT EXISTS adventurers (adventurer_id TEXT PRIMARY KEY, data TEXT);")
	db.query("CREATE TABLE IF NOT EXISTS party_meta (key TEXT PRIMARY KEY, value INTEGER);")
	db.query("CREATE TABLE IF NOT EXISTS active_dungeons (dungeon_id TEXT PRIMARY KEY, data TEXT);")
	
	print("All tables created/verified")

func _add_missing_skill_columns() -> void:
	"""
	Check existing player_data table and add any missing skill columns.
	This allows the database to upgrade gracefully without losing save data.
	"""
	# Get list of existing columns in player_data table
	db.query("PRAGMA table_info(player_data);")
	var existing_columns = []
	for row in db.query_result:
		existing_columns.append(row["name"])
	
	print("Existing columns in player_data: %s" % str(existing_columns))
	
	# Add missing skill columns for each skill
	var columns_added = 0
	for skill in ALL_SKILLS:
		var xp_col = skill + "_xp"
		var level_col = skill + "_level"
		
		# Add XP column if missing
		if not existing_columns.has(xp_col):
			db.query("ALTER TABLE player_data ADD COLUMN %s INTEGER DEFAULT 0;" % xp_col)
			print("✓ Added column: %s" % xp_col)
			columns_added += 1
		
		# Add level column if missing (with special default for hitpoints)
		if not existing_columns.has(level_col):
			var default_level = 10 if skill == "hitpoints" else 1
			db.query("ALTER TABLE player_data ADD COLUMN %s INTEGER DEFAULT %d;" % [level_col, default_level])
			print("✓ Added column: %s" % level_col)
			columns_added += 1
	
	if columns_added == 0:
		print("No missing columns - database is up to date")
	else:
		print("Added %d missing columns" % columns_added)

# ─── Player Data ─────────────────────────────────────────────────────────────

func save_player_data(gold: int, skills: Dictionary, skills_used: Dictionary) -> void:
	print("\n=== SAVING PLAYER DATA ===")
	print("Gold to save: %d" % gold)
	
	# Start a transaction for atomic save
	db.query("BEGIN TRANSACTION;")
	
	# Delete existing data
	db.query("DELETE FROM player_data;")
	print("Cleared existing player_data")
	
	# Build the INSERT statement
	var cols = "id, gold"
	var vals = "1, " + str(gold)
	for skill in ALL_SKILLS:
		cols += ", %s_xp, %s_level" % [skill, skill]
		var xp  = skills[skill]["xp"]    if skills.has(skill) else 0
		var lvl = skills[skill]["level"] if skills.has(skill) else 1
		vals += ", %d, %d" % [xp, lvl]
	
	var sql = "INSERT INTO player_data (%s) VALUES (%s);" % [cols, vals]
	db.query(sql)
	
	# Save skills_used
	db.query("DELETE FROM skills_used;")
	for skill_name in skills_used.keys():
		db.query_with_bindings("INSERT OR IGNORE INTO skills_used (skill_name) VALUES (?);", [skill_name])
	print("Saved %d skills_used entries" % skills_used.size())
	
	# Commit the transaction and force write to disk
	db.query("COMMIT;")
	
	# Verify the save worked by reading it back
	db.query("SELECT * FROM player_data WHERE id = 1;")
	if db.query_result.size() > 0:
		print("✓ Player data saved")
	else:
		push_error("✗ SAVE FAILED - No data in database after save!")
	print("=== SAVE COMPLETE ===\n")

func load_player_data() -> Dictionary:
	print("\n=== LOADING PLAYER DATA ===")
	db.query("SELECT * FROM player_data WHERE id = 1;")
	
	if db.query_result.size() > 0:
		var data = db.query_result[0]
		print("✓ Loaded player data")
		print("  Gold: %d" % data.get("gold", 0))
		var total = _calculate_total_level_from_data(data)
		print("  Total level: %d" % total)
		print("=== LOAD COMPLETE ===\n")
		return data
	else:
		print("✗ No save data found in database")
		print("=== LOAD COMPLETE (empty) ===\n")
		return {}

func _calculate_total_level_from_data(data: Dictionary) -> int:
	var total = 0
	for skill in ALL_SKILLS:
		total += data.get(skill + "_level", 1)
	return total

func load_skills_used() -> Dictionary:
	db.query("SELECT * FROM skills_used;")
	var result = {}
	for row in db.query_result:
		result[row["skill_name"]] = true
	return result

# ─── Inventory ───────────────────────────────────────────────────────────────

func save_inventory(inventory: Dictionary) -> void:
	db.query("BEGIN TRANSACTION;")
	db.query("DELETE FROM inventory_data;")
	for item in inventory.keys():
		if inventory[item] > 0:
			db.query_with_bindings(
				"INSERT INTO inventory_data (item_name, amount) VALUES (?, ?);",
				[item, inventory[item]]
			)
	db.query("COMMIT;")

func load_inventory() -> Dictionary:
	db.query("SELECT * FROM inventory_data;")
	var result: Dictionary = {}
	for row in db.query_result:
		result[row["item_name"]] = row["amount"]
	return result

# ─── Equipment ───────────────────────────────────────────────────────────────

func save_equipped(equipped: Dictionary) -> void:
	db.query("BEGIN TRANSACTION;")
	db.query("DELETE FROM equipped_data;")
	for slot in equipped.keys():
		db.query_with_bindings(
			"INSERT INTO equipped_data (slot, item_id) VALUES (?, ?);",
			[slot, equipped[slot]]
		)
	db.query("COMMIT;")

func load_equipped() -> Dictionary:
	db.query("SELECT * FROM equipped_data;")
	var result: Dictionary = {}
	for row in db.query_result:
		result[row["slot"]] = row["item_id"]
	return result

# ─── Party System ────────────────────────────────────────────────────────────

func save_adventurers(adventurers: Dictionary, next_id: int) -> void:
	db.query("BEGIN TRANSACTION;")
	db.query("DELETE FROM adventurers;")
	db.query("DELETE FROM party_meta;")
	
	# Save each adventurer as JSON
	for adv_id in adventurers.keys():
		var json_data = JSON.stringify(adventurers[adv_id])
		db.query_with_bindings(
			"INSERT INTO adventurers (adventurer_id, data) VALUES (?, ?);",
			[adv_id, json_data]
		)
	
	# Save next ID
	db.query_with_bindings(
		"INSERT INTO party_meta (key, value) VALUES (?, ?);",
		["next_adventurer_id", next_id]
	)
	
	db.query("COMMIT;")
	print("Saved %d adventurers" % adventurers.size())

func load_adventurers() -> Dictionary:
	db.query("SELECT * FROM adventurers;")
	var adventurers = {}
	
	for row in db.query_result:
		var adv_id = row["adventurer_id"]
		var json_str = row["data"]
		var json = JSON.new()
		var parse_result = json.parse(json_str)
		if parse_result == OK:
			adventurers[adv_id] = json.data
	
	# Load next ID
	db.query_with_bindings("SELECT value FROM party_meta WHERE key = ?;", ["next_adventurer_id"])
	var next_id = 1
	if db.query_result.size() > 0:
		next_id = db.query_result[0]["value"]
	
	print("Loaded %d adventurers" % adventurers.size())
	return {"adventurers": adventurers, "next_id": next_id}

func save_dungeons(dungeons: Dictionary) -> void:
	db.query("BEGIN TRANSACTION;")
	db.query("DELETE FROM active_dungeons;")
	
	for dungeon_id in dungeons.keys():
		var json_data = JSON.stringify(dungeons[dungeon_id])
		db.query_with_bindings(
			"INSERT INTO active_dungeons (dungeon_id, data) VALUES (?, ?);",
			[dungeon_id, json_data]
		)
	
	db.query("COMMIT;")
	print("Saved %d active dungeons" % dungeons.size())

func load_dungeons() -> Dictionary:
	db.query("SELECT * FROM active_dungeons;")
	var dungeons = {}
	
	for row in db.query_result:
		var dungeon_id = row["dungeon_id"]
		var json_str = row["data"]
		var json = JSON.new()
		var parse_result = json.parse(json_str)
		if parse_result == OK:
			dungeons[dungeon_id] = json.data
	
	print("Loaded %d active dungeons" % dungeons.size())
	return dungeons

# ─── Timestamps ──────────────────────────────────────────────────────────────

func save_timestamp(timestamp: int) -> void:
	db.query("BEGIN TRANSACTION;")
	db.query("DELETE FROM session_data;")
	db.query_with_bindings("INSERT INTO session_data (id, last_logout) VALUES (1, ?);", [timestamp])
	db.query("COMMIT;")

func load_timestamp() -> int:
	db.query("SELECT * FROM session_data WHERE id = 1;")
	if db.query_result.size() > 0:
		return db.query_result[0]["last_logout"]
	return 0

func save_state_value(key: String, value: String) -> void:
	db.query("BEGIN TRANSACTION;")
	db.query_with_bindings(
		"INSERT OR REPLACE INTO game_state (key, value) VALUES (?, ?);",
		[key, value]
	)
	db.query("COMMIT;")

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
	print("SnippetDB shutting down - ensuring all data is written to disk")
	if db:
		db.query("PRAGMA wal_checkpoint(TRUNCATE);")
		db.close_db()
	print("SnippetDB closed")
