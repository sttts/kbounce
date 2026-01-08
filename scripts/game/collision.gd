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
## This is a simple function that generates a vector perpendicular to the
## surface of rect2 at the point where rect1 intersects it.
## Note: vectors may have different lengths (not normalized)
static func calculate_normal(rect1: Rect2, rect2: Rect2) -> Vector2:
	var normal := Vector2.ZERO

	# Calculate intersection
	var intersection := rect1.intersection(rect2)
	if intersection.size == Vector2.ZERO:
		return normal

	# Determine which edges are colliding based on intersection position
	# relative to the center of rect2
	var center2 := rect2.get_center()
	var int_center := intersection.get_center()

	# Horizontal component
	if int_center.x < center2.x:
		normal.x = -1.0  # Hit from left
	elif int_center.x > center2.x:
		normal.x = 1.0   # Hit from right

	# Vertical component
	if int_center.y < center2.y:
		normal.y = -1.0  # Hit from top
	elif int_center.y > center2.y:
		normal.y = 1.0   # Hit from bottom

	return normal
