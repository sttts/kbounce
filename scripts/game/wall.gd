# wall.gd - Wall entity that extends from click point
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

class_name Wall
extends Node2D

## Emitted when wall finishes building (reaches edge or other wall)
signal finished(x1: int, y1: int, x2: int, y2: int)

## Emitted when wall is destroyed by a ball
signal died

## Emitted when wall dies from wall-to-wall collision (paired wall should also die)
signal died_from_wall_collision

## Wall direction
enum Direction { UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3 }

## Reference to the game board
var board: Board

## Direction this wall extends
var direction: Direction = Direction.UP

## Wall velocity in tiles per tick
var wall_velocity := 0.125

## Whether wall is currently being built
var _building := false

## Starting tile position
var start_x := 0
var start_y := 0

## Current bounding rect in tile coordinates
var _bounding_rect := Rect2()

## Predicted bounding rect for next frame
var _next_bounding_rect := Rect2()

## Current tile size
var _tile_size := Vector2i(32, 32)

## Sprite references
@onready var _sprite: Sprite2D = $Sprite2D


func _ready():
	visible = false


## Start building wall from a tile position
func build(x: int, y: int):
	if _building:
		return  # Already building

	start_x = x
	start_y = y
	_building = true
	visible = true

	# Initialize bounding rect covering the full starting tile.
	# Tips are at opposite edges: UP at top (position.y), DOWN at bottom (end.y)
	# Direction-aware collision checking only looks at the tip.
	match direction:
		Direction.UP, Direction.DOWN:
			_bounding_rect = Rect2(x, y, 1, 1)
		Direction.LEFT, Direction.RIGHT:
			_bounding_rect = Rect2(x, y, 1, 1)
	_next_bounding_rect = _bounding_rect

	AudioManager.play("wallstart")
	update_visuals()


## Get current bounding rectangle
func bounding_rect() -> Rect2:
	return _bounding_rect


## Get predicted bounding rectangle for collision
func next_bounding_rect() -> Rect2:
	return _next_bounding_rect


## Get inner bounding rectangle (excludes tip tile) for ball collision
## Ball only kills wall if it hits inner tiles, not the tip
func inner_bounding_rect() -> Rect2:
	var inner := _bounding_rect
	# Shrink by 1 tile from the leading edge (tip)
	match direction:
		Direction.UP:
			if inner.size.y > 1.0:
				inner.position.y += 1.0
				inner.size.y -= 1.0
			else:
				return Rect2()  # No inner area yet
		Direction.DOWN:
			if inner.size.y > 1.0:
				inner.size.y -= 1.0
			else:
				return Rect2()
		Direction.LEFT:
			if inner.size.x > 1.0:
				inner.position.x += 1.0
				inner.size.x -= 1.0
			else:
				return Rect2()
		Direction.RIGHT:
			if inner.size.x > 1.0:
				inner.size.x -= 1.0
			else:
				return Rect2()
	return inner


## Resize wall to match tile size
func resize(tile_size: Vector2i):
	_tile_size = tile_size


## Handle collision response
func collide(collision: Array):
	if not _building:
		return

	# Check for WALL and BALL collisions first (they take priority)
	for hit in collision:
		var h := hit as Collision.Hit
		if not h:
			continue

		if h.type == Collision.Type.BALL:
			# Wall hit by ball - wall dies
			die()
			return

		if h.type == Collision.Type.WALL:
			# Two walls meet with tips - both walls die
			# Also kill paired walls (from same click)
			if h.source and h.source is Wall:
				h.source.die_from_wall()
			die_from_wall()
			return

	# Then check TILE collisions (wall reached edge or another wall's body)
	for hit in collision:
		var h := hit as Collision.Hit
		if not h:
			continue

		if h.type == Collision.Type.TILE:
			# Wall reached edge or filled area
			_finish()
			return


## Perform movement calculation
func go_forward():
	if not _building:
		return

	# Extend wall in its direction
	match direction:
		Direction.UP:
			_bounding_rect.position.y -= wall_velocity
			_bounding_rect.size.y += wall_velocity
		Direction.DOWN:
			_bounding_rect.size.y += wall_velocity
		Direction.LEFT:
			_bounding_rect.position.x -= wall_velocity
			_bounding_rect.size.x += wall_velocity
		Direction.RIGHT:
			_bounding_rect.size.x += wall_velocity

	# Calculate next bounding rect for collision detection
	_next_bounding_rect = _bounding_rect
	match direction:
		Direction.UP:
			_next_bounding_rect.position.y -= wall_velocity
			_next_bounding_rect.size.y += wall_velocity
		Direction.DOWN:
			_next_bounding_rect.size.y += wall_velocity
		Direction.LEFT:
			_next_bounding_rect.position.x -= wall_velocity
			_next_bounding_rect.size.x += wall_velocity
		Direction.RIGHT:
			_next_bounding_rect.size.x += wall_velocity


## Update visual representation
func update_visuals():
	if not _building or not board:
		return

	# Update position (floor to avoid wobbling with pixel calculations)
	var pos := board.map_position(_bounding_rect.position)
	position = Vector2(floor(pos.x), floor(pos.y))

	# Trigger redraw
	queue_redraw()


## Custom drawing for the wall
func _draw():
	if not _building:
		return

	var wall_h := ThemeManager.get_texture("wall_h")  # Inner tile for LEFT/RIGHT
	var wall_v := ThemeManager.get_texture("wall_v")  # Inner tile for UP/DOWN
	var wall_end := ThemeManager.get_texture("wall_end")  # Tip tile for all directions

	var tw := _tile_size.x
	var th := _tile_size.y

	# Calculate pixel dimensions based on floored positions to avoid wobbling
	var start_x := int(floor(_bounding_rect.position.x * tw))
	var start_y := int(floor(_bounding_rect.position.y * th))
	var end_x := int(floor(_bounding_rect.end.x * tw))
	var end_y := int(floor(_bounding_rect.end.y * th))

	var pixel_width := end_x - start_x
	var pixel_height := end_y - start_y

	if pixel_width == 0 and pixel_height == 0:
		return

	# Static grid-aligned inner tiles, complete tip tile at exact sub-pixel position
	match direction:
		Direction.UP:
			if wall_v:
				var full_tiles := pixel_height / th
				var partial := pixel_height % th

				# Inner tiles below the tip (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_v, Rect2(0, partial + i * th, tw, th), false)

				# Full tip tile at exact sub-pixel position (may extend beyond bounding box)
				if wall_end:
					# Tip position: fractional pixel offset from node position
					var world_tip_y: float = _bounding_rect.position.y * th
					var exact_tip_y: float = world_tip_y - floor(world_tip_y)
					draw_texture_rect(wall_end, Rect2(0, exact_tip_y, tw, th), false)

		Direction.DOWN:
			if wall_v:
				var full_tiles := pixel_height / th
				var partial := pixel_height % th

				# Inner tiles from top (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_v, Rect2(0, i * th, tw, th), false)

				# Full tip tile at exact sub-pixel position
				if wall_end:
					# Tip at bottom: world end minus node position minus tile height
					var world_end_y: float = _bounding_rect.end.y * th
					var node_y: float = floor(_bounding_rect.position.y * th)
					var exact_tip_y: float = world_end_y - node_y - th
					draw_texture_rect(wall_end, Rect2(0, exact_tip_y, tw, th), false)

		Direction.LEFT:
			if wall_h:
				var full_tiles := pixel_width / tw
				var partial := pixel_width % tw

				# Inner tiles to the right (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_h, Rect2(partial + i * tw, 0, tw, th), false)

				# Full tip tile at exact sub-pixel position
				if wall_end:
					# Tip position: fractional pixel offset from node position
					var world_tip_x: float = _bounding_rect.position.x * tw
					var exact_tip_x: float = world_tip_x - floor(world_tip_x)
					draw_texture_rect(wall_end, Rect2(exact_tip_x, 0, tw, th), false)

		Direction.RIGHT:
			if wall_h:
				var full_tiles := pixel_width / tw
				var partial := pixel_width % tw

				# Inner tiles from left (grid-aligned)
				for i in range(full_tiles):
					draw_texture_rect(wall_h, Rect2(i * tw, 0, tw, th), false)

				# Full tip tile at exact sub-pixel position
				if wall_end:
					# Tip at right: world end minus node position minus tile width
					var world_end_x: float = _bounding_rect.end.x * tw
					var node_x: float = floor(_bounding_rect.position.x * tw)
					var exact_tip_x: float = world_end_x - node_x - tw
					draw_texture_rect(wall_end, Rect2(exact_tip_x, 0, tw, th), false)


## Wall completed successfully
func _finish():
	if not _building:
		return

	_building = false
	visible = false

	AudioManager.play("wallend")

	# Calculate tile bounds from bounding rect
	var x1 := int(_bounding_rect.position.x)
	var y1 := int(_bounding_rect.position.y)
	var x2 := int(ceil(_bounding_rect.end.x))
	var y2 := int(ceil(_bounding_rect.end.y))

	finished.emit(x1, y1, x2, y2)


## Wall destroyed by ball or another wall
func die():
	if not _building:
		return
	_building = false
	visible = false

	AudioManager.play("death")
	died.emit()


## Wall destroyed by wall-to-wall collision (paired wall should also die)
## Does NOT cost a life - only ball collisions cost lives
func die_from_wall():
	if not _building:
		return
	_building = false
	visible = false

	AudioManager.play("death")
	# Don't emit died - wall-to-wall collision doesn't cost a life
	died_from_wall_collision.emit()


## Stop wall construction without finishing or dying (for level reset)
func stop():
	_building = false
	visible = false
