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
// Summary
// =============================================================================

console.log('\n========================================');
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log('========================================\n');

process.exit(failed > 0 ? 1 : 0);
