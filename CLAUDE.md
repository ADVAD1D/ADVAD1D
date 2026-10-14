# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ADVAD is a 2D arcade space shooter written in GDScript for **Godot 4.7** (`project.godot` targets 4.7; CI pins `4.7.1-stable`). `docs/README.md` and `docs/AGENTS.md` still mention 4.5/4.6 — trust `project.godot`. The renderer is `gl_compatibility` (the "Forward Plus" feature tag is misleading), with a 520x300 base viewport stretched via `canvas_items`.

## Agent rules (from `docs/AGENTS.md` and `docs/README.md`)

1. **No Git commands.** Do not commit, push, pull, etc. Version control is handled by the developer.
2. **Ask before running any terminal command.**
3. **Ask before creating or running any Python, utility, or node-search scripts.**

## Commands

There is no test suite. All CI workflows are `workflow_dispatch` only (manual).

```bash
# Lint (gdtoolkit: pip install gdtoolkit) — same as .github/workflows/gdlint.yml
gdlint . --exclude addons/
gdlint Scripts/player.gd            # single file

# Run the game / a single scene
godot --path .
godot --path . res://Scenes/arena2.tscn

# Import assets headlessly (CI runs this twice; the second pass is needed for heavy audio)
godot --headless --editor --quit

# Export (preset names: "Web", "Android", "iOS", "Windows Desktop", "Linux")
godot --headless --export-release "Web" build_web/index.html
```

`export_presets.cfg` and `.env` are gitignored; CI recreates both from secrets (`EXPORT_PRESETS_CFG`, `APP_TOKEN`). `.env` must exist at the project root with `APP_TOKEN=...` — `EnvParser` reads `./.env` and `Network` puts the value in the `X-App-Token` header.

## Architecture

### Autoloads (`project.godot` `[autoload]`)

Global state and cross-scene services live in autoloads. Several are registered by UID or under a name that differs from the file:

- `GameManager` (`Autoloads/game_manager.gd`) — the hub. Score, `phase_to_start`, `current_arena_index`, pause, feature/debug flags, speedrun timer, save/load (`user://save_game.json`; web builds persist only the pilot name), glitch transition helpers (`play_glitch_effect`, `freeze_frame`/`unfreeze_frame`), and preloaded `PackedScene`s for the heavy scenes.
- `Network` → `Autoloads/api_service.gd`. HTTP client for the backend (`advad-ai-server`, a separate FastAPI repo on Render described in `docs/SECURITY.md`). One `HTTPRequest` node per endpoint so calls can overlap; an in-flight request on the same node is dropped, not queued. Results come back through signals (`server_status_checked`, `ai_response_received`, `request_failed`, `phase_recorded_successfully`, `name_check_completed`, `identity_recovered`). `GameManager.production_server_active` picks the Render URL vs `http://127.0.0.1:10000`.
- `SkinManager` — ship list and the selected ship (`selected_ship_index`, `ship_selection_changed`). Ship data lives here, not in `GameManager` as `docs/AGENTS.md` says.
- `ShaderManager`, `WebOptimizer`, `MobileOptimizer` — platform degradation, see below.
- `EnemyLaserPool` — object pool for enemy lasers.
- `DebugMenu` — overlay toggled by the `debug` action (Tab); other scripts feed it via `DebugMenu.track(label, value)`, `watch()`, `register_ray()`, `register_point()`.
- `MusicPlayer` (a `.tscn`), `SfxManager`, `FontManager`.
- `MainManager` is an empty stub. `DialogueManager`, `DiscordRPCLoader`, `EnvParser`, `_mcp_game_helper` come from `addons/`.

### Scene flow

`spash_screen.tscn` (main scene; the filename typo is real) → `main_menu.tscn` → `Abduction.tscn` → `tutorial.tscn` → arenas → `trigger_scene.tscn` (an `Area2D` in the arena that fades to `ending.tscn`) → `main_menu.tscn`.

Scene links are `@export var next_scene: PackedScene` set in the `.tscn`, not paths in code.

### Arenas and phases

`main.tscn` (arena index 0) and `arena2.tscn` (index 1) both use `Scripts/main.gd`; the only per-arena switch is `@export var arena_index`, which `main.gd` writes to `GameManager.current_arena_index` in `_enter_tree` — before `PhaseManager._ready` reads it.

`Scripts/phase_manager.gd` (a node inside each arena scene) drives the loop. Its three dictionaries — `arena_enemy_configs`, `arena_phase_requirements`, `arena_phase_durations` — are keyed by arena index, then phase 1–10, and are the place to tune difficulty. Arena 2 exists in the tables but has no scene yet. The phase table in `docs/AGENTS.md` only describes arena 0.

- Phase start: `apply_difficulty()` lerps ship count/speed/fire rate by phase progress and pushes the result into the spawners through `configure_for_phase(max_enemies, config)`; the spawner hands the config dictionary to each enemy's `setup()`.
- Success (score reached): clear the board, set `GameManager.phase_to_start = current_phase + 1`, start the next phase in place — no scene reload. From phase 2 onward it also reports the phase to the leaderboard via `Network.send_player_phase`.
- Failure (timer out or player death): `reload_current_scene()` with `phase_to_start` unchanged, so the player retries the same phase. State that must survive the reload (`is_shader_animation`, `is_glitch_sound`, the frozen frame) is parked on `GameManager` and consumed in `main.gd._ready`.
- All phases done: spawners stop, `wall_to_remove` is freed, opening the path to the scene trigger.

`PhaseManager` reaches HUD nodes by hardcoded relative paths (`$"../UILayer/HUD"...`), and `trigger_scene.gd` looks up `/root/Main`, so arena scenes need those node names and layout.

### Groups are the collision/interaction contract

Entities identify each other with `is_in_group` checks rather than types, and group names are a mix of Spanish and English: `asteroides`, `enemigos`, `colisiones`, `lasers`, `enemy_laser`, `saws`, `enemies`, `enemies_death`, `allies`, `player`, `player_shield`, `destructibles`, `powerup_spawners`, `time_slow_effect`. Note `enemies` (added by the spawner at runtime, used for `call_group("enemies", "die_silently")`) versus `enemigos` (checked for player body collisions). Anything in `saws`/`enemies` must implement `die_silently()`; anything in `powerup_spawners` must implement `stop()`.

### Enemy laser pooling

Enemy lasers are never instantiated or freed directly. Use `EnemyLaserPool.acquire(parent, spawn_position, fire_direction, origin)` and `EnemyLaserPool.release(laser)`; `enemy_laser.gd` implements `activate()`/`deactivate()`. Calling `queue_free()` on one breaks the pool. The laser shield re-tags a deflected enemy laser into the `lasers` group, which `enemy_laser.gd` undoes on reactivation.

### Platform degradation

One codebase serves desktop, web (single-threaded), and mobile; behavior branches at runtime on `GameManager.mobile_mode_active`, `OS.has_feature("web")`, and `GameManager.force_web_mode` (set it to test the web path on desktop).

- CRT shader (`Shaders/CRT.gdshader`): `ShaderManager` and `WebOptimizer` hook `SceneTree.node_added`, and on every scene change scan for `ShaderMaterial`s whose shader path contains `"CRT"` and set `low_quality` and related parameters. `WebOptimizer` frees itself on native builds. A new CRT-style shader needs "CRT" in its path to be picked up.
- Shader warm-up: at boot `GameManager` runs `Scripts/shader_warmup.gd`, which reads the preloaded scenes through `SceneState` (no instantiation), and draws one script-less "ghost" per unique drawable/material in an offscreen `SubViewport`, a few per frame, so shaders compile during the splash instead of freezing the first frame of an arena. The splash waits on `GameManager.wait_for_shader_warmup()`. Scenes spawned only via `preload()` in scripts must be added to the list in `GameManager._start_shader_warmup`.
- `MobileOptimizer` turns on `mobile_mode_active` for Android/iOS, caps the framerate to an even divisor of the screen refresh rate (60 on 60/120Hz, 90 on 90Hz) and sets the physics tick rate to match, so per-tick smoothing must be written delta-based (`1.0 - pow(1.0 - k, delta * 60.0)`), never as a fixed lerp factor, and switches the window to `CONTENT_SCALE_ASPECT_EXPAND`.
- UI is laid out with absolute coordinates for 520x300. Instead of anchors, UI scripts (`hud.gd`, `main_menu.gd`, `skin_selector.gd`, splash) store original positions and shift them by the offset from x=260 on `size_changed`. New UI nodes in those scenes follow that pattern.
- Particle scripts shorten lifetimes and arenas disable light shadows in mobile mode.

### Conventions

- Logging goes through a per-script `_log_message(message)` (string or array) that prints only when `GameManager.is_debug_text` is true. The function is copy-pasted into each script rather than shared; `Network` additionally has `_log_dev` for debug builds only.
- Comments and log strings are a mix of English and Spanish.
- `addons/` is third-party (Dialogue Manager, Discord RPC, env_parser, godot_ai MCP plugin, kanban_tasks, git plugin) and is excluded from linting.
