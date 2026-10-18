// Relay routing check: host + 2 players, a wrong code, a taken code, a player leaving, the host leaving.
const BASE = process.argv[2] || "ws://127.0.0.1:8787";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
function open(path) {
  const ws = new WebSocket(BASE + path);
  ws.got = [];
  ws.onmessage = (e) => ws.got.push(JSON.parse(e.data));
  return new Promise((res) => { ws.onopen = () => res(ws); ws.onerror = () => res(ws); });
}
const code = "T" + Math.random().toString(36).slice(2, 6).toUpperCase();
const results = [];
const check = (label, ok) => { results.push([label, ok]); console.log((ok ? "PASS " : "FAIL ") + label); };

const host = await open(`/room/${code}?host=1&name=Timmy`);
await sleep(300);
check("host welcomed as peer 1", host.got.some((m) => m.t === "welcome" && m.peer === 1));
const a = await open(`/room/${code}?name=Ana`);
const b = await open(`/room/${code}?name=Ben`);
await sleep(400);
check("players welcomed as 2 and 3", a.got.some((m) => m.t === "welcome" && m.peer === 2) && b.got.some((m) => m.t === "welcome" && m.peer === 3));
check("host told who joined", host.got.filter((m) => m.t === "joined").map((m) => m.name).join(",") === "Ana,Ben");
a.send(JSON.stringify({ t: "pick", move: "jab" }));
await sleep(300);
check("a player's message reaches the host with from=2", host.got.some((m) => m.t === "pick" && m.from === 2));
check("...and not the other player", !b.got.some((m) => m.t === "pick"));
host.send(JSON.stringify({ t: "lobby", n: 3 }));
host.send(JSON.stringify({ t: "seat", to: 3, you: 2 }));
await sleep(300);
check("host broadcast reaches both", a.got.some((m) => m.t === "lobby") && b.got.some((m) => m.t === "lobby"));
check("host message with to=3 reaches only Ben", b.got.some((m) => m.t === "seat") && !a.got.some((m) => m.t === "seat"));
const bad = await open(`/room/ZZZZ9?name=X`);
await sleep(300);
check("a wrong code is refused", bad.got.some((m) => m.t === "error" && /No game/.test(m.msg)));
const dup = await open(`/room/${code}?host=1&name=Y`);
await sleep(300);
check("a second host on the same code is refused", dup.got.some((m) => m.t === "error"));
b.close();
await sleep(400);
check("host told when a player leaves", host.got.some((m) => m.t === "left" && m.peer === 3));
host.close();
await sleep(400);
check("players told when the host leaves", a.got.some((m) => m.t === "host_left"));
const failed = results.filter((r) => !r[1]).length;
console.log(`${results.length - failed}/${results.length} relay checks passed`);
process.exit(failed ? 1 : 0);
