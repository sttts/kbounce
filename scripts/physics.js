// physics.js - KBounce deterministic physics engine
// Version: 2 (increment when physics behavior changes)
//
// SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

const VERSION = 2;

const BOARD_W = 32, BOARD_H = 20;
const BALL_SIZE = 0.8;
const D = 0.01;  // Epsilon for corner detection
const CORNER_EPSILON = 0.5;  // Threshold for corner vs edge hit

// Tile types (match board.gd TileType enum)
const FREE = 1, BORDER = 2, WALL = 3;

// Wall directions (match wall.gd Direction enum)
const DIR_UP = 0, DIR_DOWN = 1, DIR_LEFT = 2, DIR_RIGHT = 3;

// Wall velocity (tiles per tick)
const WALL_VELOCITY = 0.125;

// Spatial grid for O(n) ball-ball collision
const GRID_CELL_SIZE = 4;  // Tiles per cell
const GRID_W = Math.ceil(BOARD_W / GRID_CELL_SIZE);  // 8 cells
const GRID_H = Math.ceil(BOARD_H / GRID_CELL_SIZE);  // 5 cells

// Game state
let tiles = [];
let balls = [];
let walls = [];  // Array of wall objects
let ballGrid = [];  // 2D array of ball index lists

// Initialize the physics engine
function init() {
  tiles = [];
  balls = [];
  walls = [];
  for (let x = 0; x < BOARD_W; x++) {
    tiles[x] = [];
    for (let y = 0; y < BOARD_H; y++) {
      if (x === 0 || x === BOARD_W - 1 || y === 0 || y === BOARD_H - 1) {
        tiles[x][y] = BORDER;
      } else {
        tiles[x][y] = FREE;
      }
    }
  }
  return VERSION;
}

// Get current version
function getVersion() {
  return VERSION;
}

// Clear all balls
function clearBalls() {
  balls = [];
}

// Add a ball with position and velocity
function addBall(x, y, vx, vy) {
  const id = balls.length;
  balls.push({
    id: id,
    x: x,
    y: y,
    vx: vx,
    vy: vy,
    reflectX: false,
    reflectY: false
  });
  return id;
}

// Set a tile type
function setTile(x, y, type) {
  if (x >= 0 && x < BOARD_W && y >= 0 && y < BOARD_H) {
    tiles[x][y] = type;
  }
}

// Get a tile type
function getTile(x, y) {
  if (x >= 0 && x < BOARD_W && y >= 0 && y < BOARD_H) {
    return tiles[x][y];
  }
  return BORDER;
}

// Set tiles in a rectangle
function setTileRect(x1, y1, x2, y2, type) {
  for (let x = x1; x < x2; x++) {
    for (let y = y1; y < y2; y++) {
      setTile(x, y, type);
    }
  }
}

// Get ball state
function getBall(id) {
  if (id >= 0 && id < balls.length) {
    const b = balls[id];
    return { x: b.x, y: b.y, vx: b.vx, vy: b.vy };
  }
  return null;
}

// Get all balls state
function getBalls() {
  return balls.map(b => ({ id: b.id, x: b.x, y: b.y, vx: b.vx, vy: b.vy }));
}

// Get ball count
function getBallCount() {
  return balls.length;
}

// Clear all walls
function clearWalls() {
  walls = [];
}

// Add a wall at position with direction
// Returns wall ID
function addWall(startX, startY, direction) {
  const id = walls.length;
  walls.push({
    id: id,
    startX: startX,
    startY: startY,
    direction: direction,
    building: true,
    // Bounding rect: x, y, w, h (starts as 1x1 tile)
    x: startX,
    y: startY,
    w: 1,
    h: 1
  });
  return id;
}

// Get wall state
function getWall(id) {
  if (id >= 0 && id < walls.length) {
    const w = walls[id];
    return {
      id: w.id,
      startX: w.startX,
      startY: w.startY,
      direction: w.direction,
      building: w.building,
      x: w.x, y: w.y, w: w.w, h: w.h
    };
  }
  return null;
}

// Get all walls state
function getWalls() {
  return walls.map(w => ({
    id: w.id,
    startX: w.startX,
    startY: w.startY,
    direction: w.direction,
    building: w.building,
    x: w.x, y: w.y, w: w.w, h: w.h
  }));
}

// Get wall count
function getWallCount() {
  return walls.length;
}

// Get wall's next bounding rect (after growth)
function wallNextRect(wall) {
  let nx = wall.x, ny = wall.y, nw = wall.w, nh = wall.h;
  switch (wall.direction) {
    case DIR_UP:
      ny -= WALL_VELOCITY;
      nh += WALL_VELOCITY;
      break;
    case DIR_DOWN:
      nh += WALL_VELOCITY;
      break;
    case DIR_LEFT:
      nx -= WALL_VELOCITY;
      nw += WALL_VELOCITY;
      break;
    case DIR_RIGHT:
      nw += WALL_VELOCITY;
      break;
  }
  return { x: nx, y: ny, w: nw, h: nh };
}

// Get wall's inner rect (excludes tip tile, for ball collision)
function wallInnerRect(wall) {
  let ix = wall.x, iy = wall.y, iw = wall.w, ih = wall.h;
  switch (wall.direction) {
    case DIR_UP:
      if (ih > 1.0) { iy += 1.0; ih -= 1.0; }
      else { return null; }
      break;
    case DIR_DOWN:
      if (ih > 1.0) { ih -= 1.0; }
      else { return null; }
      break;
    case DIR_LEFT:
      if (iw > 1.0) { ix += 1.0; iw -= 1.0; }
      else { return null; }
      break;
    case DIR_RIGHT:
      if (iw > 1.0) { iw -= 1.0; }
      else { return null; }
      break;
  }
  return { x: ix, y: iy, w: iw, h: ih };
}

// Get wall's tip tile coordinates
function wallTipTile(wall) {
  const rect = wallNextRect(wall);
  switch (wall.direction) {
    case DIR_UP:
      return { x: Math.floor(rect.x), y: Math.floor(rect.y) };
    case DIR_DOWN:
      return { x: Math.floor(rect.x), y: Math.floor(rect.y + rect.h - 0.01) };
    case DIR_LEFT:
      return { x: Math.floor(rect.x), y: Math.floor(rect.y) };
    case DIR_RIGHT:
      return { x: Math.floor(rect.x + rect.w - 0.01), y: Math.floor(rect.y) };
  }
  return { x: -1, y: -1 };
}

// Get wall's tip rect (small strip at leading edge)
function wallTipRect(wall) {
  const rect = wallNextRect(wall);
  const TIP_SIZE = 0.1;
  switch (wall.direction) {
    case DIR_UP:
      return { x: rect.x, y: rect.y, w: rect.w, h: TIP_SIZE };
    case DIR_DOWN:
      return { x: rect.x, y: rect.y + rect.h - TIP_SIZE, w: rect.w, h: TIP_SIZE };
    case DIR_LEFT:
      return { x: rect.x, y: rect.y, w: TIP_SIZE, h: rect.h };
    case DIR_RIGHT:
      return { x: rect.x + rect.w - TIP_SIZE, y: rect.y, w: TIP_SIZE, h: rect.h };
  }
  return rect;
}

// Check if two walls are paired (same start, opposite directions)
function arePairedWalls(w1, w2) {
  if (w1.startX !== w2.startX || w1.startY !== w2.startY) return false;
  const d1 = w1.direction, d2 = w2.direction;
  return (d1 === DIR_UP && d2 === DIR_DOWN) ||
         (d1 === DIR_DOWN && d2 === DIR_UP) ||
         (d1 === DIR_LEFT && d2 === DIR_RIGHT) ||
         (d1 === DIR_RIGHT && d2 === DIR_LEFT);
}

// Check if two rects share any tile
function rectsShareTile(r1, r2) {
  const r1x1 = Math.floor(r1.x), r1y1 = Math.floor(r1.y);
  const r1x2 = Math.ceil(r1.x + r1.w - 0.001), r1y2 = Math.ceil(r1.y + r1.h - 0.001);
  const r2x1 = Math.floor(r2.x), r2y1 = Math.floor(r2.y);
  const r2x2 = Math.ceil(r2.x + r2.w - 0.001), r2y2 = Math.ceil(r2.y + r2.h - 0.001);
  return r1x1 <= r2x2 && r2x1 <= r1x2 && r1y1 <= r2y2 && r2y1 <= r1y2;
}

// Check if two rects intersect
function rectsIntersect(r1, r2) {
  return !(r1.x + r1.w <= r2.x || r1.x >= r2.x + r2.w ||
           r1.y + r1.h <= r2.y || r1.y >= r2.y + r2.h);
}

// Extend wall by one tick
function wallGoForward(wallId) {
  if (wallId < 0 || wallId >= walls.length) return;
  const wall = walls[wallId];
  if (!wall.building) return;

  switch (wall.direction) {
    case DIR_UP:
      wall.y -= WALL_VELOCITY;
      wall.h += WALL_VELOCITY;
      break;
    case DIR_DOWN:
      wall.h += WALL_VELOCITY;
      break;
    case DIR_LEFT:
      wall.x -= WALL_VELOCITY;
      wall.w += WALL_VELOCITY;
      break;
    case DIR_RIGHT:
      wall.w += WALL_VELOCITY;
      break;
  }
}

// Stop wall (die or finish)
function wallStop(wallId) {
  if (wallId < 0 || wallId >= walls.length) return;
  walls[wallId].building = false;
}

// Check wall vs tile collision (tip only)
// Returns: { hit: bool, materialize: bool }
function checkWallTileCollision(wallId) {
  if (wallId < 0 || wallId >= walls.length) return { hit: false };
  const wall = walls[wallId];
  if (!wall.building) return { hit: false };

  const tipTile = wallTipTile(wall);
  const startTile = { x: wall.startX, y: wall.startY };

  // Skip if tip is still in start tile
  if (tipTile.x === startTile.x && tipTile.y === startTile.y) {
    return { hit: false };
  }

  if (tipTile.x >= 0 && tipTile.x < BOARD_W && tipTile.y >= 0 && tipTile.y < BOARD_H) {
    if (tiles[tipTile.x][tipTile.y] !== FREE) {
      return { hit: true, materialize: true };
    }
  }

  return { hit: false };
}

// Check wall vs wall collision
// Returns: { hit: bool, otherWallId: int, bothDie: bool }
function checkWallWallCollision(wallId) {
  if (wallId < 0 || wallId >= walls.length) return { hit: false };
  const wall = walls[wallId];
  if (!wall.building) return { hit: false };

  const myTipTile = wallTipTile(wall);
  const myTipRect = wallTipRect(wall);
  const myNextRect = wallNextRect(wall);

  // Skip if tip is still in start tile
  if (myTipTile.x === wall.startX && myTipTile.y === wall.startY) {
    return { hit: false };
  }

  for (let i = 0; i < walls.length; i++) {
    if (i === wallId) continue;
    const other = walls[i];
    if (!other.building) continue;

    // Skip paired walls
    if (arePairedWalls(wall, other)) continue;

    const otherNextRect = { x: other.x, y: other.y, w: other.w, h: other.h };

    // Check if my tip intersects other wall
    if (rectsIntersect(myTipRect, otherNextRect)) {
      const otherTipRect = wallTipRect(other);

      // If tips share a tile, both walls die
      if (rectsShareTile(myTipRect, otherTipRect)) {
        return { hit: true, otherWallId: i, bothDie: true };
      } else {
        // My tip hits other wall's body - I materialize
        return { hit: true, otherWallId: i, bothDie: false };
      }
    }
  }

  return { hit: false };
}

// Check ball vs wall collision
// Returns: { hit: bool, wallId: int, normal: {x, y}, killsWall: bool }
function checkBallWallCollision(ballId) {
  if (ballId < 0 || ballId >= balls.length) return { hit: false };
  const ball = balls[ballId];

  const ballNextRect = {
    x: ball.x + ball.vx,
    y: ball.y + ball.vy,
    w: BALL_SIZE,
    h: BALL_SIZE
  };

  for (let i = 0; i < walls.length; i++) {
    const wall = walls[i];
    if (!wall.building) continue;

    const wallRect = { x: wall.x, y: wall.y, w: wall.w, h: wall.h };

    if (rectsIntersect(ballNextRect, wallRect)) {
      // Calculate collision normal
      const normal = calculateNormal(
        ballNextRect.x, ballNextRect.y, ballNextRect.w, ballNextRect.h,
        wallRect.x, wallRect.y, wallRect.w, wallRect.h
      );

      // Check if ball hits inner rect (kills wall) or just tip (reflects only)
      const innerRect = wallInnerRect(wall);
      const killsWall = innerRect && rectsIntersect(ballNextRect, innerRect);

      return { hit: true, wallId: i, normal: normal, killsWall: killsWall };
    }
  }

  return { hit: false };
}

// Materialize wall into tiles (when finished)
// Returns tile bounds: { x1, y1, x2, y2 }
function wallMaterialize(wallId, skipStartTile = false) {
  if (wallId < 0 || wallId >= walls.length) return null;
  const wall = walls[wallId];

  const x1 = Math.floor(wall.x);
  const y1 = Math.floor(wall.y);
  const x2 = Math.ceil(wall.x + wall.w);
  const y2 = Math.ceil(wall.y + wall.h);

  for (let x = x1; x < x2; x++) {
    for (let y = y1; y < y2; y++) {
      if (x >= 0 && x < BOARD_W && y >= 0 && y < BOARD_H) {
        // Skip start tile if paired wall still building
        if (skipStartTile && x === wall.startX && y === wall.startY) continue;
        tiles[x][y] = WALL;
      }
    }
  }

  return { x1, y1, x2, y2 };
}

// Port of _get_crossing_normal from board.gd
function getCrossingNormal(currX, currY, nextX, nextY, nextTileX, nextTileY, nx, ny) {
  const tileEdgeX = nx < 0 ? nextTileX : nextTileX + 1;
  const tileEdgeY = ny < 0 ? nextTileY : nextTileY + 1;

  const penetrationX = Math.abs(nextX - tileEdgeX);
  const penetrationY = Math.abs(nextY - tileEdgeY);

  let penetrationRatio = penetrationY > 0.001 ? penetrationX / penetrationY : 999.0;
  if (penetrationRatio < 0.001) {
    penetrationRatio = 1.0 / 999.0;
  }

  const isCorner = penetrationRatio > (1.0 / (1.0 + CORNER_EPSILON)) &&
                   penetrationRatio < (1.0 + CORNER_EPSILON);

  if (isCorner) {
    return { x: nx, y: ny };
  } else if (penetrationX < penetrationY) {
    return { x: nx, y: 0 };
  } else {
    return { x: 0, y: ny };
  }
}

// Check ball collision against tiles
function checkBallCollisionTiles(ball) {
  const currRect = { x: ball.x, y: ball.y, w: BALL_SIZE, h: BALL_SIZE };
  const nextRect = {
    x: ball.x + ball.vx,
    y: ball.y + ball.vy,
    w: BALL_SIZE,
    h: BALL_SIZE
  };

  let normalX = 0, normalY = 0;
  const cornersHit = { ul: false, ur: false, ll: false, lr: false };

  // Upper-left corner
  const ulCurrX = currRect.x + D, ulCurrY = currRect.y + D;
  const ulNextX = nextRect.x + D, ulNextY = nextRect.y + D;
  const ulTileX = Math.floor(ulNextX), ulTileY = Math.floor(ulNextY);
  if (ulTileX >= 0 && ulTileX < BOARD_W && ulTileY >= 0 && ulTileY < BOARD_H) {
    if (tiles[ulTileX][ulTileY] !== FREE) {
      const n = getCrossingNormal(ulCurrX, ulCurrY, ulNextX, ulNextY, ulTileX, ulTileY, 1, 1);
      normalX += n.x;
      normalY += n.y;
      cornersHit.ul = true;
    }
  }

  // Upper-right corner
  const urCurrX = currRect.x + currRect.w - D, urCurrY = currRect.y + D;
  const urNextX = nextRect.x + nextRect.w - D, urNextY = nextRect.y + D;
  const urTileX = Math.floor(urNextX), urTileY = Math.floor(urNextY);
  if (urTileX >= 0 && urTileX < BOARD_W && urTileY >= 0 && urTileY < BOARD_H) {
    if (tiles[urTileX][urTileY] !== FREE) {
      const n = getCrossingNormal(urCurrX, urCurrY, urNextX, urNextY, urTileX, urTileY, -1, 1);
      normalX += n.x;
      normalY += n.y;
      cornersHit.ur = true;
    }
  }

  // Lower-right corner
  const lrCurrX = currRect.x + currRect.w - D, lrCurrY = currRect.y + currRect.h - D;
  const lrNextX = nextRect.x + nextRect.w - D, lrNextY = nextRect.y + nextRect.h - D;
  const lrTileX = Math.floor(lrNextX), lrTileY = Math.floor(lrNextY);
  if (lrTileX >= 0 && lrTileX < BOARD_W && lrTileY >= 0 && lrTileY < BOARD_H) {
    if (tiles[lrTileX][lrTileY] !== FREE) {
      const n = getCrossingNormal(lrCurrX, lrCurrY, lrNextX, lrNextY, lrTileX, lrTileY, -1, -1);
      normalX += n.x;
      normalY += n.y;
      cornersHit.lr = true;
    }
  }

  // Lower-left corner
  const llCurrX = currRect.x + D, llCurrY = currRect.y + currRect.h - D;
  const llNextX = nextRect.x + D, llNextY = nextRect.y + nextRect.h - D;
  const llTileX = Math.floor(llNextX), llTileY = Math.floor(llNextY);
  if (llTileX >= 0 && llTileX < BOARD_W && llTileY >= 0 && llTileY < BOARD_H) {
    if (tiles[llTileX][llTileY] !== FREE) {
      const n = getCrossingNormal(llCurrX, llCurrY, llNextX, llNextY, llTileX, llTileY, 1, -1);
      normalX += n.x;
      normalY += n.y;
      cornersHit.ll = true;
    }
  }

  // Adjust normal based on corner hit patterns
  if ((cornersHit.ul && cornersHit.ur) && !(cornersHit.ll || cornersHit.lr)) {
    normalX = 0; normalY = 2;
  } else if ((cornersHit.ll && cornersHit.lr) && !(cornersHit.ul || cornersHit.ur)) {
    normalX = 0; normalY = -2;
  } else if ((cornersHit.ul && cornersHit.ll) && !(cornersHit.ur || cornersHit.lr)) {
    normalX = 2; normalY = 0;
  } else if ((cornersHit.ur && cornersHit.lr) && !(cornersHit.ul || cornersHit.ll)) {
    normalX = -2; normalY = 0;
  }

  return {
    hit: cornersHit.ul || cornersHit.ur || cornersHit.ll || cornersHit.lr,
    normalX: normalX,
    normalY: normalY
  };
}

// Check if ball rect intersects with a rect (for wall collision)
function rectIntersects(ballId, rx, ry, rw, rh) {
  if (ballId < 0 || ballId >= balls.length) return false;
  const b = balls[ballId];
  const nextX = b.x + b.vx;
  const nextY = b.y + b.vy;
  return !(nextX + BALL_SIZE <= rx || nextX >= rx + rw ||
           nextY + BALL_SIZE <= ry || nextY >= ry + rh);
}

// Calculate collision normal between two rects
function calculateNormal(ax, ay, aw, ah, bx, by, bw, bh) {
  const aCenterX = ax + aw / 2;
  const aCenterY = ay + ah / 2;
  const bCenterX = bx + bw / 2;
  const bCenterY = by + bh / 2;

  const dx = bCenterX - aCenterX;
  const dy = bCenterY - aCenterY;

  const overlapX = (aw + bw) / 2 - Math.abs(dx);
  const overlapY = (ah + bh) / 2 - Math.abs(dy);

  if (overlapX < overlapY) {
    return { x: dx > 0 ? -1 : 1, y: 0 };
  } else {
    return { x: 0, y: dy > 0 ? -1 : 1 };
  }
}

// Build spatial grid for ball-ball collision optimization
function buildBallGrid() {
  // Clear grid
  ballGrid = [];
  for (let x = 0; x < GRID_W; x++) {
    ballGrid[x] = [];
    for (let y = 0; y < GRID_H; y++) {
      ballGrid[x][y] = [];
    }
  }

  // Add balls to grid cells based on next position
  for (let i = 0; i < balls.length; i++) {
    const ball = balls[i];
    const nextX = ball.x + ball.vx;
    const nextY = ball.y + ball.vy;

    // Get cell range (ball may span multiple cells)
    let cx1 = Math.floor(nextX / GRID_CELL_SIZE);
    let cy1 = Math.floor(nextY / GRID_CELL_SIZE);
    let cx2 = Math.floor((nextX + BALL_SIZE) / GRID_CELL_SIZE);
    let cy2 = Math.floor((nextY + BALL_SIZE) / GRID_CELL_SIZE);

    // Clamp to grid bounds
    cx1 = Math.max(0, Math.min(cx1, GRID_W - 1));
    cx2 = Math.max(0, Math.min(cx2, GRID_W - 1));
    cy1 = Math.max(0, Math.min(cy1, GRID_H - 1));
    cy2 = Math.max(0, Math.min(cy2, GRID_H - 1));

    // Add ball to all cells it overlaps
    for (let cx = cx1; cx <= cx2; cx++) {
      for (let cy = cy1; cy <= cy2; cy++) {
        ballGrid[cx][cy].push(i);
      }
    }
  }
}

// Check ball vs ball collisions using spatial grid (O(n) for typical distributions)
// Returns array of collision pairs: [{ ball1: id, ball2: id, normal: {x, y} }, ...]
function checkBallBallCollisions() {
  buildBallGrid();

  const collisions = [];
  const checked = new Set();  // Track checked pairs to avoid duplicates

  for (let i = 0; i < balls.length; i++) {
    const a = balls[i];
    const aNextX = a.x + a.vx;
    const aNextY = a.y + a.vy;

    // Get cells this ball occupies (include adjacent for safety)
    let cx1 = Math.floor(aNextX / GRID_CELL_SIZE) - 1;
    let cy1 = Math.floor(aNextY / GRID_CELL_SIZE) - 1;
    let cx2 = Math.floor((aNextX + BALL_SIZE) / GRID_CELL_SIZE) + 1;
    let cy2 = Math.floor((aNextY + BALL_SIZE) / GRID_CELL_SIZE) + 1;

    cx1 = Math.max(0, Math.min(cx1, GRID_W - 1));
    cx2 = Math.max(0, Math.min(cx2, GRID_W - 1));
    cy1 = Math.max(0, Math.min(cy1, GRID_H - 1));
    cy2 = Math.max(0, Math.min(cy2, GRID_H - 1));

    // Check against balls in nearby cells
    for (let cx = cx1; cx <= cx2; cx++) {
      for (let cy = cy1; cy <= cy2; cy++) {
        for (const j of ballGrid[cx][cy]) {
          if (j <= i) continue;  // Only check each pair once (j > i)

          const pairKey = i * 1000 + j;
          if (checked.has(pairKey)) continue;
          checked.add(pairKey);

          const b = balls[j];
          const bNextX = b.x + b.vx;
          const bNextY = b.y + b.vy;

          // Check if next positions intersect
          if (rectsIntersect(
            { x: aNextX, y: aNextY, w: BALL_SIZE, h: BALL_SIZE },
            { x: bNextX, y: bNextY, w: BALL_SIZE, h: BALL_SIZE }
          )) {
            const normal = calculateNormal(
              aNextX, aNextY, BALL_SIZE, BALL_SIZE,
              bNextX, bNextY, BALL_SIZE, BALL_SIZE
            );
            collisions.push({ ball1: i, ball2: j, normal: normal });
          }
        }
      }
    }
  }

  return collisions;
}

// Apply collision to ball (set reflect flags)
function applyBallCollision(ballId, normalX, normalY) {
  if (ballId < 0 || ballId >= balls.length) return;
  const ball = balls[ballId];

  ball.reflectX = false;
  ball.reflectY = false;

  if (normalX > 0) {
    ball.reflectX = ball.reflectX || ball.vx < 0;
  } else if (normalX < 0) {
    ball.reflectX = ball.reflectX || ball.vx > 0;
  }

  if (normalY > 0) {
    ball.reflectY = ball.reflectY || ball.vy < 0;
  } else if (normalY < 0) {
    ball.reflectY = ball.reflectY || ball.vy > 0;
  }
}

// Move ball (apply reflections and velocity)
function moveBall(ballId) {
  if (ballId < 0 || ballId >= balls.length) return;
  const ball = balls[ballId];

  if (ball.reflectX) ball.vx *= -1;
  if (ball.reflectY) ball.vy *= -1;
  ball.x += ball.vx;
  ball.y += ball.vy;
  ball.reflectX = false;
  ball.reflectY = false;
}

// Single tick for one ball - returns collision info
// Returns: { hit: bool, normalX: float, normalY: float }
function tickBall(ballId) {
  if (ballId < 0 || ballId >= balls.length) {
    return { hit: false, normalX: 0, normalY: 0 };
  }
  return checkBallCollisionTiles(balls[ballId]);
}

// Tick all balls (collision check phase only)
// Returns array of collision results per ball
function tickCollisions() {
  const results = [];
  for (let i = 0; i < balls.length; i++) {
    results.push(checkBallCollisionTiles(balls[i]));
  }
  return results;
}

// Move all balls (movement phase)
function tickMovement() {
  for (let i = 0; i < balls.length; i++) {
    moveBall(i);
  }
}

// Tick walls: check collisions and grow
// Returns array of wall events: { wallId, event: 'die'|'finish'|'wall_collision', ... }
function tickWalls() {
  const events = [];

  // Check wall collisions first (before growth)
  for (let i = 0; i < walls.length; i++) {
    const wall = walls[i];
    if (!wall.building) continue;

    // Check wall vs tile collision
    const tileResult = checkWallTileCollision(i);
    if (tileResult.hit) {
      // Find paired wall
      let pairedBuilding = false;
      for (let j = 0; j < walls.length; j++) {
        if (j !== i && walls[j].building && arePairedWalls(wall, walls[j])) {
          pairedBuilding = true;
          break;
        }
      }

      const bounds = wallMaterialize(i, pairedBuilding);
      wallStop(i);
      events.push({ wallId: i, event: 'finish', bounds: bounds });
      continue;
    }

    // Check wall vs wall collision
    const wallResult = checkWallWallCollision(i);
    if (wallResult.hit) {
      if (wallResult.bothDie) {
        // Both walls die - find and kill paired walls too
        wallStop(i);
        wallStop(wallResult.otherWallId);

        // Kill paired walls
        for (let j = 0; j < walls.length; j++) {
          if (walls[j].building) {
            if (arePairedWalls(wall, walls[j])) wallStop(j);
            if (arePairedWalls(walls[wallResult.otherWallId], walls[j])) wallStop(j);
          }
        }

        events.push({ wallId: i, event: 'wall_collision', otherWallId: wallResult.otherWallId });
      } else {
        // I materialize (hit other wall's body)
        let pairedBuilding = false;
        for (let j = 0; j < walls.length; j++) {
          if (j !== i && walls[j].building && arePairedWalls(wall, walls[j])) {
            pairedBuilding = true;
            break;
          }
        }

        const bounds = wallMaterialize(i, pairedBuilding);
        wallStop(i);
        events.push({ wallId: i, event: 'finish', bounds: bounds });
      }
      continue;
    }
  }

  // Grow walls that are still building
  for (let i = 0; i < walls.length; i++) {
    if (walls[i].building) {
      wallGoForward(i);
    }
  }

  return events;
}

// Full tick: check collisions, apply, and move
// Returns { balls: array of ball collision info, walls: array of wall events }
function tick() {
  const ballCollisions = [];
  const wallEvents = [];

  // Check ball vs wall collisions first
  for (let i = 0; i < balls.length; i++) {
    const wallResult = checkBallWallCollision(i);
    if (wallResult.hit) {
      // Apply reflection
      applyBallCollision(i, wallResult.normal.x, wallResult.normal.y);
      ballCollisions.push({
        hit: true,
        normalX: wallResult.normal.x,
        normalY: wallResult.normal.y,
        hitWall: true,
        wallId: wallResult.wallId
      });

      // Kill wall if hit inner area
      if (wallResult.killsWall) {
        wallStop(wallResult.wallId);
        wallEvents.push({ wallId: wallResult.wallId, event: 'die', ballId: i });

        // Kill paired wall too (emits 'die_paired' - no life loss)
        const wall = walls[wallResult.wallId];
        for (let j = 0; j < walls.length; j++) {
          if (j !== wallResult.wallId && walls[j].building && arePairedWalls(wall, walls[j])) {
            wallStop(j);
            wallEvents.push({ wallId: j, event: 'die_paired' });
          }
        }
      }
      continue;
    }

    // Check ball vs tile collisions
    const tileResult = checkBallCollisionTiles(balls[i]);
    ballCollisions.push(tileResult);
    if (tileResult.hit) {
      applyBallCollision(i, tileResult.normalX, tileResult.normalY);
    }
  }

  // Check ball vs ball collisions
  const ballBallCollisions = checkBallBallCollisions();
  for (const collision of ballBallCollisions) {
    // Ball 1 reflects based on normal (away from ball 2)
    applyBallCollision(collision.ball1, collision.normal.x, collision.normal.y);
    // Ball 2 reflects based on opposite normal (away from ball 1)
    applyBallCollision(collision.ball2, -collision.normal.x, -collision.normal.y);
  }

  // Tick walls (collisions and growth)
  const wallTickEvents = tickWalls();
  wallEvents.push(...wallTickEvents);

  // Move balls
  for (let i = 0; i < balls.length; i++) {
    moveBall(i);
  }

  return { balls: ballCollisions, walls: wallEvents };
}

// Simulate N ticks and return final state (for testing)
function simulate(ticks) {
  for (let i = 0; i < ticks; i++) {
    tick();
  }
  return getBalls();
}

// Export for CommonJS (Node.js)
if (typeof module !== 'undefined') {
  module.exports = {
    VERSION, BOARD_W, BOARD_H, BALL_SIZE, FREE, BORDER, WALL,
    DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT, WALL_VELOCITY,
    init, getVersion, clearBalls, addBall, setTile, getTile, setTileRect,
    getBall, getBalls, getBallCount,
    clearWalls, addWall, getWall, getWalls, getWallCount,
    wallNextRect, wallInnerRect, wallTipTile, wallTipRect,
    arePairedWalls, rectsShareTile, rectsIntersect,
    wallGoForward, wallStop, wallMaterialize,
    checkWallTileCollision, checkWallWallCollision, checkBallWallCollision,
    checkBallBallCollisions, rectIntersects, calculateNormal,
    tickBall, applyBallCollision, moveBall,
    tickCollisions, tickMovement, tickWalls, tick, simulate
  };
}
