# game_manager.gd - Global game state manager (Autoload)
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Emitted when score changes
signal score_changed(score: int)
## Emitted when lives change
signal lives_changed(lives: int)
## Emitted when time changes
signal time_changed(time: int)
## Emitted when level changes
signal level_changed(level: int)
## Emitted when game state changes
signal state_changed(state: GameState)
## Emitted when fill percentage changes
signal fill_changed(percent: int)
## Emitted on game over
signal game_over
## Emitted when level is completed with bonus info
signal level_completed(level: int, fill_bonus: int, lives_bonus: int)

## Game states
enum GameState {
	BEFORE_FIRST_GAME,
	RUNNING,
	BETWEEN_LEVELS,
	PAUSED,
	SUSPENDED,
	GAME_OVER_SPLASH,     # Showing 2-second splash before leaderboard
	GAME_OVER_LEADERBOARD # Showing leaderboard overlay
}

## Minimum fill percentage required to complete a level
const MIN_FILL_PERCENT := 75
## Base time per level in seconds
const GAME_TIME_PER_LEVEL := 90
## Ball velocity (tiles per tick) - matches original
const BALL_VELOCITY := 0.125
## Wall velocity (tiles per tick) - matches original
const WALL_VELOCITY := 0.125

## Current game state
var state := GameState.BEFORE_FIRST_GAME
## Current score
var score := 0
## Remaining lives (initialized to level + 1 for display before first game)
var lives := 2
## Remaining time in seconds
var time := GAME_TIME_PER_LEVEL
## Current level (1-based)
var level := 1
## Current fill percentage
var filled := 0

## Ball velocity (for board access)
var ball_velocity := BALL_VELOCITY
## Wall velocity (for board access)
var wall_velocity := WALL_VELOCITY

## Game over flow ID (incremented each game over, invalidates stale API responses)
var _game_over_flow_id: int = 0
## When splash started (for 2-second minimum)
var _splash_start_time: int = 0

## Debug cheating flag (prevents score submission)
var debug_cheated := false


func _ready():
	var platform_info := OS.get_name()
	if not OS.get_version().is_empty():
		platform_info += " " + OS.get_version()
	if not OS.get_processor_name().is_empty():
		platform_info += ", " + OS.get_processor_name()
	if OS.has_feature("web"):
		var ua = JavaScriptBridge.eval("navigator.userAgent")
		if ua:
			platform_info += ", " + str(ua)
	print("KBounce %s (%s)" % [Version.TAG, platform_info])


## Start a new game
func new_game():
	score = 0
	level = 1
	lives = level + 1  # Lives = balls = level + 1
	time = GAME_TIME_PER_LEVEL
	filled = 0
	debug_cheated = false

	score_changed.emit(score)
	level_changed.emit(level)
	lives_changed.emit(lives)
	time_changed.emit(time)
	fill_changed.emit(filled)

	_change_state(GameState.RUNNING)


## Advance to next level
func next_level():
	level += 1
	lives = level + 1  # Lives = balls = level + 1
	time = GAME_TIME_PER_LEVEL
	filled = 0

	level_changed.emit(level)
	lives_changed.emit(lives)
	time_changed.emit(time)
	fill_changed.emit(filled)

	_change_state(GameState.RUNNING)


## Called when player loses a life
func lose_life():
	# Ignore if already in game over state
	if is_game_over():
		return

	lives -= 1
	lives_changed.emit(lives)

	if lives <= 0:
		start_game_over()


## Add points to score
func add_score(points: int):
	score += points
	score_changed.emit(score)


## Called when fill percentage changes
func update_fill(percent: int):
	filled = percent
	fill_changed.emit(filled)

	if filled >= MIN_FILL_PERCENT:
		level_complete()


## Points per remaining life
const POINTS_FOR_LIFE := 15


## Called when level is completed
func level_complete():
	# Stop game immediately (no more ball movement, collisions, or time updates)
	_change_state(GameState.BETWEEN_LEVELS)

	# Record level completion for replay
	ReplayManager.record_level_complete(filled, time, lives, score)

	# Wait 1 second for walls to finish building animation before showing overlay
	await get_tree().create_timer(1.0).timeout

	# Calculate bonuses:
	# Fill Bonus = (filled% - 75) × 2 × (level + 5)
	# Lives Bonus = lives × 15
	var fill_bonus := (filled - MIN_FILL_PERCENT) * 2 * (level + 5)
	var lives_bonus := lives * POINTS_FOR_LIFE

	level_completed.emit(level, fill_bonus, lives_bonus)


## Decrement time by one second, returns true if time ran out
func tick_time() -> bool:
	time -= 1
	if time < 0:
		time = 0
	time_changed.emit(time)

	if time <= 0:
		return true
	return false


## Pause/unpause the game
func set_paused(paused: bool):
	if paused and state == GameState.RUNNING:
		_change_state(GameState.PAUSED)
	elif not paused and state == GameState.PAUSED:
		_change_state(GameState.RUNNING)


## Suspend/resume the game (for focus loss)
func set_suspended(suspended: bool):
	if suspended and state == GameState.RUNNING:
		_change_state(GameState.SUSPENDED)
	elif not suspended and state == GameState.SUSPENDED:
		_change_state(GameState.RUNNING)


## Close current game
func close_game():
	_change_state(GameState.BEFORE_FIRST_GAME)


## Check if game is currently playable
func is_playing() -> bool:
	return state == GameState.RUNNING


## Check if in any game over state
func is_game_over() -> bool:
	return state == GameState.GAME_OVER_SPLASH or state == GameState.GAME_OVER_LEADERBOARD


## Start the game over flow
func start_game_over():
	# Record level failure and stop replay
	ReplayManager.record_level_failed(filled, time, lives, score)
	ReplayManager.stop_game(score, level)

	# Skip leaderboard for score = 0 (died on first level without points)
	if score <= 0:
		_change_state(GameState.GAME_OVER_SPLASH)
		await get_tree().create_timer(2.0).timeout
		_change_state(GameState.BEFORE_FIRST_GAME)
		return

	_game_over_flow_id += 1
	_splash_start_time = Time.get_ticks_msec()
	_change_state(GameState.GAME_OVER_SPLASH)
	game_over.emit()


## Get current game over flow ID (for API response validation)
func get_game_over_flow_id() -> int:
	return _game_over_flow_id


## Called when API response is ready (HUD passes flow_id to validate)
func on_api_ready(flow_id: int):
	print("[GM] on_api_ready flow_id=%d expected=%d state=%s" % [flow_id, _game_over_flow_id, state])
	# Ignore stale responses from previous game overs
	if flow_id != _game_over_flow_id:
		print("[GM] on_api_ready: flow_id mismatch, ignoring")
		return
	if state != GameState.GAME_OVER_SPLASH:
		print("[GM] on_api_ready: not in GAME_OVER_SPLASH, ignoring")
		return
	# Calculate remaining splash time (minimum 2 seconds)
	var elapsed := Time.get_ticks_msec() - _splash_start_time
	var remaining := 2000 - elapsed
	print("[GM] on_api_ready: elapsed=%d remaining=%d" % [elapsed, remaining])
	if remaining > 0:
		await get_tree().create_timer(remaining / 1000.0).timeout
		# Recheck state after wait (user may have started new game)
		if state != GameState.GAME_OVER_SPLASH:
			print("[GM] on_api_ready: state changed during wait, now %s" % state)
			return
	print("[GM] on_api_ready: transitioning to GAME_OVER_LEADERBOARD")
	_change_state(GameState.GAME_OVER_LEADERBOARD)


## Internal state change with signal emission
func _change_state(new_state: GameState):
	if state != new_state:
		state = new_state
		state_changed.emit(state)
