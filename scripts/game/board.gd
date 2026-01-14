# board.gd - Game board with tile-based collision
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

class_name Board
extends Node2D

## Emitted when ball count changes
signal balls_changed(count: int)
## Emitted when fill percentage changes
signal fill_changed(percent: int)
## Emitted when a wall is destroyed by a ball
signal wall_died

## Board dimensions in tiles
const TILE_NUM_W := 32
const TILE_NUM_H := 20

## Tile types
enum TileType { EMPTY, FREE, BORDER, WALL, TEMP }

## Wall directions for indexing
const DIR_UP := 0
const DIR_RIGHT := 1
const DIR_DOWN := 2
const DIR_LEFT := 3

## 2D array of tile states [x][y]
var tiles: Array = []

## Size of each tile in pixels
var tile_size := Vector2i(32, 32)

## Current fill percentage (0-100)
var filled_percent := 0

## Active balls on the board
var balls: Array = []

## Four walls (UP, RIGHT, DOWN, LEFT)
var walls: Array = []

## Ball velocity (tiles per tick)
var ball_velocity := 0.125

## Wall velocity (tiles per tick)
var wall_velocity := 0.125

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

	_init_walls()
	clear()

	# JS physics is required
	if not PhysicsManager.is_ready():
		push_error("Board: JS physics not ready - physics will not work!")


## Mapping from GDScript wall index to JS wall ID
var _js_wall_ids: Array[int] = [-1, -1, -1, -1]

## Initialize JS physics state (call after clear() and before adding balls)
func _init_js_physics():
	PhysicsManager.init()
	_js_wall_ids = [-1, -1, -1, -1]


## Sync a ball to JS physics (call after setting position/velocity)
func _sync_ball_to_js(ball: Ball, ball_id: int):
	var id := PhysicsManager.add_ball(
		ball.relative_pos.x, ball.relative_pos.y,
		ball.velocity.x, ball.velocity.y)
	if id != ball_id:
		push_warning("Board: JS ball ID mismatch: expected %d, got %d" % [ball_id, id])


## Sync ball position from JS physics (call after tick)
func _sync_ball_from_js(ball: Ball, ball_id: int):
	var state := PhysicsManager.get_ball(ball_id)
	if state.is_empty():
		return
	ball.velocity = Vector2(state.get("vx", 0), state.get("vy", 0))
	ball.set_relative_pos(state.get("x", 0), state.get("y", 0))


## Sync all tiles to JS physics
func _sync_tiles_to_js():
	for x in range(TILE_NUM_W):
		for y in range(TILE_NUM_H):
			PhysicsManager.set_tile(x, y, tiles[x][y])


## Add a wall to JS physics when it starts building
func _add_wall_to_js(wall_index: int, start_x: int, start_y: int):
	var wall: Wall = walls[wall_index]
	var js_id := PhysicsManager.add_wall(start_x, start_y, wall.direction)
	_js_wall_ids[wall_index] = js_id


## Show demo balls (animated but not moving) for start screen
func show_demo(ball_count: int = 2):
	clear()
	hide_walls()

	# Remove excess balls
	while balls.size() > ball_count:
		var ball = balls.pop_back()
		ball.queue_free()

	# Add missing balls
	while balls.size() < ball_count:
		var ball: Ball = _ball_scene.instantiate()
		ball.board = self
		balls.append(ball)
		add_child(ball)

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


## Stop and hide all walls (for game over / returning to menu)
func hide_walls():
	for wall in walls:
		wall.stop()


func _init_walls():
	# Create 4 walls, one for each direction
	# Order: UP=0, RIGHT=1, DOWN=2, LEFT=3
	var directions = [
		Wall.Direction.UP,
		Wall.Direction.RIGHT,
		Wall.Direction.DOWN,
		Wall.Direction.LEFT
	]

	for dir in directions:
		var wall: Wall = _wall_scene.instantiate()
		wall.direction = dir
		wall.board = self
		wall.visible = false
		wall.died.connect(_on_wall_died)
		wall.finished.connect(_on_wall_finished.bind(wall))
		wall.died_from_wall_collision.connect(_on_wall_died_from_collision.bind(wall))
		walls.append(wall)
		add_child(wall)


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

	filled_percent = 0
	queue_redraw()


## Fixed tile size
const TILE_SIZE := 30

## Resize the board (uses fixed tile size)
func resize(_size: Vector2i) -> Vector2i:
	tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Resize all balls
	for ball in balls:
		ball.resize(tile_size)

	# Resize all walls
	for wall in walls:
		wall.resize(tile_size)

	# Return actual board size
	var actual_size := Vector2i(TILE_SIZE * TILE_NUM_W, TILE_SIZE * TILE_NUM_H)
	queue_redraw()
	return actual_size


## Start a new level with specified number of balls
func new_level(level: int):
	clear()
	_init_js_physics()
	fill_changed.emit(filled_percent)

	# Generate seed for deterministic ball placement
	var level_seed := randi()
	seed(level_seed)

	# Level determines ball count: level 1 = 2 balls, level 2 = 3 balls, etc.
	var target_ball_count := level + 1

	# Remove excess balls
	while balls.size() > target_ball_count:
		var ball = balls.pop_back()
		ball.queue_free()

	# Add missing balls
	while balls.size() < target_ball_count:
		var ball: Ball = _ball_scene.instantiate()
		ball.board = self
		balls.append(ball)
		add_child(ball)

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
		ball.velocity = Vector2(dir_x * ball_velocity, dir_y * ball_velocity)

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

	# Random direction
	var dir_x := (randi() % 2) * 2 - 1
	var dir_y := (randi() % 2) * 2 - 1
	ball.velocity = Vector2(dir_x * ball_velocity, dir_y * ball_velocity)

	ball.set_random_frame()
	ball.update_visuals()
	ball.visible = true

	balls_changed.emit(balls.size())


## Reverse all ball velocities (invert time for debugging)
func reverse_balls():
	for ball in balls:
		ball.velocity = -ball.velocity
	print("REVERSED all %d balls" % balls.size())


## Reset walls
	for wall in walls:
		wall.wall_velocity = wall_velocity
		wall.stop()


## Build a wall at the given position
func build_wall(pos: Vector2, vertical: bool):
	# Two wall slots: Slot 1 = UP/LEFT, Slot 2 = DOWN/RIGHT
	# Each slot can have at most one wall building
	var slot1_busy: bool = walls[DIR_UP].visible or walls[DIR_LEFT].visible
	var slot2_busy: bool = walls[DIR_DOWN].visible or walls[DIR_RIGHT].visible

	# Need at least one free slot
	if slot1_busy and slot2_busy:
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
	for wall: Wall in walls:
		if wall.visible:
			var wall_rect: Rect2 = wall.bounding_rect()
			if tile_x >= int(wall_rect.position.x) and tile_x < int(ceil(wall_rect.end.x)) and \
			   tile_y >= int(wall_rect.position.y) and tile_y < int(ceil(wall_rect.end.y)):
				return

	# Record wall placement for replay
	ReplayManager.record_wall(tile_x, tile_y, vertical)

	# Start building walls in available slots
	if vertical:
		if not slot1_busy:
			walls[DIR_UP].build(tile_x, tile_y)
			_add_wall_to_js(DIR_UP, tile_x, tile_y)
		if not slot2_busy:
			walls[DIR_DOWN].build(tile_x, tile_y)
			_add_wall_to_js(DIR_DOWN, tile_x, tile_y)
	else:
		if not slot1_busy:
			walls[DIR_LEFT].build(tile_x, tile_y)
			_add_wall_to_js(DIR_LEFT, tile_x, tile_y)
		if not slot2_busy:
			walls[DIR_RIGHT].build(tile_x, tile_y)
			_add_wall_to_js(DIR_RIGHT, tile_x, tile_y)


## Game tick - called once per frame
func tick():
	var start := Time.get_ticks_usec()

	_tick_physics()

	# Record timing and print stats
	_tick_times.append((Time.get_ticks_usec() - start) / 1000.0)
	_print_stats()


## Tick physics (JS is source of truth)
func _tick_physics():
	# Run JS physics tick (handles all collisions: ball vs tile, ball vs wall, wall vs tile/wall)
	var js_result: Dictionary = PhysicsManager.tick()
	var js_ball_collisions: Array = js_result.get("balls", [])
	var js_wall_events: Array = js_result.get("walls", [])

	# Process ball collision results
	for i in range(balls.size()):
		var hits: Array = []
		if i < js_ball_collisions.size():
			var collision: Dictionary = js_ball_collisions[i]
			if collision.get("hit", false):
				var hit := Collision.Hit.new()
				if collision.get("hitWall", false):
					hit.type = Collision.Type.WALL
				else:
					hit.type = Collision.Type.TILE
				hit.normal = collision.get("normal", Vector2.ZERO)
				hits.append(hit)
		# Always call collide to decrement sound delay
		balls[i].collide(hits)

	# Process wall events from JS
	for event in js_wall_events:
		var js_wall_id: int = int(event.get("wallId", -1))
		var event_type: String = event.get("event", "")

		# Find the GDScript wall that corresponds to this JS wall ID
		var gd_wall_index := -1
		for i in range(4):
			if _js_wall_ids[i] == js_wall_id:
				gd_wall_index = i
				break

		if gd_wall_index < 0:
			continue

		var wall: Wall = walls[gd_wall_index]

		match event_type:
			"die":
				# Wall killed by ball - triggers life loss
				wall.die()
				_js_wall_ids[gd_wall_index] = -1
			"finish":
				# Wall completed - materialize tiles
				var bounds: Dictionary = event.get("bounds", {})
				var x1: int = int(bounds.get("x1", 0))
				var y1: int = int(bounds.get("y1", 0))
				var x2: int = int(bounds.get("x2", 0))
				var y2: int = int(bounds.get("y2", 0))
				wall._finish()
				_js_wall_ids[gd_wall_index] = -1
				# Note: _on_wall_finished will be called by the signal
			"wall_collision":
				# Wall killed by another wall - no life loss
				wall.die_from_wall()
				_js_wall_ids[gd_wall_index] = -1

	# Sync ball positions from JS and update visuals
	for i in range(balls.size()):
		_sync_ball_from_js(balls[i], i)
		balls[i].update_visuals()

	# Update wall visuals (JS handles growth, but GDScript walls need to sync)
	for i in range(4):
		var wall: Wall = walls[i]
		if wall.visible and _js_wall_ids[i] >= 0:
			# Sync wall rect from JS
			var js_wall: Dictionary = PhysicsManager.get_wall(_js_wall_ids[i])
			if not js_wall.is_empty():
				wall._bounding_rect = Rect2(
					js_wall.get("x", 0), js_wall.get("y", 0),
					js_wall.get("w", 1), js_wall.get("h", 1)
				)
			wall.update_visuals()


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


## Check if two walls are a paired set (UP/DOWN or LEFT/RIGHT from same origin)
## Paired walls extend in opposite directions from the same click point
func _are_paired_walls(wall1: Wall, wall2: Wall) -> bool:
	# Must share the same starting position
	if wall1.start_x != wall2.start_x or wall1.start_y != wall2.start_y:
		return false

	# UP(0) pairs with DOWN(1), LEFT(2) pairs with RIGHT(3)
	var d1 := wall1.direction
	var d2 := wall2.direction
	return (d1 == Wall.Direction.UP and d2 == Wall.Direction.DOWN) or \
		   (d1 == Wall.Direction.DOWN and d2 == Wall.Direction.UP) or \
		   (d1 == Wall.Direction.LEFT and d2 == Wall.Direction.RIGHT) or \
		   (d1 == Wall.Direction.RIGHT and d2 == Wall.Direction.LEFT)


## Convert relative position to pixel position
func map_position(relative_pos: Vector2) -> Vector2:
	return Vector2(tile_size.x * relative_pos.x, tile_size.y * relative_pos.y)


## Get bounding rectangle of the board in global screen coordinates
func get_board_rect() -> Rect2:
	return Rect2(global_position, Vector2(TILE_NUM_W * tile_size.x, TILE_NUM_H * tile_size.y))


## Handle wall death (hit by ball)
func _on_wall_died():
	ReplayManager.record_wall_killed()
	wall_died.emit()


## Handle wall death from wall-to-wall collision (kill paired wall too)
func _on_wall_died_from_collision(wall: Wall):
	# Find and kill the paired wall (same start position, opposite direction)
	# Use die_from_wall() so it doesn't cost a life
	for other_wall in walls:
		if other_wall != wall and other_wall.visible:
			if _are_paired_walls(wall, other_wall):
				other_wall.die_from_wall()


## Handle wall completion
func _on_wall_finished(x1: int, y1: int, x2: int, y2: int, wall: Wall):
	# Check if paired wall is still building
	var paired_wall_active := false
	var start_x := wall.start_x
	var start_y := wall.start_y
	for other_wall in walls:
		if other_wall != wall and other_wall.visible:
			if _are_paired_walls(wall, other_wall):
				paired_wall_active = true
				break

	# Mark tiles as wall (skip starting tile if paired wall still active)
	for x in range(x1, x2):
		for y in range(y1, y2):
			if x >= 0 and x < TILE_NUM_W and y >= 0 and y < TILE_NUM_H:
				# Skip starting tile if paired wall is still building
				if paired_wall_active and x == start_x and y == start_y:
					continue
				tiles[x][y] = TileType.WALL

	# Flood fill from each ball position to mark reachable areas as TEMP
	for ball in balls:
		var ball_rect: Rect2 = ball.ball_bounding_rect()
		var bx1 := int(ball_rect.position.x)
		var by1 := int(ball_rect.position.y)
		var bx2 := int(ball_rect.end.x)
		var by2 := int(ball_rect.end.y)

		# Fill from all corners of ball bounding rect
		_flood_fill(bx1, by1)
		_flood_fill(bx1, by2)
		_flood_fill(bx2, by1)
		_flood_fill(bx2, by2)

	# Convert remaining FREE to WALL, TEMP back to FREE
	for x in range(TILE_NUM_W):
		for y in range(TILE_NUM_H):
			if tiles[x][y] == TileType.FREE:
				tiles[x][y] = TileType.WALL
			elif tiles[x][y] == TileType.TEMP:
				tiles[x][y] = TileType.FREE

	# Calculate fill percentage
	var filled_count := 0
	for x in range(1, TILE_NUM_W - 1):
		for y in range(1, TILE_NUM_H - 1):
			if tiles[x][y] == TileType.WALL:
				filled_count += 1

	filled_percent = filled_count * 100 / ((TILE_NUM_W - 2) * (TILE_NUM_H - 2))
	fill_changed.emit(filled_percent)

	# Sync tiles to JS physics
	_sync_tiles_to_js()

	queue_redraw()


## Iterative flood fill algorithm (avoids stack overflow on iOS)
func _flood_fill(start_x: int, start_y: int):
	if start_x < 0 or start_x >= TILE_NUM_W or start_y < 0 or start_y >= TILE_NUM_H:
		return
	if tiles[start_x][start_y] != TileType.FREE:
		return

	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]

	while not stack.is_empty():
		var pos: Vector2i = stack.pop_back()
		var x: int = pos.x
		var y: int = pos.y

		if x < 0 or x >= TILE_NUM_W or y < 0 or y >= TILE_NUM_H:
			continue
		if tiles[x][y] != TileType.FREE:
			continue

		tiles[x][y] = TileType.TEMP

		# Add adjacent tiles to stack
		stack.push_back(Vector2i(x, y - 1))  # Up
		stack.push_back(Vector2i(x + 1, y))  # Right
		stack.push_back(Vector2i(x, y + 1))  # Down
		stack.push_back(Vector2i(x - 1, y))  # Left


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
	print("Board._draw: %.2f ms" % elapsed)
