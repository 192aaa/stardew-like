// 星露谷类农场游戏 - 双人联机中继服务器
// 协议（客户端 -> 服务器）:
//   {t:"host"}            创建房间        -> {t:"hosted",code}
//   {t:"join",code}       加入房间        -> {t:"joined"} 或 {t:"err",msg}
//   {t:"msg",data}        转发 data 给对方 -> 对方收到 {t:"msg",data}
//   {t:"leave"}           主动离开房间
// 服务器主动推送: {t:"peer_joined"} / {t:"peer_left"}
// 心跳: 15s ping，两次未 pong 判死并清理房间

const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = process.env.PORT || 8765;
// 房间码字符集：去掉易混淆的 0/O/1/I/L
const CODE_CHARS = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server });
const rooms = new Map(); // code -> { host, guest }

function makeCode() {
  let code;
  do {
    code = '';
    for (let i = 0; i < 4; i++) {
      code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    }
  } while (rooms.has(code));
  return code;
}

function send(ws, obj) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(obj));
  }
}

function leaveRoom(ws, notifyPeer = true) {
  if (!ws.room) return;
  const room = rooms.get(ws.room);
  if (room) {
    const peer = ws.role === 'host' ? room.guest : room.host;
    if (notifyPeer && peer) send(peer, { t: 'peer_left' });
    if (ws.role === 'host') rooms.delete(ws.room);
    else room.guest = null;
  }
  ws.room = null;
  ws.role = null;
}

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.room = null;
  ws.role = null;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (raw) => {
    let m;
    try { m = JSON.parse(raw.toString()); } catch { return; }
    if (!m || typeof m.t !== 'string') return;

    if (m.t === 'host') {
      leaveRoom(ws);
      const code = makeCode();
      rooms.set(code, { host: ws, guest: null });
      ws.room = code;
      ws.role = 'host';
      send(ws, { t: 'hosted', code });

    } else if (m.t === 'join') {
      leaveRoom(ws);
      const code = String(m.code || '').trim().toUpperCase();
      const room = rooms.get(code);
      if (!room) { send(ws, { t: 'err', msg: '房间不存在' }); return; }
      if (room.guest) { send(ws, { t: 'err', msg: '房间已满' }); return; }
      room.guest = ws;
      ws.room = code;
      ws.role = 'guest';
      send(ws, { t: 'joined', code });
      send(room.host, { t: 'peer_joined' });

    } else if (m.t === 'msg') {
      const room = ws.room ? rooms.get(ws.room) : null;
      if (!room) return;
      const peer = ws.role === 'host' ? room.guest : room.host;
      send(peer, { t: 'msg', data: m.data });

    } else if (m.t === 'leave') {
      leaveRoom(ws);
    }
  });

  ws.on('close', () => leaveRoom(ws));
  ws.on('error', () => leaveRoom(ws));
});

const HEARTBEAT_MS = 15000;
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) { leaveRoom(ws); ws.terminate(); return; }
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_MS);

server.listen(PORT, () => {
  console.log('[relay] listening on port ' + PORT);
});
