# ADVAD Agent Instructions

## Context
- **Engine:** Godot 4.6 (Forward Plus)
- **Project Structure:**
  - `Scenes/`: Core game scenes.
  - `Scripts/`: Game logic.
  - `Autoloads/`: Global singletons.
  - `Assets/`: Sprites, audio, fonts.
  - `addons/`: Third-party plugins.

## Key Systems
- **Progression:** `PhaseManager` (in `main.tscn`) controls phases 1-10 with score requirements and time limits.
- **Global State:** `GameManager` holds score, phase, selected ship, debug flags, speedrun timer.
- **API Service:** `api_service.gd` handles AI server communication, requires `APP_TOKEN` via `EnvParser`.

## Controls
- **Move:** W/A/S/D or Arrow Keys
- **Shoot:** Spacebar
- **Dash (Boost):** E
- **Pause:** Escape
- **Skip Cutscenes:** Enter

## Game Mechanics
- **Ship Data:** 33 ships stored in `GameManager.ship_data` array (index 0-32).
- **Speedrun Mode:** Track elapsed time via `GameManager.speedrun_mode_active`.
- **Relative Controls:** Toggle via `GameManager.relative_control_active` (rotational movement).
- **Save/Load:** Uses `user://save_game.json` path. Skipped on web builds.

## Important Scripts
- `player.gd`: Movement, shooting, dash mechanic, hitbox handling.
- `phase_manager.gd`: Phase progression, difficulty scaling, timer management.
- `main.gd`: Scene setup, player death, visual effects.
- `game_manager.gd`: Global state, score, pause, ship selection.
- `api_service.gd`: AI server communication via HTTP.

## Development & Debugging
- **Debug Flags:** `GameManager.is_debug_text`, `GameManager.show_debug`, `GameManager.show_fps`.
- **API Server:**
  - Production: `https://advad-ai-server.onrender.com`
  - Local: `http://127.0.0.1:10000`
- **Resetting State:** Use `GameManager.reset_game_state()` to clear progress.
- **Discord RPC:** Handled via plugins in `/addons`.

## Phase Requirements (Score/Time)
- Phase 1: 500 pts / 10s
- Phase 2: 1000 pts / 15s
- Phase 3: 1500 pts / 20s
- Phase 4: 2000 pts / 30s
- Phase 5: 2500 pts / 40s
- Phases 6-10: 3000-5000 pts / 50-100s (increasing)

## Signals to Know
- `score_updated(new_score)` - Emitted when score changes.
- `phase_started(phase_number, score_requirement)` - Phase begins.
- `pause(is_paused)` - Pause state toggled.
- `died` - Player death.
- `server_status_checked(is_online)` - API server status.
- `ai_response_received(text)` - AI response received.