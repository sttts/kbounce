# test_physics_js.gd - Test JS physics integration
#
# NOTE: These tests require the game to be running with autoloads.
# They will be skipped when PhysicsManager is not available.
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends RefCounted


func test_physics_init() -> String:
	# PhysicsManager is an autoload - check if available
	var pm = Engine.get_main_loop().root.get_node_or_null("/root/PhysicsManager")
	if pm == null:
		# Skip test if autoload not available
		return ""

	if not pm.is_ready():
		return "PhysicsManager not ready"

	var version: int = pm.get_version()
	if version < 1:
		return "Invalid physics version: %d" % version

	return ""


func test_ball_creation() -> String:
	var pm = Engine.get_main_loop().root.get_node_or_null("/root/PhysicsManager")
	if pm == null:
		return ""

	pm.init()
	pm.clear_balls()

	var id1: int = pm.add_ball(10.0, 8.0, 0.125, 0.125)
	var id2: int = pm.add_ball(20.0, 12.0, -0.125, 0.125)

	if id1 != 0:
		return "First ball ID should be 0, got %d" % id1

	if id2 != 1:
		return "Second ball ID should be 1, got %d" % id2

	var count: int = pm.get_ball_count()
	if count != 2:
		return "Ball count should be 2, got %d" % count

	var state: Dictionary = pm.get_ball(0)
	if abs(state.get("x", 0) - 10.0) > 0.001:
		return "Ball 0 x position wrong: %f" % state.get("x", 0)

	return ""


func test_ball_movement() -> String:
	var pm = Engine.get_main_loop().root.get_node_or_null("/root/PhysicsManager")
	if pm == null:
		return ""

	pm.init()
	pm.clear_balls()

	# Ball moving right-down
	pm.add_ball(10.0, 10.0, 0.125, 0.125)

	# Get initial position
	var initial: Dictionary = pm.get_ball(0)
	var initial_x: float = initial.get("x", 0)
	var initial_y: float = initial.get("y", 0)

	# Tick physics (no collision expected)
	pm.tick()

	# Get new position
	var after: Dictionary = pm.get_ball(0)
	var after_x: float = after.get("x", 0)
	var after_y: float = after.get("y", 0)

	# Ball should have moved by velocity
	var expected_x: float = initial_x + 0.125
	var expected_y: float = initial_y + 0.125

	if abs(after_x - expected_x) > 0.001:
		return "Ball x position wrong: expected %f, got %f" % [expected_x, after_x]

	if abs(after_y - expected_y) > 0.001:
		return "Ball y position wrong: expected %f, got %f" % [expected_y, after_y]

	return ""


func test_tile_collision() -> String:
	var pm = Engine.get_main_loop().root.get_node_or_null("/root/PhysicsManager")
	if pm == null:
		return ""

	pm.init()
	pm.clear_balls()

	# Ball moving left into border (x=0 is BORDER)
	pm.add_ball(1.5, 10.0, -0.125, 0.125)

	# Tick until collision should occur
	for i in range(20):
		pm.tick()

	# Get final state
	var state: Dictionary = pm.get_ball(0)
	var vx: float = state.get("vx", 0)

	# Velocity should have reversed (positive) after hitting left border
	if vx < 0:
		return "Ball should have reflected off left border, vx=%f" % vx

	return ""


func test_wall_collision_sync() -> String:
	var pm = Engine.get_main_loop().root.get_node_or_null("/root/PhysicsManager")
	if pm == null:
		return ""

	pm.init()
	pm.clear_balls()

	# Ball at center
	var id: int = pm.add_ball(15.0, 10.0, 0.125, 0.0)

	# Apply a collision (simulating wall hit)
	pm.apply_ball_collision(id, Vector2(-1, 0))  # Hit from right

	# The ball's reflect flag should be set, but won't be applied until tick
	var before: Dictionary = pm.get_ball(0)
	var before_vx: float = before.get("vx", 0)

	# Tick to apply collision
	pm.tick()

	# Get state after
	var after: Dictionary = pm.get_ball(0)
	var after_vx: float = after.get("vx", 0)

	# Velocity should have reversed
	if before_vx > 0 and after_vx > 0:
		return "Ball should have reflected after applying collision"

	return ""
