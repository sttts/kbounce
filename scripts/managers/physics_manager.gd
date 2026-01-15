# physics_manager.gd - Physics engine wrapper (QuickJS native, JavaScriptBridge on web)
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

extends Node

## Physics version from JS engine
var version: int = 0

## QuickJS instance (null on web, Variant to avoid parse error when QuickJS unavailable)
var _js: Variant = null

## Whether running on web platform
var _is_web: bool = false

## Whether physics engine is ready
var _initialized: bool = false


func _ready():
	_is_web = OS.get_name() == "Web"
	_init_physics()


func _init_physics():
	if _is_web:
		_init_physics_web()
	else:
		_init_physics_native()


func _init_physics_web():
	# Load physics.js into browser context
	var file := FileAccess.open("res://scripts/physics.js", FileAccess.READ)
	if not file:
		push_error("PhysicsManager: Failed to open physics.js")
		return
	var code := file.get_as_text()
	file.close()

	# Wrap CommonJS module for browser and expose as window.physics
	var wrapper := """
(function() {
	var module = { exports: {} };
	(function(module, exports) {
		%s
	})(module, module.exports);
	window.physics = module.exports;
})();
""" % code
	JavaScriptBridge.eval(wrapper)

	# Initialize the physics engine
	var result = JavaScriptBridge.eval("physics.init()")
	if result == null:
		push_error("PhysicsManager: Failed to init physics on web")
		return

	version = int(result)
	_initialized = true
	print("PhysicsManager: Initialized with physics version %d (web)" % version)


func _init_physics_native():
	# Use ClassDB to instantiate QuickJS to avoid parse errors on web
	_js = ClassDB.instantiate(&"QuickJS")

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


## Evaluate JS code (dispatches to web or native)
## For web, complex objects are JSON-serialized to work around JavaScriptObject limitations
func _eval(code: String) -> Variant:
	if _is_web:
		# Wrap in JSON.stringify for complex returns, parse in GDScript
		var json_str = JavaScriptBridge.eval("JSON.stringify(physics." + code + ")")
		if json_str == null:
			return null
		return JSON.parse_string(json_str)
	else:
		return _js.eval(code)


## Check if physics is ready
func is_ready() -> bool:
	return _initialized


## Re-initialize physics state (call at level start)
func init():
	if not _initialized:
		return
	_eval("init()")


## Get physics version
func get_version() -> int:
	return version


## Add a ball and return its ID
func add_ball(x: float, y: float, vx: float, vy: float) -> int:
	if not _initialized:
		return -1
	var result = _eval("addBall(%f, %f, %f, %f)" % [x, y, vx, vy])
	return int(result) if result != null else -1


## Get tiles (2D array [x][y]) - for rendering
func get_tiles() -> Array:
	if not _initialized:
		return []
	var result = _eval("getTiles()")
	return result if result != null else []


## Tick all physics with wall placement actions
## actions: array of { x, y, vertical } - wall placements for this tick
## Returns { tick, balls, collisions, wallEvents, newWalls, activeWalls, tilesChanged, levelComplete, fillPercent }
func tick(actions: Array = []) -> Dictionary:
	var empty_result := {
		"tick": 0, "balls": [], "collisions": [], "wallEvents": [], "newWalls": [],
		"activeWalls": [], "tilesChanged": false, "levelComplete": false, "fillPercent": 0
	}
	if not _initialized:
		return empty_result

	var actions_json := JSON.stringify(actions)
	var result = _eval("tick(%s)" % actions_json)
	if result == null:
		return empty_result

	# Convert collision results for sound effects
	var collisions: Array = []
	for r in result.get("collisions", []):
		collisions.append({
			"hit": r.get("hit", false),
			"normal": Vector2(r.get("normalX", 0), r.get("normalY", 0)),
			"hitWall": r.get("hitWall", false),
			"wallId": int(r.get("wallId", -1))
		})

	return {
		"tick": int(result.get("tick", 0)),
		"balls": result.get("balls", []),
		"collisions": collisions,
		"wallEvents": result.get("wallEvents", []),
		"newWalls": result.get("newWalls", []),
		"activeWalls": result.get("activeWalls", []),
		"tilesChanged": result.get("tilesChanged", false),
		"levelComplete": result.get("levelComplete", false),
		"fillPercent": int(result.get("fillPercent", 0))
	}


## Validate a level replay using the same physics code as the server
## Returns: { valid: bool, error?: string, tick?: int, ball?: int, expected?: {x, y}, actual?: {x, y} }
func validate_level(level_data: Dictionary) -> Dictionary:
	if not _initialized:
		return { "valid": false, "error": "Physics not initialized" }

	# Convert Dictionary to JSON string for JS
	var json_str := JSON.stringify(level_data)

	if _is_web:
		var result_str = JavaScriptBridge.eval("JSON.stringify(physics.validateLevel(%s))" % json_str)
		if result_str == null:
			return { "valid": false, "error": "Validation failed on web" }
		return JSON.parse_string(result_str)
	else:
		return _js.eval("validateLevel(%s)" % json_str)


