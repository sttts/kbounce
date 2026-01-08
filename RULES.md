# Rules of KBounce

## Game/Level Length

1. The game will be over if:
   - your number of lives is zero, or
   - your time is over.
2. When at least 75% of the field is filled, a level is completed.

## Lives

3. A level is started with one life per ball on the field.
4. You lose a life if a ball hits the inner part of a building wall.

## Balls

5. Each level includes one more ball.
6. A ball is reflected by borders, filled walls, and building walls.

## Walls

7. Tap/click to build a wall. Swipe to change direction.
8. You can _always_ build _two_ wall halves concurrently. If one half is already finished, you can build another wall half.
9. A wall half is finished when its tip reaches a border or filled wall. Ball hitting the tip does nothing (tip is protected).
10. A wall half is removed if:
    - a ball hits the inner part (non-tip), or
    - two wall halves hit each other with their tips.

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

## Collision Detection

- Only the tip is checked for collision with borders/filled walls
- Tip still in starting tile: no collision check (overlap allowed at start)

## Wall-to-Wall Collision

1. My tip overlaps other wall's bounding rectangle: collision detected
2. Check if tip rectangles cover any same tile:
   - **YES** (tip-to-tip): Both walls removed, paired walls also removed
   - **NO** (tip-to-inner): Hitting wall materializes

## Starting Tile Fill

- First wall half to finish: skip starting tile (paired wall may still build)
- Second wall half to finish: fill starting tile

## Cannot Start Wall

- On non-free tile (border, filled wall)
- Inside another building wall's rectangle
