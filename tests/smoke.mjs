import assert from 'node:assert/strict';
import { readdir, mkdir, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const corePath = process.env.PLAYWRIGHT_CORE_PATH || '/opt/homebrew/lib/node_modules/agent-browser/node_modules/playwright-core/index.mjs';
const { chromium } = await import(pathToFileURL(corePath));
const cloakRoot = resolve(homedir(), '.cloakbrowser');
const versions = (await readdir(cloakRoot)).filter(name => name.startsWith('chromium-')).sort();
const executablePath = process.env.AGENT_BROWSER_EXECUTABLE_PATH || resolve(cloakRoot, versions.at(-1), 'Chromium.app/Contents/MacOS/Chromium');
const base = process.env.PROTOTYPE_URL || 'http://127.0.0.1:4173';
const evidence = resolve('verification');
await mkdir(evidence, { recursive: true });
const browser = await chromium.launch({ executablePath, headless: true });
const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' });
const page = await context.newPage();
const errors = [];
const requests = [];
const results = [];
page.on('pageerror', error => errors.push(error.message));
page.on('request', request => requests.push(request.url()));
page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
page.setDefaultTimeout(7000);
const action = name => page.locator(`[data-action="${name}"]`).filter({ visible: true });
const click = name => action(name).first().click();
const text = () => page.locator('body').innerText();
const waitText = value => page.getByText(value, { exact: false }).first().waitFor();
const activeId = () => page.evaluate(() => document.activeElement.id);
let fixtureNumber = 0;
async function fixture(screen) {
  await page.goto(`${base}/?test=${++fixtureNumber}#${screen}`);
  await page.locator('main').waitFor({ state: 'attached' });
}
async function fresh() {
  await page.goto(base);
  await page.evaluate(() => localStorage.clear());
  await page.goto(base);
}
async function test(name, run) {
  try { await run(); results.push({ name, passed: true }); console.log(`PASS ${name}`); }
  catch (error) {
    results.push({ name, passed: false, error: error.message });
    await page.screenshot({ path: `${evidence}/failure.png`, fullPage: true });
    throw error;
  }
}
async function checkNoHorizontalOverflow() {
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
}

try {
  await test('Four tiles fit 1440×900, 1920×1080 and 1280×720 without vertical or horizontal overflow', async () => {
    await fresh();
    for (const [width, height] of [[1440, 900], [1920, 1080], [1280, 720]]) {
      await page.setViewportSize({ width, height });
      assert.equal(await page.locator('.camera-tile').count(), 4);
      const firstTile = await page.locator('.camera-tile').first().boundingBox();
      assert.ok(firstTile.y <= 112, `Home bar consumed ${firstTile.y}px at ${width}px`);
      await checkNoHorizontalOverflow();
      assert.equal(await page.evaluate(() => document.documentElement.scrollHeight > innerHeight + 1), false);
      const bottom = await page.locator('.camera-tile').last().boundingBox();
      assert.ok(bottom.y + bottom.height < height - 46);
      await page.screenshot({ path: `${evidence}/home-${width}.png` });
    }
    await page.setViewportSize({ width: 1440, height: 900 });
  });
  await test('D-pad spatial navigation, Enter fullscreen, Escape restores selected camera focus', async () => {
    await page.locator('#tile-front').focus();
    await page.keyboard.press('ArrowRight');
    assert.equal(await activeId(), 'tile-drive');
    await page.keyboard.press('ArrowDown');
    assert.equal(await activeId(), 'tile-living');
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('.full-title h1').innerText(), 'Living room');
    await page.screenshot({ path: `${evidence}/fullscreen.png` });
    await page.keyboard.press('Escape');
    assert.equal(await activeId(), 'tile-living');
  });
  await test('Compact home bar filters views and all actions stay on one TV row', async () => {
    await fresh();
    for (const width of [1920, 1440, 1280, 1024, 768]) {
      await page.setViewportSize({ width, height: 900 });
      await checkNoHorizontalOverflow();
      const bounds = await Promise.all(['#brand', '#nav-home', '#home-view', '#layout-button', '#add-button'].map(selector => page.locator(selector).boundingBox()));
      const centers = bounds.map(b => b.y + b.height / 2);
      assert.ok(Math.max(...centers) - Math.min(...centers) < 4, `Controls wrapped at ${width}px`);
      for (let i = 1; i < bounds.length; i++) assert.ok(bounds[i].x >= bounds[i - 1].x + bounds[i - 1].width, `Controls overlap at ${width}px`);
    }
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.locator('#home-view').selectOption('favorites');
    assert.equal(await page.locator('.camera-tile').count(), 2);
    assert.equal(await activeId(), 'home-view');
    await page.locator('#home-view').selectOption('all');
    assert.equal(await page.locator('.camera-tile').count(), 4);
  });
  await test('Discovery flow, required credentials, simulated preview, favourite and save to home', async () => {
    await click('start-add');
    await page.screenshot({ path: `${evidence}/add-camera.png` });
    assert.equal(await page.locator('#app').getAttribute('inert'), '');
    await click('permission');
    await click('scan');
    await waitText('Found around your home.');
    await page.screenshot({ path: `${evidence}/discovery.png` });
    await action('device').nth(1).click();
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    assert.match(await page.locator('#form-error').innerText(), /Enter a username/);
    await click('demo-credentials');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    await waitText('There you are.');
    await page.locator('#name').fill('Garage side');
    await page.locator('#room').fill('Outdoors');
    await click('draft-favorite');
    assert.equal(await page.locator('#name').inputValue(), 'Garage side');
    await page.screenshot({ path: `${evidence}/preview.png` });
    await page.getByRole('button', { name: 'Add to home', exact: true }).click();
    await waitText('Right where it belongs.');
    await click('finish');
    assert.match(await text(), /Garage side/);
    assert.match(await text(), /Page 2 of 2/);
    const stored = await page.evaluate(() => localStorage.getItem('home-cameras-design-v1'));
    assert.equal(JSON.parse(stored).cameras.length, 5);
    assert.ok(!stored.includes('demo-only') && !stored.includes('username') && !stored.includes('password'));
    await page.goto(base);
    await click('next-page');
    assert.match(await text(), /Garage side/);
  });
  await test('Manual URL validation rejects non-RTSP and embedded credentials, permits anonymous stream', async () => {
    await fixture('manual');
    await page.locator('#url').fill('https://example.com/video');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    assert.match(await page.locator('#form-error').innerText(), /valid RTSP/);
    await page.locator('#url').fill('rtsp://viewer:secret@192.168.1.55/stream');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    assert.match(await page.locator('#form-error').innerText(), /separate fields/);
    await page.locator('#url').fill('rtsp://192.168.1.55:554/stream');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    await waitText('There you are.');
  });
  await test('Wrong-password outcome, retry with corrected outcome, unreachable outcome', async () => {
    await fixture('credentials');
    await click('demo-credentials');
    await page.locator('#sim-outcome').selectOption('auth');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    await waitText('The camera is locked.');
    await page.screenshot({ path: `${evidence}/wrong-password.png` });
    await click('retry-credentials');
    await page.locator('#sim-outcome').selectOption('unreachable');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    await waitText('We couldn’t reach this camera.');
    await click('retry-credentials');
    await page.locator('#sim-outcome').selectOption('success');
    await page.getByRole('button', { name: 'Test connection', exact: true }).click();
    await waitText('There you are.');
  });
  await test('Scan cancellation stops pending transitions, no-results outcome works', async () => {
    await fixture('add');
    await click('permission');
    await click('scan');
    await click('manual');
    await page.waitForTimeout(2100);
    assert.equal(await page.locator('#dialog-title').innerText(), 'Add a camera you know.');
    await fixture('add');
    await click('permission');
    await click('scan');
    await page.locator('#sim-outcome').selectOption('none');
    await waitText('No cameras found. Yet.');
  });
  await test('Edit preserves typed values across favourite toggle; reorder and removal cancellation', async () => {
    await fixture('manage');
    await page.locator('#edit-front').click();
    await page.locator('#name').fill('Main entrance');
    await click('draft-favorite');
    assert.equal(await page.locator('#name').inputValue(), 'Main entrance');
    await page.getByRole('button', { name: 'Save changes', exact: true }).click();
    assert.match(await text(), /Main entrance/);
    await page.locator('#down-front').click();
    assert.equal(await page.locator('.manage-info h3').nth(1).innerText(), 'Main entrance');
    await page.screenshot({ path: `${evidence}/manage.png` });
    await page.locator('#edit-front').click();
    await click('confirm-remove');
    await click('keep-camera');
    assert.equal(await page.locator('#name').inputValue(), 'Main entrance');
    await click('confirm-remove');
    await click('remove-camera');
    assert.equal(await page.locator('.manage-row').count(), 3);
  });
  await test('Six-slot layout, settings persistence and quality/audio UI feedback', async () => {
    await fresh();
    await click('layout');
    await page.locator('#layout-6').click();
    await click('close');
    assert.equal(await page.locator('.empty-slot').count(), 2);
    await click('settings');
    await click('keep-awake');
    await page.screenshot({ path: `${evidence}/settings.png` });
    await page.goto(base);
    await click('settings');
    assert.equal(await page.locator('#keep-awake').getAttribute('aria-checked'), 'false');
    await click('home');
    await page.locator('#tile-front').click();
    await click('quality');
    await page.locator('[data-value="Low bandwidth"]').click();
    assert.match(await page.locator('#quality-button').innerText(), /Low bandwidth/);
    await click('audio');
    assert.equal(await page.locator('#audio-button').getAttribute('aria-pressed'), 'true');
    assert.match(await page.locator('#toast').innerText(), /no sound/);
  });
  await test('Network recovery and individual camera retry', async () => {
    await fixture('network-offline');
    await click('retry-network');
    await page.waitForFunction(() => !document.querySelector('.banner'));
    assert.equal(await page.locator('.camera-tile.offline').count(), 0);
    await fixture('fullscreen-offline');
    await click('retry-camera');
    assert.equal(await page.locator('.full-offline').count(), 0);
  });
  await test('Dialog Tab trap, close focus return and text caret arrow preservation', async () => {
    await fresh();
    await page.locator('#add-button').click();
    const buttons = page.locator('[role="dialog"] button');
    await buttons.last().focus();
    await page.keyboard.press('Tab');
    assert.equal(await page.evaluate(() => document.activeElement.dataset.action), 'back');
    await page.keyboard.press('Shift+Tab');
    assert.equal(await page.evaluate(() => document.activeElement.dataset.action), 'manual');
    await click('close');
    assert.equal(await activeId(), 'add-button');
    await fixture('manual');
    await page.locator('#url').focus();
    await page.keyboard.press('ArrowLeft');
    assert.equal(await activeId(), 'url');
  });
  await test('Empty-slot setup restores its initiating focus and edited fields stay visible', async () => {
    await fixture('six');
    await page.locator('#empty-slot-1').click();
    await click('close');
    assert.equal(await activeId(), 'empty-slot-1');
    await fixture('edit');
    await click('draft-favorite');
    const focused = await page.locator('#draft-favorite').boundingBox();
    const body = await page.locator('.sheet-body').boundingBox();
    assert.ok(focused.y >= body.y && focused.y + focused.height <= body.y + body.height + 1);
  });
  await test('All review links render, all 28 states fit horizontally at 1440px and 390px', async () => {
    await fresh();
    await click('review');
    const screens = await page.locator('[data-screen]').evaluateAll(nodes => nodes.map(n => n.dataset.screen));
    assert.equal(screens.length, 28);
    await page.screenshot({ path: `${evidence}/screen-index.png` });
    for (const width of [1440, 390]) {
      await page.setViewportSize({ width, height: width === 390 ? 844 : 900 });
      for (const screen of screens) {
        await fixture(screen);
        await checkNoHorizontalOverflow();
        if (await page.locator('[role="dialog"]').count()) {
          assert.ok((await page.locator('#dialog-title').innerText()).length > 0, screen);
          assert.equal(await page.evaluate(() => document.querySelector('.sheet-body').scrollWidth > document.querySelector('.sheet-body').clientWidth + 1), false, screen);
        }
      }
    }
    await fixture('home');
    await page.screenshot({ path: `${evidence}/home-mobile.png`, fullPage: true });
    await fixture('manual');
    await page.screenshot({ path: `${evidence}/manual-mobile.png` });
  });
  await test('No JavaScript/resource errors and no external camera or image requests', async () => {
    assert.deepEqual(errors, []);
    assert.ok(requests.every(url => url.startsWith(base)), requests.filter(url => !url.startsWith(base)).join('\n'));
  });
} finally {
  await writeFile(`${evidence}/results.json`, JSON.stringify({ date: new Date().toISOString(), results, errors }, null, 2));
  await browser.close();
}
