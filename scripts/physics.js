// physics.js - KBounce deterministic physics engine
// Version: 1 (increment when physics behavior changes)
//
// SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

const VERSION = 1;

const BOARD_W = 32, BOARD_H = 20;
const BALL_SIZE = 0.8;
const D = 0.01;  // Epsilon for corner detection
const CORNER_EPSILON = 0.5;  // Threshold for corner vs edge hit

// Tile types (match board.gd TileType enum)
const FREE = 1, BORDER = 2, WALL = 3;

// Game state
let tiles = [];
let balls = [];

// Initialize the physics engine
function init() {
  tiles = [];
  balls = [];
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

// Full tick: check collisions, apply, and move
// Returns array of collision info per ball
function tick() {
  const collisions = [];

  // Check collisions
  for (let i = 0; i < balls.length; i++) {
    const result = checkBallCollisionTiles(balls[i]);
    collisions.push(result);
    if (result.hit) {
      applyBallCollision(i, result.normalX, result.normalY);
    }
  }

  // Move balls
  for (let i = 0; i < balls.length; i++) {
    moveBall(i);
  }

  return collisions;
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
    init, getVersion, clearBalls, addBall, setTile, getTile, setTileRect,
    getBall, getBalls, getBallCount,
    rectIntersects, calculateNormal,
    tickBall, applyBallCollision, moveBall,
    tickCollisions, tickMovement, tick, simulate
  };
}
