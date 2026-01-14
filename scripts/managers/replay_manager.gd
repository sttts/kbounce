# replay_manager.gd - Records game replay data for verification (Autoload)
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Current replay data
var _replay: Dictionary = {}
## Tick counter for action timestamps
var _tick: int = 0
## Whether recording is active
var _recording := false


## Start recording a new game
func start_game():
	_recording = true
	_tick = 0
	_replay = {
		"physics_version": PhysicsManager.get_version() if PhysicsManager.is_ready() else 0,
		"levels": []
	}


## Start recording a new level
func start_level(level: int, seed_value: int, ball_states: Array):
	if not _recording:
		return

	_tick = 0
	_replay.levels.append({
		"level": level,
		"seed": seed_value,
		"balls": ball_states,
		"actions": [],
		"result": null
	})


## Record a wall placement action
func record_wall(tile_x: int, tile_y: int, vertical: bool):
	if not _recording or _replay.levels.is_empty():
		return

	_replay.levels[-1].actions.append({
		"t": _tick,
		"x": tile_x,
		"y": tile_y,
		"v": vertical
	})


## Record a wall being killed (hit by ball)
func record_wall_killed():
	if not _recording or _replay.levels.is_empty():
		return

	_replay.levels[-1].actions.append({
		"t": _tick,
		"type": "wall_killed"
	})


## Record level completion
func record_level_complete(fill_percent: int, time_remaining: int, lives: int, score: int):
	if not _recording or _replay.levels.is_empty():
		return

	_replay.levels[-1].result = {
		"complete": true,
		"fill": fill_percent,
		"time": time_remaining,
		"lives": lives,
		"score": score,
		"tick": _tick
	}


## Record level failure (ran out of lives or time)
func record_level_failed(fill_percent: int, time_remaining: int, lives: int, score: int):
	if not _recording or _replay.levels.is_empty():
		return

	_replay.levels[-1].result = {
		"complete": false,
		"fill": fill_percent,
		"time": time_remaining,
		"lives": lives,
		"score": score,
		"tick": _tick
	}


## Checkpoint interval (record ball positions every N ticks)
const CHECKPOINT_INTERVAL := 60  # Every 1 second at 60fps

## Called every physics tick
## board: reference to get ball positions for checkpoints
func tick(board = null):
	if _recording:
		_tick += 1

		# Record ball positions periodically for verification
		if board and _tick % CHECKPOINT_INTERVAL == 0 and not _replay.levels.is_empty():
			var positions: Array = []
			for ball in board.balls:
				positions.append({
					"x": snappedf(ball.relative_pos.x, 0.001),
					"y": snappedf(ball.relative_pos.y, 0.001)
				})
			if not _replay.levels[-1].has("checkpoints"):
				_replay.levels[-1]["checkpoints"] = []
			_replay.levels[-1].checkpoints.append({
				"t": _tick,
				"balls": positions
			})


## Stop recording and output replay
func stop_game(final_score: int, final_level: int):
	if not _recording:
		return

	_recording = false
	_replay["final_score"] = final_score
	_replay["final_level"] = final_level

	# Output replay JSON
	var json := JSON.stringify(_replay, "  ")

	# In editor mode, write to file for easy testing
	if OS.has_feature("editor"):
		var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
		var filename := "user://replay_%s.json" % timestamp
		var file := FileAccess.open(filename, FileAccess.WRITE)
		if file:
			file.store_string(json)
			file.close()
			print("[Replay] Saved to: %s" % ProjectSettings.globalize_path(filename))
		else:
			print("[Replay] Failed to save file")


## Get replay data (for API submission)
func get_replay() -> Dictionary:
	return _replay


## Check if currently recording
func is_recording() -> bool:
	return _recording
