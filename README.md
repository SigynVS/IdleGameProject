# Idle Skilling Game

> A browser-based idle/clicker game built with Godot 4.6, featuring passive resource generation, skill progression, and upgrade systems.

![Godot](https://img.shields.io/badge/Engine-Godot%204.6-blue) ![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20Android-green) ![Language](https://img.shields.io/badge/Language-GDScript-orange)

---

## What This Project Demonstrates

- **Godot 4.6** game development with scene/node architecture
- **GDScript** scripting for game logic, save/load systems, and UI
- **Android export** — packaged as `.apk` via Godot's export pipeline
- **Game systems design** — idle progression, resource management, upgrade trees
- **Save/load system** — persistent game state across sessions
- **Party/multiplayer system** — experimental party mechanics (see `party_test.tscn`)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Engine | Godot 4.6 |
| Language | GDScript |
| Platform | Web, Android (.apk) |
| Architecture | Scene/Node tree, Autoload singletons |

---

## Project Structure

```
IdleGameProject/
  project.godot         Godot project config
  scenes/               Game scenes (UI, gameplay, menus)
  scripts/              GDScript logic files
  assets/               Sprites, icons, audio
  data/                 Game data definitions
  addons/               Godot plugins/addons
  build/                Export output
  IdleGame.apk          Android build
```

---

## Running the Project

1. Download [Godot 4.6](https://godotengine.org/download)
2. Open Godot → **Import** → select `project.godot`
3. Press **F5** to run

---

## Android Build

An `.apk` is included in the repo root. Install directly on Android or use:

```bash
adb install IdleGame.apk
```

---

*Built by [Brian Justice](https://github.com/SigynVS)*
