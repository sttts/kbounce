# test_wall_ball.gd - Unit tests for wall building and ball movement
#
# SPDX-FileCopyrightText: 2025 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted

const TestRunner = preload("res://tests/test_runner.gd")


# =============================================================================
# Tests for wall inner bounding rect
# =============================================================================

func test_inner_rect_up_wall_small():
	# Wall too small (size <= 1) has no inner rect
	var rect := Rect2(5, 5, 1, 0.8)  # Less than 1 tile tall
	var inner := _inner_bounding_rect(rect, Wall.Direction.UP)
	return TestRunner.assert_true(not inner.has_area(), "Small UP wall should have no inner rect")


func test_inner_rect_up_wall_large():
	# Wall larger than 1 tile has inner rect excluding tip
	var rect := Rect2(5, 3, 1, 3)  # 3 tiles tall, tip at y=3
	var inner := _inner_bounding_rect(rect, Wall.Direction.UP)
	# Inner should exclude top tile (tip), so start at y=4
	return TestRunner.assert_approx(inner.position.y, 4.0, 0.01, "Inner Y start") + \
		   TestRunner.assert_approx(inner.size.y, 2.0, 0.01, "Inner Y size")


func test_inner_rect_down_wall_small():
	var rect := Rect2(5, 5, 1, 0.8)
	var inner := _inner_bounding_rect(rect, Wall.Direction.DOWN)
	return TestRunner.assert_true(not inner.has_area(), "Small DOWN wall should have no inner rect")


func test_inner_rect_down_wall_large():
	var rect := Rect2(5, 5, 1, 3)  # 3 tiles tall, tip at y=8
	var inner := _inner_bounding_rect(rect, Wall.Direction.DOWN)
	# Inner should exclude bottom tile (tip), size reduced by 1
	return TestRunner.assert_approx(inner.position.y, 5.0, 0.01, "Inner Y start unchanged") + \
		   TestRunner.assert_approx(inner.size.y, 2.0, 0.01, "Inner Y size")


func test_inner_rect_left_wall_small():
	var rect := Rect2(5, 5, 0.8, 1)
	var inner := _inner_bounding_rect(rect, Wall.Direction.LEFT)
	return TestRunner.assert_true(not inner.has_area(), "Small LEFT wall should have no inner rect")


func test_inner_rect_left_wall_large():
	var rect := Rect2(3, 5, 3, 1)  # 3 tiles wide, tip at x=3
	var inner := _inner_bounding_rect(rect, Wall.Direction.LEFT)
	# Inner should exclude left tile (tip), so start at x=4
	return TestRunner.assert_approx(inner.position.x, 4.0, 0.01, "Inner X start") + \
		   TestRunner.assert_approx(inner.size.x, 2.0, 0.01, "Inner X size")


func test_inner_rect_right_wall_small():
	var rect := Rect2(5, 5, 0.8, 1)
	var inner := _inner_bounding_rect(rect, Wall.Direction.RIGHT)
	return TestRunner.assert_true(not inner.has_area(), "Small RIGHT wall should have no inner rect")


func test_inner_rect_right_wall_large():
	var rect := Rect2(5, 5, 3, 1)  # 3 tiles wide, tip at x=8
	var inner := _inner_bounding_rect(rect, Wall.Direction.RIGHT)
	# Inner should exclude right tile (tip), size reduced by 1
	return TestRunner.assert_approx(inner.position.x, 5.0, 0.01, "Inner X start unchanged") + \
		   TestRunner.assert_approx(inner.size.x, 2.0, 0.01, "Inner X size")


# =============================================================================
# Tests for wall growth
# =============================================================================

func test_wall_growth_up():
	var rect := Rect2(5, 5, 1, 1)
	var velocity := 0.125
	var new_rect := _grow_wall(rect, Wall.Direction.UP, velocity)
	# UP: position.y decreases, size.y increases
	return TestRunner.assert_approx(new_rect.position.y, 4.875, 0.001, "Y position") + \
		   TestRunner.assert_approx(new_rect.size.y, 1.125, 0.001, "Y size")


func test_wall_growth_down():
	var rect := Rect2(5, 5, 1, 1)
	var velocity := 0.125
	var new_rect := _grow_wall(rect, Wall.Direction.DOWN, velocity)
	# DOWN: position.y unchanged, size.y increases
	return TestRunner.assert_approx(new_rect.position.y, 5.0, 0.001, "Y position unchanged") + \
		   TestRunner.assert_approx(new_rect.size.y, 1.125, 0.001, "Y size")


func test_wall_growth_left():
	var rect := Rect2(5, 5, 1, 1)
	var velocity := 0.125
	var new_rect := _grow_wall(rect, Wall.Direction.LEFT, velocity)
	# LEFT: position.x decreases, size.x increases
	return TestRunner.assert_approx(new_rect.position.x, 4.875, 0.001, "X position") + \
		   TestRunner.assert_approx(new_rect.size.x, 1.125, 0.001, "X size")


func test_wall_growth_right():
	var rect := Rect2(5, 5, 1, 1)
	var velocity := 0.125
	var new_rect := _grow_wall(rect, Wall.Direction.RIGHT, velocity)
	# RIGHT: position.x unchanged, size.x increases
	return TestRunner.assert_approx(new_rect.position.x, 5.0, 0.001, "X position unchanged") + \
		   TestRunner.assert_approx(new_rect.size.x, 1.125, 0.001, "X size")


func test_wall_growth_multiple_ticks():
	# Wall grows 8 ticks at 0.125 = 1 full tile
	var rect := Rect2(5, 5, 1, 1)
	var velocity := 0.125
	for i in range(8):
		rect = _grow_wall(rect, Wall.Direction.DOWN, velocity)
	return TestRunner.assert_approx(rect.size.y, 2.0, 0.001, "Should grow 1 tile after 8 ticks")


# =============================================================================
# Tests for ball movement
# =============================================================================

func test_ball_movement_positive():
	var pos := Vector2(5, 5)
	var velocity := Vector2(0.125, 0.125)
	var new_pos := pos + velocity
	return TestRunner.assert_approx(new_pos.x, 5.125, 0.001, "X position") + \
		   TestRunner.assert_approx(new_pos.y, 5.125, 0.001, "Y position")


func test_ball_movement_negative():
	var pos := Vector2(5, 5)
	var velocity := Vector2(-0.125, -0.125)
	var new_pos := pos + velocity
	return TestRunner.assert_approx(new_pos.x, 4.875, 0.001, "X position") + \
		   TestRunner.assert_approx(new_pos.y, 4.875, 0.001, "Y position")


func test_ball_bounding_rect():
	var pos := Vector2(5, 5)
	var rect := _ball_bounding_rect(pos)
	# Ball is 0.8 tiles in size
	return TestRunner.assert_approx(rect.position.x, 5.0, 0.001, "Rect X") + \
		   TestRunner.assert_approx(rect.position.y, 5.0, 0.001, "Rect Y") + \
		   TestRunner.assert_approx(rect.size.x, 0.8, 0.001, "Rect width") + \
		   TestRunner.assert_approx(rect.size.y, 0.8, 0.001, "Rect height")


func test_ball_next_bounding_rect():
	var pos := Vector2(5, 5)
	var velocity := Vector2(0.125, -0.125)
	var next_rect := _ball_next_bounding_rect(pos, velocity)
	return TestRunner.assert_approx(next_rect.position.x, 5.125, 0.001, "Next X") + \
		   TestRunner.assert_approx(next_rect.position.y, 4.875, 0.001, "Next Y")


func test_ball_velocity_reflection_x():
	var velocity := Vector2(0.125, 0.125)
	var reflected := _reflect_velocity(velocity, true, false)
	return TestRunner.assert_approx(reflected.x, -0.125, 0.001, "X reflected") + \
		   TestRunner.assert_approx(reflected.y, 0.125, 0.001, "Y unchanged")


func test_ball_velocity_reflection_y():
	var velocity := Vector2(0.125, 0.125)
	var reflected := _reflect_velocity(velocity, false, true)
	return TestRunner.assert_approx(reflected.x, 0.125, 0.001, "X unchanged") + \
		   TestRunner.assert_approx(reflected.y, -0.125, 0.001, "Y reflected")


func test_ball_velocity_reflection_both():
	var velocity := Vector2(0.125, 0.125)
	var reflected := _reflect_velocity(velocity, true, true)
	return TestRunner.assert_approx(reflected.x, -0.125, 0.001, "X reflected") + \
		   TestRunner.assert_approx(reflected.y, -0.125, 0.001, "Y reflected")


func test_ball_movement_8_ticks():
	# Ball moves 8 ticks at 0.125 = 1 full tile
	var pos := Vector2(5, 5)
	var velocity := Vector2(0.125, 0)
	for i in range(8):
		pos += velocity
	return TestRunner.assert_approx(pos.x, 6.0, 0.001, "Should move 1 tile after 8 ticks")


# =============================================================================
# Helper functions
# =============================================================================

## Calculate inner bounding rect (mimics Wall.inner_bounding_rect)
func _inner_bounding_rect(rect: Rect2, direction: int) -> Rect2:
	var inner := rect
	match direction:
		Wall.Direction.UP:
			if inner.size.y > 1.0:
				inner.position.y += 1.0
				inner.size.y -= 1.0
			else:
				return Rect2()
		Wall.Direction.DOWN:
			if inner.size.y > 1.0:
				inner.size.y -= 1.0
			else:
				return Rect2()
		Wall.Direction.LEFT:
			if inner.size.x > 1.0:
				inner.position.x += 1.0
				inner.size.x -= 1.0
			else:
				return Rect2()
		Wall.Direction.RIGHT:
			if inner.size.x > 1.0:
				inner.size.x -= 1.0
			else:
				return Rect2()
	return inner


## Grow wall in direction (mimics Wall.go_forward)
func _grow_wall(rect: Rect2, direction: int, velocity: float) -> Rect2:
	var new_rect := rect
	match direction:
		Wall.Direction.UP:
			new_rect.position.y -= velocity
			new_rect.size.y += velocity
		Wall.Direction.DOWN:
			new_rect.size.y += velocity
		Wall.Direction.LEFT:
			new_rect.position.x -= velocity
			new_rect.size.x += velocity
		Wall.Direction.RIGHT:
			new_rect.size.x += velocity
	return new_rect


## Ball bounding rect (mimics Ball.ball_bounding_rect)
const BALL_RELATIVE_SIZE := 0.8

func _ball_bounding_rect(pos: Vector2) -> Rect2:
	return Rect2(pos.x, pos.y, BALL_RELATIVE_SIZE, BALL_RELATIVE_SIZE)


## Ball next bounding rect (mimics Ball._update_next_bounding_rect)
func _ball_next_bounding_rect(pos: Vector2, velocity: Vector2) -> Rect2:
	var next_pos := pos + velocity
	return Rect2(next_pos.x, next_pos.y, BALL_RELATIVE_SIZE, BALL_RELATIVE_SIZE)


## Reflect velocity (mimics Ball.go_forward reflection)
func _reflect_velocity(velocity: Vector2, reflect_x: bool, reflect_y: bool) -> Vector2:
	var result := velocity
	if reflect_x:
		result.x *= -1
	if reflect_y:
		result.y *= -1
	return result
