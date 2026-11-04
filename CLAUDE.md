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
- `SkinManager` — ship list and the selected ship (`selected_ship_index`, `ship_selection_changed`). Ship data lives here, not in `GameManager` as `docs/AGENTS.md` says. `selected_ship_index` is what the skin selector shows; `equipped_ship_index` is what the player flies and what gets saved (only unlocked ships). Ships are locked by default: `is_ship_unlocked()` is true only for `default_unlocked_ships`, ships whose rewarding achievement is unlocked, or everything when `unlock_all_ships` is on. The selector covers locked ships with a padlock (`LockIcon`). Ship colours (Geometry Dash style): the ship sprites themselves are black and white, and `Shaders/ship_color.gdshader` paints them by grey value: black (0–24) = outline, mid grey (48–140) = colour 1 / body, light grey (160–255) = colour 2 / details, darker grey inside a band = shadow, any non-grey pixel keeps its own colour. New ship sprites must be drawn in those grey bands (they must match the shader constants); the coloured originals are backed up in `tools/ship_originals/` (has a `.gdignore`). A ship shown without that shader looks black and white. Anything that shows a ship calls `SkinManager.apply_ship_colors(node, ship_index)` (player, selector preview, shop). Colours come from `Resources/ship_color_palette.tres` (`ShipColorPalette`: colors/names/prices, price 0 = free), are global for every ship, picked in the selector's colour panel and saved by GameManager (`ship_color1`/`ship_color2`). Paid colours are sold in the shop: ShopManager creates one `COLOR` ShopItem per paid colour.
- `AchievementManager` (`Autoloads/achievement_manager.gd`, registered before `GameManager`) — loads every `Achievement` resource (`Scripts/Achievements/achievement.gd`) from `res://Resources/Achievements/`. Gameplay feeds stats with `add_stat()` / `submit_best_time()` / `raise_stat()` (mirrors a count kept elsewhere, e.g. the `deaths` stat follows `GameManager.deaths_count`, capped at 9999, for the "die 1000 times" achievement) or calls `unlock()`; progress lives in `user://achievements.json` (not saved on web). Unlocking an achievement with `reward_ship_index` unlocks that ship (`is_ship_reward_unlocked`). `GameManager.achievements_enabled` only shows the main menu button and the unlock toast. The button opens its own scene, `Scenes/achievements.tscn`, whose rows are built by `Scripts/achievements_screen.gd` from the loaded achievements. Arena clear times come from `begin_arena_run` (main.gd, phase 1 only) and `complete_arena_run` (PhaseManager), which also counts every clear in `arena_<n>_clears` (main mode only; arcade never clears an arena). `main.gd` unlocks the MANUAL `arena_2_reached` achievement (NEW GROUND, ship 27) when arena 2 loads.
- `ArcadeManager` (`Autoloads/arcade_manager.gd`, after `GameManager`) — arcade mode: arena 1 (`main.tscn`) with no phase limit, started from the main menu's play-mode picker (the arrow on PLAY, `PlayModeArrow`, opens `PlayModePanel` with NORMAL/ARCADE; PLAY itself always starts the main mode) via `start_run()`; the scene comes from `GameManager.preloaded_main` because `main.tscn` links back to the menu. `GameManager.arcade_mode_active` marks the run; `GameManager.arcade_enabled` shows the arrow. Every `GameManager.add_score()` also emits `points_added`; ArcadeManager multiplies those points into a separate run score (kill-chain multiplier, `combo_window` / `kills_per_step` / `max_multiplier`), so phase goals still use the raw `GameManager.score`. Every `points_per_diamond` run points pay a diamond. A death (main.gd) or timeout (PhaseManager) calls `end_run()`, which sets `phase_to_start = 1`; the reloaded HUD shows the summary (`take_last_results()`) only after the first death of each arcade session. Best score/phase go to `user://arcade.json`. Its HUD is `Scripts/arcade_hud.gd` (the `ArcadeHud` node in `hud.tscn`, built in code, hidden outside arcade).
- `CurrencyManager` (`Autoloads/currency_manager.gd`) — the diamonds wallet (`add_diamonds`, `spend_diamonds`, `can_afford`, `diamonds_changed`), saved to `user://wallet.json` (not on web).
- `ShopManager` (`Autoloads/shop_manager.gd`, registered after `AchievementManager` and before `GameManager`, because `load_data()` asks SkinManager about owned ships) — loads every `ShopItem` resource (`Scripts/Shop/shop_item.gd`) from `res://Resources/Shop/` and sells them through CurrencyManager; progress in `user://shop.json` (not on web). `UPGRADE` items have one price per level; powerup spawners (`power_up_1_spawner.gd`, `laser_shield_spawner.gd`) with a matching `@export var upgrade_stat` (`shield`, `timewarp`, `ally_saw` in `main.tscn`) get a shorter interval from `get_powerup_interval()`, in arcade mode only. `MYSTERY_SHIP` gives a random ship that is locked by default, not an achievement reward and not in `reserved_ship_numbers` (ships kept for future achievements, by ship number); owned ships count in `SkinManager.is_ship_unlocked()`. The shop scene is `Scenes/shop.tscn` / `Scripts/shop_screen.gd` (3 cards per page with arrows, on desktop buying needs two presses on the same card; with `mobile_mode_active` a tap only selects and the `BuyButton` under the cards buys), opened by the main menu's `ShopButton` (`GameManager.shop_enabled`).
- `ShaderManager`, `WebOptimizer`, `MobileOptimizer` — platform degradation, see below.
- `EnemyLaserPool` — object pool for enemy lasers.
- `CursorManager` (`Autoloads/cursor_manager.gd`) — custom hardware mouse cursor: a pixel-art arrow drawn from the `ARROW` character map (no image file), scaled by the same whole factor as the game's pixels and rebuilt on window resize; lighter while the left button is held. Off on phones.
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
- Arcade mode (`GameManager.arcade_mode_active`): every phase exists. Past the table, the score goal keeps the last step (+500 in arena 1), the duration keeps the last phase's points-per-second pace, and difficulty progress keeps growing by `arcade_overdrive_per_phase` up to `arcade_max_progress` (lerp extrapolates), except the ship count, which stays at its `arcade_ship_count_cap_phase` (8) value. No leaderboard reports, no speedrun timer, no arena clear time.

Arena 2 also has laser guns: `LaserGunSpawner` (`Scripts/Enemies/laser_gun_spawner.gd`, at the scene origin, wall faces in global coordinates) puts `Scenes/laser_gun.tscn` (`LaserGun`, groups `laser_guns` + `enemies`) on the side walls. They patrol up and down, charge (blinking aim line) and fire a beam made with a `RayCast2D` that only stops at walls (`StaticBody2D`); the player is tested against their `Hitbox/CollisionShape2D` (`Shape2D.collide` with the beam as a rectangle), so a disabled hitbox (dash, debugging) is never hit, and a laser shield blocks the beam. The beam also destroys the saws, enemy ships and asteroids it crosses (`intersect_shape`, calling their `die_and_respawn()` / `Asteroid.explode()`, which give no score or saw-achievement progress). How many per phase comes from the arena config's `"laser_guns"` table (`{from phase: count}`, `{3: 1, 7: 2}`), read by `PhaseManager._get_laser_gun_count()`. Spritesheets in `Assets/Sprites/Enemies/`: `laser_gun_sheet.png` (10 frames of 56x32: idle 0-3, charge 4-7, fire 8-9), `laser_gun_spawn.png` (the `spawn` animation of the same sprite, 10 frames of 96x64 with the gun at the same centre; it can't be hit until it ends), `laser_gun_break.png` (death, 9 frames of 96x64) and `laser_beam_impact.png` (4 frames of 24x24 where the beam ends). The gun uses no particles. Shooting one down (player lasers only) adds the `laser_guns_destroyed` stat (GUN BREAKER achievement, rewards ship 15; its icon is an `AtlasTexture` of `laser_gun_break.png`). Its sounds are `Assets/Audio/laser_gun_charge.ogg` (0.9 s, matches `charge_time`) and `laser_gun_fire.ogg` (0.55 s, matches `fire_time`); its death sound is the enemy ships' one, played at the gun's position. `PhaseManager.nodes_to_remove` frees extra nodes with `wall_to_remove` when the arena is won (arena 2: the `LaserZone` shape over the bridge opening).

Arena 2's background (`Sprite2D`, `arena2.png`) has a `BackgroundWaves` child (`Scripts/background_waves.gd`, `Shaders/background_waves.gdshader`): the same texture again, drawing slow pixel-grid waves only where the background is the empty `fill_color` (#000c07, the panels below the room, texture rows >= 280) and copying the background's `grayscale_amount`. The drawing itself is untouched.

Each arena has its own UI colour: the hidden `ArenaTint` node in `hud.tscn` (`Scripts/UI/arena_ui_tint.gd`, `Shaders/ui_hue_shift.gdshader`) hue-rotates every CanvasItem of the HUD (also ones added later) by `GameManager.arena_ui_hue_shifts[current_arena_index]` (0 = blue, -60 = green, 180 = red). Drop the same node into any other UI to tint it. `reset_game_state()` sets `current_arena_index` back to 0.

`PhaseManager` reaches HUD nodes by hardcoded relative paths (`$"../UILayer/HUD"...`), and `trigger_scene.gd` looks up `/root/Main`, so arena scenes need those node names and layout.

### Groups are the collision/interaction contract

Entities identify each other with `is_in_group` checks rather than types, and group names are a mix of Spanish and English: `asteroides`, `enemigos`, `colisiones`, `lasers`, `enemy_laser`, `saws`, `enemies`, `enemies_death`, `allies`, `player`, `player_shield`, `destructibles`, `powerup_spawners`, `time_slow_effect`. Note `enemies` (added by the spawner at runtime, used for `call_group("enemies", "die_silently")`) versus `enemigos` (checked for player body collisions). Anything in `saws`/`enemies` must implement `die_silently()`; anything in `powerup_spawners` must implement `stop()`.

### Enemy laser pooling

Enemy lasers are never instantiated or freed directly. Use `EnemyLaserPool.acquire(parent, spawn_position, fire_direction, origin)` and `EnemyLaserPool.release(laser)`; `enemy_laser.gd` implements `activate()`/`deactivate()`. Calling `queue_free()` on one breaks the pool. The laser shield re-tags a deflected enemy laser into the `lasers` group, which `enemy_laser.gd` undoes on reactivation. So anything hit by a `lasers` area must release it with `EnemyLaserPool.release()` when it `has_method("deactivate")` (a deflected enemy laser) and only `queue_free()` real player lasers (ship_enemy, saw and laser_gun do this). `enemy_laser.shooter` is the ship that fired it (set by `ship_enemy.gd`, cleared on `activate()`); a ship killed by its own deflected laser adds the `own_laser_kills` stat (RETURN TO SENDER achievement, ship 17).

### Platform degradation

One codebase serves desktop, web (single-threaded), and mobile; behavior branches at runtime on `GameManager.mobile_mode_active`, `OS.has_feature("web")`, and `GameManager.force_web_mode` (set it to test the web path on desktop).

- CRT shader (`Shaders/CRT.gdshader`): `ShaderManager` and `WebOptimizer` hook `SceneTree.node_added`, and on every scene change scan for `ShaderMaterial`s whose shader path contains `"CRT"` and set `low_quality` and related parameters. `WebOptimizer` frees itself on native builds. A new CRT-style shader needs "CRT" in its path to be picked up. The roll (bands scrolling down the screen) follows `GameManager.crt_roll_enabled` (saved), but only on the PC high-quality path; `ShaderManager.is_roll_supported()` is false on mobile/web/optimized shaders.
- Main menu settings: the gear `SettingsButton` opens `SettingsPanel` (a `NinePatchRect`, closes on Esc or a click outside, like the play-mode picker), which holds the controls, FPS, full screen, retro-shader, roll and speedrun toggles (3x2 grid), the special thanks button (under roll) and two `VolumeRow`s (`Scripts/UI/volume_row.gd`: music / SFX, hold to repeat, same sprites as the pause menu). Volume lives in `MusicPlayer.increase_volume()`/`decrease_volume()` and `SfxManager.increase_sfx_volume()`/`decrease_sfx_volume()`, which store the percentage in `GameManager.music_volume_percent`/`sfx_volume_percent` and save on every change (`music_volume`/`sfx_volume` in `save_game.json`, not on web); both managers read it back in `_ready`. The arenas' pause menus (built-in scripts in `main.tscn`/`arena2.tscn`) call the same functions. The gear and roll sprites are in `Assets/Sprites/Settings/`.
- Shader warm-up: at boot `GameManager` runs `Scripts/shader_warmup.gd`, which reads the preloaded scenes through `SceneState` (no instantiation), and draws one script-less "ghost" per unique drawable/material in an offscreen `SubViewport`, a few per frame, so shaders compile during the splash instead of freezing the first frame of an arena. The splash waits on `GameManager.wait_for_shader_warmup()`. Scenes spawned only via `preload()` in scripts must be added to the list in `GameManager._start_shader_warmup`.
- `MobileOptimizer` turns on `mobile_mode_active` for Android/iOS, caps the framerate to an even divisor of the screen refresh rate (60 on 60/120Hz, 90 on 90Hz) and sets the physics tick rate to match, so per-tick smoothing must be written delta-based (`1.0 - pow(1.0 - k, delta * 60.0)`), never as a fixed lerp factor, and switches the window to `CONTENT_SCALE_ASPECT_EXPAND`.
- UI is laid out with absolute coordinates for 520x300. Instead of anchors, UI scripts (`hud.gd`, `main_menu.gd`, `skin_selector.gd`, splash) store original positions and shift them by the offset from x=260 on `size_changed`. New UI nodes in those scenes follow that pattern.
- Particle scripts shorten lifetimes and arenas disable light shadows in mobile mode.

### Conventions

- Logging goes through a per-script `_log_message(message)` (string or array) that prints only when `GameManager.is_debug_text` is true. The function is copy-pasted into each script rather than shared; `Network` additionally has `_log_dev` for debug builds only.
- Comments and log strings are a mix of English and Spanish.
- `addons/` is third-party (Dialogue Manager, Discord RPC, env_parser, godot_ai MCP plugin, kanban_tasks, git plugin) and is excluded from linting.
