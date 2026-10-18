// The Standoff relay: wss://<host>/room/<CODE>?host=1&name=... (the host - the phone that runs the match) or
// ?name=... (a player joining). One Durable Object per room code keeps the sockets and passes messages along:
//   host -> a player ({..., to: peer}) or everyone (no `to`)
//   player -> the host (the relay adds `from: peer`)
// The relay knows nothing about the game. It tells the host who joined / left, closes the room when the host goes,
// and sends {t: "welcome", peer} to each socket (the host is peer 1, players 2-6) or {t: "error", msg} and closes.

const MAX_PEERS = 6;
const CODE = /^\/room\/([A-Z0-9]{4,8})$/;

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/") return new Response("Standoff relay - ok\n");
    const m = url.pathname.match(CODE);
    if (!m) return new Response("not found\n", { status: 404 });
    if (req.headers.get("Upgrade") !== "websocket") return new Response("expected a websocket\n", { status: 426 });
    return env.ROOMS.get(env.ROOMS.idFromName(m[1])).fetch(req);
  },
};

export class Room {
  constructor(ctx, env) {
    this.ctx = ctx;
  }

  info(ws) {
    return ws.deserializeAttachment() || {};
  }

  open() {
    return this.ctx.getWebSockets().filter((s) => this.info(s).peer && s.readyState === 1);
  }

  async fetch(req) {
    const url = new URL(req.url);
    const host = url.searchParams.get("host") === "1";
    const name = (url.searchParams.get("name") || "Player").slice(0, 16);
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    const socks = this.open();
    const hostWs = socks.find((s) => this.info(s).host);
    let error = "";
    if (host && hostWs) error = "That room code is taken - try hosting again";
    else if (!host && !hostWs) error = "No game with that code";
    else if (socks.length >= MAX_PEERS) error = "That game is full";
    if (error) {
      server.send(JSON.stringify({ t: "error", msg: error }));
      server.close(1000, "refused");
      return new Response(null, { status: 101, webSocket: client });
    }
    const used = new Set(socks.map((s) => this.info(s).peer));
    let peer = host ? 1 : 2;
    while (used.has(peer)) peer++;
    server.serializeAttachment({ peer, host, name });
    server.send(JSON.stringify({ t: "welcome", peer }));
    if (!host) hostWs.send(JSON.stringify({ t: "joined", peer, name }));
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(ws, msg) {
    const me = this.info(ws);
    if (!me.peer || typeof msg !== "string") return;
    let data;
    try {
      data = JSON.parse(msg);
    } catch {
      return;
    }
    const socks = this.open();
    if (me.host) {
      for (const s of socks) {
        const a = this.info(s);
        if (!a.host && (data.to === undefined || data.to === a.peer)) s.send(msg);
      }
    } else {
      data.from = me.peer;
      const h = socks.find((s) => this.info(s).host);
      if (h) h.send(JSON.stringify(data));
    }
  }

  webSocketClose(ws, code, reason) {
    const me = this.info(ws);
    const others = this.open().filter((s) => s !== ws);
    if (me.host) {
      for (const s of others) {
        s.send(JSON.stringify({ t: "host_left" }));
        s.close(1000, "host left");
      }
    } else if (me.peer) {
      const h = others.find((s) => this.info(s).host);
      if (h) h.send(JSON.stringify({ t: "left", peer: me.peer }));
    }
    try {
      ws.close(1000, "bye");
    } catch {}
  }

  webSocketError(ws) {
    this.webSocketClose(ws, 1011, "error");
  }
}
