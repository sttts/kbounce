# test_collision.gd - Unit tests for ball collision and reflection logic
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")


# =============================================================================
# Tests for Collision.calculate_normal_with_velocity
# =============================================================================

func test_normal_ball_moving_right_hits_wall():
	# Ball about to hit wall on right - ball end.x almost touches wall start.x
	var ball := Rect2(5.0, 5.0, 0.8, 0.8)  # Ball from (5,5) to (5.8,5.8)
	var velocity := Vector2(0.125, 0)
	var wall := Rect2(5.8, 5.0, 1.0, 1.0)  # Wall starts where ball ends

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# Moving X causes collision, should reflect X (normal points left)
	return TestRunner.assert_eq(normal.x, -1.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, 0.0, "Y normal")


func test_normal_ball_moving_left_hits_wall():
	# Ball about to hit wall on left
	var ball := Rect2(5.0, 5.0, 0.8, 0.8)  # Ball from (5,5) to (5.8,5.8)
	var velocity := Vector2(-0.125, 0)
	var wall := Rect2(4.0, 5.0, 1.0, 1.0)  # Wall ends at x=5 where ball starts

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# Moving X causes collision, should reflect X (normal points right)
	return TestRunner.assert_eq(normal.x, 1.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, 0.0, "Y normal")


func test_normal_ball_moving_down_hits_wall():
	# Ball about to hit wall below
	var ball := Rect2(5.0, 5.0, 0.8, 0.8)  # Ball from (5,5) to (5.8,5.8)
	var velocity := Vector2(0, 0.125)
	var wall := Rect2(5.0, 5.8, 1.0, 1.0)  # Wall starts where ball ends in Y

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# Moving Y causes collision, should reflect Y (normal points up)
	return TestRunner.assert_eq(normal.x, 0.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, -1.0, "Y normal")


func test_normal_ball_moving_up_hits_wall():
	# Ball about to hit wall above
	var ball := Rect2(5.0, 5.0, 0.8, 0.8)
	var velocity := Vector2(0, -0.125)
	var wall := Rect2(5.0, 4.0, 1.0, 1.0)  # Wall ends at y=5 where ball starts

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# Moving Y causes collision, should reflect Y (normal points down)
	return TestRunner.assert_eq(normal.x, 0.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, 1.0, "Y normal")


func test_normal_ball_diagonal_hits_corner():
	# Ball moving diagonally, both axes would cause collision
	var ball := Rect2(5.0, 5.0, 0.8, 0.8)
	var velocity := Vector2(0.125, 0.125)
	var wall := Rect2(5.8, 5.8, 1.0, 1.0)  # Corner exactly at ball's corner

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# Both X and Y movement cause collision
	return TestRunner.assert_eq(normal.x, -1.0, "X normal") + \
		   TestRunner.assert_eq(normal.y, -1.0, "Y normal")


func test_normal_ball_diagonal_hits_vertical_edge():
	# Ball moving diagonally but wall spans Y range - only X causes new collision
	var ball := Rect2(5.0, 5.0, 0.8, 0.8)
	var velocity := Vector2(0.125, 0.125)
	var wall := Rect2(5.8, 4.5, 1.0, 2.0)  # Wall spans y=4.5 to 6.5, overlaps ball's Y

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# Only X movement causes collision (Y already overlaps)
	return TestRunner.assert_eq(normal.x, -1.0, "X normal")


func test_normal_no_collision():
	# Ball not colliding with wall
	var ball := Rect2(5, 5, 0.8, 0.8)
	var velocity := Vector2(0.125, 0)
	var wall := Rect2(10, 10, 1, 1)  # Far away

	var normal := Collision.calculate_normal_with_velocity(ball, velocity, wall)

	# No collision, normal should be zero
	return TestRunner.assert_eq(normal, Vector2.ZERO, "No collision normal")


# =============================================================================
# Tests for ball reflection logic
# =============================================================================

func test_reflection_horizontal():
	# Ball moving right, hits wall, should reverse X
	var velocity := Vector2(0.125, 0.125)
	var normal := Vector2(-1, 0)  # Wall to the right

	var reflected := _apply_reflection(velocity, normal)

	return TestRunner.assert_eq(reflected.x, -0.125, "Reflected X") + \
		   TestRunner.assert_eq(reflected.y, 0.125, "Y unchanged")


func test_reflection_vertical():
	# Ball moving down, hits floor, should reverse Y
	var velocity := Vector2(0.125, 0.125)
	var normal := Vector2(0, -1)  # Floor below

	var reflected := _apply_reflection(velocity, normal)

	return TestRunner.assert_eq(reflected.x, 0.125, "X unchanged") + \
		   TestRunner.assert_eq(reflected.y, -0.125, "Reflected Y")


func test_reflection_corner():
	# Ball hits corner, should reverse both
	var velocity := Vector2(0.125, 0.125)
	var normal := Vector2(-1, -1)  # Corner

	var reflected := _apply_reflection(velocity, normal)

	return TestRunner.assert_eq(reflected.x, -0.125, "Reflected X") + \
		   TestRunner.assert_eq(reflected.y, -0.125, "Reflected Y")


func test_reflection_already_moving_away():
	# Ball already moving away from wall, no reflection
	var velocity := Vector2(-0.125, 0)  # Moving left
	var normal := Vector2(-1, 0)  # Wall to the right

	var reflected := _apply_reflection(velocity, normal)

	# Should not change (already moving away)
	return TestRunner.assert_eq(reflected.x, -0.125, "X unchanged (moving away)")


# =============================================================================
# Tests for trap detection
# =============================================================================

func test_trap_ball_near_top_border_wall_going_down():
	# Ball is near top border (y=2), wall going DOWN
	# Ball has only 1 tile of escape space -> trapped
	var tiles := _create_empty_tiles()
	var ball_y := 2  # Near top border (border at y=0)
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(is_trapped, "Ball near top border should be trapped")


func test_trap_ball_far_from_border_wall_going_down():
	# Ball is far from top border (y=10), wall going DOWN
	# Ball has plenty of escape space -> not trapped
	var tiles := _create_empty_tiles()
	var ball_y := 10  # Far from border
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(not is_trapped, "Ball far from border should not be trapped")


func test_trap_ball_near_bottom_border_wall_going_up():
	# Ball near bottom border, wall going UP
	var tiles := _create_empty_tiles()
	var ball_y := 17  # Near bottom (border at y=19)
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.UP)

	return TestRunner.assert_true(is_trapped, "Ball near bottom border should be trapped")


func test_trap_ball_near_left_border_wall_going_right():
	# Ball near left border, wall going RIGHT
	var tiles := _create_empty_tiles()
	var ball_x := 2  # Near left border
	var is_trapped := _check_trapped(tiles, ball_x, 10, Wall.Direction.RIGHT)

	return TestRunner.assert_true(is_trapped, "Ball near left border should be trapped")


func test_trap_ball_near_right_border_wall_going_left():
	# Ball near right border, wall going LEFT
	var tiles := _create_empty_tiles()
	var ball_x := 29  # Near right border (border at x=31)
	var is_trapped := _check_trapped(tiles, ball_x, 10, Wall.Direction.LEFT)

	return TestRunner.assert_true(is_trapped, "Ball near right border should be trapped")


func test_trap_ball_blocked_by_filled_area():
	# Ball in middle, but filled area blocks escape
	var tiles := _create_empty_tiles()
	# Fill tiles above the ball position
	for y in range(1, 8):
		tiles[10][y] = Board.TileType.WALL
	var ball_y := 9  # Ball just below filled area
	var is_trapped := _check_trapped(tiles, 10, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(is_trapped, "Ball blocked by filled area should be trapped")


func test_trap_ball_has_escape_route():
	# Ball with clear escape route
	var tiles := _create_empty_tiles()
	var ball_y := 10  # Middle of board
	var is_trapped := _check_trapped(tiles, 15, ball_y, Wall.Direction.DOWN)

	return TestRunner.assert_true(not is_trapped, "Ball with escape route should not be trapped")


# =============================================================================
# Helper functions
# =============================================================================

## Apply reflection logic (mimics Ball.collide + go_forward)
func _apply_reflection(velocity: Vector2, normal: Vector2) -> Vector2:
	var reflect_x := false
	var reflect_y := false

	if normal.x > 0:
		reflect_x = velocity.x < 0
	elif normal.x < 0:
		reflect_x = velocity.x > 0

	if normal.y > 0:
		reflect_y = velocity.y < 0
	elif normal.y < 0:
		reflect_y = velocity.y > 0

	var result := velocity
	if reflect_x:
		result.x *= -1
	if reflect_y:
		result.y *= -1
	return result


## Create empty tile array (mimics Board.clear())
func _create_empty_tiles() -> Array:
	var tiles: Array = []
	for x in range(Board.TILE_NUM_W):
		var column: Array = []
		for y in range(Board.TILE_NUM_H):
			if x == 0 or x == Board.TILE_NUM_W - 1 or y == 0 or y == Board.TILE_NUM_H - 1:
				column.append(Board.TileType.BORDER)
			else:
				column.append(Board.TileType.FREE)
		tiles.append(column)
	return tiles


## Check if ball would be trapped (mimics Board._would_ball_be_trapped logic)
func _check_trapped(tiles: Array, ball_x: int, ball_y: int, wall_dir: int) -> bool:
	const MIN_ESCAPE_SPACE := 2

	match wall_dir:
		Wall.Direction.DOWN:
			var free := 0
			for y in range(ball_y - 1, 0, -1):
				if tiles[ball_x][y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.UP:
			var free := 0
			for y in range(ball_y + 1, Board.TILE_NUM_H - 1):
				if tiles[ball_x][y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.RIGHT:
			var free := 0
			for x in range(ball_x - 1, 0, -1):
				if tiles[x][ball_y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

		Wall.Direction.LEFT:
			var free := 0
			for x in range(ball_x + 1, Board.TILE_NUM_W - 1):
				if tiles[x][ball_y] != Board.TileType.FREE:
					break
				free += 1
			return free < MIN_ESCAPE_SPACE

	return false
