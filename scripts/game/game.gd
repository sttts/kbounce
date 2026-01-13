# game.gd - Main game controller
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node2D

## Time tick interval (1 second)
const TIME_TICK := 1.0

## Physics tick rate (ticks per second)
const PHYSICS_TICK_RATE := 60.0
## Time per physics tick
const PHYSICS_TICK_TIME := 1.0 / PHYSICS_TICK_RATE

## Reference to the game board
@onready var board: Board = $Board

## Reference to HUD
@onready var hud = $CanvasLayer/HUD

## Reference to background sprite
@onready var background: Sprite2D = $Background

## Time countdown timer
@onready var time_timer: Timer = $TimeTimer

## Emitted when wall direction changes
signal direction_changed(vertical: bool)

## Wall direction toggle (true = vertical, false = horizontal)
var vertical_wall := true:
	set(value):
		if vertical_wall != value:
			vertical_wall = value
			direction_changed.emit(vertical_wall)
			_update_cursor()

## Swipe tracking (works for both mouse and touch)
var _swipe_start_pos := Vector2.ZERO
var _swipe_active := false
const SWIPE_THRESHOLD := 20.0  # Pixels to determine swipe direction

## Physics time accumulator for fixed timestep
var _physics_accumulator := 0.0



func _ready():
	# Add to game group so HUD can find us
	add_to_group("game")
	# Connect to game manager signals
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.level_changed.connect(_on_level_changed)

	# Connect board signals
	board.fill_changed.connect(_on_fill_changed)
	board.wall_died.connect(_on_wall_died)

	# Setup time timer
	time_timer.wait_time = TIME_TICK
	time_timer.timeout.connect(_on_time_tick)

	# Initial resize
	_resize_board()

	# Update cursor
	_update_cursor()

	# Show demo balls on start screen
	_start_demo()

	# Debug UI (only in editor)
	if OS.has_feature("editor"):
		_setup_debug_ui()


func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_resize_board()


func _resize_board():
	var viewport_size := get_viewport_rect().size
	const TOP_MARGIN := 26  # Space for HUD

	var board_size := board.resize(Vector2i.ZERO)  # Fixed size, parameter ignored

	# Position board: left edge, centered vertically below HUD
	board.position.x = 0
	board.position.y = TOP_MARGIN + int((viewport_size.y - TOP_MARGIN - board_size.y) / 2.0)

	# Update background
	if background and ThemeManager.get_texture("background"):
		background.texture = ThemeManager.get_texture("background")
		background.position = viewport_size / 2
		# Scale to fill viewport
		var bg_size := background.texture.get_size()
		var scale_x := viewport_size.x / bg_size.x
		var scale_y := viewport_size.y / bg_size.y
		var bg_scale: float = max(scale_x, scale_y)
		background.scale = Vector2(bg_scale, bg_scale)


## Handle input events (unhandled so UI buttons get priority)
func _unhandled_input(event):
	if GameManager.state != GameManager.GameState.RUNNING:
		# Handle pause toggle
		if event.is_action_pressed("pause"):
			if GameManager.state == GameManager.GameState.PAUSED:
				GameManager.set_paused(false)
			elif GameManager.state == GameManager.GameState.RUNNING:
				GameManager.set_paused(true)
		return

	# Handle pause
	if event.is_action_pressed("pause"):
		GameManager.set_paused(true)
		return

	# Handle reverse balls (editor only)
	if OS.has_feature("editor") and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		board.reverse_balls()
		return

	# Handle wall direction toggle (right click)
	if event.is_action_pressed("toggle_direction"):
		vertical_wall = not vertical_wall
		return

	# Handle mouse button - swipe to determine direction
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Only start tracking if click is inside board area
				var board_rect: Rect2 = board.get_board_rect()
				if board_rect.has_point(event.position):
					_swipe_start_pos = event.position
					_swipe_active = true
			else:
				# Mouse released - build with current direction if no swipe detected
				if _swipe_active and _swipe_start_pos != Vector2.ZERO:
					_build_wall_at(_swipe_start_pos)
				_swipe_start_pos = Vector2.ZERO
				_swipe_active = false

	# Handle mouse motion - detect swipe direction
	elif event is InputEventMouseMotion:
		if _swipe_active and _swipe_start_pos != Vector2.ZERO:
			var delta: Vector2 = event.position - _swipe_start_pos
			# Use max of horizontal/vertical movement (not Euclidean distance)
			var max_delta := maxf(abs(delta.x), abs(delta.y))
			if max_delta >= SWIPE_THRESHOLD:
				# Determine direction from dominant axis
				if abs(delta.x) > abs(delta.y):
					vertical_wall = false  # Horizontal swipe = horizontal wall
				else:
					vertical_wall = true   # Vertical swipe = vertical wall
				# Build wall at start position with detected direction
				_build_wall_at(_swipe_start_pos)
				_swipe_start_pos = Vector2.ZERO
				_swipe_active = false

	# Handle touch - same swipe logic
	elif event is InputEventScreenTouch:
		if event.pressed:
			# Only start tracking if touch is inside board area
			var board_rect: Rect2 = board.get_board_rect()
			if board_rect.has_point(event.position):
				_swipe_start_pos = event.position
				_swipe_active = true
		else:
			# Touch released - build with current direction if no swipe detected
			if _swipe_active and _swipe_start_pos != Vector2.ZERO:
				_build_wall_at(_swipe_start_pos)
			_swipe_start_pos = Vector2.ZERO
			_swipe_active = false

	elif event is InputEventScreenDrag:
		if _swipe_active and _swipe_start_pos != Vector2.ZERO:
			var delta: Vector2 = event.position - _swipe_start_pos
			# Use max of horizontal/vertical movement (not Euclidean distance)
			var max_delta := maxf(abs(delta.x), abs(delta.y))
			if max_delta >= SWIPE_THRESHOLD:
				# Determine direction from dominant axis
				if abs(delta.x) > abs(delta.y):
					vertical_wall = false  # Horizontal swipe = horizontal wall
				else:
					vertical_wall = true   # Vertical swipe = vertical wall
				# Build wall at start position with detected direction
				_build_wall_at(_swipe_start_pos)
				_swipe_start_pos = Vector2.ZERO
				_swipe_active = false


## Build wall at screen position
func _build_wall_at(screen_pos: Vector2):
	# Convert to board-local coordinates
	var local_pos := screen_pos - board.position
	board.build_wall(local_pos, vertical_wall)


## Update mouse cursor based on wall direction
func _update_cursor():
	# Skip cursor updates on mobile (no mouse support)
	if OS.has_feature("mobile"):
		return
	if vertical_wall:
		Input.set_default_cursor_shape(Input.CURSOR_VSIZE)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_HSIZE)


## Start a new game
func new_game():
	# Request game token for leaderboard submission
	LeaderboardManager.request_game_token()
	GameManager.new_game()


## Start demo mode with animated balls
func _start_demo():
	board.show_demo(2)


## Physics process - accumulates time and calls tick() to maintain constant physics rate
func _physics_process(delta: float):
	if GameManager.state == GameManager.GameState.RUNNING:
		# Accumulate elapsed time
		_physics_accumulator += delta

		# Run physics ticks to catch up
		while _physics_accumulator >= PHYSICS_TICK_TIME:
			board.tick()
			AudioManager.tick()
			_physics_accumulator -= PHYSICS_TICK_TIME
	else:
		# Animate balls in all non-running states (demo, paused, game over, etc.)
		board.animate_balls()


## Time tick callback (once per second)
func _on_time_tick():
	if GameManager.state != GameManager.GameState.RUNNING:
		return

	# Refresh token if about to expire
	if LeaderboardManager.should_refresh_token():
		LeaderboardManager.request_game_token()

	var time_up := GameManager.tick_time()

	# Warning sound at 5 seconds
	if GameManager.time <= 5 and GameManager.time > 0:
		AudioManager.play("seconds")

	# Time ran out
	if time_up:
		AudioManager.play("timeout")
		GameManager.lose_life()
		if GameManager.state == GameManager.GameState.RUNNING:
			# Still have lives, restart level
			_start_level()


## Fill percentage changed
func _on_fill_changed(percent: int):
	GameManager.update_fill(percent)


## Wall destroyed by ball
func _on_wall_died():
	GameManager.lose_life()
	if GameManager.state == GameManager.GameState.RUNNING:
		# Still have lives, continue playing
		pass


## Game state changed
func _on_state_changed(state: GameManager.GameState):
	match state:
		GameManager.GameState.RUNNING:
			time_timer.start()
			# Reset physics accumulator to avoid burst of ticks
			_physics_accumulator = 0.0
			# Reset swipe state to ignore any ongoing mouse press from button click
			_swipe_active = false
			_swipe_start_pos = Vector2.ZERO

		GameManager.GameState.PAUSED, GameManager.GameState.SUSPENDED:
			time_timer.stop()

		GameManager.GameState.BETWEEN_LEVELS:
			time_timer.stop()
			# HUD handles level complete overlay and next_level transition

		GameManager.GameState.GAME_OVER_SPLASH, GameManager.GameState.GAME_OVER_LEADERBOARD:
			time_timer.stop()
			# HUD handles game over overlays

		GameManager.GameState.BEFORE_FIRST_GAME:
			time_timer.stop()
			_start_demo()  # Show demo balls again


## Level changed
func _on_level_changed(_level: int):
	_start_level()


## Start/restart current level
func _start_level():
	board.ball_velocity = GameManager.ball_velocity
	board.wall_velocity = GameManager.wall_velocity
	board.new_level(GameManager.level)


## Debug UI active flag
var _debug_ui_active := false

## Setup debug UI (editor or hidden activation)
func _setup_debug_ui():
	if _debug_ui_active:
		return
	_debug_ui_active = true

	var top_right := hud.get_node("TopRightButtons")

	# Style with no padding
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	style.set_content_margin_all(0)
	style.set_corner_radius_all(2)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.3, 0.3)
	style_hover.set_content_margin_all(0)
	style_hover.set_corner_radius_all(2)

	var buttons := [
		["+10", func():
			GameManager.debug_cheated = true
			GameManager.add_score(10)],
		["+100", func():
			GameManager.debug_cheated = true
			GameManager.add_score(100)],
		["+1 ball", func():
			GameManager.debug_cheated = true
			board.add_ball()
			GameManager.level += 1
			GameManager.lives += 1
			GameManager.level_changed.emit(GameManager.level)
			GameManager.lives_changed.emit(GameManager.lives)],
		["+10 ball", func():
			GameManager.debug_cheated = true
			for i in 10:
				board.add_ball()
			GameManager.level += 10
			GameManager.lives += 10
			GameManager.level_changed.emit(GameManager.level)
			GameManager.lives_changed.emit(GameManager.lives)],
		["die", func():
			GameManager.debug_cheated = true
			GameManager.lose_life()],
		["game over", func():
			GameManager.debug_cheated = true
			GameManager.lives = 1
			GameManager.lose_life()],
		["next lvl", func():
			GameManager.debug_cheated = true
			GameManager.filled = 75
			GameManager.level_complete()],
		["timeout", func():
			GameManager.debug_cheated = true
			GameManager.time = 2
			GameManager.time_changed.emit(GameManager.time)],
		["+60s", func():
			GameManager.time += 60
			GameManager.time_changed.emit(GameManager.time)],
		["+1 life", func():
			GameManager.lives += 1
			GameManager.lives_changed.emit(GameManager.lives)],
	]

	for btn_data in buttons:
		var btn := Button.new()
		btn.text = btn_data[0]
		btn.custom_minimum_size = Vector2(54, 27)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.pressed.connect(btn_data[1])
		top_right.add_child(btn)
