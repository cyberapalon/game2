const fs = require('node:fs');
const { test, expect } = require('/workspace/.godot-cloud/tools/browser/node_modules/@playwright/test');
const gamePath = process.env.GODOT_WEB_BASE_PATH || '';
const state = page => page.evaluate(() => window.__depthE2E);
const poll = async (page, predicate, timeout = 12000) => {
  try {
    await expect.poll(async () => predicate(await state(page)), { intervals: [16], timeout }).toBe(true);
  } catch (error) {
    throw new Error(`${error.message}\nObserved physics: ${JSON.stringify(await state(page))}`);
  }
};
async function walk(page, x) {
  const before = await state(page);
  if (Math.abs(before.x - x) < 6) return;
  const sign = Math.sign(x - before.x);
  const key = sign > 0 ? 'KeyD' : 'KeyA';
  await page.keyboard.down(key);
  try {
    await page.waitForFunction(([target, direction]) => direction * (window.__depthE2E.x - target) >= -4, [x, sign], { polling: 'raf', timeout: 12000 });
  } finally { await page.keyboard.up(key); }
  await poll(page, s => s.vx === 0);
  // Key-up is delivered over the browser protocol. Correct any overshoot with
  // real short key presses; a busy renderer must not miss a nearby trigger.
  for (let attempt = 0; attempt < 10; attempt++) {
    const error = x - (await state(page)).x;
    if (Math.abs(error) <= 10) break;
    const correction = error > 0 ? 'KeyD' : 'KeyA';
    await page.keyboard.down(correction);
    try { await page.waitForTimeout(Math.max(16, Math.min(80, Math.abs(error) / 240 * 600))); }
    finally { await page.keyboard.up(correction); }
    await poll(page, s => s.vx === 0);
  }
  expect(Math.abs((await state(page)).x - x)).toBeLessThanOrEqual(12);
}
async function jump(page, x) {
  await poll(page, s => s.grounded);
  const depth = (await state(page)).depth_km;
  const sign = Math.sign(x - (await state(page)).x);
  const key = sign > 0 ? 'KeyD' : 'KeyA';
  await page.keyboard.down('Space');
  await page.keyboard.down(key);
  try {
    await poll(page, s => !s.grounded);
    expect((await state(page)).depth_km).toBe(depth);
    await page.waitForFunction(([target, direction]) => direction * (window.__depthE2E.x - target) >= -4, [x, sign], { polling: 'raf', timeout: 12000 });
  } finally {
    await page.keyboard.up('Space');
    await page.keyboard.up(key);
  }
  await poll(page, s => s.grounded && s.vx === 0);
  expect((await state(page)).depth_km).toBe(depth);
  await walk(page, x);
}
async function pressE(page) {
  // Separate physical down/up across rendered frames, including slower software WebGL.
  await page.keyboard.down('KeyE');
  await page.waitForTimeout(70);
  await page.keyboard.up('KeyE');
  await page.waitForTimeout(70);
}
async function enter(page, interaction, room, depth, spawnX, spawnY) {
  await poll(page, s => s.interaction === interaction && !s.transitioning);
  const count = (await state(page)).transition_count;
  await page.waitForTimeout(350);
  await page.keyboard.down('KeyE');
  try {
    await poll(page, s => s.transitioning);
    // Hold through the entire transition: a held key must never repeat it.
    await poll(page, s => s.room === room && !s.transitioning, 20000);
    await page.waitForTimeout(400);
  } finally { await page.keyboard.up('KeyE'); }
  await poll(page, s => s.grounded);
  const arrived = await state(page);
  expect(arrived.transition_count).toBe(count + 1);
  expect(arrived.player_count).toBe(1);
  expect(arrived.control_locked).toBe(false);
  expect(arrived.depth_km).toBe(depth);
  expect(arrived.depth_text).toBe(`Глубина: ${depth.toFixed(2)} км`);
  expect(Math.abs(arrived.x - spawnX)).toBeLessThan(1);
  expect(Math.abs(arrived.y - spawnY)).toBeLessThan(1);
}
async function landingForward(page) {
  await walk(page, 440); await jump(page, 530);
  await walk(page, 760); await jump(page, 860);
  await walk(page, 1180);
}
async function landingBack(page) {
  await walk(page, 970); await jump(page, 860);
  await walk(page, 630); await jump(page, 530);
  await walk(page, 100);
}

test('complete route: NPC, descent, all Roots rooms, secret, seal, and return', async ({ page }, info) => {
  test.setTimeout(180000);
  const errors = [];
  const checkpoints = {};
  const cancelledPck = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error' || /SCRIPT ERROR:|Parse Error:|^ERROR:/.test(message.text())) { errors.push(message.text()); console.log(message.text()); }
  });
  page.on('requestfailed', request => {
    const failure = `${request.url()}: ${request.failure().errorText}`;
    if (request.url().endsWith('/index.pck') && request.failure().errorText === 'net::ERR_ABORTED') cancelledPck.push(failure);
    else errors.push(failure);
  });
  const shot = async name => {
    checkpoints[name] = await state(page);
    await page.screenshot({ path: info.outputPath(`${name}.png`) });
  };
  await page.goto(`${gamePath}/index.html?e2e=1`);
  if (gamePath) expect(await page.evaluate(() => crossOriginIsolated)).toBe(false);
  await poll(page, s => s?.grounded, 45000);
  // Godot may cancel a redundant PCK fetch. Booted physics plus a complete
  // validated PCK response distinguish that cancellation from a failed load.
  const pck = await page.request.get(`${gamePath}/index.pck`);
  expect(pck.ok()).toBe(true);
  expect((await pck.body()).subarray(0, 4).toString()).toBe('GDPC');
  await page.locator('#canvas').click();
  await shot('surface');
  expect((await state(page)).prompt).toBe('');
  await pressE(page);
  expect((await state(page)).dialogue_active).toBe(false);
  await walk(page, 540);
  await shot('surface-with-npc');
  await walk(page, 650);
  await poll(page, s => s.prompt.includes('заговорить'));
  for (let i = 0; i < 3; i++) {
    await pressE(page);
    await poll(page, s => s.dialogue_active && s.dialogue_index === i);
    expect((await state(page)).control_locked).toBe(true);
    if (i === 0) {
      const x = (await state(page)).x;
      await page.keyboard.down('KeyD');
      await page.waitForTimeout(200);
      await page.keyboard.up('KeyD');
      expect((await state(page)).x).toBe(x);
      await shot('npc');
    }
  }
  await pressE(page);
  await poll(page, s => !s.dialogue_active && !s.control_locked);
  await walk(page, 880); await jump(page, 1000);
  await walk(page, 1450);
  await poll(page, s => s.interaction === 'Mine');
  await shot('mine-entrance');
  // Screenshot the moving shaft while held E tests re-entry protection.
  await page.keyboard.down('KeyE');
  await poll(page, s => s.transitioning && s.room === 'landing');
  await shot('descent');
  await page.keyboard.up('KeyE');
  await poll(page, s => !s.transitioning && s.grounded);
  expect((await state(page)).transition_count).toBe(1);
  expect((await state(page)).depth_km).toBe(.12);
  await walk(page, 320); await shot('roots-landing');
  await landingForward(page);
  await enter(page, 'Burrow', 'junction', .24, 175, 438);
  await walk(page, 350); await shot('roots-junction');
  await walk(page, 430); await jump(page, 530);
  await walk(page, 550); await jump(page, 685);
  await enter(page, 'Hidden', 'hollow', .27, 175, 438);
  await walk(page, 430); await jump(page, 530);
  await walk(page, 740); await jump(page, 820);
  await jump(page, 980);
  await walk(page, 940);
  await poll(page, s => s.interaction === 'Memory');
  await shot('roots-hollow');
  await pressE(page);
  await poll(page, s => s.secret_found && s.note_active);
  await shot('secret');
  await pressE(page);
  await poll(page, s => !s.note_active && !s.control_locked);
  await walk(page, 650); // Step down; the return obstacle is low enough from the floor.
  await walk(page, 640); await jump(page, 540);
  await walk(page, 80);
  await enter(page, 'Back', 'junction', .24, 685, 318);
  expect((await state(page)).secret_found).toBe(true);
  await walk(page, 1180);
  await enter(page, 'Deep', 'seal', .42, 175, 438);
  await walk(page, 380); await jump(page, 480);
  await walk(page, 660); await jump(page, 760);
  await walk(page, 1080); await shot('roots-seal');
  await walk(page, 1110); await pressE(page);
  await poll(page, s => s.note_active);
  await shot('closed-passage');
  expect((await state(page)).room).toBe('seal');
  await pressE(page);
  await page.keyboard.down('KeyD');
  try {
    await page.waitForTimeout(350);
    expect((await state(page)).x).toBeLessThan(1129);
    expect((await state(page)).room).toBe('seal');
  } finally { await page.keyboard.up('KeyD'); }
  // Full return checks reverse obstacles, every connection and surface depth reset.
  await walk(page, 860); await jump(page, 760);
  await walk(page, 570); await jump(page, 480);
  await walk(page, 80);
  await enter(page, 'Back', 'junction', .24, 1080, 438);
  await walk(page, 990); await jump(page, 900);
  await walk(page, 870); await jump(page, 740);
  await walk(page, 80);
  await enter(page, 'Back', 'landing', .12, 1090, 438);
  await landingBack(page);
  await enter(page, 'Ladder', 'surface', 0, 1350, 398);
  await shot('returned-surface');
  expect((await state(page)).secret_found).toBe(true);
  expect((await state(page)).transition_count).toBe(8);
  await walk(page, 1400);
  expect((await state(page)).vx).toBe(0);
  expect(errors).toEqual([]);
  fs.writeFileSync(info.outputPath('route-evidence.json'), JSON.stringify({ checkpoints, final: await state(page), errors, cancelledPck }, null, 2));
});
