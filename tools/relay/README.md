# 双人联机中继服务器

Godot 客户端（scripts/net.gd）通过 WebSocket 连接本服务：按 4 位房间码配对双人房间，
在两名玩家之间转发 JSON 消息（主机权威同步）。

## 本地运行（桌面版联机）

```
npm install
npm start        # 默认端口 8765，可用环境变量 PORT 覆盖
```

游戏开局面板选「建房联机」（生成房间码）或「加入好友」（输码）。默认连 ws://localhost:8765：

- 同一台电脑双开游戏即可联机；
- 局域网另一台电脑：先在服务器机器启动 `npm start`，对方以环境变量
  `SL_RELAY=ws://<服务器内网IP>:8765` 启动游戏。

## 公网部署（网页版联机）

GitHub Pages 是 HTTPS，浏览器禁止 `ws://` 混合内容，网页版联机必须用 `wss://`：

1. 把本目录部署到任意支持 TLS 的平台（Render / Railway / 自有服务器 + Caddy/nginx）。
   启动命令 `npm install && npm start`；平台注入的 `PORT` 环境变量本服务已兼容。
2. 玩家访问网页时带参数：
   `https://192aaa.github.io/stardew-like/?ws=wss://<你的域名>`
   中继地址的解析顺序：环境变量 SL_RELAY → 网页 `?ws=` 参数 → 默认 ws://localhost:8765。

## 协议速查

客户端 -> 服务器：`{t:"host"}` 建房 / `{t:"join",code}` 加入 / `{t:"msg",data}` 转发给对方 / `{t:"leave"}`
服务器 -> 客户端：`{t:"hosted",code}` / `{t:"joined",code}` / `{t:"err",msg}` / `{t:"peer_joined"}` / `{t:"peer_left"}` / `{t:"msg",data}`
心跳：服务端 15s ping，未 pong 判死并清理房间。
