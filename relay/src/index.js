// The Standoff lobby server (Timmy, 18 Oct 2026 20:19: "Can we work on the lobby system? Look at the steam lobby your
// only move is hustle has" - its lobbies, studied from a video: a list with name / version / players, create with a
// name / public / max players, a code to find one; inside, members with their status and a challenge button, the
// matches going on with spectate, the owner's rules, chat).
//
//   GET /lobbies                 the public lobbies: [{code, name, version, players, max}]
//   POST /replays {data, v}      a replay shared (19 Oct 02:36 "I cant share those with my friends?") -> {code}
//   GET /replays/<CODE>          that replay: {data, v} (kept 30 days)
//   WS  /lobby/<CODE>?name=..&create=1&lname=..&public=1&max=8&v=..   create (create=1) or join a lobby
//
// One Durable Object per lobby keeps its members' sockets and passes messages along. It knows nothing about the game:
//   {t:"chat", text}                  -> everyone {t:"chat", from, name, text}
//   {t:"member", data}                your own member data (status, colour...) -> everyone {t:"member", id, data}
//   {t:"lobby", data}                 the owner's lobby data (name, public, max, rules) -> everyone {t:"lobby", data}
//   {t:"to", to, msg}                 one member -> them {t:"from", from, msg} (challenges, answers)
//   {t:"sub" | "unsub", ch}           listen to a match channel (its players and spectators)
//   {t:"chan", ch, msg}               -> everyone listening on ch but you {t:"chan", ch, from, msg} (the match)
// It sends {t:"welcome", id, owner, lobby, members}, {t:"joined", id, name}, {t:"left", id}, {t:"owner", id} (the
// owner left - the next one in takes over) and {t:"error", msg}. A second Durable Object keeps the public list.

const CODE = /^\/lobby\/([0-9]{4,6})$/;
const REPLAY = /^\/replays\/([0-9]{6})$/;
const REPLAY_MAX = 600 * 1024;          // a shared replay's most (it comes packed: gzip + base64)
const REPLAY_KEEP = 30 * 24 * 3600 * 1000;
const MAX_MEMBERS = 16;
const GRACE = 120 * 1000;   // an empty lobby waits this long for someone to come back (Timmy 00:11)
const STALE_MS = 3 * 60 * 1000;
const json = (d, status = 200) => new Response(JSON.stringify(d), {
  status, headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
});

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    // A browser asks first before it POSTs JSON from another site (the web version, 19 Oct 13:58).
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: {
      "access-control-allow-origin": "*", "access-control-allow-methods": "GET, POST, OPTIONS",
      "access-control-allow-headers": "content-type", "access-control-max-age": "86400" } });
    if (url.pathname === "/") return new Response("Standoff lobbies - ok\n");
    if (url.pathname === "/lobbies") return env.DIRECTORY.get(env.DIRECTORY.idFromName("all")).fetch(req);
    if (url.pathname === "/replays" || REPLAY.test(url.pathname)) return env.SHELF.get(env.SHELF.idFromName("all")).fetch(req);
    const m = url.pathname.match(CODE);
    if (!m) return new Response("not found\n", { status: 404 });
    if (req.headers.get("Upgrade") !== "websocket") return new Response("expected a websocket\n", { status: 426 });
    return env.LOBBIES.get(env.LOBBIES.idFromName(m[1])).fetch(req);
  },
};

// The list of public lobbies (each lobby tells it when it changes, and every minute while it's open).
export class Directory {
  constructor(ctx) {
    this.ctx = ctx;
  }

  async fetch(req) {
    const url = new URL(req.url);
    if (req.method === "POST" && url.pathname === "/update") {
      const d = await req.json();
      await this.ctx.storage.put("l:" + d.code, { ...d, updated: Date.now() });
      return json({ ok: true });
    }
    if (req.method === "POST" && url.pathname === "/remove") {
      const d = await req.json();
      await this.ctx.storage.delete("l:" + d.code);
      return json({ ok: true });
    }
    const all = await this.ctx.storage.list({ prefix: "l:" });
    const now = Date.now();
    const out = [];
    for (const [k, v] of all) {
      if (now - v.updated > STALE_MS) await this.ctx.storage.delete(k);
      else if (v.public && v.players > 0) out.push({ code: v.code, name: v.name, version: v.version, players: v.players, max: v.max });
    }
    return json(out);
  }
}

// Shared replays, each under a 6-digit code; a day's alarm clears the ones older than REPLAY_KEEP.
export class Shelf {
  constructor(ctx) {
    this.ctx = ctx;
  }

  async fetch(req) {
    const url = new URL(req.url);
    if (req.method === "POST" && url.pathname === "/replays") {
      const body = await req.text();
      if (body.length > REPLAY_MAX) return json({ error: "That replay is too big to share" }, 413);
      let d;
      try { d = JSON.parse(body); } catch { return json({ error: "Not a replay" }, 400); }
      if (typeof d.data !== "string" || d.data.length < 10) return json({ error: "Not a replay" }, 400);
      let code = "";
      for (let i = 0; i < 20 && !code; i++) {
        const c = String(100000 + Math.floor(Math.random() * 900000));
        if (!(await this.ctx.storage.get("r:" + c))) code = c;
      }
      if (!code) return json({ error: "Try again" }, 503);
      await this.ctx.storage.put("r:" + code, { data: d.data, v: String(d.v || "?"), at: Date.now() });
      if (!(await this.ctx.storage.getAlarm())) await this.ctx.storage.setAlarm(Date.now() + 24 * 3600 * 1000);
      return json({ code });
    }
    const m = url.pathname.match(REPLAY);
    if (req.method === "GET" && m) {
      const r = await this.ctx.storage.get("r:" + m[1]);
      return r ? json({ data: r.data, v: r.v }) : json({ error: "No replay with that code" }, 404);
    }
    return new Response("not found\n", { status: 404 });
  }

  async alarm() {
    const all = await this.ctx.storage.list({ prefix: "r:" });
    const now = Date.now();
    for (const [k, v] of all) if (now - v.at > REPLAY_KEEP) await this.ctx.storage.delete(k);
    if (all.size) await this.ctx.storage.setAlarm(now + 24 * 3600 * 1000);
  }
}

export class Lobby {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  info(ws) {
    return ws.deserializeAttachment() || {};
  }

  open() {
    return this.ctx.getWebSockets().filter((s) => this.info(s).id && s.readyState === 1);
  }

  members() {
    return this.open().map((s) => {
      const a = this.info(s);
      return { id: a.id, name: a.name, data: a.data || {} };
    });
  }

  send(ws, d) {
    try {
      ws.send(JSON.stringify(d));
    } catch {}
  }

  all(d, except) {
    const s = JSON.stringify(d);
    for (const w of this.open()) if (w !== except) try { w.send(s); } catch {}
  }

  async meta() {
    return (await this.ctx.storage.get("meta")) || null;
  }

  async listing(meta, players) {
    const dir = this.env.DIRECTORY.get(this.env.DIRECTORY.idFromName("all"));
    const body = players > 0
      ? { code: meta.code, name: meta.name, version: meta.version, players, max: meta.max, public: !!meta.public }
      : { code: meta.code };
    try {
      await dir.fetch("https://dir/" + (players > 0 ? "update" : "remove"), { method: "POST", body: JSON.stringify(body) });
    } catch {}
  }

  async fetch(req) {
    const url = new URL(req.url);
    const code = url.pathname.split("/").pop();
    const p = url.searchParams;
    const name = (p.get("name") || "Player").slice(0, 16);
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    const socks = this.open();
    let meta = await this.meta();
    let error = "";
    if (p.get("create") === "1") {
      if (meta && socks.length > 0) error = "That lobby code is taken - try again";
      else meta = {
        code, name: (p.get("lname") || name + "'s Lobby").slice(0, 28), public: p.get("public") !== "0",
        max: Math.max(2, Math.min(MAX_MEMBERS, parseInt(p.get("max") || "8", 10) || 8)),
        version: (p.get("v") || "?").slice(0, 16), owner: 0, rules: {},
      };
    } else if (!meta || (socks.length === 0 && !(meta.empty_at && Date.now() - meta.empty_at < GRACE)))
      error = "No lobby with that code";
    else if (socks.length >= meta.max) error = "That lobby is full";
    if (error) {
      this.send(server, { t: "error", msg: error });
      server.close(1000, "refused");
      return new Response(null, { status: 101, webSocket: client });
    }
    const id = ((await this.ctx.storage.get("next")) || 0) + 1;
    await this.ctx.storage.put("next", id);
    if (!meta.owner || socks.length === 0) meta.owner = id;
    delete meta.empty_at;
    await this.ctx.storage.put("meta", meta);
    server.serializeAttachment({ id, name, data: {}, subs: [] });
    this.send(server, { t: "welcome", id, owner: meta.owner, lobby: meta, members: this.members() });
    this.all({ t: "joined", id, name }, server);
    await this.listing(meta, socks.length + 1);
    await this.ctx.storage.setAlarm(Date.now() + 60 * 1000);
    return new Response(null, { status: 101, webSocket: client });
  }

  async alarm() {
    const meta = await this.meta();
    const n = this.open().length;
    if (n === 0) {   // (empty: closed once its wait is over)
      if (!meta || !meta.empty_at || Date.now() - meta.empty_at >= GRACE - 1000) await this.ctx.storage.deleteAll();
      else await this.ctx.storage.setAlarm(meta.empty_at + GRACE);
      return;
    }
    if (meta) await this.listing(meta, n);
    await this.ctx.storage.setAlarm(Date.now() + 60 * 1000);
  }

  async webSocketMessage(ws, msg) {
    const me = this.info(ws);
    if (!me.id || typeof msg !== "string" || msg.length > 200000) return;
    let d;
    try {
      d = JSON.parse(msg);
    } catch {
      return;
    }
    switch (d.t) {
      case "chat":
        this.all({ t: "chat", from: me.id, name: me.name, text: String(d.text || "").slice(0, 200) });
        break;
      case "member":
        me.data = { ...(me.data || {}), ...(d.data || {}) };
        ws.serializeAttachment(me);
        this.all({ t: "member", id: me.id, data: me.data });
        break;
      case "lobby": {
        const meta = await this.meta();
        if (!meta || meta.owner !== me.id) break;
        const nd = d.data || {};
        if (typeof nd.name === "string") meta.name = nd.name.slice(0, 28);
        if (typeof nd.public === "boolean") meta.public = nd.public;
        if (Number.isInteger(nd.max)) meta.max = Math.max(2, Math.min(MAX_MEMBERS, nd.max));
        if (nd.rules && typeof nd.rules === "object") meta.rules = nd.rules;
        await this.ctx.storage.put("meta", meta);
        this.all({ t: "lobby", data: meta });
        await this.listing(meta, this.open().length);
        break;
      }
      case "to": {
        const s = JSON.stringify({ t: "from", from: me.id, msg: d.msg });
        for (const w of this.open()) if (this.info(w).id === d.to) w.send(s);
        break;
      }
      case "sub":
      case "unsub": {
        const subs = new Set(me.subs || []);
        if (d.t === "sub") subs.add(String(d.ch)); else subs.delete(String(d.ch));
        me.subs = [...subs];
        ws.serializeAttachment(me);
        break;
      }
      case "chan": {
        const s = JSON.stringify({ t: "chan", ch: String(d.ch), from: me.id, msg: d.msg });
        for (const w of this.open()) if (w !== ws && (this.info(w).subs || []).includes(String(d.ch))) w.send(s);
        break;
      }
    }
  }

  async webSocketClose(ws) {
    const me = this.info(ws);
    try {
      ws.close(1000, "bye");
    } catch {}
    if (!me.id) return;
    const others = this.open().filter((s) => s !== ws);
    this.all({ t: "left", id: me.id }, ws);
    const meta = await this.meta();
    if (!meta) return;
    if (others.length === 0) {   // (the last one out: off the list, but it waits GRACE for them to come back -
      meta.empty_at = Date.now();  // a phone put aside to send the code, 00:11)
      await this.ctx.storage.put("meta", meta);
      await this.listing(meta, 0);
      await this.ctx.storage.setAlarm(meta.empty_at + GRACE);
      return;
    }
    if (meta.owner === me.id) {   // the owner left - the next one in takes over
      meta.owner = Math.min(...others.map((s) => this.info(s).id));
      await this.ctx.storage.put("meta", meta);
      this.all({ t: "owner", id: meta.owner }, ws);
    }
    await this.listing(meta, others.length);
  }

  async webSocketError(ws) {
    await this.webSocketClose(ws);
  }
}
