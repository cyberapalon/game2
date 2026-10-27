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


test.use({ video: { mode: 'on', size: { width: 960, height: 540 } } });

async function strike(page, key = 'KeyJ', capture) {
  const hits = (await state(page)).hits_landed;
  await page.keyboard.press(key, { delay: 35 });
  if (capture) {
    await poll(page, s => s.hits_landed > hits);
    await capture();
  }
  await page.waitForTimeout(360);
}

async function fight(page, id, capture) {
  for (let tick = 0; tick < 80; tick++) {
    const s = await state(page);
    if (s.dead) throw new Error(`Died fighting ${id}: ${JSON.stringify(s)}`);
    const foe = s.enemies.find(e => e.id === id && e.health > 0);
    if (!foe) return;
    const dx = foe.x - s.x;
    if (Math.abs(dx) > 47) {
      const key = dx > 0 ? 'KeyD' : 'KeyA';
      await page.keyboard.down(key);
      await page.waitForTimeout(80);
      await page.keyboard.up(key);
    } else {
      const face = dx > 0 ? 'KeyD' : 'KeyA';
      await page.keyboard.press(face, { delay: 20 });
      await strike(page, tick % 2 ? 'KeyJ' : 'KeyX', capture);
      capture = null;
    }
  }
  throw new Error(`Enemy did not die: ${JSON.stringify(await state(page))}`);
}

test('complete episode by real keyboard: combat, death, checkpoints, boss, dash and ending', async ({ page }, info) => {
  test.setTimeout(360000);
  const errors = [], evidence = {};
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error' || /SCRIPT ERROR:|Parse Error:|^ERROR:/.test(m.text())) errors.push(m.text()); });
  const shot = async name => {
    evidence[name] = await state(page);
    fs.writeFileSync(info.outputPath('episode-checkpoints.json'), JSON.stringify(evidence, null, 2));
    await page.screenshot({path: info.outputPath(name + '.png')});
    console.log('EPISODE', name, JSON.stringify({room: evidence[name].room, hp: evidence[name].health, boss: evidence[name].boss}));
  };
  await page.goto(`${gamePath}/index.html?e2e=1`);
  await poll(page, s => s?.mode === 'title', 45000);
  await shot('01-title');
  await page.locator('#canvas').click({position: {x: 12, y: 12}});
  await page.keyboard.press('Enter');
  await poll(page, s => s.mode === 'playing' && s.grounded);
  await page.keyboard.press('Escape');
  await poll(page, s => s.mode === 'pause');
  const pausedX = (await state(page)).x;
  await page.keyboard.down('KeyD'); await page.waitForTimeout(180); await page.keyboard.up('KeyD');
  expect((await state(page)).x).toBe(pausedX);
  await shot('02-pause');
  await page.keyboard.press('Escape');
  await poll(page, s => s.mode === 'playing');
  await walk(page, 650);
  for (let i = 0; i < 4; i++) await pressE(page);
  await walk(page, 880); await jump(page, 1000); await walk(page, 1450);
  await enter(page, 'Mine', 'landing', .12, 180, 438);
  await walk(page, 285);
  await poll(page, s => s.checkpoint === 'landing');
  await shot('03-checkpoint-roots');
  await walk(page, 440); await jump(page, 530); await walk(page, 650);
  const hp = (await state(page)).health;
  await poll(page, s => s.health < hp);
  expect((await state(page)).invulnerable).toBe(true);
  const hurtHP = (await state(page)).health;
  await shot('04-receiving-damage');
  await page.waitForTimeout(250);
  expect((await state(page)).health).toBe(hurtHP);
  // Stay in the hound's range until an actual death; no debug damage API.
  for (let n = 0; n < 160 && !(await state(page)).dead; n++) {
    const s = await state(page), foe = s.enemies.find(e => e.id === 'landing_a');
    if (foe && Math.abs(foe.x - s.x) > 55) {
      await page.keyboard.press(foe.x > s.x ? 'KeyD' : 'KeyA', {delay: 75});
    }
    await page.waitForTimeout(80);
  }
  await poll(page, s => s.dead);
  await shot('05-death');
  await poll(page, s => !s.dead && s.respawn_count === 1);
  expect((await state(page)).room).toBe('landing');
  expect((await state(page)).health).toBe(6);
  await shot('06-respawn');
  await walk(page, 440); await jump(page, 530); await walk(page, 640);
  await fight(page, 'landing_a', () => shot('07-kornevik-combat'));
  expect((await state(page)).hits_landed).toBeGreaterThanOrEqual(3);
  await walk(page, 760); await jump(page, 860); await walk(page, 975);
  await fight(page, 'landing_b');
  await walk(page, 1180);
  await enter(page, 'Burrow', 'junction', .24, 175, 438);
  await fight(page, 'junction_a');
  await walk(page, 430); await jump(page, 530); await walk(page, 550); await jump(page, 685);
  await enter(page, 'Hidden', 'hollow', .27, 175, 438);
  await walk(page, 430); await jump(page, 530); await walk(page, 600);
  await poll(page, s => s.enemies.some(e => e.species === 'sporon' && e.shots > 0), 12000);
  await shot('08-sporon-combat');
  await fight(page, 'hollow_a');
  await walk(page, 740); await jump(page, 820); await jump(page, 980);
  await fight(page, 'hollow_b');
  await jump(page, 980);
  await walk(page, 940); await pressE(page);
  await poll(page, s => s.secret_found && s.note_active);
  await shot('09-memory'); await pressE(page);
  await walk(page, 650); await walk(page, 640); await jump(page, 540); await walk(page, 80);
  await enter(page, 'Back', 'junction', .24, 685, 318);
  await walk(page, 960); await fight(page, 'junction_b');
  await walk(page, 1180);
  await poll(page, s => s.checkpoint === 'junction');
  expect((await state(page)).health).toBe(6);
  await shot('10-checkpoint-heart');
  await enter(page, 'Deep', 'seal', .42, 175, 438);
  await walk(page, 350); await pressE(page);
  await poll(page, s => s.boss_active);
  expect((await state(page)).music).toBe('boss');
  let bossShot = false, phaseShot = false, jumpHeld = false, moving = '';
  const bossStart = Date.now();
  while (!(await state(page)).boss_defeated && Date.now() - bossStart < 160000) {
    const s = await state(page), boss = s.boss;
    if (s.dead) throw new Error('Boss defeated player: ' + JSON.stringify(s));
    if (boss.state === 'dead') { await page.waitForTimeout(60); continue; }
    if (!bossShot && boss.slams > 0 && boss.storms > 0) { await shot('11-boss-fight'); bossShot = true; }
    if (!phaseShot && boss.phase === 2) { await shot('12-boss-phase-two'); phaseShot = true; }
    const goal = boss.state === 'windup_storm' ? 660 : 815;
    const direction = Math.abs(s.x - goal) < 8 ? '' : s.x < goal ? 'KeyD' : 'KeyA';
    if (direction !== moving) {
      if (moving) await page.keyboard.up(moving);
      moving = direction;
      if (moving) await page.keyboard.down(moving);
    }
    if (boss.state === 'windup_slam' && boss.left < .46 && s.grounded && !jumpHeld) {
      await page.keyboard.down('Space'); jumpHeld = true;
    }
    if (jumpHeld && boss.state === 'recover') { await page.keyboard.up('Space'); jumpHeld = false; }
    if (boss.state === 'recover' && s.x > 790 && s.attack_left <= 0) {
      if (s.facing_left) await page.keyboard.press('KeyD', {delay: 18});
      await page.keyboard.press('KeyJ', {delay: 24});
    }
    await page.waitForTimeout(35);
  }
  if (moving) await page.keyboard.up(moving);
  if (jumpHeld) await page.keyboard.up('Space');
  await poll(page, s => s.boss_defeated && s.dash_unlocked && s.note_active);
  expect((await state(page)).dash_awards).toBe(1);
  expect(phaseShot && bossShot).toBe(true);
  await shot('13-dash-reward');
  await pressE(page); await poll(page, s => !s.note_active);
  await walk(page, 1110);
  await enter(page, 'Seal', 'afterheart', .56, 180, 438);
  await shot('14-open-passage');
  // A real full jump fails the gap, then the learned air dash succeeds.
  await walk(page, 320);
  await page.keyboard.down('KeyD'); await page.keyboard.down('Space');
  await poll(page, s => s.course_retries > 0);
  await page.keyboard.up('KeyD'); await page.keyboard.up('Space');
  await poll(page, s => s.grounded);
  await walk(page, 320);
  const retries = (await state(page)).course_retries;
  await page.keyboard.down('Space'); await page.keyboard.down('KeyD');
  await poll(page, s => !s.grounded && s.vy > -100 && s.x > 365);
  await page.keyboard.down('ShiftLeft');
  await poll(page, s => s.dash_count > 0);
  await page.keyboard.up('ShiftLeft');
  await poll(page, s => s.x > 670 && s.grounded);
  await page.keyboard.up('Space'); await page.keyboard.up('KeyD');
  expect((await state(page)).course_retries).toBe(retries);
  expect((await state(page)).dash_awards).toBe(1);
  await shot('15-dash-gap');
  await walk(page, 1150); await pressE(page);
  await poll(page, s => s.episode_complete && s.transitioning);
  await page.waitForTimeout(1400);
  await shot('16-final-descent');
  await poll(page, s => s.mode === 'victory');
  expect((await state(page)).depth_km).toBe(1.86);
  expect((await state(page)).depth_text).toBe('Глубина: 1.86 км');
  await shot('17-episode-complete');
  await page.keyboard.press('Enter');
  await poll(page, s => s.mode === 'playing' && s.room === 'surface');
  const reset = await state(page);
  expect(reset.dash_unlocked).toBe(false);
  expect(reset.boss_defeated).toBe(false);
  expect(reset.enemies_defeated).toBe(0);
  expect(errors).toEqual([]);
  fs.writeFileSync(info.outputPath('episode-evidence.json'), JSON.stringify({evidence, reset, errors, boss_seconds: (Date.now() - bossStart)/1000}, null, 2));
});
