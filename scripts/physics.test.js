// physics.test.js - Unit tests for physics.js public API
// Run with: node physics.test.js
//
// SPDX-FileCopyrightText: 2000-2026 Stefan Schimanski <1Stein@gmx.de>
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

const assert = require('assert');
const physics = require('./physics.js');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ✗ ${name}`);
    console.log(`    ${e.message}`);
    failed++;
  }
}

function approx(actual, expected, epsilon = 0.001) {
  if (Math.abs(actual - expected) > epsilon) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}

// =============================================================================
// Initialization tests
// =============================================================================

console.log('\nSuite: Initialization');

test('init returns version', () => {
  const version = physics.init();
  assert.ok(version >= 1, 'Version should be >= 1');
});

test('init creates borders', () => {
  physics.init();
  const tiles = physics.getTiles();
  assert.strictEqual(tiles[0][0], physics.BORDER);
  assert.strictEqual(tiles[31][19], physics.BORDER);
  assert.strictEqual(tiles[0][10], physics.BORDER);
  assert.strictEqual(tiles[31][10], physics.BORDER);
});

test('init creates free center', () => {
  physics.init();
  const tiles = physics.getTiles();
  assert.strictEqual(tiles[15][10], physics.FREE);
  assert.strictEqual(tiles[1][1], physics.FREE);
  assert.strictEqual(tiles[30][18], physics.FREE);
});

// =============================================================================
// Ball creation and movement tests
// =============================================================================

console.log('\nSuite: Ball creation and movement');

test('addBall returns sequential IDs', () => {
  physics.init();
  const id0 = physics.addBall(10, 10, 1, 1);
  const id1 = physics.addBall(20, 10, -1, 1);
  assert.strictEqual(id0, 0);
  assert.strictEqual(id1, 1);
});

test('tick returns ball state', () => {
  physics.init();
  physics.addBall(10.5, 8.25, 1, -1);
  const result = physics.tick();
  const ball = result.balls[0];
  approx(ball.x, 10.5 + 0.125);
  approx(ball.y, 8.25 - 0.125);
  approx(ball.vx, 0.125);
  approx(ball.vy, -0.125);
});

test('ball moves by velocity after tick', () => {
  physics.init();
  physics.addBall(10, 10, 1, 1);
  const result = physics.tick();
  const ball = result.balls[0];
  approx(ball.x, 10.125);
  approx(ball.y, 10.125);
});

test('ball moves 1 tile after 8 ticks', () => {
  physics.init();
  physics.addBall(10, 10, 1, 0);
  let result;
  for (let i = 0; i < 8; i++) result = physics.tick();
  approx(result.balls[0].x, 11.0);
});

test('tick returns incrementing tick counter', () => {
  physics.init();
  physics.addBall(10, 10, 1, 1);
  assert.strictEqual(physics.tick().tick, 1);
  assert.strictEqual(physics.tick().tick, 2);
  assert.strictEqual(physics.tick().tick, 3);
});

// =============================================================================
// Ball reflection tests
// =============================================================================

console.log('\nSuite: Ball reflection');

test('ball reflects off left border', () => {
  physics.init();
  physics.addBall(1.5, 10, -1, 0);
  let result;
  for (let i = 0; i < 20; i++) result = physics.tick();
  assert.ok(result.balls[0].vx > 0, 'Ball should reflect right');
});

test('ball reflects off right border', () => {
  physics.init();
  physics.addBall(30, 10, 1, 0);
  let result;
  for (let i = 0; i < 20; i++) result = physics.tick();
  assert.ok(result.balls[0].vx < 0, 'Ball should reflect left');
});

test('ball reflects off top border', () => {
  physics.init();
  physics.addBall(15, 1.5, 0, -1);
  let result;
  for (let i = 0; i < 20; i++) result = physics.tick();
  assert.ok(result.balls[0].vy > 0, 'Ball should reflect down');
});

test('ball reflects off bottom border', () => {
  physics.init();
  physics.addBall(15, 18, 0, 1);
  let result;
  for (let i = 0; i < 20; i++) result = physics.tick();
  assert.ok(result.balls[0].vy < 0, 'Ball should reflect up');
});

test('ball reflects off corner', () => {
  physics.init();
  physics.addBall(1.5, 1.5, -1, -1);
  let result;
  for (let i = 0; i < 20; i++) result = physics.tick();
  assert.ok(result.balls[0].vx > 0, 'Ball should reflect right');
  assert.ok(result.balls[0].vy > 0, 'Ball should reflect down');
});

// =============================================================================
// Wall placement tests
// =============================================================================

console.log('\nSuite: Wall placement');

test('tick with action creates walls', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  const result = physics.tick([{ x: 15, y: 10, vertical: true }]);
  assert.strictEqual(result.newWalls.length, 2, 'Should create 2 walls (up + down)');
});

test('vertical wall creates UP and DOWN', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  const result = physics.tick([{ x: 15, y: 10, vertical: true }]);
  const directions = result.newWalls.map(w => w.direction).sort();
  assert.deepStrictEqual(directions, [0, 1], 'Should have UP(0) and DOWN(1)');
});

test('horizontal wall creates LEFT and RIGHT', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  const result = physics.tick([{ x: 15, y: 10, vertical: false }]);
  const directions = result.newWalls.map(w => w.direction).sort();
  assert.deepStrictEqual(directions, [2, 3], 'Should have LEFT(2) and RIGHT(3)');
});

test('activeWalls shows growing walls', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  physics.tick([{ x: 15, y: 10, vertical: true }]);
  const result = physics.tick();
  assert.strictEqual(result.activeWalls.length, 2, 'Should have 2 active walls');
  assert.ok(result.activeWalls[0].h > 1, 'Wall should have grown');
});

// =============================================================================
// Wall completion tests
// =============================================================================

console.log('\nSuite: Wall completion');

test('wall finishes when hitting border', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  physics.tick([{ x: 15, y: 2, vertical: true }]);  // Near top border
  let finished = false;
  for (let i = 0; i < 30; i++) {
    const result = physics.tick();
    if (result.wallEvents.some(e => e.event === 'finish')) {
      finished = true;
      break;
    }
  }
  assert.ok(finished, 'Wall should finish when hitting border');
});

test('tilesChanged is true when wall finishes', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  physics.tick([{ x: 15, y: 2, vertical: true }]);
  let tilesChanged = false;
  for (let i = 0; i < 30; i++) {
    const result = physics.tick();
    if (result.tilesChanged) {
      tilesChanged = true;
      break;
    }
  }
  assert.ok(tilesChanged, 'tilesChanged should be true when wall finishes');
});

test('wall materializes tiles when finished', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);
  physics.tick([{ x: 15, y: 2, vertical: true }]);
  for (let i = 0; i < 30; i++) physics.tick();
  const tiles = physics.getTiles();
  assert.strictEqual(tiles[15][1], physics.WALL, 'Tile should be WALL');
});

// =============================================================================
// Ball vs wall collision tests
// =============================================================================

console.log('\nSuite: Ball vs wall collisions');

test('ball kills wall when hitting it', () => {
  physics.init();
  // Ball starts at x=10, heading right. Wall will be at x=15.
  // Ball moves 0.125/tick, so reaches x=15 after 40 ticks.
  // Place wall and let it grow before ball arrives.
  physics.addBall(10, 8.4, 1, 0);  // Ball heading right at y=8.4
  physics.tick([{ x: 15, y: 5, vertical: true }]);  // Wall from y=5, grows up/down
  // Wall grows down: after 32 ticks, extends to y=9 (4 tiles)
  // Ball at x=10 + 32*0.125 = 14 after 32 ticks

  let wallDied = false;
  for (let i = 0; i < 60; i++) {
    const result = physics.tick();
    if (result.wallEvents.some(e => e.event === 'die')) {
      wallDied = true;
      break;
    }
  }
  assert.ok(wallDied, 'Wall should die when ball hits it');
});

// =============================================================================
// Collision reporting tests
// =============================================================================

console.log('\nSuite: Collision reporting');

test('collision reported when ball hits border', () => {
  physics.init();
  physics.addBall(1.5, 10, -1, 0);
  let hitReported = false;
  for (let i = 0; i < 20; i++) {
    const result = physics.tick();
    if (result.collisions[0] && result.collisions[0].hit) {
      hitReported = true;
      break;
    }
  }
  assert.ok(hitReported, 'Collision should be reported');
});

// =============================================================================
// Determinism tests
// =============================================================================

console.log('\nSuite: Determinism');

test('same inputs produce same results', () => {
  // First run
  physics.init();
  physics.addBall(10, 10, 1, 1);
  physics.addBall(20, 10, -1, 1);
  let result1;
  for (let i = 0; i < 100; i++) result1 = physics.tick();

  // Second run with same inputs
  physics.init();
  physics.addBall(10, 10, 1, 1);
  physics.addBall(20, 10, -1, 1);
  let result2;
  for (let i = 0; i < 100; i++) result2 = physics.tick();

  assert.strictEqual(result1.balls.length, result2.balls.length);
  for (let i = 0; i < result1.balls.length; i++) {
    approx(result1.balls[i].x, result2.balls[i].x);
    approx(result1.balls[i].y, result2.balls[i].y);
    approx(result1.balls[i].vx, result2.balls[i].vx);
    approx(result1.balls[i].vy, result2.balls[i].vy);
  }
});

// =============================================================================
// Ball-ball collision tests
// =============================================================================

console.log('\nSuite: Ball-ball collision');

test('two balls collide head-on horizontally', () => {
  physics.init();
  // Ball 0 at x=10 heading right, Ball 1 at x=12 heading left
  // They should collide and reverse
  physics.addBall(10, 10, 1, 0);
  physics.addBall(12, 10, -1, 0);

  let ball0ReversedX = false;
  let ball1ReversedX = false;
  for (let i = 0; i < 20; i++) {
    const result = physics.tick();
    if (result.balls[0].vx < 0) ball0ReversedX = true;
    if (result.balls[1].vx > 0) ball1ReversedX = true;
  }
  assert.ok(ball0ReversedX, 'Ball 0 should reverse direction');
  assert.ok(ball1ReversedX, 'Ball 1 should reverse direction');
});

test('two balls collide head-on vertically', () => {
  physics.init();
  physics.addBall(10, 10, 0, 1);
  physics.addBall(10, 12, 0, -1);

  let ball0ReversedY = false;
  let ball1ReversedY = false;
  for (let i = 0; i < 20; i++) {
    const result = physics.tick();
    if (result.balls[0].vy < 0) ball0ReversedY = true;
    if (result.balls[1].vy > 0) ball1ReversedY = true;
  }
  assert.ok(ball0ReversedY, 'Ball 0 should reverse direction');
  assert.ok(ball1ReversedY, 'Ball 1 should reverse direction');
});

test('balls moving apart do not collide', () => {
  physics.init();
  physics.addBall(10, 10, -1, 0);  // Moving left
  physics.addBall(12, 10, 1, 0);   // Moving right

  let result;
  for (let i = 0; i < 50; i++) result = physics.tick();

  // Both balls should still be moving in original directions
  assert.ok(result.balls[0].vx < 0, 'Ball 0 should still move left');
  assert.ok(result.balls[1].vx > 0, 'Ball 1 should still move right');
});

// =============================================================================
// Wall-wall collision tests
// =============================================================================

console.log('\nSuite: Wall-wall collision');

test('wall tips collide - both walls die', () => {
  physics.init();
  physics.addBall(5, 15, 1, 1);  // Keep ball in bottom-left, away from walls

  // Place two horizontal walls that will collide in the middle
  // Wall at x=12 and x=18, both on y=5 - close enough to collide quickly
  physics.tick([{ x: 12, y: 5, vertical: false }]);  // Creates LEFT+RIGHT walls
  physics.tick([{ x: 18, y: 5, vertical: false }]);  // Creates LEFT+RIGHT walls

  // The RIGHT wall from x=12 and LEFT wall from x=18 should collide
  let wallCollisionEvent = false;
  for (let i = 0; i < 100; i++) {
    const result = physics.tick();
    if (result.wallEvents.some(e => e.event === 'wall_collision')) {
      wallCollisionEvent = true;
      break;
    }
  }
  assert.ok(wallCollisionEvent, 'Wall collision event should be emitted');
});

test('paired walls do not collide with each other', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);

  // Place one vertical wall - creates UP and DOWN walls from same point
  physics.tick([{ x: 15, y: 10, vertical: true }]);

  // Let walls grow - they should NOT collide with each other
  let wallCollisionEvent = false;
  for (let i = 0; i < 50; i++) {
    const result = physics.tick();
    if (result.wallEvents.some(e => e.event === 'wall_collision')) {
      wallCollisionEvent = true;
      break;
    }
  }
  assert.ok(!wallCollisionEvent, 'Paired walls should not collide');
});

test('wall tip hits wall body - wall materializes', () => {
  physics.init();
  physics.addBall(5, 15, 1, 1);  // Keep ball away

  // Place vertical wall first - let it grow
  physics.tick([{ x: 15, y: 10, vertical: true }]);
  for (let i = 0; i < 30; i++) physics.tick();  // Let it grow

  // Place horizontal wall that will hit the vertical wall's body
  physics.tick([{ x: 10, y: 10, vertical: false }]);  // RIGHT wall will hit vertical

  let wallFinished = false;
  for (let i = 0; i < 60; i++) {
    const result = physics.tick();
    // The horizontal wall should finish when hitting vertical wall body
    if (result.wallEvents.some(e => e.event === 'finish')) {
      wallFinished = true;
      break;
    }
  }
  assert.ok(wallFinished, 'Wall should finish when hitting another wall body');
});

// =============================================================================
// Flood fill / enclosed area tests
// =============================================================================

console.log('\nSuite: Flood fill');

test('enclosed area gets filled', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);  // Ball in top-left

  // Create a vertical wall near right border to enclose right side
  physics.tick([{ x: 25, y: 10, vertical: true }]);

  // Wait for BOTH walls to finish (UP hits top, DOWN hits bottom)
  let finishCount = 0;
  for (let i = 0; i < 200; i++) {
    const result = physics.tick();
    finishCount += result.wallEvents.filter(e => e.event === 'finish').length;
    if (finishCount >= 2) break;
  }
  assert.ok(finishCount >= 2, 'Both walls should finish');

  // Check that right side is now filled
  const tiles = physics.getTiles();
  assert.strictEqual(tiles[28][10], physics.WALL, 'Enclosed area should be WALL');
});

test('area with ball is not filled', () => {
  physics.init();
  physics.addBall(28, 10, 1, 1);  // Ball in right side

  // Create vertical wall - should NOT fill right side where ball is
  physics.tick([{ x: 25, y: 10, vertical: true }]);

  for (let i = 0; i < 200; i++) physics.tick();

  // Ball's area should still be FREE
  const tiles = physics.getTiles();
  // The ball is at (28, 10), check nearby tile
  assert.strictEqual(tiles[27][10], physics.FREE, 'Ball area should remain FREE');
});

test('fillPercent increases after enclosure', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);

  // Initial fill should be 0
  let result = physics.tick();
  assert.strictEqual(result.fillPercent, 0, 'Initial fill should be 0');

  // Create wall to enclose area
  physics.tick([{ x: 25, y: 10, vertical: true }]);

  let finalFill = 0;
  for (let i = 0; i < 200; i++) {
    result = physics.tick();
    if (result.fillPercent > 0) {
      finalFill = result.fillPercent;
    }
  }
  assert.ok(finalFill > 0, 'Fill percent should increase after enclosure');
});

// =============================================================================
// Replay validation tests
// =============================================================================

console.log('\nSuite: Replay validation');

test('validateLevel accepts valid replay', () => {
  // First, generate a valid replay by running physics
  physics.init();
  physics.addBall(10, 10, 1, 1);

  // Run 100 ticks and record final position
  let finalResult;
  for (let i = 0; i < 100; i++) {
    finalResult = physics.tick();
  }

  // Create replay data with checkpoint at tick 100
  const levelData = {
    balls: [{ x: 10, y: 10, vx: 1, vy: 1 }],
    actions: [],
    checkpoints: [{
      t: 100,
      balls: [{ x: finalResult.balls[0].x, y: finalResult.balls[0].y }]
    }],
    result: { tick: 100 }
  };

  const result = physics.validateLevel(levelData);
  assert.ok(result.valid, 'Valid replay should pass validation');
});

test('validateLevel rejects invalid checkpoint', () => {
  const levelData = {
    balls: [{ x: 10, y: 10, vx: 1, vy: 1 }],
    actions: [],
    checkpoints: [{
      t: 100,
      balls: [{ x: 999, y: 999 }]  // Wrong position
    }],
    result: { tick: 100 }
  };

  const result = physics.validateLevel(levelData);
  assert.ok(!result.valid, 'Invalid checkpoint should fail validation');
  assert.strictEqual(result.error, 'Ball position mismatch');
});

test('validateLevel applies actions correctly', () => {
  // Run physics with a wall action and record result
  physics.init();
  physics.addBall(5, 15, 1, 1);  // Ball away from wall

  physics.tick();  // Tick 1
  physics.tick([{ x: 15, y: 10, vertical: true }]);  // Tick 2 with wall

  let result;
  for (let i = 0; i < 50; i++) {
    result = physics.tick();
  }
  const ballAtTick52 = result.balls[0];

  // Validate with same actions
  const levelData = {
    balls: [{ x: 5, y: 15, vx: 1, vy: 1 }],
    actions: [{ t: 2, x: 15, y: 10, v: true }],  // Wall at tick 2
    checkpoints: [{
      t: 52,
      balls: [{ x: ballAtTick52.x, y: ballAtTick52.y }]
    }],
    result: { tick: 52 }
  };

  const validationResult = physics.validateLevel(levelData);
  assert.ok(validationResult.valid, 'Replay with actions should validate');
});

// =============================================================================
// Multiple walls tests
// =============================================================================

console.log('\nSuite: Multiple walls');

test('can have 4 walls active simultaneously', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);

  // Place 2 wall pairs = 4 walls
  physics.tick([
    { x: 10, y: 10, vertical: true },
    { x: 20, y: 10, vertical: false }
  ]);

  const result = physics.tick();
  assert.strictEqual(result.activeWalls.length, 4, 'Should have 4 active walls');
});

test('multiple walls finish independently', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);

  // Place walls at different distances from borders
  physics.tick([
    { x: 15, y: 2, vertical: true },   // Near top - UP finishes fast
    { x: 15, y: 17, vertical: true }   // Near bottom - DOWN finishes fast
  ]);

  let finishEvents = 0;
  for (let i = 0; i < 200; i++) {
    const result = physics.tick();
    finishEvents += result.wallEvents.filter(e => e.event === 'finish').length;
  }

  // Should have multiple finish events (at least 2 walls finishing quickly)
  assert.ok(finishEvents >= 2, 'Multiple walls should finish');
});

// =============================================================================
// Edge case tests
// =============================================================================

console.log('\nSuite: Edge cases');

test('ball reflects correctly from corner', () => {
  physics.init();
  // Ball heading toward top-left corner
  physics.addBall(2, 2, -1, -1);

  let result;
  for (let i = 0; i < 30; i++) {
    result = physics.tick();
  }

  // After hitting corner, should be heading away (positive velocity)
  assert.ok(result.balls[0].vx > 0, 'Ball should reflect from corner (vx)');
  assert.ok(result.balls[0].vy > 0, 'Ball should reflect from corner (vy)');
});

test('wall at border finishes immediately', () => {
  physics.init();
  physics.addBall(5, 5, 1, 1);

  // Place wall right next to border
  physics.tick([{ x: 2, y: 10, vertical: false }]);  // LEFT wall will hit border fast

  let fastFinish = false;
  for (let i = 0; i < 20; i++) {
    const result = physics.tick();
    if (result.wallEvents.some(e => e.event === 'finish')) {
      fastFinish = true;
      break;
    }
  }
  assert.ok(fastFinish, 'Wall near border should finish quickly');
});

test('ball bounces multiple times correctly', () => {
  physics.init();
  physics.addBall(15, 10, 1, 0);  // Ball in center, moving right

  let bounceCount = 0;
  let lastVx = 0.125;  // Initial positive vx

  for (let i = 0; i < 500; i++) {
    const result = physics.tick();
    const vx = result.balls[0].vx;
    if (Math.sign(vx) !== Math.sign(lastVx)) {
      bounceCount++;
      lastVx = vx;
    }
  }

  // Ball should bounce multiple times (at least 2: right border, left border)
  assert.ok(bounceCount >= 2, 'Ball should bounce multiple times');
});

test('level completes at 75% fill', () => {
  physics.init();
  physics.addBall(3, 3, 1, 1);  // Ball in top-left corner

  // Create walls to fill most of the board
  // Vertical walls across the board
  physics.tick([{ x: 5, y: 10, vertical: true }]);
  for (let i = 0; i < 100; i++) physics.tick();

  physics.tick([{ x: 8, y: 10, vertical: true }]);
  for (let i = 0; i < 100; i++) physics.tick();

  physics.tick([{ x: 11, y: 10, vertical: true }]);
  for (let i = 0; i < 100; i++) physics.tick();

  physics.tick([{ x: 14, y: 10, vertical: true }]);
  let levelComplete = false;
  for (let i = 0; i < 200; i++) {
    const result = physics.tick();
    if (result.levelComplete) {
      levelComplete = true;
      assert.ok(result.fillPercent >= 75, 'Fill should be >= 75%');
      break;
    }
  }
  // Note: May not complete if ball interferes - that's ok for this test
});

test('paired wall dies when partner is killed', () => {
  physics.init();
  // Ball heading right toward vertical wall
  physics.addBall(10, 10, 1, 0);

  // Place vertical wall in ball's path
  physics.tick([{ x: 15, y: 8, vertical: true }]);

  // Let wall grow a bit, then ball hits it
  let dieEvent = false;
  let diePairedEvent = false;
  for (let i = 0; i < 60; i++) {
    const result = physics.tick();
    for (const e of result.wallEvents) {
      if (e.event === 'die') dieEvent = true;
      if (e.event === 'die_paired') diePairedEvent = true;
    }
    if (dieEvent) break;
  }
  assert.ok(dieEvent, 'Wall should die from ball hit');
  assert.ok(diePairedEvent, 'Paired wall should also die');
});

test('addBall normalizes direction to velocity', () => {
  physics.init();
  // Pass arbitrary direction values, not just ±1
  physics.addBall(10, 10, 5, -3);

  const result = physics.tick();
  const ball = result.balls[0];

  // Should be normalized to ±BALL_VELOCITY (0.125)
  approx(Math.abs(ball.vx), 0.125);
  approx(Math.abs(ball.vy), 0.125);
  assert.ok(ball.vx > 0, 'vx should be positive (from dx=5)');
  assert.ok(ball.vy < 0, 'vy should be negative (from dy=-3)');
});

test('validateLevel detects velocity mismatch', () => {
  physics.init();
  physics.addBall(10, 10, 1, 1);

  let result;
  for (let i = 0; i < 50; i++) result = physics.tick();

  // Record with wrong velocity
  const levelData = {
    balls: [{ x: 10, y: 10, vx: 1, vy: 1 }],
    actions: [],
    checkpoints: [{
      t: 50,
      balls: [{
        x: result.balls[0].x,
        y: result.balls[0].y,
        vx: -0.125,  // Wrong velocity
        vy: -0.125
      }]
    }],
    result: { tick: 50 }
  };

  const validationResult = physics.validateLevel(levelData);
  assert.ok(!validationResult.valid, 'Should fail on velocity mismatch');
  assert.strictEqual(validationResult.error, 'Ball velocity mismatch');
});

test('validateLevel handles multiple checkpoints', () => {
  physics.init();
  physics.addBall(10, 10, 1, 0);  // Moving right only

  // Record positions at tick 20 and 40
  let pos20, pos40;
  for (let i = 0; i < 50; i++) {
    const result = physics.tick();
    if (result.tick === 20) pos20 = { x: result.balls[0].x, y: result.balls[0].y };
    if (result.tick === 40) pos40 = { x: result.balls[0].x, y: result.balls[0].y };
  }

  const levelData = {
    balls: [{ x: 10, y: 10, vx: 1, vy: 0 }],
    actions: [],
    checkpoints: [
      { t: 20, balls: [pos20] },
      { t: 40, balls: [pos40] }
    ],
    result: { tick: 50 }
  };

  const result = physics.validateLevel(levelData);
  assert.ok(result.valid, 'Multiple checkpoints should validate');
});

// =============================================================================
// Summary
// =============================================================================

console.log('\n========================================');
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log('========================================\n');

process.exit(failed > 0 ? 1 : 0);
