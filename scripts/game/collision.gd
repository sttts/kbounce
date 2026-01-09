# collision.gd - Collision data structures
#
# SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

class_name Collision
extends RefCounted

## Collision object types
enum Type {
	TILE = 1,
	BALL = 2,
	WALL = 4,
	ALL = 0xFF
}

## Represents a single collision hit
class Hit:
	## Type of the object that was hit
	var type: int = Type.TILE
	## Bounding rectangle of the hitter
	var bounding_rect: Rect2 = Rect2()
	## Velocity of the hitter (for ball/wall collisions)
	var velocity: Vector2 = Vector2.ZERO
	## Normal vector perpendicular to collision surface
	var normal: Vector2 = Vector2.ZERO
	## Reference to the source object (for wall-to-wall collisions)
	var source: Node = null

	func _init(t: int = Type.TILE, rect: Rect2 = Rect2(),
			   vel: Vector2 = Vector2.ZERO, norm: Vector2 = Vector2.ZERO):
		type = t
		bounding_rect = rect
		velocity = vel
		normal = norm


## Calculate normal vector for collision response
##
## Uses the 2014 KBounce approach: test each axis independently.
## - Would moving only X cause collision? -> reflect X
## - Would moving only Y cause collision? -> reflect Y
## - Only if neither, but diagonal would -> reflect both (corner)
##
## current_rect: object's current position (before movement)
## velocity: movement vector
## obstacle: the obstacle rectangle
static func calculate_normal_with_velocity(current_rect: Rect2, velocity: Vector2, obstacle: Rect2) -> Vector2:
	var normal := Vector2.ZERO

	# Test X-only movement
	var rect_x := Rect2(current_rect.position + Vector2(velocity.x, 0), current_rect.size)
	var collide_x := rect_x.intersects(obstacle)

	# Test Y-only movement
	var rect_y := Rect2(current_rect.position + Vector2(0, velocity.y), current_rect.size)
	var collide_y := rect_y.intersects(obstacle)

	if collide_x:
		# Hit vertical edge - normal points opposite to velocity
		if velocity.x < 0:
			normal.x = 1.0   # Moving left, normal points right
		elif velocity.x > 0:
			normal.x = -1.0  # Moving right, normal points left

	if collide_y:
		# Hit horizontal edge - normal points opposite to velocity
		if velocity.y < 0:
			normal.y = 1.0   # Moving up, normal points down
		elif velocity.y > 0:
			normal.y = -1.0  # Moving down, normal points up

	# Corner case: neither axis alone collides, but diagonal does
	if not collide_x and not collide_y:
		var rect_xy := Rect2(current_rect.position + velocity, current_rect.size)
		if rect_xy.intersects(obstacle):
			if velocity.x < 0:
				normal.x = 1.0
			elif velocity.x > 0:
				normal.x = -1.0
			if velocity.y < 0:
				normal.y = 1.0
			elif velocity.y > 0:
				normal.y = -1.0

	return normal


## Legacy function for compatibility - uses intersection geometry
static func calculate_normal(rect1: Rect2, rect2: Rect2) -> Vector2:
	var normal := Vector2.ZERO
	var intersection := rect1.intersection(rect2)
	if intersection.size == Vector2.ZERO:
		return normal

	var center2 := rect2.get_center()
	var int_center := intersection.get_center()

	if int_center.x < center2.x:
		normal.x = -1.0
	elif int_center.x > center2.x:
		normal.x = 1.0
	if int_center.y < center2.y:
		normal.y = -1.0
	elif int_center.y > center2.y:
		normal.y = 1.0

	return normal
