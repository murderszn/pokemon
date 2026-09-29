import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { WebSocketServer, type WebSocket } from 'ws';
import { Emulator, type Button } from '../emu/emulator.js';

const romPath = process.env.ROM_PATH ?? 'roms/red.gb';
const port = Number(process.env.PLAY_PORT ?? 8788);
const savePath = 'saves/player.json';
const buttons = new Set<Button>(['A', 'B', 'START', 'SELECT', 'UP', 'DOWN', 'LEFT', 'RIGHT']);
const emulator = new Emulator(fs.readFileSync(romPath));
if (fs.existsSync(savePath)) {
  try {
    emulator.loadState(savePath);
    console.log(`Loaded ${savePath}`);
  } catch (error) {
    console.error(`Could not load ${savePath}: ${String(error)}`);
  }
}
const server = http.createServer((req, res) => {
  if (req.url !== '/') { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  fs.createReadStream(path.resolve('web/play.html')).pipe(res);
});
const wss = new WebSocketServer({ server });
const clients = new Map<WebSocket, Set<Button>>();

function message(ws: WebSocket, text: string) {
  ws.send(JSON.stringify({ type: 'message', text }));
}

wss.on('connection', (ws) => {
  clients.set(ws, new Set());
  message(ws, 'Connected. Click the game, then use the keyboard or on-screen buttons.');
  ws.on('message', (raw) => {
    let input: { cmd?: string; button?: string };
    try { input = JSON.parse(String(raw)); } catch { return; }
    const held = clients.get(ws);
    if (!held) return;
    if ((input.cmd === 'down' || input.cmd === 'up') && buttons.has(input.button as Button)) {
      const button = input.button as Button;
      if (input.cmd === 'down') held.add(button);
      else held.delete(button);
    } else if (input.cmd === 'release') {
      held.clear();
    } else if (input.cmd === 'save') {
      try {
        fs.mkdirSync('saves', { recursive: true });
        emulator.saveState(savePath);
        message(ws, 'Saved to saves/player.json');
      } catch (error) { message(ws, `Save failed: ${String(error)}`); }
    } else if (input.cmd === 'load') {
      try {
        emulator.loadState(savePath);
        held.clear();
        message(ws, 'Loaded saves/player.json');
      } catch (error) { message(ws, `Load failed: ${String(error)}`); }
    }
  });
  ws.on('close', () => clients.delete(ws));
});

// serverboy's doFrame advances a CPU slice. About 125 slices make one second.
const slicesPerSecond = 4194304 / (emulator.core.baseCPUCyclesPerIteration || 33554.432);
let last = performance.now();
let pending = 0;
let lastSent = 0;
setInterval(() => {
  const now = performance.now();
  pending += Math.min(now - last, 100) * slicesPerSecond / 1000;
  last = now;
  const held = new Set<Button>();
  for (const keys of clients.values()) for (const key of keys) held.add(key);
  const frames = Math.min(Math.floor(pending), 12);
  pending -= frames;
  for (let i = 0; i < frames; i++) emulator.frame([...held]);
  if (now - lastSent < 50 || !clients.size) return;
  lastSent = now;
  const screen = Buffer.from(Uint8Array.from(emulator.screen()));
  for (const ws of clients.keys()) if (ws.readyState === ws.OPEN) ws.send(screen);
}, 8);

server.listen(port, '127.0.0.1', () => console.log(`Play Pokémon Red at http://localhost:${port}`));
