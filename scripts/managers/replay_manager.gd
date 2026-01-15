# replay_manager.gd - Records game replay data for verification (Autoload)
#
# Records actions, checkpoints, and ball positions.
# Physics.js only handles physics simulation.
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Checkpoint interval (record ball positions every N ticks)
const CHECKPOINT_INTERVAL := 60

## Current replay data
var _replay: Dictionary = {}
## Whether recording is active
var _recording := false
## Current tick number (updated from physics.js tick() result)
var _tick := 0
## Actions recorded this level
var _actions: Array = []
## Checkpoints recorded this level
var _checkpoints: Array = []
## Initial ball states for this level
var _initial_balls: Array = []


## Start recording a new game
func start_game():
	_recording = true
	_replay = {
		"physics_version": PhysicsManager.get_version() if PhysicsManager.is_ready() else 0,
		"levels": []
	}


## Start recording a new level
## balls: array of { x, y, vx, vy } - initial ball states
func start_level(level: int, seed_value: int, balls: Array):
	if not _recording:
		return

	_tick = 0
	_actions = []
	_checkpoints = []
	_initial_balls = balls.duplicate(true)

	# Store level metadata
	_replay.levels.append({
		"level": level,
		"seed": seed_value,
		"result": null
	})


## Record a wall placement action
## Call this when player clicks to place a wall
func record_wall(x: int, y: int, vertical: bool):
	if not _recording:
		return
	# Action takes effect on the NEXT tick
	_actions.append({
		"t": _tick + 1,
		"x": x,
		"y": y,
		"v": vertical
	})


## Stop recording current level and store its data
func stop_level(fill_percent: int, time_remaining: int, lives: int, score: int, complete: bool):
	if not _recording or _replay.levels.is_empty():
		return

	# Store level data
	var current_level: Dictionary = _replay.levels[-1]
	current_level["balls"] = _initial_balls
	current_level["actions"] = _actions
	current_level["checkpoints"] = _checkpoints
	current_level["result"] = {
		"complete": complete,
		"fill": fill_percent,
		"time": time_remaining,
		"lives": lives,
		"score": score,
		"tick": _tick
	}


## Update tick counter and record checkpoint if needed
## balls: array of { x, y, vx, vy } from tick result
func update_tick(tick_result: int, balls: Array):
	if not _recording:
		return

	_tick = tick_result

	# Record checkpoint every CHECKPOINT_INTERVAL ticks
	if _tick % CHECKPOINT_INTERVAL == 0:
		var checkpoint_balls: Array = []
		for b in balls:
			checkpoint_balls.append({
				"x": snappedf(b.get("x", 0), 0.001),
				"y": snappedf(b.get("y", 0), 0.001),
				"vx": b.get("vx", 0),
				"vy": b.get("vy", 0)
			})
		_checkpoints.append({
			"t": _tick,
			"balls": checkpoint_balls
		})


## Stop recording and output replay
func stop_game(final_score: int, final_level: int):
	if not _recording:
		return

	_recording = false
	_replay["final_score"] = final_score
	_replay["final_level"] = final_level

	# Self-validate the replay
	_self_validate()

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


## Self-validate the replay using the same physics code
func _self_validate():
	if _replay.levels.is_empty():
		return

	print("[Replay] Self-validating %d levels..." % _replay.levels.size())

	for i in range(_replay.levels.size()):
		var level_data: Dictionary = _replay.levels[i]

		var num_balls: int = level_data.balls.size() if level_data.has("balls") else 0
		var num_actions: int = level_data.actions.size() if level_data.has("actions") else 0
		var num_checkpoints: int = level_data.checkpoints.size() if level_data.has("checkpoints") else 0
		print("[Replay] Level %d: %d balls, %d actions, %d checkpoints" % [i + 1, num_balls, num_actions, num_checkpoints])

		var result: Dictionary = PhysicsManager.validate_level(level_data)

		if result.get("valid", false):
			print("[Replay] Level %d: ✓ valid" % (i + 1))
		else:
			var error: String = result.get("error", "Unknown error")
			var tick_num: int = result.get("tick", 0)
			print("[Replay] Level %d: ✗ %s at tick %d" % [i + 1, error, tick_num])
			if result.has("expected") and result.has("actual"):
				print("[Replay]   Expected: %s" % JSON.stringify(result.expected))
				print("[Replay]   Actual: %s" % JSON.stringify(result.actual))

			if level_data.has("checkpoints"):
				var checkpoints: Array = level_data.checkpoints
				var passed := 0
				for cp in checkpoints:
					if cp.t < tick_num:
						passed += 1
				print("[Replay]   Checkpoints passed: %d / %d" % [passed, checkpoints.size()])

			if result.has("trace"):
				print("[Replay]   Trace:")
				for entry in result.trace:
					var t: int = entry.get("t", 0)
					var balls_str := ""
					for ball in entry.get("balls", []):
						balls_str += " (%.2f,%.2f)" % [ball.x, ball.y]
					print("[Replay]     t=%d:%s" % [t, balls_str])

			if _is_dev_mode():
				_show_validation_error(i + 1, error, tick_num, result)
			break


func _is_dev_mode() -> bool:
	if OS.has_feature("editor"):
		return true
	if OS.get_name() == "Web":
		var host: String = JavaScriptBridge.eval("window.location.hostname")
		if host in ["localhost", "127.0.0.1", ""]:
			return true
	return false


func _show_validation_error(level: int, error: String, tick_num: int, result: Dictionary):
	var msg := "Replay validation failed!\n\n"
	msg += "Level: %d\n" % level
	msg += "Error: %s\n" % error
	msg += "Tick: %d\n" % tick_num
	if result.has("expected") and result.has("actual"):
		msg += "\nExpected: %s\n" % JSON.stringify(result.expected)
		msg += "Actual: %s" % JSON.stringify(result.actual)

	var dialog := AcceptDialog.new()
	dialog.title = "Replay Validation Error"
	dialog.dialog_text = msg
	dialog.dialog_autowrap = true

	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		main_loop.root.add_child(dialog)
		dialog.popup_centered_ratio(0.4)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)


func get_replay() -> Dictionary:
	return _replay


func is_recording() -> bool:
	return _recording
