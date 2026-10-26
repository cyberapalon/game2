const fs = require('node:fs');
const { test, expect } = require('/workspace/.godot-cloud/tools/browser/node_modules/@playwright/test');

const state = page => page.evaluate(() => window.__depthE2E);
const frames = (page, count = 12) => page.evaluate(async n => {
  for (let i = 0; i < n; i++) await new Promise(requestAnimationFrame);
}, count);

test('Web surface receives keyboard input, moves, jumps, lands and releases focus', async ({ page, context }, testInfo) => {
  const errors = [];
  const checkpoints = {};
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR:|Parse Error:|^ERROR:/.test(message.text())) {
      errors.push(message.text());
    }
  });
  page.on('pageerror', error => errors.push(error.message));
  page.on('requestfailed', request => errors.push(`${request.url()}: ${request.failure().errorText}`));

  const response = await page.goto('/index.html?e2e=1');
  expect(response.ok()).toBeTruthy();
  const wasm = await page.request.get('/index.wasm');
  expect(wasm.ok()).toBeTruthy();
  expect(wasm.headers()['content-type']).toContain('application/wasm');
  await expect.poll(async () => (await state(page))?.grounded, { timeout: 45000 }).toBe(true);

  const canvas = page.locator('#canvas');
  await expect(canvas).toBeVisible();
  const gl = await canvas.evaluate(c => {
    const context = c.getContext('webgl2');
    return context && { version: context.getParameter(context.VERSION), width: c.width, height: c.height };
  });
  expect(gl?.version).toContain('WebGL 2.0');
  expect(gl.width).toBe(960);
  expect(gl.height).toBe(540);
  await canvas.click();
  await expect(canvas).toBeFocused();
  checkpoints.spawn = await state(page);
  expect(checkpoints.spawn.screen_y).toBeGreaterThan(22);
  expect(checkpoints.spawn.screen_y).toBeLessThan(440);

  // Real browser events only. The bridge is read-only and cannot move the player.
  for (const [key, sign] of [['KeyD', 1], ['KeyA', -1], ['ArrowRight', 1], ['ArrowLeft', -1]]) {
    const before = await state(page);
    await page.keyboard.down(key);
    try {
      await expect.poll(async () => sign * ((await state(page)).x - before.x)).toBeGreaterThan(45);
    } finally {
      await page.keyboard.up(key);
    }
    await expect.poll(async () => (await state(page)).vx).toBe(0);
    const stopped = await state(page);
    await frames(page);
    expect(Math.abs((await state(page)).x - stopped.x)).toBeLessThan(0.5);
    checkpoints[key] = stopped;
  }

  const floor = await state(page);
  await page.keyboard.down('Space');
  try {
    await expect.poll(async () => floor.y - (await state(page)).y, { intervals: [16] }).toBeGreaterThan(25);
    checkpoints.airborne = await state(page);
    expect(checkpoints.airborne.grounded).toBe(false);
    expect(checkpoints.airborne.vy).toBeLessThan(0);
    expect(checkpoints.airborne.depth_text).toBe('Глубина: 0.00 км');
    await page.screenshot({ path: testInfo.outputPath('jump.png') });
    // Holding Space through landing must not start another jump.
    await expect.poll(async () => (await state(page)).grounded, { intervals: [16] }).toBe(true);
    await frames(page, 20);
    expect((await state(page)).grounded).toBe(true);
  } finally {
    await page.keyboard.up('Space');
  }
  checkpoints.landed = await state(page);
  expect(Math.abs(checkpoints.landed.y - floor.y)).toBeLessThan(0.5);
  expect(checkpoints.landed.depth_km).toBe(0);

  await page.keyboard.down('KeyD');
  await expect.poll(async () => (await state(page)).vx).toBeGreaterThan(0);
  // A real click outside canvas tests its blur handler. Headless Chromium keeps
  // background pages focused, so bringToFront alone cannot verify focus loss.
  await page.evaluate(() => {
    const button = document.createElement('button');
    button.id = 'focus-probe';
    button.textContent = 'Focus probe';
    button.style.cssText = 'position:fixed;right:0;top:0;z-index:100';
    document.body.append(button);
  });
  try {
    await page.locator('#focus-probe').click();
    await expect(canvas).not.toBeFocused();
    // No key-up yet: losing canvas focus must clear the held direction.
    await expect.poll(async () => (await state(page)).vx).toBe(0);
  } finally {
    await page.locator('#focus-probe').evaluate(button => button.remove());
    await page.keyboard.up('KeyD');
  }
  await canvas.click();
  const unfocusedStop = await state(page);
  await frames(page);
  expect(Math.abs((await state(page)).x - unfocusedStop.x)).toBeLessThan(0.5);

  // Verify input recovers after returning to the game.
  await page.keyboard.down('ArrowLeft');
  try {
    await expect.poll(async () => unfocusedStop.x - (await state(page)).x).toBeGreaterThan(30);
  } finally {
    await page.keyboard.up('ArrowLeft');
  }
  await expect.poll(async () => (await state(page)).vx).toBe(0);
  await frames(page, 2);
  await page.screenshot({ path: testInfo.outputPath('surface.png') });
  expect(errors).toEqual([]);
  fs.writeFileSync(testInfo.outputPath('evidence.json'), JSON.stringify({
    chromium: context.browser().version(), gl, checkpoints, errors,
  }, null, 2));
});

test('ordinary Web launch works without exposing E2E state', async ({ page }) => {
  const errors = [];
  const messages = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    messages.push(message.text());
    if (message.type() === 'error' || /SCRIPT ERROR:|Parse Error:|^ERROR:/.test(message.text())) errors.push(message.text());
  });
  await page.goto('/index.html');
  await expect.poll(() => messages.some(m => m.includes('DEPTH_SURFACE_READY')), { timeout: 45000 }).toBe(true);
  await expect(page.locator('#canvas')).toBeVisible();
  expect(await state(page)).toBeUndefined();
  expect(errors).toEqual([]);
});
