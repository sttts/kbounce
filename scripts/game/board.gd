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


func _ready():
	# Preload scenes
	_ball_scene = preload("res://scenes/game/ball.tscn")
	_wall_scene = preload("res://scenes/game/wall.tscn")

	_init_walls()
	clear()


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
	fill_changed.emit(filled_percent)

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
	for ball in balls:
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

	balls_changed.emit(target_ball_count)

	# Reset walls
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

	# Start building walls in available slots
	if vertical:
		if not slot1_busy:
			walls[DIR_UP].build(tile_x, tile_y)
		if not slot2_busy:
			walls[DIR_DOWN].build(tile_x, tile_y)
	else:
		if not slot1_busy:
			walls[DIR_LEFT].build(tile_x, tile_y)
		if not slot2_busy:
			walls[DIR_RIGHT].build(tile_x, tile_y)


## Game tick - called once per frame
func tick():
	# Check collisions first
	_check_collisions()

	# Move all objects
	for ball in balls:
		ball.go_forward()
	for wall in walls:
		if wall.visible:
			wall.go_forward()

	# Update visuals
	for ball in balls:
		ball.update_visuals()
	for wall in walls:
		if wall.visible:
			wall.update_visuals()


## Check all collisions
func _check_collisions():
	# Check wall collisions
	for wall in walls:
		if wall.visible:
			var rect: Rect2 = wall.next_bounding_rect()
			var inner_rect: Rect2 = wall.inner_bounding_rect()
			var collision: Array = check_collision(wall, rect, Collision.Type.ALL, inner_rect)
			wall.collide(collision)

	# Check ball collisions
	for ball in balls:
		var rect: Rect2 = ball.next_bounding_rect()
		var collision: Array = check_collision(ball, rect, Collision.Type.ALL)
		ball.collide(collision)


## Check collision for an object against other objects
## inner_rect: optional rect for ball collision checks (for walls, excludes tip)
func check_collision(object: Node, rect: Rect2, type: int, inner_rect: Rect2 = Rect2()) -> Array:
	var result: Array = []

	# Check tile collisions
	if type & Collision.Type.TILE:
		if object is Wall:
			# For walls, only check the tip tile (skip if still in start tile)
			var tip_tile := _get_tip_tile(rect, object.direction)
			var start_tile := Vector2i(object.start_x, object.start_y)
			if tip_tile != start_tile:  # Tip has left starting tile
				if tip_tile.x >= 0 and tip_tile.x < TILE_NUM_W and tip_tile.y >= 0 and tip_tile.y < TILE_NUM_H:
					if tiles[tip_tile.x][tip_tile.y] != TileType.FREE:
						var hit := Collision.Hit.new()
						hit.type = Collision.Type.TILE
						result.append(hit)
		elif object is Ball:
			# For balls, use 2014 KBounce approach: test axes independently
			result.append_array(_check_ball_tile_collision(object))

	# Check wall collisions (wall vs wall)
	if type & Collision.Type.WALL and object is Wall:
		var my_tip_tile := _get_tip_tile(rect, object.direction)
		var my_tip_rect := _get_tip_rect(rect, object.direction)
		var my_start := Vector2i(object.start_x, object.start_y)

		# Skip if my tip is still in start tile
		if my_tip_tile == my_start:
			pass  # Allow, no wall collision check needed
		else:
			for wall in walls:
				if wall != object and wall.visible:
					# Skip paired walls (same start, opposite direction)
					if _are_paired_walls(object, wall):
						continue

					# Check if MY TIP overlaps other wall (not full rect)
					if my_tip_rect.intersects(wall.next_bounding_rect()):
						var other_tip_rect := _get_tip_rect(wall.next_bounding_rect(), wall.direction)

						var hit := Collision.Hit.new()
						hit.bounding_rect = wall.next_bounding_rect()
						hit.normal = Collision.calculate_normal(rect, hit.bounding_rect)
						hit.source = wall

						# Check if tip rects cover any same tiles
						var tips_share_tile := _rects_share_tile(my_tip_rect, other_tip_rect)
						if tips_share_tile:
							hit.type = Collision.Type.WALL  # Both die
						else:
							hit.type = Collision.Type.TILE  # Materialize

						result.append(hit)

	# Check ball vs wall collisions (for ball reflection off growing walls)
	if type & Collision.Type.WALL and object is Ball:
		var ball := object as Ball
		var current_rect := ball.ball_bounding_rect()
		var velocity := ball.velocity

		for wall in walls:
			if wall.visible:
				var wall_rect: Rect2 = wall.next_bounding_rect()
				if rect.intersects(wall_rect):
					# Use 2014 approach: test axes independently
					var hit := Collision.Hit.new()
					hit.type = Collision.Type.WALL
					hit.bounding_rect = wall_rect
					hit.normal = Collision.calculate_normal_with_velocity(
						current_rect, velocity, wall_rect)
					hit.source = wall
					result.append(hit)

	# Check ball collisions
	if type & Collision.Type.BALL:
		# Use inner_rect if provided (for walls, only inner area triggers death)
		var check_rect := inner_rect if inner_rect.has_area() else rect
		for ball in balls:
			if ball != object:
				var ball_next: Rect2 = ball.next_bounding_rect()
				if check_rect.intersects(ball_next):
					# Ball hit inner wall area - wall dies
					var hit := Collision.Hit.new()
					hit.type = Collision.Type.BALL
					hit.bounding_rect = ball_next
					hit.normal = Collision.calculate_normal(check_rect, ball_next)
					result.append(hit)
				elif object is Wall and rect.intersects(ball_next):
					# Ball hit wall tip (not inner rect) - check if ball would be trapped
					if _would_ball_be_trapped(ball, object as Wall):
						# Ball would be trapped - wall should materialize early
						var hit := Collision.Hit.new()
						hit.type = Collision.Type.TILE
						result.append(hit)

	return result


## Check ball collision against tiles using 2014 KBounce approach
## Tests each axis independently to determine correct reflection
func _check_ball_tile_collision(ball: Ball) -> Array:
	var current_rect := ball.ball_bounding_rect()
	var velocity := ball.velocity

	# Small epsilon to avoid edge-case collisions
	const D := 0.01

	var reflect_x := false
	var reflect_y := false

	# Test X-only movement
	var rect_x := Rect2(current_rect.position + Vector2(velocity.x, 0), current_rect.size)
	if _rect_hits_tile(rect_x, D):
		reflect_x = true

	# Test Y-only movement
	var rect_y := Rect2(current_rect.position + Vector2(0, velocity.y), current_rect.size)
	if _rect_hits_tile(rect_y, D):
		reflect_y = true

	# Corner case: neither axis alone collides, but diagonal does
	if not reflect_x and not reflect_y:
		var rect_xy := Rect2(current_rect.position + velocity, current_rect.size)
		if _rect_hits_tile(rect_xy, D):
			reflect_x = true
			reflect_y = true

	# Build normal from reflection flags
	var result: Array = []
	if reflect_x or reflect_y:
		var hit := Collision.Hit.new()
		hit.type = Collision.Type.TILE
		# Normal points opposite to velocity (away from obstacle)
		if reflect_x:
			hit.normal.x = 1.0 if velocity.x < 0 else -1.0
		if reflect_y:
			hit.normal.y = 1.0 if velocity.y < 0 else -1.0
		result.append(hit)

	return result


## Check if a rectangle hits any non-free tile
func _rect_hits_tile(rect: Rect2, epsilon: float) -> bool:
	var check_rect := rect
	check_rect.position.x = clamp(check_rect.position.x, 0, TILE_NUM_W - 1)
	check_rect.position.y = clamp(check_rect.position.y, 0, TILE_NUM_H - 1)
	check_rect.end.x = clamp(check_rect.end.x, 0, TILE_NUM_W)
	check_rect.end.y = clamp(check_rect.end.y, 0, TILE_NUM_H)

	# Check all four corners
	var ul: int = tiles[int(check_rect.position.x + epsilon)][int(check_rect.position.y + epsilon)]
	var ur: int = tiles[int(check_rect.end.x - epsilon)][int(check_rect.position.y + epsilon)]
	var lr: int = tiles[int(check_rect.end.x - epsilon)][int(check_rect.end.y - epsilon)]
	var ll: int = tiles[int(check_rect.position.x + epsilon)][int(check_rect.end.y - epsilon)]

	return ul != TileType.FREE or ur != TileType.FREE or lr != TileType.FREE or ll != TileType.FREE


## Check collision against tiles
## wall_dir: -1 for non-walls (check all corners), or Wall.Direction to check only leading edge
func _check_collision_tiles(rect: Rect2, wall_dir: int = -1) -> Array:
	var normal := Vector2.ZERO

	# Small epsilon to avoid edge-case collisions
	const D := 0.01

	# Clamp to valid range (end can reach TILE_NUM to detect right/bottom borders)
	var check_rect := rect
	check_rect.position.x = clamp(check_rect.position.x, 0, TILE_NUM_W - 1)
	check_rect.position.y = clamp(check_rect.position.y, 0, TILE_NUM_H - 1)
	check_rect.end.x = clamp(check_rect.end.x, 0, TILE_NUM_W)
	check_rect.end.y = clamp(check_rect.end.y, 0, TILE_NUM_H)

	# For walls, only check corners on the leading edge (tip)
	# UP=0: check top corners (ul, ur)
	# DOWN=1: check bottom corners (lr, ll)
	# LEFT=2: check left corners (ul, ll)
	# RIGHT=3: check right corners (ur, lr)
	var check_ul := wall_dir == -1 or wall_dir == Wall.Direction.UP or wall_dir == Wall.Direction.LEFT
	var check_ur := wall_dir == -1 or wall_dir == Wall.Direction.UP or wall_dir == Wall.Direction.RIGHT
	var check_lr := wall_dir == -1 or wall_dir == Wall.Direction.DOWN or wall_dir == Wall.Direction.RIGHT
	var check_ll := wall_dir == -1 or wall_dir == Wall.Direction.DOWN or wall_dir == Wall.Direction.LEFT

	var ul: int = TileType.FREE
	var ur: int = TileType.FREE
	var lr: int = TileType.FREE
	var ll: int = TileType.FREE

	if check_ul:
		ul = tiles[int(check_rect.position.x + D)][int(check_rect.position.y + D)]
		if ul != TileType.FREE:
			normal += Vector2(1, 1)

	if check_ur:
		ur = tiles[int(check_rect.end.x - D)][int(check_rect.position.y + D)]
		if ur != TileType.FREE:
			normal += Vector2(-1, 1)

	if check_lr:
		lr = tiles[int(check_rect.end.x - D)][int(check_rect.end.y - D)]
		if lr != TileType.FREE:
			normal += Vector2(-1, -1)

	if check_ll:
		ll = tiles[int(check_rect.position.x + D)][int(check_rect.end.y - D)]
		if ll != TileType.FREE:
			normal += Vector2(1, -1)

	var result: Array = []
	if ul != TileType.FREE or ur != TileType.FREE or lr != TileType.FREE or ll != TileType.FREE:
		var hit := Collision.Hit.new()
		hit.type = Collision.Type.TILE
		hit.normal = normal
		result.append(hit)

	return result


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


## Get the tip rectangle for a wall (leading edge only)
## Used for wall-to-wall collision - only the tip triggers collision
func _get_tip_rect(rect: Rect2, direction: int) -> Rect2:
	const TIP_SIZE := 0.1  # Small strip representing the tip

	match direction:
		Wall.Direction.UP:
			return Rect2(rect.position.x, rect.position.y, rect.size.x, TIP_SIZE)
		Wall.Direction.DOWN:
			return Rect2(rect.position.x, rect.end.y - TIP_SIZE, rect.size.x, TIP_SIZE)
		Wall.Direction.LEFT:
			return Rect2(rect.position.x, rect.position.y, TIP_SIZE, rect.size.y)
		Wall.Direction.RIGHT:
			return Rect2(rect.end.x - TIP_SIZE, rect.position.y, TIP_SIZE, rect.size.y)

	return rect  # Fallback


## Check if two rectangles cover any of the same tiles
func _rects_share_tile(rect1: Rect2, rect2: Rect2) -> bool:
	# Get tile ranges for each rect
	var r1_x1 := int(rect1.position.x)
	var r1_y1 := int(rect1.position.y)
	var r1_x2 := int(ceil(rect1.end.x - 0.001))  # Exclusive end, small epsilon
	var r1_y2 := int(ceil(rect1.end.y - 0.001))

	var r2_x1 := int(rect2.position.x)
	var r2_y1 := int(rect2.position.y)
	var r2_x2 := int(ceil(rect2.end.x - 0.001))
	var r2_y2 := int(ceil(rect2.end.y - 0.001))

	# Check if tile ranges overlap
	var x_overlap := r1_x1 <= r2_x2 and r2_x1 <= r1_x2
	var y_overlap := r1_y1 <= r2_y2 and r2_y1 <= r1_y2

	return x_overlap and y_overlap


## Get the tile coordinates of a wall's tip
func _get_tip_tile(rect: Rect2, direction: int) -> Vector2i:
	match direction:
		Wall.Direction.UP:
			return Vector2i(int(rect.position.x), int(rect.position.y))
		Wall.Direction.DOWN:
			return Vector2i(int(rect.position.x), int(rect.end.y - 0.01))
		Wall.Direction.LEFT:
			return Vector2i(int(rect.position.x), int(rect.position.y))
		Wall.Direction.RIGHT:
			return Vector2i(int(rect.end.x - 0.01), int(rect.position.y))

	return Vector2i(-1, -1)  # Fallback


## Convert relative position to pixel position
func map_position(relative_pos: Vector2) -> Vector2:
	return Vector2(tile_size.x * relative_pos.x, tile_size.y * relative_pos.y)


## Get bounding rectangle of the board in global screen coordinates
func get_board_rect() -> Rect2:
	return Rect2(global_position, Vector2(TILE_NUM_W * tile_size.x, TILE_NUM_H * tile_size.y))


## Handle wall death (hit by ball)
func _on_wall_died():
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


## Check if ball would be trapped if wall continues growing
## Returns true if ball has insufficient space to escape after reflecting off wall tip
func _would_ball_be_trapped(ball: Ball, wall: Wall) -> bool:
	var ball_rect := ball.ball_bounding_rect()
	var ball_center := ball_rect.get_center()
	var check_x := int(ball_center.x)
	var check_y := int(ball_center.y)

	# Ball needs at least 2 tiles of free space to escape safely
	const MIN_ESCAPE_SPACE := 2

	match wall.direction:
		Wall.Direction.DOWN:
			# Wall going down, ball must escape upward
			var free := 0
			for y in range(check_y - 1, 0, -1):
				if tiles[check_x][y] != TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.UP:
			# Wall going up, ball must escape downward
			var free := 0
			for y in range(check_y + 1, TILE_NUM_H - 1):
				if tiles[check_x][y] != TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.RIGHT:
			# Wall going right, ball must escape leftward
			var free := 0
			for x in range(check_x - 1, 0, -1):
				if tiles[x][check_y] != TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.LEFT:
			# Wall going left, ball must escape rightward
			var free := 0
			for x in range(check_x + 1, TILE_NUM_W - 1):
				if tiles[x][check_y] != TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

	return false


## Custom drawing for the board tiles
func _draw():
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
