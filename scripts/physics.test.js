// physics.test.js - Unit tests for physics.js
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
  assert.strictEqual(physics.getTile(0, 0), physics.BORDER);
  assert.strictEqual(physics.getTile(31, 19), physics.BORDER);
  assert.strictEqual(physics.getTile(0, 10), physics.BORDER);
  assert.strictEqual(physics.getTile(31, 10), physics.BORDER);
});

test('init creates free center', () => {
  physics.init();
  assert.strictEqual(physics.getTile(15, 10), physics.FREE);
  assert.strictEqual(physics.getTile(1, 1), physics.FREE);
  assert.strictEqual(physics.getTile(30, 18), physics.FREE);
});

// =============================================================================
// Ball creation and movement tests
// =============================================================================

console.log('\nSuite: Ball creation and movement');

test('addBall returns sequential IDs', () => {
  physics.init();
  const id0 = physics.addBall(10, 10, 0.125, 0.125);
  const id1 = physics.addBall(20, 10, -0.125, 0.125);
  assert.strictEqual(id0, 0);
  assert.strictEqual(id1, 1);
});

test('getBall returns ball state', () => {
  physics.init();
  physics.addBall(10.5, 8.25, 0.125, -0.125);
  const ball = physics.getBall(0);
  approx(ball.x, 10.5);
  approx(ball.y, 8.25);
  approx(ball.vx, 0.125);
  approx(ball.vy, -0.125);
});

test('ball moves by velocity after tick', () => {
  physics.init();
  physics.addBall(10, 10, 0.125, 0.125);
  physics.tick();
  const ball = physics.getBall(0);
  approx(ball.x, 10.125);
  approx(ball.y, 10.125);
});

test('ball moves 1 tile after 8 ticks', () => {
  physics.init();
  physics.addBall(10, 10, 0.125, 0);
  for (let i = 0; i < 8; i++) physics.tick();
  const ball = physics.getBall(0);
  approx(ball.x, 11.0);
});

// =============================================================================
// Ball reflection tests
// =============================================================================

console.log('\nSuite: Ball reflection');

test('ball reflects off left border', () => {
  physics.init();
  physics.addBall(1.5, 10, -0.125, 0);
  for (let i = 0; i < 20; i++) physics.tick();
  const ball = physics.getBall(0);
  assert.ok(ball.vx > 0, 'Ball should reflect right');
});

test('ball reflects off right border', () => {
  physics.init();
  physics.addBall(30, 10, 0.125, 0);
  for (let i = 0; i < 20; i++) physics.tick();
  const ball = physics.getBall(0);
  assert.ok(ball.vx < 0, 'Ball should reflect left');
});

test('ball reflects off top border', () => {
  physics.init();
  physics.addBall(15, 1.5, 0, -0.125);
  for (let i = 0; i < 20; i++) physics.tick();
  const ball = physics.getBall(0);
  assert.ok(ball.vy > 0, 'Ball should reflect down');
});

test('ball reflects off bottom border', () => {
  physics.init();
  physics.addBall(15, 18, 0, 0.125);
  for (let i = 0; i < 20; i++) physics.tick();
  const ball = physics.getBall(0);
  assert.ok(ball.vy < 0, 'Ball should reflect up');
});

test('ball reflects off corner', () => {
  physics.init();
  physics.addBall(1.5, 1.5, -0.125, -0.125);
  for (let i = 0; i < 20; i++) physics.tick();
  const ball = physics.getBall(0);
  assert.ok(ball.vx > 0, 'Ball should reflect right');
  assert.ok(ball.vy > 0, 'Ball should reflect down');
});

// =============================================================================
// Wall growth tests
// =============================================================================

console.log('\nSuite: Wall growth');

test('wall grows UP', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_UP);
  const before = physics.getWall(0);
  physics.tick();
  const after = physics.getWall(0);
  approx(after.y, before.y - physics.WALL_VELOCITY);
  approx(after.h, before.h + physics.WALL_VELOCITY);
});

test('wall grows DOWN', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_DOWN);
  const before = physics.getWall(0);
  physics.tick();
  const after = physics.getWall(0);
  approx(after.y, before.y);
  approx(after.h, before.h + physics.WALL_VELOCITY);
});

test('wall grows LEFT', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_LEFT);
  const before = physics.getWall(0);
  physics.tick();
  const after = physics.getWall(0);
  approx(after.x, before.x - physics.WALL_VELOCITY);
  approx(after.w, before.w + physics.WALL_VELOCITY);
});

test('wall grows RIGHT', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_RIGHT);
  const before = physics.getWall(0);
  physics.tick();
  const after = physics.getWall(0);
  approx(after.x, before.x);
  approx(after.w, before.w + physics.WALL_VELOCITY);
});

test('wall grows 1 tile after 8 ticks', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_DOWN);
  for (let i = 0; i < 8; i++) physics.tick();
  const wall = physics.getWall(0);
  approx(wall.h, 2.0);
});

// =============================================================================
// Wall inner rect tests
// =============================================================================

console.log('\nSuite: Wall inner rect');

test('small wall has no inner rect', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_UP);
  const wall = physics.getWall(0);
  const inner = physics.wallInnerRect(wall);
  assert.strictEqual(inner, null);
});

test('UP wall inner rect excludes tip', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_UP);
  for (let i = 0; i < 16; i++) physics.tick();  // Grow 2 tiles
  const wall = physics.getWall(0);
  const inner = physics.wallInnerRect(wall);
  assert.ok(inner !== null);
  approx(inner.y, wall.y + 1.0);
  approx(inner.h, wall.h - 1.0);
});

test('DOWN wall inner rect excludes tip', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_DOWN);
  for (let i = 0; i < 16; i++) physics.tick();
  const wall = physics.getWall(0);
  const inner = physics.wallInnerRect(wall);
  assert.ok(inner !== null);
  approx(inner.y, wall.y);
  approx(inner.h, wall.h - 1.0);
});

test('LEFT wall inner rect excludes tip', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_LEFT);
  for (let i = 0; i < 16; i++) physics.tick();
  const wall = physics.getWall(0);
  const inner = physics.wallInnerRect(wall);
  assert.ok(inner !== null);
  approx(inner.x, wall.x + 1.0);
  approx(inner.w, wall.w - 1.0);
});

test('RIGHT wall inner rect excludes tip', () => {
  physics.init();
  physics.addWall(10, 10, physics.DIR_RIGHT);
  for (let i = 0; i < 16; i++) physics.tick();
  const wall = physics.getWall(0);
  const inner = physics.wallInnerRect(wall);
  assert.ok(inner !== null);
  approx(inner.x, wall.x);
  approx(inner.w, wall.w - 1.0);
});

// =============================================================================
// Paired walls tests
// =============================================================================

console.log('\nSuite: Paired walls');

test('UP and DOWN from same origin are paired', () => {
  const w1 = { startX: 10, startY: 10, direction: physics.DIR_UP };
  const w2 = { startX: 10, startY: 10, direction: physics.DIR_DOWN };
  assert.ok(physics.arePairedWalls(w1, w2));
});

test('LEFT and RIGHT from same origin are paired', () => {
  const w1 = { startX: 10, startY: 10, direction: physics.DIR_LEFT };
  const w2 = { startX: 10, startY: 10, direction: physics.DIR_RIGHT };
  assert.ok(physics.arePairedWalls(w1, w2));
});

test('different origins are not paired', () => {
  const w1 = { startX: 10, startY: 10, direction: physics.DIR_UP };
  const w2 = { startX: 15, startY: 10, direction: physics.DIR_DOWN };
  assert.ok(!physics.arePairedWalls(w1, w2));
});

test('same direction is not paired', () => {
  const w1 = { startX: 10, startY: 10, direction: physics.DIR_UP };
  const w2 = { startX: 10, startY: 10, direction: physics.DIR_UP };
  assert.ok(!physics.arePairedWalls(w1, w2));
});

test('perpendicular walls are not paired', () => {
  const w1 = { startX: 10, startY: 10, direction: physics.DIR_UP };
  const w2 = { startX: 10, startY: 10, direction: physics.DIR_LEFT };
  assert.ok(!physics.arePairedWalls(w1, w2));
});

// =============================================================================
// Wall collision tests
// =============================================================================

console.log('\nSuite: Wall collisions');

test('wall finishes when hitting border', () => {
  physics.init();
  physics.addWall(10, 2, physics.DIR_UP);  // Start near top border
  let finished = false;
  for (let i = 0; i < 20; i++) {
    const result = physics.tick();
    if (result.walls.some(e => e.event === 'finish')) {
      finished = true;
      break;
    }
  }
  assert.ok(finished, 'Wall should finish when hitting border');
});

test('wall finishes when hitting filled tile', () => {
  physics.init();
  physics.setTile(10, 5, physics.WALL);  // Place wall tile
  physics.addWall(10, 10, physics.DIR_UP);
  let finished = false;
  for (let i = 0; i < 50; i++) {
    const result = physics.tick();
    if (result.walls.some(e => e.event === 'finish')) {
      finished = true;
      break;
    }
  }
  assert.ok(finished, 'Wall should finish when hitting filled tile');
});

test('wall materializes tiles when finished', () => {
  physics.init();
  physics.addWall(10, 2, physics.DIR_UP);
  for (let i = 0; i < 20; i++) physics.tick();
  // Check that tiles are now WALL
  assert.strictEqual(physics.getTile(10, 1), physics.WALL);
});

// =============================================================================
// Ball vs wall collision tests
// =============================================================================

console.log('\nSuite: Ball vs wall collisions');

test('ball kills wall when hitting inner area', () => {
  physics.init();
  // Create a tall wall
  physics.addWall(15, 5, physics.DIR_DOWN);
  for (let i = 0; i < 24; i++) physics.tick();  // Grow 3 tiles

  // Add ball heading toward wall body (not tip)
  physics.clearBalls();
  physics.addBall(13, 6.5, 0.125, 0);  // Heading right into wall body

  let wallDied = false;
  for (let i = 0; i < 30; i++) {
    const result = physics.tick();
    if (result.walls.some(e => e.event === 'die')) {
      wallDied = true;
      break;
    }
  }
  assert.ok(wallDied, 'Wall should die when ball hits inner area');
});

test('ball reflects off wall', () => {
  physics.init();
  physics.addWall(15, 5, physics.DIR_DOWN);
  for (let i = 0; i < 24; i++) physics.tick();

  physics.clearBalls();
  physics.addBall(13, 6.5, 0.125, 0);
  const before = physics.getBall(0);

  for (let i = 0; i < 30; i++) {
    physics.tick();
    const after = physics.getBall(0);
    if (after.vx < 0) {
      assert.ok(true, 'Ball reflected');
      return;
    }
  }
  assert.fail('Ball should have reflected');
});

// =============================================================================
// Rect intersection tests
// =============================================================================

console.log('\nSuite: Rect intersection');

test('overlapping rects intersect', () => {
  const r1 = { x: 5, y: 5, w: 2, h: 2 };
  const r2 = { x: 6, y: 6, w: 2, h: 2 };
  assert.ok(physics.rectsIntersect(r1, r2));
});

test('non-overlapping rects do not intersect', () => {
  const r1 = { x: 5, y: 5, w: 1, h: 1 };
  const r2 = { x: 10, y: 10, w: 1, h: 1 };
  assert.ok(!physics.rectsIntersect(r1, r2));
});

test('adjacent rects do not intersect', () => {
  const r1 = { x: 5, y: 5, w: 1, h: 1 };
  const r2 = { x: 6, y: 5, w: 1, h: 1 };
  assert.ok(!physics.rectsIntersect(r1, r2));
});

test('rects sharing tile', () => {
  const r1 = { x: 5.0, y: 5.0, w: 1, h: 1 };
  const r2 = { x: 5.5, y: 5.5, w: 1, h: 1 };
  assert.ok(physics.rectsShareTile(r1, r2));
});

test('rects in separate tiles', () => {
  const r1 = { x: 5.0, y: 5.0, w: 0.8, h: 0.8 };
  const r2 = { x: 7.0, y: 5.0, w: 0.8, h: 0.8 };
  assert.ok(!physics.rectsShareTile(r1, r2));
});

// =============================================================================
// Calculate normal tests
// =============================================================================

console.log('\nSuite: Calculate normal');

test('ball hits wall from left', () => {
  const n = physics.calculateNormal(5, 5, 1, 1, 5.5, 5, 2, 1);
  assert.strictEqual(n.x, -1);
  assert.strictEqual(n.y, 0);
});

test('ball hits wall from right', () => {
  const n = physics.calculateNormal(7, 5, 1, 1, 5, 5, 2, 1);
  assert.strictEqual(n.x, 1);
  assert.strictEqual(n.y, 0);
});

test('ball hits wall from top', () => {
  const n = physics.calculateNormal(5, 5, 1, 1, 5, 5.5, 1, 2);
  assert.strictEqual(n.x, 0);
  assert.strictEqual(n.y, -1);
});

test('ball hits wall from bottom', () => {
  const n = physics.calculateNormal(5, 7, 1, 1, 5, 5, 1, 2);
  assert.strictEqual(n.x, 0);
  assert.strictEqual(n.y, 1);
});

// =============================================================================
// Determinism tests
// =============================================================================

console.log('\nSuite: Determinism');

test('same inputs produce same results', () => {
  // First run
  physics.init();
  physics.addBall(10, 10, 0.125, 0.125);
  physics.addBall(20, 10, -0.125, 0.125);
  for (let i = 0; i < 100; i++) physics.tick();
  const result1 = physics.getBalls();

  // Second run with same inputs
  physics.init();
  physics.addBall(10, 10, 0.125, 0.125);
  physics.addBall(20, 10, -0.125, 0.125);
  for (let i = 0; i < 100; i++) physics.tick();
  const result2 = physics.getBalls();

  assert.strictEqual(result1.length, result2.length);
  for (let i = 0; i < result1.length; i++) {
    approx(result1[i].x, result2[i].x);
    approx(result1[i].y, result2[i].y);
    approx(result1[i].vx, result2[i].vx);
    approx(result1[i].vy, result2[i].vy);
  }
});

// =============================================================================
// Summary
// =============================================================================

console.log('\n========================================');
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log('========================================\n');

process.exit(failed > 0 ? 1 : 0);
