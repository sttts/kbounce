# physics_manager.gd - QuickJS-based physics engine wrapper
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Physics version from JS engine
var version: int = 0

## QuickJS instance
var _js: QuickJS

## Whether physics engine is ready
var _initialized: bool = false


func _ready():
	_init_physics()


func _init_physics():
	_js = QuickJS.new()

	# Load physics.js
	var path := "res://scripts/physics.js"
	if not _js.load_file(path):
		push_error("PhysicsManager: Failed to load physics.js: " + _js.get_error())
		return

	# Initialize the physics engine
	var result = _js.eval("init()")
	if result == null:
		push_error("PhysicsManager: Failed to init physics: " + _js.get_error())
		return

	version = int(result)
	_initialized = true
	print("PhysicsManager: Initialized with physics version %d" % version)


## Check if physics is ready
func is_initialized() -> bool:
	return _initialized


## Alias for is_initialized
func is_ready() -> bool:
	return _initialized


## Re-initialize physics state (call at level start)
func init():
	if not _initialized:
		return
	_js.eval("init()")


## Get physics version
func get_version() -> int:
	return version


## Clear all balls
func clear_balls():
	if not _initialized:
		return
	_js.eval("clearBalls()")


## Add a ball and return its ID
func add_ball(x: float, y: float, vx: float, vy: float) -> int:
	if not _initialized:
		return -1
	var result = _js.eval("addBall(%f, %f, %f, %f)" % [x, y, vx, vy])
	return int(result) if result != null else -1


## Set a tile type
func set_tile(x: int, y: int, type: int):
	if not _initialized:
		return
	_js.eval("setTile(%d, %d, %d)" % [x, y, type])


## Get a tile type
func get_tile(x: int, y: int) -> int:
	if not _initialized:
		return 2  # BORDER
	var result = _js.eval("getTile(%d, %d)" % [x, y])
	return int(result) if result != null else 2


## Set tiles in a rectangle
func set_tile_rect(x1: int, y1: int, x2: int, y2: int, type: int):
	if not _initialized:
		return
	_js.eval("setTileRect(%d, %d, %d, %d, %d)" % [x1, y1, x2, y2, type])


## Get ball state
func get_ball(id: int) -> Dictionary:
	if not _initialized:
		return {}
	var result = _js.eval("getBall(%d)" % id)
	if result == null or result is bool:
		return {}
	return result


## Get all balls state
func get_balls() -> Array:
	if not _initialized:
		return []
	var result = _js.eval("getBalls()")
	return result if result != null else []


## Get ball count
func get_ball_count() -> int:
	if not _initialized:
		return 0
	var result = _js.eval("getBallCount()")
	return int(result) if result != null else 0


## Clear all walls
func clear_walls():
	if not _initialized:
		return
	_js.eval("clearWalls()")


## Add a wall at position with direction and return its ID
## Direction: 0=UP, 1=DOWN, 2=LEFT, 3=RIGHT
func add_wall(start_x: int, start_y: int, direction: int) -> int:
	if not _initialized:
		return -1
	var result = _js.eval("addWall(%d, %d, %d)" % [start_x, start_y, direction])
	return int(result) if result != null else -1


## Get wall state
func get_wall(id: int) -> Dictionary:
	if not _initialized:
		return {}
	var result = _js.eval("getWall(%d)" % id)
	if result == null or result is bool:
		return {}
	return result


## Get all walls state
func get_walls() -> Array:
	if not _initialized:
		return []
	var result = _js.eval("getWalls()")
	return result if result != null else []


## Get wall count
func get_wall_count() -> int:
	if not _initialized:
		return 0
	var result = _js.eval("getWallCount()")
	return int(result) if result != null else 0


## Stop a wall (called when wall dies or finishes)
func wall_stop(wall_id: int):
	if not _initialized:
		return
	_js.eval("wallStop(%d)" % wall_id)


## Materialize a wall into tiles
## Returns bounds { x1, y1, x2, y2 } or empty dict on failure
func wall_materialize(wall_id: int, skip_start_tile: bool = false) -> Dictionary:
	if not _initialized:
		return {}
	var skip_str := "true" if skip_start_tile else "false"
	var result = _js.eval("wallMaterialize(%d, %s)" % [wall_id, skip_str])
	if result == null or result is bool:
		return {}
	return result


## Check if ball intersects a rect (for wall collision)
func ball_intersects_rect(ball_id: int, rx: float, ry: float, rw: float, rh: float) -> bool:
	if not _initialized:
		return false
	var result = _js.eval("rectIntersects(%d, %f, %f, %f, %f)" % [ball_id, rx, ry, rw, rh])
	return result == true


## Calculate collision normal between two rects
func calculate_normal(ax: float, ay: float, aw: float, ah: float,
					  bx: float, by: float, bw: float, bh: float) -> Vector2:
	if not _initialized:
		return Vector2.ZERO
	var result = _js.eval("calculateNormal(%f, %f, %f, %f, %f, %f, %f, %f)" % [
		ax, ay, aw, ah, bx, by, bw, bh])
	if result == null:
		return Vector2.ZERO
	return Vector2(result.get("x", 0), result.get("y", 0))


## Tick collision detection for a single ball
## Returns: { hit: bool, normal: Vector2 }
func tick_ball(ball_id: int) -> Dictionary:
	if not _initialized:
		return { "hit": false, "normal": Vector2.ZERO }
	var result = _js.eval("tickBall(%d)" % ball_id)
	if result == null:
		return { "hit": false, "normal": Vector2.ZERO }
	return {
		"hit": result.get("hit", false),
		"normal": Vector2(result.get("normalX", 0), result.get("normalY", 0))
	}


## Apply collision to ball
func apply_ball_collision(ball_id: int, normal: Vector2):
	if not _initialized:
		return
	_js.eval("applyBallCollision(%d, %f, %f)" % [ball_id, normal.x, normal.y])


## Move a single ball
func move_ball(ball_id: int):
	if not _initialized:
		return
	_js.eval("moveBall(%d)" % ball_id)


## Tick all physics - returns { balls: Array, walls: Array }
## balls: array of { hit: bool, normal: Vector2, hitWall: bool, wallId: int }
## walls: array of { wallId: int, event: String, ... }
func tick() -> Dictionary:
	if not _initialized:
		return { "balls": [], "walls": [] }
	var result = _js.eval("tick()")
	if result == null:
		return { "balls": [], "walls": [] }

	# Convert ball collision results
	var ball_collisions: Array = []
	var balls_result = result.get("balls", [])
	for r in balls_result:
		ball_collisions.append({
			"hit": r.get("hit", false),
			"normal": Vector2(r.get("normalX", 0), r.get("normalY", 0)),
			"hitWall": r.get("hitWall", false),
			"wallId": int(r.get("wallId", -1))
		})

	# Wall events are already in right format
	var wall_events: Array = result.get("walls", [])

	return { "balls": ball_collisions, "walls": wall_events }


## Simulate N ticks (for testing)
func simulate(ticks: int) -> Array:
	if not _initialized:
		return []
	var result = _js.eval("simulate(%d)" % ticks)
	return result if result != null else []
