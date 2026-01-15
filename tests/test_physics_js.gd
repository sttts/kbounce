# test_physics_js.gd - Test JS physics integration
#
# Tests the public physics API: init(), add_ball(), tick()
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted


func _get_pm():
	return Engine.get_main_loop().root.get_node_or_null("/root/PhysicsManager")


func test_physics_init() -> String:
	var pm = _get_pm()
	if pm == null:
		return ""

	if not pm.is_ready():
		return "PhysicsManager not ready"

	var version: int = pm.get_version()
	if version < 1:
		return "Invalid physics version: %d" % version

	return ""


func test_ball_movement() -> String:
	var pm = _get_pm()
	if pm == null:
		return ""

	pm.init()
	pm.add_ball(10.0, 10.0, 0.125, 0.125)

	# Run one tick
	var result: Dictionary = pm.tick()
	var balls: Array = result.get("balls", [])

	if balls.size() != 1:
		return "Expected 1 ball, got %d" % balls.size()

	var ball: Dictionary = balls[0]
	var expected_x := 10.0 + 0.125
	var expected_y := 10.0 + 0.125

	if abs(ball.get("x", 0) - expected_x) > 0.001:
		return "Ball x wrong: expected %f, got %f" % [expected_x, ball.get("x", 0)]

	if abs(ball.get("y", 0) - expected_y) > 0.001:
		return "Ball y wrong: expected %f, got %f" % [expected_y, ball.get("y", 0)]

	return ""


func test_tile_collision() -> String:
	var pm = _get_pm()
	if pm == null:
		return ""

	pm.init()

	# Ball moving left into border (x=0 is BORDER)
	pm.add_ball(1.5, 10.0, -0.125, 0.0)

	# Tick until collision should occur
	var result: Dictionary
	for i in range(20):
		result = pm.tick()

	var balls: Array = result.get("balls", [])
	if balls.is_empty():
		return "No balls after ticks"

	var vx: float = balls[0].get("vx", 0)

	# Velocity should have reversed (positive) after hitting left border
	if vx < 0:
		return "Ball should have reflected off left border, vx=%f" % vx

	return ""


func test_tick_counter() -> String:
	var pm = _get_pm()
	if pm == null:
		return ""

	pm.init()
	pm.add_ball(10.0, 10.0, 0.125, 0.125)

	# Run 5 ticks
	var result: Dictionary
	for i in range(5):
		result = pm.tick()

	var tick: int = result.get("tick", -1)
	if tick != 5:
		return "Expected tick 5, got %d" % tick

	return ""


func test_wall_placement() -> String:
	var pm = _get_pm()
	if pm == null:
		return ""

	pm.init()
	pm.add_ball(10.0, 10.0, 0.125, 0.125)

	# Place a vertical wall
	var actions := [{"x": 15, "y": 10, "vertical": true}]
	var result: Dictionary = pm.tick(actions)

	var new_walls: Array = result.get("newWalls", [])
	if new_walls.size() != 2:
		return "Expected 2 new walls (up+down), got %d" % new_walls.size()

	return ""
