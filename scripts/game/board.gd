# board.gd - Game board with tile-based collision
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

class_name Board
extends Node2D

## Emitted when ball count changes
signal balls_changed(count: int)
## Emitted when a wall is destroyed by a ball
signal wall_died

## Board dimensions in tiles
const TILE_NUM_W := 32
const TILE_NUM_H := 20

## Tile types (values must match physics.js: FREE=1, BORDER=2, WALL=3)
enum TileType { EMPTY, FREE, BORDER, WALL, TEMP }

## 2D array of tile states [x][y]
var tiles: Array = []

## Size of each tile in pixels
var tile_size := Vector2i(32, 32)

## Active balls on the board
var balls: Array = []

## Active walls (js_id → Wall node)
var _walls: Dictionary = {}

## Reference to preloaded scenes
var _ball_scene: PackedScene
var _wall_scene: PackedScene

## Tick timing stats
var _tick_times: Array[float] = []
var _last_stats_time := 0.0

## Draw timing stats
var _draw_count := 0
var _draw_times: Array[float] = []

func _ready():
	# Preload scenes
	_ball_scene = preload("res://scenes/game/ball.tscn")
	_wall_scene = preload("res://scenes/game/wall.tscn")

	clear()

	# JS physics is required
	if not PhysicsManager.is_ready():
		push_error("Board: JS physics not ready - physics will not work!")


## Initialize JS physics state (call after clear() and before adding balls)
func _init_js_physics():
	PhysicsManager.init()
	# Clear any leftover walls
	for wall in _walls.values():
		wall.queue_free()
	_walls.clear()


## Sync a ball to JS physics (call after setting position/velocity)
func _sync_ball_to_js(ball: Ball, ball_id: int):
	var id := PhysicsManager.add_ball(
		ball.relative_pos.x, ball.relative_pos.y,
		ball.velocity.x, ball.velocity.y)
	if id != ball_id:
		push_warning("Board: JS ball ID mismatch: expected %d, got %d" % [ball_id, id])




## Sync all tiles FROM JS physics (physics.js is source of truth)
func _sync_tiles_from_js():
	var js_tiles: Array = PhysicsManager.get_tiles()
	if js_tiles.is_empty():
		return
	for x in range(TILE_NUM_W):
		for y in range(TILE_NUM_H):
			tiles[x][y] = int(js_tiles[x][y])


## Adjust ball count to target (remove excess, add missing)
func _adjust_ball_count(target: int):
	while balls.size() > target:
		var ball = balls.pop_back()
		ball.queue_free()
	while balls.size() < target:
		var ball: Ball = _ball_scene.instantiate()
		ball.board = self
		balls.append(ball)
		add_child(ball)


## Show demo balls (animated but not moving) for start screen
func show_demo(ball_count: int = 2):
	clear()
	hide_walls()
	_adjust_ball_count(ball_count)

	# Position balls with zero velocity (just animate)
	for i in range(balls.size()):
		var ball: Ball = balls[i]
		ball.resize(tile_size)

		# Position balls spread across the board
		var rand_x := 6 + randi() % (TILE_NUM_W - 12)
		var rand_y := 4 + randi() % (TILE_NUM_H - 8)
		ball.set_relative_pos(rand_x, rand_y)

		# Zero velocity - balls don't move in demo
		ball.velocity = Vector2.ZERO

		ball.set_random_frame()
		ball.update_visuals()
		ball.visible = true


## Animate balls without moving them (for demo mode)
func animate_balls():
	for ball in balls:
		ball.update_visuals()


## Stop and remove all walls (for game over / returning to menu)
func hide_walls():
	for wall in _walls.values():
		wall.queue_free()
	_walls.clear()




## Clear the board to initial state
func clear():
	tiles.clear()

	# Initialize tile array with borders
	for x in range(TILE_NUM_W):
		var column: Array = []
		for y in range(TILE_NUM_H):
			if x == 0 or x == TILE_NUM_W - 1 or y == 0 or y == TILE_NUM_H - 1:
				column.append(TileType.BORDER)
			else:
				column.append(TileType.FREE)
		tiles.append(column)

	queue_redraw()


## Fixed tile size
const TILE_SIZE := 30

## Resize the board and return actual size in pixels
func resize() -> Vector2i:
	tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Resize all balls
	for ball in balls:
		ball.resize(tile_size)

	# Resize all walls
	for wall in _walls.values():
		wall.resize(tile_size)

	# Return actual board size
	var actual_size := Vector2i(TILE_SIZE * TILE_NUM_W, TILE_SIZE * TILE_NUM_H)
	queue_redraw()
	return actual_size


## Start a new level with specified number of balls
func new_level(level: int):
	clear()
	_init_js_physics()

	# Generate seed for deterministic ball placement
	var level_seed := randi()
	seed(level_seed)

	# Level determines ball count: level 1 = 2 balls, level 2 = 3 balls, etc.
	var target_ball_count := level + 1
	_adjust_ball_count(target_ball_count)

	# Position and initialize balls
	var ball_states: Array = []
	for i in range(balls.size()):
		var ball: Ball = balls[i]
		ball.resize(tile_size)

		# Random position in center area (avoiding borders)
		var rand_x := 4 + randi() % (TILE_NUM_W - 8)
		var rand_y := 4 + randi() % (TILE_NUM_H - 8)
		ball.set_relative_pos(rand_x, rand_y)

		# Random direction: -1 or 1 for each axis
		var dir_x := (randi() % 2) * 2 - 1
		var dir_y := (randi() % 2) * 2 - 1
		ball.velocity = Vector2(dir_x, dir_y)

		ball.set_random_frame()
		ball.update_visuals()  # Set initial screen position
		ball.visible = true

		# Sync to JS physics
		_sync_ball_to_js(ball, i)

		# Record initial ball state for replay
		ball_states.append({
			"x": ball.relative_pos.x,
			"y": ball.relative_pos.y,
			"vx": ball.velocity.x,
			"vy": ball.velocity.y
		})

	# Re-randomize seed so future randi() calls aren't predictable
	randomize()

	# Record level start for replay
	ReplayManager.start_level(level, level_seed, ball_states)

	balls_changed.emit(target_ball_count)

	# Reset walls


## Add a ball to the board (for debug)
func add_ball():
	var ball: Ball = _ball_scene.instantiate()
	ball.board = self
	balls.append(ball)
	add_child(ball)

	ball.resize(tile_size)

	# Random position in center area
	var rand_x := 4 + randi() % (TILE_NUM_W - 8)
	var rand_y := 4 + randi() % (TILE_NUM_H - 8)
	ball.set_relative_pos(rand_x, rand_y)

	# Random direction: -1 or 1 for each axis
	var dir_x := (randi() % 2) * 2 - 1
	var dir_y := (randi() % 2) * 2 - 1
	ball.velocity = Vector2(dir_x, dir_y)

	ball.set_random_frame()
	ball.update_visuals()
	ball.visible = true

	balls_changed.emit(balls.size())


## Reverse all ball velocities (invert time for debugging)
func reverse_balls():
	for ball in balls:
		ball.velocity = -ball.velocity
	print("REVERSED all %d balls" % balls.size())


## Pending wall actions for next tick
var _pending_actions: Array = []


## Queue a wall placement for the next tick
func build_wall(pos: Vector2, vertical: bool):
	# Max 2 active walls (2 half-wall slots)
	if _walls.size() >= 2:
		return

	# Convert pixel position to tile coordinates
	var tile_x := int(pos.x / tile_size.x)
	var tile_y := int(pos.y / tile_size.y)

	# Validate position
	if tile_x < 0 or tile_x >= TILE_NUM_W:
		return
	if tile_y < 0 or tile_y >= TILE_NUM_H:
		return
	if tiles[tile_x][tile_y] != TileType.FREE:
		return

	# Cannot start inside another building wall's rectangle
	for wall: Wall in _walls.values():
		var wall_rect: Rect2 = wall.bounding_rect()
		if tile_x >= int(wall_rect.position.x) and tile_x < int(ceil(wall_rect.end.x)) and \
		   tile_y >= int(wall_rect.position.y) and tile_y < int(ceil(wall_rect.end.y)):
			return

	# Queue action for next tick (will be passed to tick())
	_pending_actions.append({"x": tile_x, "y": tile_y, "vertical": vertical})


## Game tick - called once per frame
## Returns { tick: int, levelComplete: bool, fillPercent: int }
func tick() -> Dictionary:
	var start := Time.get_ticks_usec()

	# Record pending actions for replay before passing to physics
	for action in _pending_actions:
		ReplayManager.record_wall(action.x, action.y, action.vertical)

	# Pass pending actions to physics - this is the ONLY way walls are placed
	var result := _tick_physics(_pending_actions)
	_pending_actions.clear()

	# Record timing and print stats
	_tick_times.append((Time.get_ticks_usec() - start) / 1000.0)
	_print_stats()

	return result


## Tick physics (JS is source of truth)
## Returns { tick, balls, levelComplete, fillPercent, tilesChanged }
func _tick_physics(actions: Array) -> Dictionary:
	var js_result: Dictionary = PhysicsManager.tick(actions)
	var js_balls: Array = js_result.get("balls", [])
	var js_collisions: Array = js_result.get("collisions", [])
	var js_wall_events: Array = js_result.get("wallEvents", [])
	var js_new_walls: Array = js_result.get("newWalls", [])
	var js_active_walls: Array = js_result.get("activeWalls", [])

	# Create wall visuals for newly created walls
	for new_wall in js_new_walls:
		var js_id: int = int(new_wall.get("id", -1))
		var start_x: int = int(new_wall.get("startX", 0))
		var start_y: int = int(new_wall.get("startY", 0))
		var direction: int = int(new_wall.get("direction", 0))

		var wall: Wall = _wall_scene.instantiate()
		wall.direction = direction
		wall.board = self
		wall.resize(tile_size)
		wall.died.connect(_on_wall_died.bind(wall))
		add_child(wall)
		_walls[js_id] = wall
		wall.build(start_x, start_y)

	# Process ball collision results (for sound effects)
	for i in range(balls.size()):
		if i < js_collisions.size():
			var collision: Dictionary = js_collisions[i]
			balls[i].collide(collision.get("hit", false), collision.get("hitWall", false))

	# Process wall events
	for event in js_wall_events:
		var js_id: int = int(event.get("wallId", -1))
		var event_type: String = event.get("event", "")
		var wall: Wall = _walls.get(js_id)
		if wall == null:
			continue

		match event_type:
			"die":
				wall.die()
			"finish":
				wall._finish()
		_walls.erase(js_id)
		wall.queue_free()

	# Sync ball positions and update visuals
	for i in range(balls.size()):
		if i < js_balls.size():
			var state: Dictionary = js_balls[i]
			balls[i].velocity = Vector2(state.get("vx", 0), state.get("vy", 0))
			balls[i].set_relative_pos(state.get("x", 0), state.get("y", 0))
		balls[i].update_visuals()

	# Sync wall visuals from activeWalls
	for active_wall in js_active_walls:
		var js_id: int = int(active_wall.get("id", -1))
		var wall: Wall = _walls.get(js_id)
		if wall:
			wall._bounding_rect = Rect2(
				active_wall.get("x", 0), active_wall.get("y", 0),
				active_wall.get("w", 1), active_wall.get("h", 1)
			)
			wall.update_visuals()

	# Sync tiles only when changed
	if js_result.get("tilesChanged", false):
		_sync_tiles_from_js()
		queue_redraw()

	return {
		"tick": js_result.get("tick", 0),
		"balls": js_balls,
		"levelComplete": js_result.get("levelComplete", false),
		"fillPercent": js_result.get("fillPercent", 0)
	}


## Print performance stats (called from tick)
func _print_stats():
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_stats_time < 5.0:
		return

	var fps := Engine.get_frames_per_second()

	# Tick stats
	var tick_avg := 0.0
	var tick_max := 0.0
	if _tick_times.size() > 0:
		var total := 0.0
		for t in _tick_times:
			total += t
			if t > tick_max:
				tick_max = t
		tick_avg = total / _tick_times.size()

	# Draw stats
	var draw_avg := 0.0
	var draw_max := 0.0
	if _draw_times.size() > 0:
		var total := 0.0
		for t in _draw_times:
			total += t
			if t > draw_max:
				draw_max = t
		draw_avg = total / _draw_times.size()

	print("Stats: fps=%d | tick: avg=%.2f ms, max=%.2f ms, %d/s | draw: avg=%.2f ms, max=%.2f ms, %d/s" % [
		fps, tick_avg, tick_max, _tick_times.size() / 5, draw_avg, draw_max, _draw_count / 5])

	_tick_times.clear()
	_draw_times.clear()
	_draw_count = 0
	_last_stats_time = now


## Convert relative position to pixel position
func map_position(relative_pos: Vector2) -> Vector2:
	return Vector2(tile_size.x * relative_pos.x, tile_size.y * relative_pos.y)


## Get bounding rectangle of the board in global screen coordinates
func get_board_rect() -> Rect2:
	return Rect2(global_position, Vector2(TILE_NUM_W * tile_size.x, TILE_NUM_H * tile_size.y))


## Handle wall death (hit by ball)
func _on_wall_died(_wall: Wall):
	wall_died.emit()


## Custom drawing for the board tiles
func _draw():
	var start := Time.get_ticks_usec()

	var grid_tile := ThemeManager.get_texture("grid_tile")
	var wall_tile := ThemeManager.get_texture("wall_tile")

	# Draw each tile
	for x in range(TILE_NUM_W):
		for y in range(TILE_NUM_H):
			var pos := Vector2(x * tile_size.x, y * tile_size.y)
			var dest_rect := Rect2(pos, Vector2(tile_size))

			match tiles[x][y]:
				TileType.FREE:
					if grid_tile:
						draw_texture_rect(grid_tile, dest_rect, false)
				TileType.BORDER, TileType.WALL:
					if wall_tile:
						draw_texture_rect(wall_tile, dest_rect, false)

	var elapsed := (Time.get_ticks_usec() - start) / 1000.0
	_draw_count += 1
	_draw_times.append(elapsed)
