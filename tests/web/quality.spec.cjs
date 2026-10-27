const fs = require('node:fs');
const { test, expect } = require('/workspace/.godot-cloud/tools/browser/node_modules/@playwright/test');
const { recording } = require('./recording.cjs');
const state = page => page.evaluate(() => window.__depthE2E);

async function observe(page, milliseconds) {
  return page.evaluate(async duration => {
    const samples = [];
    const end = performance.now() + duration;
    do {
      const s = window.__depthE2E;
      if (s) samples.push({ ...s, time: (performance.timeOrigin + performance.now()) / 1000 });
      await new Promise(requestAnimationFrame);
    } while (performance.now() < end);
    return samples;
  }, milliseconds);
}

async function flight(page, full) {
  const start = await state(page);
  const trajectory = page.evaluate(async () => {
    const samples = [];
    let airborne = false;
    const deadline = performance.now() + 5000;
    while (performance.now() < deadline) {
      const s = window.__depthE2E;
      samples.push({ ...s, time: (performance.timeOrigin + performance.now()) / 1000 });
      airborne ||= !s.grounded;
      if (airborne && s.grounded) return samples;
      await new Promise(requestAnimationFrame);
    }
    throw new Error('No complete jump was observed');
  });
  if (full) await page.keyboard.down('Space');
  else await page.keyboard.press('Space', { delay: 10 });
  const samples = await trajectory;
  if (full) {
    await page.waitForTimeout(150);
    expect((await state(page)).grounded).toBe(true);
    await page.keyboard.up('Space');
  }
  return { height: start.y - Math.min(...samples.map(s => s.y)),
    samples: samples.map(s => ({ ...s, jump_kind: full ? 'full' : 'short' })) };
}

test('visual review: stable five second idle, both run directions, short and full jump', async ({ page }, info) => {
  test.setTimeout(90000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR:|Parse Error:|^ERROR:/.test(message.text())) errors.push(message.text());
  });
  await page.goto('/index.html?e2e=1');
  await page.waitForFunction(() => window.__depthE2E?.mode === 'title', null, {timeout: 45000});
  await page.locator('#canvas').click({position: {x: 12, y: 12}});
  await page.keyboard.press('Enter');
  await expect.poll(async () => (await state(page))?.grounded, { timeout: 45000 }).toBe(true);
  await page.locator('#canvas').click();
  await page.waitForTimeout(250);
  let stop = await recording(page, info.outputDir, 'idle');
  const idle = await observe(page, 5300);
  await stop(idle);
  const spread = (samples, field) => Math.max(...samples.map(s => s[field])) - Math.min(...samples.map(s => s[field]));
  expect(idle.every(s => s.animation === 'idle')).toBe(true);
  expect(spread(idle, 'x')).toBeLessThan(0.1);
  expect(spread(idle, 'body_y')).toBeLessThan(0.25);
  for (const key of ['front_sole_x', 'back_sole_x', 'front_sole_y', 'back_sole_y']) expect(spread(idle, key)).toBeLessThan(0.2);
  await page.screenshot({ path: info.outputPath('stable-idle.png') });

  stop = await recording(page, info.outputDir, 'run');
  const watching = observe(page, 3300);
  await page.keyboard.down('KeyD');
  await page.waitForTimeout(1100);
  await page.keyboard.up('KeyD');
  await page.waitForTimeout(200);
  await page.keyboard.down('KeyA');
  await page.waitForTimeout(1100);
  await page.keyboard.up('KeyA');
  const running = await watching;
  await stop(running);
  expect(running.filter(s => s.animation === 'run' && !s.facing_left).length).toBeGreaterThan(12);
  expect(running.filter(s => s.animation === 'run' && s.facing_left).length).toBeGreaterThan(12);
  let checked = 0;
  let maxDrift = 0;
  for (let i = 1; i < running.length; i++) {
    const a = running[i-1], b = running[i];
    if (a.animation !== 'run' || b.animation !== 'run' || a.facing_left !== b.facing_left || b.gait_phase < a.gait_phase) continue;
    // Skip the first 80 ms blend into the cycle, then inspect planted feet.
    if (a.gait_phase < 0.55 || a.gait_phase > 0.85) continue;
    if (a.back_planted && b.back_planted) {
      maxDrift = Math.max(maxDrift, Math.abs(a.back_sole_x-b.back_sole_x));
      checked++;
    }
  }
  expect(checked).toBeGreaterThan(5);
  expect(maxDrift).toBeLessThan(0.6);

  await expect.poll(async () => (await state(page)).grounded).toBe(true);
  stop = await recording(page, info.outputDir, 'jumps');
  const short = await flight(page, false);
  await page.waitForTimeout(450);
  const full = await flight(page, true);
  await page.waitForTimeout(200);
  await stop([...short.samples, ...full.samples]);
  expect(short.height).toBeGreaterThan(44);
  expect(short.height).toBeLessThan(56);
  expect(full.height).toBeGreaterThan(88);
  expect(full.height).toBeLessThan(101);
  expect(full.height-short.height).toBeGreaterThan(30);
  expect(errors).toEqual([]);
  fs.writeFileSync(info.outputPath('quality-metrics.json'), JSON.stringify({
    idleSeconds: idle.at(-1).time-idle[0].time, idleBodyTravel: spread(idle,'body_y'),
    plantedSamples: checked, maxPlantedFootDrift: maxDrift,
    shortJumpPixels: short.height, fullJumpPixels: full.height, errors,
  }, null, 2));
});
