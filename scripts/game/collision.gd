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
