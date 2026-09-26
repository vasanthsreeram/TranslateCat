import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/RoomEnvironment.js';

// ===== Device dimensions (world units) =====
const W = 5, H = 3.2, T = 0.12, B = 0.025, R = 0.42;
const PX = 200; // canvas pixels per world unit

// ===== Renderer / scene =====
const host = document.getElementById('stage');
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
host.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 100);

const key = new THREE.DirectionalLight(0xffffff, 2.2);
key.position.set(4, 9, 6);
key.castShadow = true;
key.shadow.mapSize.set(2048, 2048);
Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7 });
key.shadow.radius = 6;
scene.add(key, new THREE.AmbientLight(0xffffff, 0.35));

const ground = new THREE.Mesh(new THREE.PlaneGeometry(40, 40), new THREE.ShadowMaterial({ opacity: 0.13 }));
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);

// ===== Materials =====
const titanium = new THREE.MeshStandardMaterial({ color: 0xd9d4c8, metalness: 1, roughness: 0.28 });

// Rounded-rect slab spanning x∈[-W/2,W/2], y∈[0,H], z∈[-T,0]
function slabGeometry() {
  const s = new THREE.Shape(), w = W / 2 - B, h0 = B, h1 = H - B, r = R;
  s.moveTo(-w + r, h0); s.lineTo(w - r, h0); s.quadraticCurveTo(w, h0, w, h0 + r);
  s.lineTo(w, h1 - r); s.quadraticCurveTo(w, h1, w - r, h1); s.lineTo(-w + r, h1);
  s.quadraticCurveTo(-w, h1, -w, h1 - r); s.lineTo(-w, h0 + r); s.quadraticCurveTo(-w, h0, -w + r, h0);
  const g = new THREE.ExtrudeGeometry(s, { depth: T - 2 * B, bevelEnabled: true, bevelThickness: B, bevelSize: B, bevelSegments: 4, curveSegments: 16 });
  g.translate(0, 0, -T + B);
  return g;
}

// ===== Screen canvases =====
function makeCanvas(w, h) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 8;
  return { c, ctx: c.getContext('2d'), tex };
}
const innerC = makeCanvas(W * PX, 2 * H * PX);   // 1000 x 1280, spans both halves
const outerC = makeCanvas(W * PX, H * PX);       // 1000 x 640

function screenPlane(tex, v0, v1) {
  const g = new THREE.PlaneGeometry(W, H);
  const uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) uv.setY(i, v0 + uv.getY(i) * (v1 - v0));
  return new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: tex, transparent: true, toneMapped: false }));
}

// Bottom half: lies flat, z∈[0,H]
const bottom = new THREE.Group();
const bottomBody = new THREE.Mesh(slabGeometry().rotateX(Math.PI / 2), titanium);
bottomBody.castShadow = true;
const bottomScreen = screenPlane(innerC.tex, 0, 0.5);
bottomScreen.rotation.x = -Math.PI / 2;
bottomScreen.position.set(0, T + 0.003, H / 2);
bottom.add(bottomBody, bottomScreen);

// Top half: hinged at (0,T,0), rotation.x = fold angle
const top = new THREE.Group();
top.position.set(0, T, 0);
const topBody = new THREE.Mesh(slabGeometry(), titanium);
topBody.castShadow = true;
const topScreen = screenPlane(innerC.tex, 0.5, 1);
topScreen.position.set(0, H / 2, 0.003);
const outerScreen = screenPlane(outerC.tex, 0, 1);
outerScreen.position.set(0, H / 2, -T - 0.003);
outerScreen.rotation.y = Math.PI;
top.add(topBody, topScreen, outerScreen);

const hinge = new THREE.Mesh(new THREE.CylinderGeometry(T / 2, T / 2, W - 0.5, 24), titanium);
hinge.rotation.z = Math.PI / 2;
hinge.position.set(0, T / 2, 0);

const device = new THREE.Group();
device.add(bottom, top, hinge);
scene.add(device);

// ===== Icons (24pt SF Symbol-style paths) =====
const ICONS = {
  cat: [['M4 3l4 4.2a9 9 0 0 1 8 0L20 3v9.5A8 8 0 0 1 12 21a8 8 0 0 1-8-8.5z', 'fill']],
  book: [['M5 4h11a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2zM5 18a2 2 0 0 1 2-2h11M9 8h5', 'stroke']],
  sparkles: [['M10 3l1.8 5.2L17 10l-5.2 1.8L10 17l-1.8-5.2L3 10l5.2-1.8zM18 14l.9 2.1L21 17l-2.1.9L18 20l-.9-2.1L15 17l2.1-.9z', 'fill']],
  globe: [['M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M8 12a4 9 0 1 0 8 0a4 9 0 1 0-8 0M3 12h18', 'stroke']],
  keyboard: [['M5 6h14a2.5 2.5 0 0 1 2.5 2.5v7a2.5 2.5 0 0 1-2.5 2.5H5a2.5 2.5 0 0 1-2.5-2.5v-7A2.5 2.5 0 0 1 5 6zM6 10h1M9.5 10h1M13 10h1M16.5 10h1M8 14h8', 'stroke']],
  mic: [['M12 3a3 3 0 0 1 3 3v5a3 3 0 0 1-6 0V6a3 3 0 0 1 3-3z', 'fill'], ['M6 11a6 6 0 0 0 12 0M12 17v4', 'stroke']],
  stop: [['M8 6h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z', 'fill']],
  waveform: [['M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4', 'stroke']],
  bubble: [['M4 5h16v11H10l-4 3v-3H4zM8 9h8M8 12h5', 'stroke']],
  ear: [['M7 9a5 5 0 0 1 10 0c0 3-3 4-3 7a3 3 0 0 1-5 2M10 9a2 2 0 0 1 4 0', 'stroke']],
  wifi: [['M3 9a13 13 0 0 1 18 0M6 12.5a8.5 8.5 0 0 1 12 0M9 16a4 4 0 0 1 6 0', 'stroke'], ['M10.7 19a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0-2.6 0', 'fill']],
};
const paths = Object.fromEntries(Object.entries(ICONS).map(([k, v]) => [k, v.map(([d, m]) => [new Path2D(d), m])]));
function icon(ctx, name, x, y, size, color) {
  ctx.save(); ctx.translate(x, y); ctx.scale(size / 24, size / 24);
  ctx.fillStyle = ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.lineCap = ctx.lineJoin = 'round';
  for (const [p, m] of paths[name]) m === 'fill' ? ctx.fill(p) : ctx.stroke(p);
  ctx.restore();
}

// ===== Drawing helpers =====
const C = { accent: '#2e5a4a', canvas: '#f2ede0', surface: '#fcfaf2', ink: '#293329', muted: '#636b5e', rule: '#d1ccba' };
const SERIF = 'ui-serif, "New York", "Iowan Old Style", Georgia, serif';
const SANS = '-apple-system, "SF Pro Text", system-ui, sans-serif';

function rr(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); }
function wrap(ctx, text, maxW) {
  const words = text.split(' '), lines = []; let line = '';
  for (const w of words) {
    const t = line ? line + ' ' + w : w;
    if (ctx.measureText(t).width > maxW && line) { lines.push(line); line = w; } else line = t;
  }
  lines.push(line); return lines;
}
// Draws wrapped text that shrinks to fit; returns caret position
function fitText(ctx, text, x, y, w, h, maxSize, family, color, weight = 500) {
  let size = maxSize, lines, lh;
  for (;;) {
    ctx.font = `${weight} ${size}px ${family}`; lh = size * 1.18;
    lines = wrap(ctx, text, w);
    if (lines.length * lh <= h || size < 18) break;
    size -= 2;
  }
  ctx.fillStyle = color; ctx.textBaseline = 'top';
  lines.forEach((l, i) => ctx.fillText(l, x, y + i * lh));
  const last = lines[lines.length - 1];
  return { x: x + ctx.measureText(last).width + 4, y: y + (lines.length - 1) * lh, h: size };
}
function kicker(ctx, iconName, label, x, y, size = 19) {
  icon(ctx, iconName, x, y - 2, size + 4, C.accent);
  ctx.font = `700 ${size}px ${SANS}`; ctx.letterSpacing = `${size * 0.12}px`;
  ctx.fillStyle = C.accent; ctx.textBaseline = 'top'; ctx.fillText(label, x + size + 14, y);
  ctx.letterSpacing = '0px';
}
function caret(ctx, pos, now) {
  if (Math.floor(now / 450) % 2) return;
  ctx.fillStyle = C.accent; ctx.fillRect(pos.x, pos.y + pos.h * 0.08, 4, pos.h * 1.02);
}
function screenFrame(ctx, w, h, bezel, bg) {
  ctx.clearRect(0, 0, w, h);
  rr(ctx, 0, 0, w, h, R * PX - 2); ctx.fillStyle = '#000'; ctx.fill();
  rr(ctx, bezel, bezel, w - 2 * bezel, h - 2 * bezel, R * PX - bezel - 4); ctx.fillStyle = bg; ctx.fill();
  ctx.save(); ctx.clip();
}

// ===== Conversation state =====
const S = { you: '', them: '', cover: '', typing: null, running: false, hearing: false, autoText: '', tap: { i: -1, t: 0 }, escuchando: false };

function drawInner(now) {
  const ctx = innerC.ctx, w = innerC.c.width, h = innerC.c.height;
  screenFrame(ctx, w, h, 16, C.canvas);
  // status bar (portrait inner display keeps horizontal bars)
  ctx.fillStyle = C.ink; ctx.font = `600 26px ${SANS}`; ctx.textBaseline = 'middle'; ctx.fillText('9:41', 80, 60);
  icon(ctx, 'wifi', 850, 46, 28, C.ink);
  rr(ctx, 890, 50, 44, 20, 6); ctx.strokeStyle = C.ink; ctx.lineWidth = 2; ctx.stroke(); rr(ctx, 894, 54, 32, 12, 3); ctx.fillStyle = C.ink; ctx.fill();
  // nav bar
  ctx.font = `600 30px ${SANS}`; const tw = ctx.measureText('TranslateCat').width;
  icon(ctx, 'cat', 360 - 10, 118, 32, C.ink); ctx.fillStyle = C.ink; ctx.textBaseline = 'middle'; ctx.fillText('TranslateCat', 400, 135);
  // Liquid Glass toolbar group
  rr(ctx, 690, 100, 270, 70, 35); ctx.fillStyle = 'rgba(255,255,255,.7)'; ctx.fill();
  ctx.strokeStyle = 'rgba(255,255,255,1)'; ctx.lineWidth = 2; ctx.stroke();
  ['book', 'sparkles', 'globe', 'keyboard'].forEach((n, i) => {
    const cx = 728 + i * 64, k = S.tap.i === i ? Math.max(0, 1 - (now - S.tap.t) / 700) : 0;
    if (k > 0) { ctx.beginPath(); ctx.arc(cx, 135, 28, 0, 7); ctx.fillStyle = `rgba(46,90,74,${0.25 * k})`; ctx.fill(); }
    icon(ctx, n, cx - 16, 119, 32, C.ink);
  });
  // FOR THEM card (top half)
  const active = S.running;
  const card = (x, y, cw, ch) => { rr(ctx, x, y, cw, ch, 22); ctx.fillStyle = C.surface; ctx.fill(); ctx.lineWidth = active ? 4 : 2; ctx.strokeStyle = active ? C.accent : C.rule; ctx.stroke(); };
  card(40, 200, 920, 400);
  kicker(ctx, 'bubble', 'FOR THEM · SPANISH', 76, 236);
  const themTxt = S.them || 'Your live translation appears here and on the outside screen.';
  const p1 = fitText(ctx, themTxt, 76, 290, 850, 280, 50, SERIF, S.them ? C.ink : C.muted);
  if (S.typing === 'them') caret(ctx, p1, now);
  // YOUR WORDS card (bottom half, below the fold at y=640)
  card(40, 680, 920, 560);
  kicker(ctx, 'waveform', 'YOUR WORDS · ENGLISH', 76, 716);
  const youTxt = S.you || 'Tap Start conversation, then just talk.';
  const p2 = fitText(ctx, youTxt, 76, 770, 850, 250, 50, SERIF, S.you ? C.ink : C.muted);
  if (S.typing === 'you') caret(ctx, p2, now);
  if (S.running) {
    icon(ctx, S.hearing ? 'waveform' : 'ear', 76, 1052, 26, C.accent);
    ctx.font = `400 23px ${SANS}`; ctx.fillStyle = C.accent; ctx.textBaseline = 'middle'; ctx.fillText(S.autoText, 114, 1066);
  }
  rr(ctx, 76, 1110, 848, 96, 22); ctx.fillStyle = C.accent; ctx.fill();
  const label = S.running ? 'Stop conversation' : 'Start conversation';
  ctx.font = `600 30px ${SANS}`; const lw = ctx.measureText(label).width;
  icon(ctx, S.running ? 'stop' : 'mic', 500 - lw / 2 - 26, 1142, 32, C.surface);
  ctx.fillStyle = C.surface; ctx.textBaseline = 'middle'; ctx.fillText(label, 500 - lw / 2 + 20, 1158);
  ctx.restore();
  innerC.tex.needsUpdate = true;
}

function drawOuter(now) {
  const ctx = outerC.ctx, w = outerC.c.width, h = outerC.c.height;
  screenFrame(ctx, w, h, 22, C.surface);
  // corner camera + vertical status rail
  ctx.beginPath(); ctx.arc(924, 76, 24, 0, 7); ctx.fillStyle = '#000'; ctx.fill();
  ctx.beginPath(); ctx.arc(924, 76, 10, 0, 7); ctx.fillStyle = '#1d2740'; ctx.fill();
  ctx.fillStyle = C.ink; ctx.font = `600 24px ${SANS}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('9:41', 924, 140);
  ctx.textAlign = 'left'; icon(ctx, 'wifi', 910, 160, 28, C.ink);
  kicker(ctx, 'cat', 'SPANISH', 64, 64, 22);
  const p = fitText(ctx, S.cover || 'Esperando…', 64, 120, 790, 400, 84, SERIF, C.ink);
  if (S.typing === 'cover') caret(ctx, p, now);
  if (S.escuchando) {
    for (let i = 0; i < 4; i++) { const bh = 8 + 14 * Math.abs(Math.sin(now / 180 + i)); ctx.fillStyle = C.accent; rr(ctx, 64 + i * 10, 566 - bh / 2, 5, bh, 3); ctx.fill(); }
    ctx.font = `400 26px ${SANS}`; ctx.fillStyle = C.muted; ctx.textBaseline = 'middle'; ctx.fillText('Escuchando…', 116, 566);
  }
  ctx.restore();
  outerC.tex.needsUpdate = true;
}

// ===== Conversation script, typed character by character =====
const sleep = ms => new Promise(r => setTimeout(r, ms));
async function typeInto(field, text, ms = 42) {
  S[field] = ''; S.typing = field;
  for (const ch of text) { S[field] += ch; await sleep(ch === ' ' ? ms * 1.6 : ms); }
  S.typing = null;
}
async function typeBoth(text, ms = 28) {
  S.them = S.cover = ''; S.typing = 'cover';
  for (const ch of text) { S.them += ch; S.cover += ch; await sleep(ms); }
  S.typing = null;
}
const convo = [
  ['you', "Hi! Where's the nearest train station?", '¡Hola! ¿Dónde está la estación de tren más cercana?'],
  ['them', 'Está a dos calles, a la izquierda.', "It's two blocks away, on the left."],
  ['you', 'Do I need to buy a ticket before I board?', '¿Necesito comprar un billete antes de subir?'],
  ['them', 'Sí, en la máquina de la entrada.', 'Yes, at the machine by the entrance.'],
  ['you', 'Thank you so much!', '¡Muchas gracias!'],
];
async function conversation() {
  for (;;) {
    Object.assign(S, { you: '', them: '', cover: '', running: false, escuchando: false });
    await sleep(1400);
    S.tap = { i: 2, t: performance.now() }; await sleep(900);
    S.running = true; S.autoText = 'Listening for English or Spanish…';
    await sleep(900);
    for (const [who, orig, tr] of convo) {
      S.hearing = true; S.autoText = 'Hearing speech…';
      if (who === 'you') {
        await typeInto('you', orig);
        S.hearing = false; S.autoText = 'Translating…'; await sleep(450);
        await typeBoth(tr);
      } else {
        S.escuchando = true;
        await typeInto('cover', orig);
        S.them = orig; S.escuchando = false; S.hearing = false;
        S.autoText = 'Translating…'; await sleep(450);
        await typeInto('you', tr, 30);
      }
      S.autoText = 'Listening for English or Spanish…';
      await sleep(1800);
    }
    S.tap = { i: 0, t: performance.now() };
    await sleep(2600);
  }
}
conversation();

// ===== Scroll-driven choreography =====
// a = fold angle (deg): 90 closed, -90 flat open, -12 laptop pose
// phi = camera azimuth (0 = your side, ±180 = their side)
const KEYS = [
  { p: 0.00, a: 90, phi: 180, e: 58, r: 10.5, ty: 0.2, tz: 1.6 },
  { p: 0.12, a: 90, phi: 150, e: 48, r: 9.5, ty: 0.2, tz: 1.6 },
  { p: 0.32, a: -90, phi: 12, e: 52, r: 11.5, ty: 0, tz: 0 },
  { p: 0.48, a: -12, phi: -22, e: 20, r: 11, ty: 1.4, tz: 0.6 },
  { p: 0.56, a: -12, phi: -22, e: 20, r: 10.5, ty: 1.4, tz: 0.6 },
  { p: 0.70, a: -12, phi: -168, e: 16, r: 10, ty: 1.5, tz: 0.4 },
  { p: 0.80, a: -12, phi: -180, e: 14, r: 9.5, ty: 1.5, tz: 0.4 },
  { p: 1.00, a: -12, phi: -335, e: 26, r: 11, ty: 1.2, tz: 0.6 },
];
const ease = t => t * t * (3 - 2 * t);
function sample(p) {
  let i = 0; while (i < KEYS.length - 2 && p > KEYS[i + 1].p) i++;
  const k0 = KEYS[i], k1 = KEYS[i + 1], t = ease(THREE.MathUtils.clamp((p - k0.p) / (k1.p - k0.p), 0, 1));
  const o = {}; for (const k in k0) o[k] = k0[k] + (k1[k] - k0[k]) * t; return o;
}

const section = document.getElementById('stage3d');
const phases = [...document.querySelectorAll('[data-phase]')];
let mouseX = 0, mouseY = 0, smooth = null;
addEventListener('pointermove', e => { mouseX = e.clientX / innerWidth - 0.5; mouseY = e.clientY / innerHeight - 0.5; });

function progress() {
  const r = section.getBoundingClientRect();
  return THREE.MathUtils.clamp(-r.top / (r.height - innerHeight), 0, 1);
}
function resize() {
  const w = host.clientWidth, h = host.clientHeight;
  renderer.setSize(w, h); camera.aspect = w / h;
  camera.setViewOffset(w, h, innerWidth <= 900 ? 0 : -w * 0.16, 0, w, h); // shift device right of the caption card
  camera.updateProjectionMatrix();
}
addEventListener('resize', resize); resize();

function frame(now) {
  requestAnimationFrame(frame);
  const r = section.getBoundingClientRect();
  if (r.bottom < 0 || r.top > innerHeight) return;
  const target = sample(progress());
  if (!smooth) smooth = { ...target };
  for (const k in target) smooth[k] += (target[k] - smooth[k]) * 0.08;
  const s = smooth;
  top.rotation.x = THREE.MathUtils.degToRad(s.a);
  const phi = THREE.MathUtils.degToRad(s.phi + mouseX * 10), e = THREE.MathUtils.degToRad(s.e - mouseY * 6);
  const rad = s.r * (innerWidth <= 900 ? Math.max(1.45, 1.1 / camera.aspect) : 1.4);
  camera.position.set(Math.cos(e) * Math.sin(phi) * rad, s.ty + Math.sin(e) * rad, s.tz + Math.cos(e) * Math.cos(phi) * rad);
  camera.lookAt(0, s.ty, s.tz);
  const p = progress();
  phases.forEach(el => { const [a, b] = el.dataset.phase.split(',').map(Number); el.classList.toggle('on', p >= a && p < b); });
  drawInner(now); drawOuter(now);
  renderer.render(scene, camera);
}
requestAnimationFrame(frame);
document.getElementById('stage').classList.add('ready');

// Preview helper: ?p=0.6 jumps to that point of the 3D sequence
const qp = new URLSearchParams(location.search).get('p');
if (qp !== null) {
  document.documentElement.style.scrollBehavior = 'auto';
  scrollTo(0, section.offsetTop + Number(qp) * (section.offsetHeight - innerHeight));
}
