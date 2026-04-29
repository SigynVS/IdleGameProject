-- Godot Code Snippet Database Schema
-- Optimized for SQLite & Godot-SQLite Plugin

-- Enable foreign keys to ensure 'ON DELETE CASCADE' works
PRAGMA foreign_keys = ON;
-- Enable WAL mode for better performance on mobile/laptop hardware
PRAGMA journal_mode = WAL;

-- 1. Authors Table
CREATE TABLE IF NOT EXISTS author (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    source_url  TEXT
);

-- 2. Main Snippet Table
CREATE TABLE IF NOT EXISTS snippet (
    id             INTEGER  PRIMARY KEY AUTOINCREMENT,
    title          TEXT     NOT NULL,
    code           TEXT     NOT NULL,
    language       TEXT     DEFAULT 'GDScript',
    godot_version  TEXT     DEFAULT '4.x',
    description    TEXT,
    category       TEXT,
    is_favorite    INTEGER  DEFAULT 0,
    use_count      INTEGER  DEFAULT 0,
    author_id      INTEGER  REFERENCES author(id) ON DELETE SET NULL,
    created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tags Table
CREATE TABLE IF NOT EXISTS tag (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    name      TEXT    UNIQUE NOT NULL,
    color_hex TEXT    DEFAULT '#888888'
);

-- 4. Junction Table for Snippets and Tags
CREATE TABLE IF NOT EXISTS snippet_tag (
    snippet_id INTEGER,
    tag_id     INTEGER,
    PRIMARY KEY (snippet_id, tag_id),
    FOREIGN KEY (snippet_id) REFERENCES snippet(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)     REFERENCES tag(id)     ON DELETE CASCADE
);

-- 5. Collections Table
CREATE TABLE IF NOT EXISTS collection (
    id           INTEGER  PRIMARY KEY AUTOINCREMENT,
    name         TEXT     NOT NULL,
    description  TEXT,
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 6. Junction Table for Collections and Snippets
CREATE TABLE IF NOT EXISTS collection_snippet (
    collection_id INTEGER,
    snippet_id    INTEGER,
    sort_order    INTEGER DEFAULT 0,
    PRIMARY KEY (collection_id, snippet_id),
    FOREIGN KEY (collection_id) REFERENCES collection(id) ON DELETE CASCADE,
    FOREIGN KEY (snippet_id)    REFERENCES snippet(id)    ON DELETE CASCADE
);

-- 7. Dependencies Table
CREATE TABLE IF NOT EXISTS snippet_dependency (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    snippet_id     INTEGER,
    node_type      TEXT,
    autoload_name  TEXT,
    is_required    INTEGER DEFAULT 1,
    FOREIGN KEY (snippet_id) REFERENCES snippet(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- INDEXES (For Speed)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_snippet_category      ON snippet(category);
CREATE INDEX IF NOT EXISTS idx_snippet_godot_version ON snippet(godot_version);
CREATE INDEX IF NOT EXISTS idx_snippet_language      ON snippet(language);
CREATE INDEX IF NOT EXISTS idx_snippet_is_favorite   ON snippet(is_favorite);

-- ---------------------------------------------------------------------------
-- TRIGGERS (Automated Logic)
-- ---------------------------------------------------------------------------

-- Automatically update the 'updated_at' column whenever a snippet is changed
CREATE TRIGGER IF NOT EXISTS update_snippet_timestamp 
AFTER UPDATE ON snippet
FOR EACH ROW
BEGIN
    UPDATE snippet SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;