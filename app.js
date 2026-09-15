'use strict';

const paths = {
  home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1Z"/><circle cx="12" cy="14" r="3"/>',
  camera: '<rect x="3" y="6" width="13" height="12" rx="3"/><path d="m16 10 5-3v10l-5-3"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  arrow: '<path d="m9 5 7 7-7 7"/>',
  back: '<path d="m14 5-7 7 7 7"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  wifi: '<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8.5 15.5a6 6 0 0 1 7 0"/><circle cx="12" cy="20" r=".8"/>',
  offline: '<path d="m3 3 18 18M2 8a16 16 0 0 1 3-2M9 4a16 16 0 0 1 13 4M5 12a11 11 0 0 1 3-2M13 9a11 11 0 0 1 6 3M8.5 15.5a6 6 0 0 1 7 0"/><circle cx="12" cy="20" r=".8"/>',
  shield: '<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6Z"/><path d="m8 12 3 3 5-6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3"/>',
  star: '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z"/>',
  expand: '<path d="M4 9V4h5M15 4h5v5M20 15v5h-5M9 20H4v-5"/>',
  link: '<path d="m10 13 4-4M9 16l-2 2a4 4 0 0 1-6-6l4-4a4 4 0 0 1 6 0M15 8l2-2a4 4 0 0 1 6 6l-4 4a4 4 0 0 1-6 0" transform="translate(0 -1) scale(.95)"/>',
  eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  mute: '<path d="M11 4 6 8H3v8h3l5 4ZM16 9l5 6M21 9l-5 6"/>',
  volume: '<path d="M11 4 6 8H3v8h3l5 4ZM16 8a6 6 0 0 1 0 8M19 4a11 11 0 0 1 0 16"/>',
  settings: '<path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3" fill="currentColor" stroke="none"/><circle cx="15" cy="17" r="3" fill="currentColor" stroke="none"/>',
  retry: '<path d="M20 10a8 8 0 1 0-1 7M20 4v6h-6"/>',
  up: '<path d="m5 14 7-7 7 7"/>',
  down: '<path d="m5 10 7 7 7-7"/>',
  trash: '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7v.1"/>',
  monitor: '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>',
};
const icon = name => `<svg viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.camera}</svg>`;
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const storageKey = 'home-cameras-design-v1';
const images = ['front-door', 'driveway', 'garden', 'living-room'];
const initialCameras = [
  { id: 'front', name: 'Front door', room: 'Entrance', image: 'front-door', favorite: true },
  { id: 'drive', name: 'Driveway', room: 'Outdoors', image: 'driveway', favorite: true },
  { id: 'garden', name: 'Garden', room: 'Outdoors', image: 'garden', favorite: false },
  { id: 'living', name: 'Living room', room: 'Indoors', image: 'living-room', favorite: false },
];
const devices = [
  { name: 'Entrance camera', model: 'Hikvision IP camera', address: '192.168.1.21', image: 'front-door' },
  { name: 'Garage camera', model: 'Reolink IP camera', address: '192.168.1.28', image: 'driveway' },
  { name: 'Patio camera', model: 'TP-Link IP camera', address: '192.168.1.34', image: 'garden' },
];
let stored;
try {
  stored = JSON.parse(localStorage.getItem(storageKey));
  if (!stored || !Array.isArray(stored.cameras) || stored.cameras.length > 48 || stored.cameras.some(c =>
    typeof c.id !== 'string' || !/^[\w-]+$/.test(c.id) || typeof c.name !== 'string' || !c.name.trim() || c.name.length > 60 ||
    typeof c.room !== 'string' || c.room.length > 40 || !images.includes(c.image) || typeof c.favorite !== 'boolean') ||
    new Set(stored.cameras.map(c => c.id)).size !== stored.cameras.length) stored = null;
} catch { stored = null; }
const state = {
  cameras: stored?.cameras ?? structuredClone(initialCameras),
  layout: stored?.layout === 6 ? 6 : 4,
  keepAwake: stored?.keepAwake !== false,
  quality: ['Automatic', 'High quality', 'Low bandwidth'].includes(stored?.quality) ? stored.quality : 'Automatic',
  page: 'home', modal: null, filter: 'all', pageNumber: 0, selected: null,
  offline: null, network: 'connected', audio: false, draft: {}, method: 'auto',
  outcome: 'success', scanOutcome: 'found', frozen: false, returnFocus: null,
  previousReview: null, fullscreenOrigin: 'home', editOrigin: null, newlyAdded: null,
};
let timer;
let toastTimer;

function save() {
  try {
    // Only demo metadata is persisted. Credential and connection drafts never enter storage.
    localStorage.setItem(storageKey, JSON.stringify({
      cameras: state.cameras.map(({ id, name, room, image, favorite }) => ({ id, name, room, image, favorite })),
      layout: state.layout, keepAwake: state.keepAwake, quality: state.quality,
    }));
  } catch { toast('Browser storage is unavailable. Changes last for this visit only.'); }
}
function toast(message) {
  clearTimeout(toastTimer);
  document.getElementById('toast').textContent = message;
  toastTimer = setTimeout(() => { document.getElementById('toast').textContent = ''; }, 4000);
}
function button(label, action, style = '', symbol = '', extra = '') {
  return `<button class="btn ${style}" data-action="${action}" ${extra}>${symbol ? icon(symbol) : ''}${label}</button>`;
}
function intro(title, description, step = '') {
  return `<div class="sheet-intro">${step ? `<span class="step-label">${step}</span>` : ''}<h2 id="dialog-title">${title}</h2><p>${description}</p></div>`;
}
function setFocus(id) {
  const root = state.modal ? document.getElementById('overlay') : document;
  const target = (id && document.getElementById(id)) || root.querySelector('[data-autofocus]') || root.querySelector('button:not(:disabled), input, select');
  if (target && !target.closest('[inert]')) {
    target.focus({ preventScroll: true });
    if (state.modal) target.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'instant' });
  }
}
function showModal(name, focus) {
  if (!state.modal) state.returnFocus = document.activeElement?.id;
  state.modal = name;
  state.frozen = false;
  render(focus);
}
function closeModal() {
  if (state.modal === 'review' && state.previousReview) {
    state.modal = state.previousReview.modal;
    state.frozen = state.previousReview.frozen;
    state.previousReview = null;
  } else {
    state.modal = null;
    state.draft = {};
    state.editOrigin = null;
  }
  render(state.modal ? null : state.returnFocus);
}
function startAdd() {
  state.draft = { name: '', room: '', url: '', username: '', password: '', image: 'front-door', favorite: false };
  state.outcome = 'success';
  state.scanOutcome = 'found';
  state.method = 'auto';
  showModal('add');
}
function chooseDevice(index) {
  const device = devices[index];
  state.draft = { ...state.draft, name: device.name, room: '', address: device.address, model: device.model, image: device.image, url: `rtsp://${device.address}:554/stream1`, username: '', password: '' };
  state.method = 'auto';
  showModal('credentials', 'username');
}
function currentCamera() { return state.cameras.find(c => c.id === state.selected) || state.cameras[0]; }
function isOffline(camera) { return state.network !== 'connected' || state.offline === camera.id; }
function topbar() {
  const time = new Date().toLocaleTimeString('en', { hour: 'numeric', minute: '2-digit' });
  const date = new Date().toLocaleDateString('en', { weekday: 'long', month: 'short', day: 'numeric' });
  const homeView = state.page === 'home';
  const connected = state.cameras.filter(c => !isOffline(c)).length;
  return `<header class="topbar ${homeView ? 'home-topbar' : ''}">
    <button class="brand" data-action="home" id="brand" aria-label="Home Cameras home"><span class="brand-mark icon">${icon('home')}</span>${homeView ? `<span class="brand-text"><span>Home Cameras</span><small>${state.cameras.length ? `${connected} of ${state.cameras.length} connected` : 'Welcome home'}</small></span>` : 'Home Cameras'}</button>
    <nav class="main-nav" aria-label="Main navigation">${[['home', 'Live view'], ['manage', 'Cameras'], ['settings', 'Settings']].map(([page, name]) => `<button id="nav-${page}" class="nav-item ${state.page === page ? 'active' : ''}" data-action="${page}" ${state.page === page ? 'aria-current="page"' : ''}>${name}</button>`).join('')}</nav>
    ${homeView ? `<div class="home-tools"><div class="view-select"><select id="home-view" name="home-view" aria-label="Camera view"><option value="all" ${state.filter === 'all' ? 'selected' : ''}>All cameras</option><option value="favorites" ${state.filter === 'favorites' ? 'selected' : ''}>Favourites</option></select>${icon('down')}</div>${button('<span class="action-label">Layout</span>', 'layout', '', 'grid', 'id="layout-button" aria-label="Layout" title="Layout"')}${button('<span class="action-label">Add camera</span>', 'start-add', 'primary', 'plus', 'id="add-button" aria-label="Add camera" title="Add camera"')}</div>` : ''}
    <div class="clock">${time}${homeView ? '' : `<small>${date}</small>`}</div>
  </header>`;
}
function footer() {
  return `<footer class="app-footer"><div class="key-hints"><span><kbd>↑ ↓ ← →</kbd> Navigate</span><span><kbd>OK</kbd> Select</span><span><kbd>Back</kbd> Return</span></div><span class="footer-network">${icon(state.network === 'connected' ? 'shield' : 'offline')}${state.network === 'connected' ? 'Local network only' : 'Network unavailable'}${state.page === 'home' ? '<span aria-hidden="true"> · </span> Grid muted' : ''}<span aria-hidden="true"> · </span> Sample stills</span></footer>`;
}
function tile(camera, index) {
  const offline = isOffline(camera);
  const reconnecting = state.network === 'reconnecting';
  return `<button class="camera-tile ${offline ? 'offline' : ''}" id="tile-${esc(camera.id)}" data-action="fullscreen" data-id="${esc(camera.id)}" aria-label="${esc(camera.name)}, ${offline ? reconnecting ? 'reconnecting' : 'offline' : 'sample live view'}. Open fullscreen" ${index === 0 ? 'data-autofocus' : ''}>
    <img src="assets/${camera.image}.jpg" alt="" draggable="false">
    <span class="tile-top"><span class="status-pill ${offline ? 'warn' : ''}"><span class="dot"></span>${offline ? reconnecting ? 'Reconnecting' : 'Offline' : 'Live · Demo'}</span>${camera.favorite ? icon('star') : ''}</span>
    ${offline ? `<span class="tile-failure">${icon(reconnecting ? 'retry' : 'offline')}<span>${reconnecting ? 'Connecting to your camera…' : 'Camera unavailable'}</span></span>` : ''}
    <span class="tile-bottom"><span><span class="camera-name">${esc(camera.name)}</span><span class="camera-room">${offline ? 'Last image · 2 minutes ago' : esc(camera.room || 'Unassigned')}</span></span><span class="expand-hint">${icon('expand')}</span></span>
  </button>`;
}
function emptyHome(favorites = false) {
  return `<section class="empty-home"><div class="empty-symbol">${icon(favorites ? 'star' : 'home')}</div><h2>${favorites ? 'Keep your favourites close.' : 'A home for your cameras.'}</h2><p>${favorites ? 'Mark a camera as a favourite in its settings to see it here.' : 'Add your first camera. Then see the places that matter, together on one screen.'}</p>${button(favorites ? 'Manage cameras' : 'Add your first camera', favorites ? 'manage' : 'start-add', 'primary', favorites ? 'camera' : 'plus', 'data-autofocus')}<span class="empty-note">${icon('shield')}No account. No cloud. Just your home.</span></section>`;
}
function home() {
  const cameras = state.cameras.filter(c => state.filter === 'all' || c.favorite);
  const pages = Math.max(1, Math.ceil(cameras.length / state.layout));
  state.pageNumber = Math.min(state.pageNumber, pages - 1);
  const visible = cameras.slice(state.pageNumber * state.layout, (state.pageNumber + 1) * state.layout);
  return `<h1 class="sr-only">${state.cameras.length ? state.filter === 'favorites' ? 'Favourite cameras' : 'All cameras' : 'Welcome home'}</h1>
    ${state.network !== 'connected' ? `<div class="banner" role="status">${icon('offline')}<span>${state.network === 'reconnecting' ? 'Reconnecting to your network. Camera previews will return shortly.' : 'Your TV is offline. Check its Wi-Fi or Ethernet connection.'}</span>${state.network === 'offline' ? '<button data-action="retry-network">Try again</button>' : ''}</div>` : ''}
    ${visible.length ? `<div class="camera-grid ${state.layout === 6 ? 'six' : ''}" style="--rows:${state.layout === 6 ? 2 : Math.ceil(visible.length / 2)}">${visible.map(tile).join('')}${state.layout === 6 && visible.length < 6 ? Array.from({ length: 6 - visible.length }, (_, index) => `<button class="empty-slot" id="empty-slot-${index}" data-action="start-add">${icon('plus')}Add camera</button>`).join('') : ''}</div>` : emptyHome(state.cameras.length > 0)}
    ${pages > 1 ? `<div class="pagination">${button('Previous', 'prev-page', '', 'back', state.pageNumber === 0 ? 'disabled' : '')}<span>Page ${state.pageNumber + 1} of ${pages}</span>${button('Next', 'next-page', '', 'arrow', state.pageNumber === pages - 1 ? 'disabled' : '')}</div>` : ''}`;
}
function manage() {
  return `<div class="page-heading"><div><h1>Your cameras</h1><p>Make every view your own.</p></div><div class="heading-actions">${button('Add camera', 'start-add', 'primary', 'plus', 'id="add-button"')}</div></div>${state.cameras.length ? `<div class="manage-list">${state.cameras.map((c, i) => `<div class="manage-row"><span class="reorder-number">${i + 1}</span><img class="manage-thumb" src="assets/${c.image}.jpg" alt=""><div class="manage-info"><h3>${esc(c.name)}</h3><p>${esc(c.room || 'Unassigned')} ${c.favorite ? ' · Favourite' : ''}</p></div><div class="actions"><button id="up-${c.id}" class="icon-btn" data-action="move-up" data-id="${c.id}" aria-label="Move ${esc(c.name)} up" ${i === 0 ? 'disabled' : ''}>${icon('up')}</button><button id="down-${c.id}" class="icon-btn" data-action="move-down" data-id="${c.id}" aria-label="Move ${esc(c.name)} down" ${i === state.cameras.length - 1 ? 'disabled' : ''}>${icon('down')}</button>${button('Edit camera', 'edit', '', '', `data-id="${c.id}" id="edit-${c.id}"`)}</div></div>`).join('')}</div><p class="muted small">Use the arrows to change the order on your home screen.</p>` : emptyHome()}`;
}
function settings() {
  return `<div class="page-heading"><div><h1>Make yourself at home.</h1><p>A few preferences. A quieter way to keep an eye on things.</p></div></div><div class="settings-layout"><div>
    <section class="settings-section"><h3>Display</h3><button class="setting-line" data-action="layout" id="settings-layout"><span>Home layout</span><span>${state.layout} camera tiles ${icon('arrow')}</span></button><button class="switch-row" role="switch" aria-checked="${state.keepAwake}" data-action="keep-awake" id="keep-awake"><span><strong>Keep the screen awake</strong><small>While you're viewing cameras in the app</small></span><span class="switch ${state.keepAwake ? 'on' : ''}"></span></button></section>
    <section class="settings-section"><h3>Viewing</h3><button class="setting-line" data-action="quality" id="settings-quality"><span>Fullscreen quality</span><span>${state.quality} ${icon('arrow')}</span></button><div class="setting-line"><span>Grid audio</span><span>Always muted ${icon('mute')}</span></div><div class="setting-line"><span>On app launch</span><span>Saved camera grid ${icon('home')}</span></div></section>
    <p class="muted small">These preferences demonstrate the intended app behaviour.<br>This browser prototype cannot control your TV or camera streams.</p>
    </div><aside class="privacy-card">${icon('shield')}<h3>Home stays home.</h3><p>The app is designed to connect directly to cameras on your network. No account or cloud subscription required.</p><p class="small">Design reference 01<br>Sample imagery. Simulated connections.</p></aside></div>`;
}
function fullscreen() {
  const camera = currentCamera();
  const offline = isOffline(camera);
  return `<main class="full-view ${offline ? 'offline' : ''}"><img class="full-image" src="assets/${camera.image}.jpg" alt="Sample residential view for ${esc(camera.name)}"><header class="full-top"><div class="full-title"><button class="icon-btn" data-action="exit-fullscreen" aria-label="Back to camera grid" id="exit-fullscreen">${icon('back')}</button><div><h1>${esc(camera.name)}</h1><p>${esc(camera.room || 'Unassigned')} · ${offline ? 'Last image, 2 minutes ago' : 'Main stream preview'}</p></div></div><span class="status-pill ${offline ? 'warn' : ''}"><span class="dot"></span>${offline ? 'Offline' : 'Live · Demo'}</span></header>
    ${offline ? `<section class="full-offline"><div class="state-icon warn">${icon('offline')}</div><h2>This camera is taking a moment.</h2><p class="muted">Check its power and network connection.</p>${button('Try again', 'retry-camera', 'primary', 'retry', 'data-autofocus')}</section>` : ''}
    <div class="full-bottom"><div class="full-controls"><div class="control-dock">${button('Previous', 'prev-camera', '', 'back', state.cameras.length < 2 ? 'disabled' : '')}${button(state.audio ? 'Audio on' : 'Audio off', 'audio', '', state.audio ? 'volume' : 'mute', `id="audio-button" aria-pressed="${state.audio}" ${!offline ? 'data-autofocus' : ''}`)}${button(state.quality === 'Automatic' ? 'Auto quality' : state.quality, 'quality', '', 'monitor', 'id="quality-button"')}${button('Settings', 'edit', '', 'settings', `data-id="${camera.id}" id="edit-${camera.id}"`)}${button('Next', 'next-camera', '', 'arrow', state.cameras.length < 2 ? 'disabled' : '')}</div></div><div class="full-note"><span><kbd>Back</kbd> Return to your cameras</span><span>Sample still · Audio and quality controls are simulated</span></div></div></main>`;
}
function field(name, label, placeholder = '', type = 'text', hint = '') {
  const value = state.draft[name] ?? '';
  return `<div class="field"><label for="${name}">${label}</label><div class="${type === 'password' ? 'password-field' : ''}"><input id="${name}" name="${name}" type="${type}" value="${esc(value)}" placeholder="${esc(placeholder)}" autocomplete="off" spellcheck="false" maxlength="${name === 'name' ? 60 : name === 'room' ? 40 : 300}" ${hint ? `aria-describedby="hint-${name}"` : ''}>${type === 'password' ? `<button type="button" data-action="show-password" aria-label="Show password" aria-pressed="false">${icon('eye')}</button>` : ''}</div>${hint ? `<p class="hint" id="hint-${name}">${hint}</p>` : ''}</div>`;
}
function simulatedOutcome(scan = false) {
  const options = scan ? [['found', 'Devices found'], ['none', 'No devices found'], ['network', 'Network unavailable']] : [['success', 'Successful connection'], ['auth', 'Wrong credentials'], ['unreachable', 'Camera unreachable']];
  return `<div class="sim-control"><label for="sim-outcome">Prototype outcome</label><select id="sim-outcome" name="${scan ? 'scan-outcome' : 'test-outcome'}">${options.map(([value, label]) => `<option value="${value}" ${value === (scan ? state.scanOutcome : state.outcome) ? 'selected' : ''}>${label}</option>`).join('')}</select></div>`;
}
function connectionForm(manual = false, edit = false) {
  return `<form id="connection-form" data-form="${edit ? 'edit' : 'connect'}" novalidate><div class="form-error" id="form-error" role="alert"></div>
    ${edit ? field('name', 'Camera name', 'e.g. Front door') + field('room', 'Room or area', 'e.g. Entrance') : ''}
    ${manual || edit ? field('url', 'RTSP address', 'rtsp://192.168.1.21:554/stream1', 'text', 'Enter the stream address without a username or password.') : `<div class="info-box"><strong>${esc(state.draft.model || 'IP camera')}</strong><br>${esc(state.draft.address || '192.168.1.21')}</div>`}
    ${field('username', `Username${manual || edit ? ' · optional' : ''}`, 'Camera username')}${field('password', `Password${manual || edit ? ' · optional' : ''}`, 'Camera password', 'password')}
    ${edit ? `<button type="button" class="switch-row" role="switch" aria-checked="${state.draft.favorite}" data-action="draft-favorite" id="draft-favorite"><span><strong>Favourite camera</strong><small>Include in your favourites view</small></span><span class="switch ${state.draft.favorite ? 'on' : ''}"></span></button><div style="height:22px"></div>` : '<button type="button" class="demo-fill" data-action="demo-credentials">Use sample credentials</button>'}
    ${button(edit ? 'Save changes' : 'Test connection', '', 'primary full', edit ? 'check' : 'arrow', 'type="submit"')}
    ${edit ? '<p class="muted small" style="margin-top:13px">Only demo names, areas and favourites are saved. Connection edits are simulated.</p>' + button('Remove camera', 'confirm-remove', 'danger full', 'trash', 'type="button" style="margin-top:24px"') : simulatedOutcome()}
  </form>`;
}
function stateMessage(title, message, symbol = 'info', actions = '', warning = false) {
  return `<div class="state-center"><div class="state-icon ${warning ? 'warn' : ''}">${icon(symbol)}</div><h2 id="dialog-title">${title}</h2><p>${message}</p><div class="actions">${actions}</div></div>`;
}
const screenGroups = [
  ['Live view', [['home', 'Four-camera home'], ['six', 'Six-slot layout'], ['favorites', 'Favourites'], ['empty', 'First launch'], ['fullscreen', 'Fullscreen camera'], ['camera-offline', 'Offline camera'], ['fullscreen-offline', 'Fullscreen offline'], ['network-offline', 'TV network lost'], ['reconnecting', 'Reconnecting']]],
  ['Add a camera', [['add', 'Choose setup method'], ['permission', 'Network permission'], ['permission-denied', 'Permission denied'], ['scanning', 'Searching the network'], ['results', 'Discovered devices'], ['none', 'No devices found'], ['credentials', 'Camera credentials'], ['manual', 'Manual RTSP setup']]],
  ['Connection & finish', [['testing', 'Testing connection'], ['auth-error', 'Wrong credentials'], ['unreachable', 'Camera unreachable'], ['preview', 'Preview & name'], ['success', 'Camera added']]],
  ['Manage & preferences', [['manage', 'Manage cameras & reorder'], ['edit', 'Edit camera'], ['remove', 'Confirm removal'], ['settings', 'App settings'], ['layout', 'Choose layout'], ['quality', 'Fullscreen quality']]],
];
function modalContent() {
  switch (state.modal) {
    case 'add': return intro('Bring your cameras home.', 'Find cameras nearby, or add one with its stream address.') +
      `<button class="choice-card" data-action="permission" data-autofocus>${icon('wifi')}<span><strong>Find on my network</strong><small>Discover compatible cameras connected to the same network as your TV.</small><span class="tag">Recommended</span></span>${icon('arrow')}</button><button class="choice-card" data-action="manual">${icon('link')}<span><strong>Add with an RTSP address</strong><small>For cameras you already know, or ones that don't appear in discovery.</small></span>${icon('arrow')}</button><div class="info-box">Your camera needs to support <strong>RTSP</strong> for live viewing. Automatic discovery uses <strong>ONVIF</strong>.</div>`;
    case 'permission': return intro('Find cameras nearby.', 'The Android app will need access to your local network to discover and connect to cameras.', '1 of 3 · Find your camera') +
      `<div class="state-icon" style="margin:35px auto">${icon('wifi')}</div><div class="info-box">On supported Android versions, a system permission dialog follows this explanation. Your camera views stay on your network.</div>${button('Allow local network access', 'scan', 'primary full', 'wifi', 'data-autofocus')}${button('Not now', 'permission-denied', 'subtle full')}<p class="muted small" style="margin-top:16px">Design simulation. No browser or Android permission is requested here.</p>`;
    case 'permission-denied': return stateMessage('Network access is needed.', 'Both discovery and manual camera connections need local-network access. You can allow it when you are ready.', 'lock', button('Allow network access', 'scan', 'primary', 'wifi', 'data-autofocus') + button('Return home', 'cancel-setup', 'subtle'));
    case 'scanning': return intro('Looking around your home.', 'Searching for ONVIF cameras on your local network.', '1 of 3 · Find your camera') + `<div class="state-center"><div class="radar">${icon('wifi')}</div><p>Keep your cameras powered on and connected to the same network.</p><ul class="checklist"><li>${icon('check')}Local network available</li><li>${icon('retry')}Looking for compatible devices…</li></ul></div>${state.frozen ? button('Show discovered cameras', 'results', 'primary full') : ''}${button('Enter an address instead', 'manual', 'subtle full')}${simulatedOutcome(true)}`;
    case 'results': return intro('Found around your home.', 'Select a camera to connect. You can name it in the next step.', '1 of 3 · Find your camera') + `<div class="list-caption"><span>3 sample devices found</span><span>ONVIF</span></div>${devices.map((d, i) => `<button class="device-row" data-action="device" data-index="${i}" ${i === 0 ? 'data-autofocus' : ''}><span class="device-symbol">${icon('camera')}</span><span><strong>${d.name}</strong><small>${d.model}<br>${d.address}</small></span>${icon('arrow')}</button>`).join('')}<div class="info-box">Not seeing your camera? Check that ONVIF is enabled in its settings, or add its RTSP address manually.</div><div class="actions">${button('Search again', 'scan', '', 'retry')}${button('Add manually', 'manual', 'subtle')}</div>`;
    case 'none': return stateMessage('No cameras found. Yet.', 'Make sure your cameras are powered on, ONVIF is enabled, and your TV is on the same network.', 'camera', button('Search again', 'scan', 'primary', 'retry', 'data-autofocus') + button('Add with an RTSP address', 'manual', '', 'link')) + `<div class="info-box">Guest Wi-Fi and separate camera networks can block discovery. A camera connected through an NVR may need the NVR's address.</div>`;
    case 'credentials': return intro('A key to your camera.', 'Use the local camera account, which may be different from your camera app login.', '2 of 3 · Connect securely') + connectionForm();
    case 'manual': return intro('Add a camera you know.', 'Enter its RTSP address. Add credentials if the camera requires them.', '2 of 3 · Connect your camera') + connectionForm(true);
    case 'testing': return intro('Making the connection.', 'Checking the camera before adding it to your home.', '2 of 3 · Connect your camera') + `<div class="state-center"><div class="radar">${icon('camera')}</div><ul class="checklist"><li>${icon('check')}Stream address accepted</li><li>${icon('retry')}Checking camera access</li><li>${icon('camera')}Waiting for the first image</li></ul></div>${state.frozen ? button('Show preview', 'preview', 'primary full') : ''}<p class="muted small">Simulated check. No connection is made to this address.</p>`;
    case 'auth-error': return stateMessage('The camera is locked.', 'The username or password was not accepted. Check the local camera account and try again.', 'lock', button('Edit credentials', 'retry-credentials', 'primary', 'back', 'data-autofocus') + button('Choose another camera', 'results', 'subtle'), true) + `<div class="info-box">Some cameras use a separate ONVIF account. Check your camera's local access settings.</div>`;
    case 'unreachable': return stateMessage('We couldn’t reach this camera.', 'Check its power, address and network connection. If it uses a custom RTSP port, include it in the address.', 'offline', button('Edit connection', 'retry-credentials', 'primary', 'back', 'data-autofocus') + button('Try again', 'test-again', '', 'retry'), true);
    case 'preview': return intro('There you are.', 'Give this view a name so it feels right at home.', '3 of 3 · Make it yours') + `<div class="preview-image setup-preview"><img src="assets/${state.draft.image || 'front-door'}.jpg" alt="Sample camera preview"><span class="status-pill"><span class="dot"></span>Preview · Sample still</span></div><div class="preview-meta"><span>Connection successful · Simulated</span><span>H.264 demo</span></div><form data-form="add" novalidate><div class="form-error" id="form-error" role="alert"></div><div class="preview-fields">${field('name', 'Camera name', 'e.g. Front door')}${field('room', 'Area · optional', 'e.g. Entrance')}</div><button type="button" class="switch-row" role="switch" aria-checked="${state.draft.favorite}" data-action="draft-favorite" id="draft-favorite"><span><strong>Add to favourites</strong><small>Keep this view easy to find</small></span><span class="switch ${state.draft.favorite ? 'on' : ''}"></span></button>${button('Add to home', '', 'primary full', 'plus', 'type="submit" style="margin-top:24px"')}</form>`;
    case 'success': return stateMessage('Right where it belongs.', `<strong>${esc(state.draft.name || 'Front door')}</strong> is now on your home screen. It will be there the next time you open the app.`, 'check', button('View my cameras', 'finish', 'primary', 'grid', 'data-autofocus') + button('Add another camera', 'start-add', 'subtle', 'plus')) + `<div class="preview-image"><img src="assets/${state.draft.image || 'front-door'}.jpg" alt="Sample view for the added camera"></div>`;
    case 'edit': return intro('A view of your own.', 'Update the name, area or connection details for this camera.') + connectionForm(true, true);
    case 'remove': return stateMessage('Remove this camera?', `<strong>${esc(state.draft.name)}</strong> will be removed from Home Cameras. This does not change the camera itself.`, 'trash', button('Keep camera', 'keep-camera', 'primary', '', 'data-autofocus') + button('Remove camera', 'remove-camera', 'danger', 'trash'), true);
    case 'layout': return intro('Room for every view.', 'Choose how many camera tiles to show on each page.') + `<div class="layout-choices">${[4, 6].map(n => `<button class="layout-choice ${state.layout === n ? 'selected' : ''}" data-action="set-layout" data-value="${n}" aria-pressed="${state.layout === n}" id="layout-${n}"><span class="mini-grid ${n === 6 ? 'six' : ''}">${'<span></span>'.repeat(n)}</span><span class="selection"><strong>${n} cameras</strong>${state.layout === n ? icon('check') : ''}</span><small>${n === 4 ? 'A little more detail' : 'A little more in view'}</small></button>`).join('')}</div><div class="info-box">Four is the default. Extra cameras appear on another page. Actual simultaneous playback capacity will be tested on your TV during implementation.</div>${button('Done', 'close', 'primary full')}`;
    case 'quality': return intro('Choose your view.', 'This preference applies to fullscreen. The grid uses lower-bandwidth streams.') + [['Automatic', 'Switch to the main stream when available.'], ['High quality', 'Prefer the most detailed available stream.'], ['Low bandwidth', 'Prefer the camera’s smaller substream.']].map(([name, text]) => `<button class="choice-card" data-action="set-quality" data-value="${name}" aria-pressed="${state.quality === name}"><span><strong>${name}</strong><small>${text}</small></span>${icon(state.quality === name ? 'check' : 'arrow')}</button>`).join('') + `<p class="muted small">Prototype only. Sample stills do not change resolution.</p>`;
    case 'review': return `<div class="review-intro"><div>${intro('Every screen. One place.', 'Jump into a moment, or walk through the whole flow.')}</div><small>Design reference 01</small></div><div class="info-box" style="margin-top:0">This panel is for design review, not part of the TV app. All feeds are sample stills. Discovery, permissions and connection checks are simulated. <strong>Do not enter real credentials.</strong> State previews use fresh sample cameras.</div><div class="screen-index">${screenGroups.map(([title, screens]) => `<section class="screen-group"><h3>${title}</h3>${screens.map(([id, name]) => `<button class="screen-link" data-action="jump" data-screen="${id}"><span>${name}</span>${icon('arrow')}</button>`).join('')}</section>`).join('')}</div>`;
    default: return '';
  }
}
function modalFooter() {
  if (state.modal === 'review') return `<div class="actions">${button('Start first-launch flow', 'first-launch', 'primary', 'home')}${button('Reset sample cameras', 'reset', '', 'retry')}</div>`;
  return `<p>${icon('shield')}Design prototype. Sample imagery and simulated connections. Never enter real camera credentials.</p>`;
}
function render(focus) {
  clearTimeout(timer);
  if (state.page === 'fullscreen' && !currentCamera()) state.page = 'home';
  const app = document.getElementById('app');
  app.innerHTML = state.page === 'fullscreen' ? fullscreen() : `<div class="app-shell ${state.page === 'home' ? 'home-shell' : ''}">${topbar()}<main>${state.page === 'manage' ? manage() : state.page === 'settings' ? settings() : home()}</main>${footer()}</div>`;
  document.getElementById('overlay').innerHTML = state.modal ? `<div class="modal-backdrop"><section class="sheet ${state.modal === 'review' ? 'review-sheet' : ''}" role="dialog" aria-modal="true" aria-labelledby="dialog-title"><div class="sheet-head"><button class="back-btn" data-action="back">${icon('back')}${state.modal === 'review' ? 'Back to prototype' : 'Back'}</button><button class="icon-btn" data-action="close" aria-label="Close panel">${icon('close')}</button></div><div class="sheet-body">${modalContent()}</div><footer class="sheet-foot">${modalFooter()}</footer></section></div>` : '';
  const bar = document.getElementById('review-bar');
  const screenName = screenGroups.flatMap(([, screens]) => screens).find(([id]) => id === (state.modal || state.page))?.[1] || 'Live view';
  bar.innerHTML = `<div class="review-label"><b>Design reference 01</b><span class="separator"></span><span class="review-detail">${esc(screenName)}</span><span class="separator"></span><span class="review-detail">Simulated cameras · Not a working camera app</span></div><button id="review-button" data-action="review">${icon('grid')}All screens <span aria-hidden="true">↗</span></button>`;
  app.inert = Boolean(state.modal);
  bar.inert = Boolean(state.modal);
  document.body.style.overflow = state.modal ? 'hidden' : '';
  document.title = `${screenName} · Home Cameras`;
  setFocus(focus);
  if (!state.frozen && state.modal === 'scanning') timer = setTimeout(() => {
    if (state.scanOutcome === 'network') {
      state.network = 'offline'; state.modal = 'none';
    } else state.modal = state.scanOutcome === 'none' ? 'none' : 'results';
    render();
  }, 1900);
  if (!state.frozen && state.modal === 'testing') timer = setTimeout(() => {
    state.modal = state.outcome === 'auth' ? 'auth-error' : state.outcome === 'unreachable' ? 'unreachable' : 'preview';
    if (state.modal === 'preview') state.draft.password = '';
    render(state.modal === 'preview' ? 'name' : null);
  }, 1700);
  if (!state.frozen && state.network === 'reconnecting' && !state.modal) timer = setTimeout(() => {
    state.network = 'connected'; state.offline = null; render(); toast('Demo cameras reconnected.');
  }, 1600);
}
function back() {
  const previous = { permission: 'add', 'permission-denied': 'permission', scanning: 'add', results: 'add', none: 'add', credentials: 'results', manual: 'add', testing: state.method === 'manual' ? 'manual' : 'credentials', 'auth-error': state.method === 'manual' ? 'manual' : 'credentials', unreachable: state.method === 'manual' ? 'manual' : 'credentials', preview: state.method === 'manual' ? 'manual' : 'credentials', remove: 'edit' };
  if (state.modal === 'success') return finish();
  if (previous[state.modal]) return showModal(previous[state.modal]);
  if (state.modal) return closeModal();
  if (state.page === 'fullscreen') return exitFullscreen();
  if (state.page !== 'home') { state.page = 'home'; render('nav-home'); }
}
function exitFullscreen() {
  state.page = state.fullscreenOrigin;
  state.audio = false;
  render(`tile-${state.selected}`);
}
function finish() {
  state.page = 'home'; state.modal = null; state.filter = 'all';
  state.pageNumber = Math.floor(Math.max(0, state.cameras.findIndex(c => c.id === state.newlyAdded)) / state.layout);
  state.draft = {}; render(state.newlyAdded ? `tile-${state.newlyAdded}` : null);
}
function formError(message, inputName) {
  document.getElementById('form-error').textContent = message;
  if (inputName) document.getElementById(inputName)?.focus();
}
function validateConnection() {
  const { url, username, password } = state.draft;
  if (state.method === 'manual' || state.modal === 'edit') {
    try {
      const parsed = new URL(url);
      if (!['rtsp:', 'rtsps:'].includes(parsed.protocol) || !parsed.hostname || /\s/.test(url)) throw new Error();
      if (parsed.username || parsed.password) return formError('Put the username and password in their separate fields, not in the address.', 'url'), false;
    } catch { return formError('Enter a valid RTSP address, such as rtsp://192.168.1.21:554/stream1.', 'url'), false; }
    if (Boolean(username) !== Boolean(password)) return formError('Enter both a username and password, or leave both blank for a camera without authentication.', username ? 'password' : 'username'), false;
  } else if (!username?.trim() || !password) {
    return formError('Enter a username and password. You can use the sample credentials below.', !username?.trim() ? 'username' : 'password'), false;
  }
  return true;
}
function openEdit(id) {
  const camera = state.cameras.find(c => c.id === id);
  if (!camera) return;
  state.selected = id;
  state.draft = { ...camera, url: `rtsp://192.168.1.${21 + state.cameras.indexOf(camera)}:554/stream1`, username: '', password: '' };
  state.editOrigin = state.page;
  showModal('edit', 'name');
}
function jump(screen) {
  clearTimeout(timer);
  state.cameras = structuredClone(initialCameras);
  state.page = 'home'; state.modal = null; state.network = 'connected'; state.offline = null;
  state.filter = 'all'; state.pageNumber = 0; state.layout = 4; state.audio = false;
  state.frozen = true; state.previousReview = null; state.returnFocus = 'review-button';
  state.selected = 'front'; state.fullscreenOrigin = 'home'; state.method = 'auto';
  state.outcome = 'success'; state.scanOutcome = 'found'; state.newlyAdded = null;
  state.draft = { name: 'Patio camera', room: 'Outdoors', image: 'garden', url: 'rtsp://192.168.1.34:554/stream1', username: '', password: '', address: '192.168.1.34', model: 'TP-Link IP camera', favorite: false };
  if (['home', 'manage', 'settings', 'fullscreen'].includes(screen)) state.page = screen;
  else if (screen === 'six') state.layout = 6;
  else if (screen === 'favorites') state.filter = 'favorites';
  else if (screen === 'empty') state.cameras = [];
  else if (screen === 'camera-offline') state.offline = 'garden';
  else if (screen === 'fullscreen-offline') { state.offline = 'front'; state.page = 'fullscreen'; }
  else if (screen === 'network-offline') state.network = 'offline';
  else if (screen === 'reconnecting') state.network = 'reconnecting';
  else {
    state.modal = screen;
    if (screen === 'manual') state.method = 'manual';
    if (['edit', 'remove'].includes(screen)) state.draft = { ...state.cameras[0], url: 'rtsp://192.168.1.21:554/stream1', username: '', password: '' };
    if (screen === 'success') {
      state.newlyAdded = 'patio-demo';
      state.cameras.push({ id: 'patio-demo', name: state.draft.name, room: state.draft.room, image: state.draft.image, favorite: false });
    }
  }
  const valid = screenGroups.flatMap(([, screens]) => screens).some(([id]) => id === screen);
  if (!valid) state.modal = null;
  try { history.replaceState(null, '', `#${valid ? screen : 'home'}`); } catch {}
  render();
}

document.addEventListener('input', event => {
  const input = event.target;
  if (input.matches('input') && ['name', 'room', 'url', 'username', 'password'].includes(input.name)) state.draft[input.name] = input.value;
});
document.addEventListener('change', event => {
  if (event.target.name === 'home-view') {
    state.filter = event.target.value; state.pageNumber = 0; render('home-view');
  }
  if (event.target.name === 'test-outcome') state.outcome = event.target.value;
  if (event.target.name === 'scan-outcome') state.scanOutcome = event.target.value;
});
document.addEventListener('submit', event => {
  const form = event.target;
  if (!form.dataset.form) return;
  event.preventDefault();
  for (const [name, value] of new FormData(form)) if (['name', 'room', 'url', 'username', 'password'].includes(name)) state.draft[name] = String(value);
  if (form.dataset.form === 'connect') {
    if (validateConnection()) showModal('testing');
  } else {
    const name = state.draft.name?.trim();
    if (!name) return formError('Give this camera a name so you can find it on your home screen.', 'name');
    if (form.dataset.form === 'edit' && !validateConnection()) return;
    if (form.dataset.form === 'add' && state.cameras.length >= 48) return formError('This design reference supports up to 48 sample cameras. Remove one before adding another.');
    const camera = { id: form.dataset.form === 'edit' ? state.draft.id : `camera-${Date.now()}`, name: name.slice(0, 60), room: (state.draft.room || '').trim().slice(0, 40), image: state.draft.image || 'front-door', favorite: Boolean(state.draft.favorite) };
    if (form.dataset.form === 'edit') {
      const index = state.cameras.findIndex(c => c.id === camera.id);
      if (index < 0) return;
      state.cameras[index] = camera;
      save(); closeModal(); toast('Camera changes saved for this prototype.');
    } else {
      state.cameras.push(camera); state.newlyAdded = camera.id;
      state.draft = { name: camera.name, image: camera.image };
      save(); showModal('success');
    }
  }
});
document.addEventListener('click', event => {
  const target = event.target.closest('[data-action]');
  if (!target || target.disabled || target.closest('[inert]')) return;
  const action = target.dataset.action;
  const id = target.dataset.id;
  if (!action) return;
  switch (action) {
    case 'home': case 'manage': case 'settings':
      state.page = action; state.modal = null; state.audio = false; state.draft = {}; state.frozen = false; render(`nav-${action}`); break;
    case 'start-add': startAdd(); break;
    case 'close': closeModal(); break;
    case 'back': back(); break;
    case 'permission': case 'permission-denied': case 'results': case 'preview': case 'layout': case 'quality': showModal(action); break;
    case 'scan': state.network = 'connected'; showModal('scanning'); break;
    case 'manual': state.method = 'manual'; showModal('manual', 'url'); break;
    case 'device': chooseDevice(Number(target.dataset.index)); break;
    case 'review':
      state.previousReview = { modal: state.modal, frozen: state.frozen }; showModal('review'); break;
    case 'jump': jump(target.dataset.screen); break;
    case 'first-launch': jump('empty'); toast('First-launch walkthrough. Add your first sample camera.'); break;
    case 'reset':
      jump('home'); state.keepAwake = true; state.quality = 'Automatic'; state.frozen = false; save(); render(); toast('Sample cameras and preferences reset.'); break;
    case 'set-layout': state.layout = Number(target.dataset.value); state.pageNumber = 0; save(); render(`layout-${state.layout}`); break;
    case 'set-quality': state.quality = target.dataset.value; save(); closeModal(); break;
    case 'keep-awake': state.keepAwake = !state.keepAwake; save(); render('keep-awake'); break;
    case 'fullscreen': state.fullscreenOrigin = state.page; state.selected = id; state.page = 'fullscreen'; state.audio = false; render('audio-button'); break;
    case 'exit-fullscreen': exitFullscreen(); break;
    case 'prev-camera': case 'next-camera': {
      const index = state.cameras.findIndex(c => c.id === state.selected);
      state.selected = state.cameras[(index + (action === 'next-camera' ? 1 : -1) + state.cameras.length) % state.cameras.length].id;
      state.audio = false; render('audio-button'); break;
    }
    case 'audio': state.audio = !state.audio; render('audio-button'); toast(state.audio ? 'Audio on state preview. Sample stills have no sound.' : 'Audio muted.'); break;
    case 'edit': openEdit(id); break;
    case 'confirm-remove': showModal('remove'); break;
    case 'keep-camera': showModal('edit', 'name'); break;
    case 'remove-camera':
      state.cameras = state.cameras.filter(c => c.id !== state.draft.id); state.draft = {}; state.modal = null;
      if (state.page === 'fullscreen') state.page = 'home';
      save(); render(); toast('Camera removed from this prototype.'); break;
    case 'move-up': case 'move-down': {
      const index = state.cameras.findIndex(c => c.id === id);
      const next = index + (action === 'move-up' ? -1 : 1);
      if (index < 0 || next < 0 || next >= state.cameras.length) break;
      [state.cameras[index], state.cameras[next]] = [state.cameras[next], state.cameras[index]];
      save();
      const direction = next === 0 ? 'down' : next === state.cameras.length - 1 ? 'up' : action === 'move-up' ? 'up' : 'down';
      render(`${direction}-${id}`); toast(`${state.cameras[next].name} moved ${action === 'move-up' ? 'up' : 'down'}.`); break;
    }
    case 'draft-favorite': state.draft.favorite = !state.draft.favorite; render('draft-favorite'); break;
    case 'demo-credentials':
      state.draft.username = 'viewer'; state.draft.password = 'demo-only'; render('password'); break;
    case 'show-password': {
      const input = document.getElementById('password');
      input.type = input.type === 'password' ? 'text' : 'password';
      target.setAttribute('aria-label', input.type === 'password' ? 'Show password' : 'Hide password');
      target.setAttribute('aria-pressed', String(input.type === 'text')); break;
    }
    case 'retry-credentials': showModal(state.method === 'manual' ? 'manual' : 'credentials'); break;
    case 'test-again': showModal('testing'); break;
    case 'finish': finish(); break;
    case 'cancel-setup': state.page = 'home'; closeModal(); break;
    case 'retry-network': state.network = 'reconnecting'; state.frozen = false; render(); break;
    case 'retry-camera':
      if (state.network !== 'connected') { state.network = 'reconnecting'; state.frozen = false; render(); }
      else { state.offline = null; render(); toast('Demo camera reconnected.'); } break;
    case 'prev-page': case 'next-page': state.pageNumber += action === 'next-page' ? 1 : -1; render(); break;
  }
});
function focusableElements() {
  const root = state.modal ? document.getElementById('overlay') : document;
  return [...root.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled), a[href]')].filter(el => !el.closest('[inert]') && el.getClientRects().length);
}
document.addEventListener('keydown', event => {
  if (event.key === 'Escape') { event.preventDefault(); back(); return; }
  const candidates = focusableElements();
  const active = document.activeElement;
  if (event.key === 'Tab' && state.modal) {
    const index = candidates.indexOf(active);
    if (event.shiftKey && index <= 0) { event.preventDefault(); candidates.at(-1)?.focus(); }
    else if (!event.shiftKey && index === candidates.length - 1) { event.preventDefault(); candidates[0]?.focus(); }
    return;
  }
  if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return;
  if (active?.matches('select') || active?.matches('input') && ['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
  event.preventDefault();
  if (!active || !candidates.includes(active)) { candidates[0]?.focus(); return; }
  const rect = active.getBoundingClientRect();
  const x = rect.left + rect.width / 2, y = rect.top + rect.height / 2;
  const horizontal = ['ArrowLeft', 'ArrowRight'].includes(event.key);
  const positive = ['ArrowRight', 'ArrowDown'].includes(event.key);
  const scored = candidates.filter(el => el !== active).map(el => {
    const r = el.getBoundingClientRect();
    const dx = r.left + r.width / 2 - x, dy = r.top + r.height / 2 - y;
    const main = horizontal ? dx : dy;
    const cross = Math.abs(horizontal ? dy : dx);
    const overlap = horizontal ? r.bottom > rect.top && r.top < rect.bottom : r.right > rect.left && r.left < rect.right;
    return { el, score: Math.abs(main) + cross * 2.5 + (overlap ? 0 : 700), valid: positive ? main > 3 : main < -3 };
  }).filter(item => item.valid).sort((a, b) => a.score - b.score);
  if (scored[0]) { scored[0].el.focus({ preventScroll: true }); scored[0].el.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'instant' }); }
});
window.addEventListener('hashchange', () => jump(location.hash.slice(1)));
if (location.hash) jump(location.hash.slice(1)); else render();
