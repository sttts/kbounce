# Rules of KBounce

## Game

1. Fill 75% of the field to advance.
2. Game over when lives reach zero or time runs out.

## Lives

3. Start with one life per ball.
4. Lose a life if a ball hits the inner part of a building wall.

## Balls

5. Each level adds one more ball.
6. Balls reflect off borders, filled walls, and building walls.

## Walls

7. Tap/click to build a wall. Swipe to change direction.
8. Two wall halves can build at once.
9. A wall half finishes when its tip reaches a border, filled wall, or another building wall.
10. Ball hitting the tip finishes the wall shortened.
11. A wall half is removed if a ball hits the inner part (non-tip).

---

# Implementation Details

## Wall Slots

- Two wall slots: Slot 1 (UP/LEFT), Slot 2 (DOWN/RIGHT)
- Each slot holds at most one building wall half

## Tip Definition

- UP wall: tip at top (lowest y)
- DOWN wall: tip at bottom (highest y)
- LEFT wall: tip at left (lowest x)
- RIGHT wall: tip at right (highest x)

## Wall vs Border/Filled Collision

- Only the tip is checked for collision with borders/filled walls
- Tip still in starting tile: no collision check (overlap allowed at start)

## Ball vs Wall Collision

- Ball hits inner area: wall dies, ball reflects
- Ball hits tip area: wall finishes shortened, ball reflects
- Tip hit only counts if collision normal matches wall orientation

## Wall-to-Wall Collision

- If my tip overlaps another wall's bounding rectangle: I finish (materialize)
- Paired walls skip collision check with each other

## Starting Tile Fill

- First wall half to finish: skip starting tile (paired wall may still build)
- Second wall half to finish: fill starting tile

## Cannot Start Wall

- On non-free tile (border, filled wall)
- Inside another building wall's rectangle
