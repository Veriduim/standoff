// The lobby server's checks (against `wrangler dev`): create, the public list, join, chat, member data, the owner's
// rules, a direct message (a challenge), a match channel (players + a spectator), errors, the owner leaving.
const BASE = process.argv[2] || "ws://127.0.0.1:8787";
const HTTP = BASE.replace(/^ws/, "http");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
function open(path) {
  const ws = new WebSocket(BASE + path);
  ws.got = [];
  ws.onmessage = (e) => ws.got.push(JSON.parse(e.data));
  ws.say = (d) => ws.send(JSON.stringify(d));
  return new Promise((res) => { ws.onopen = () => res(ws); ws.onerror = () => res(ws); });
}
const has = (ws, f) => ws.got.some(f);
const code = String(1000 + Math.floor(Math.random() * 8999));
const results = [];
const check = (label, ok) => { results.push([label, ok]); console.log((ok ? "PASS " : "FAIL ") + label); };

const timmy = await open(`/lobby/${code}?name=Timmy&create=1&lname=Test%20Lobby&public=1&max=4&v=0.8.0`);
await sleep(400);
const w = timmy.got.find((m) => m.t === "welcome");
check("creating a lobby: welcomed as its owner", !!w && w.owner === w.id && w.lobby.name === "Test Lobby" && w.lobby.max === 4);
const list = await (await fetch(HTTP + "/lobbies")).json();
check("the public list has it with 1 player", list.some((l) => l.code === code && l.players === 1 && l.version === "0.8.0"));
const ana = await open(`/lobby/${code}?name=Ana`);
const ben = await open(`/lobby/${code}?name=Ben`);
await sleep(400);
const aw = ana.got.find((m) => m.t === "welcome");
check("joining: welcomed with the lobby and its members", !!aw && aw.members.length === 2 && aw.owner === w.id);
check("the others are told who joined", timmy.got.filter((m) => m.t === "joined").map((m) => m.name).join(",") === "Ana,Ben");
ana.say({ t: "chat", text: "hi all" });
await sleep(300);
check("chat reaches everyone", has(timmy, (m) => m.t === "chat" && m.text === "hi all") && has(ben, (m) => m.t === "chat" && m.name === "Ana"));
ben.say({ t: "member", data: { status: "idle", colour: 3 } });
await sleep(300);
check("member data reaches everyone", has(ana, (m) => m.t === "member" && m.data.colour === 3));
ana.say({ t: "lobby", data: { rules: { turn: 10 } } });
timmy.say({ t: "lobby", data: { rules: { turn: 45 }, name: "Renamed" } });
await sleep(300);
check("only the owner sets the rules", has(ben, (m) => m.t === "lobby" && m.data.rules.turn === 45 && m.data.name === "Renamed")
  && !ben.got.some((m) => m.t === "lobby" && m.data.rules.turn === 10));
const bw = ben.got.find((m) => m.t === "welcome");
ana.say({ t: "to", to: bw.id, msg: { k: "challenge" } });
await sleep(300);
check("a direct message (a challenge) reaches only its one", has(ben, (m) => m.t === "from" && m.msg.k === "challenge")
  && !has(timmy, (m) => m.t === "from"));
for (const s of [ana, ben, timmy]) s.say({ t: "sub", ch: "m1" });
await sleep(200);
ana.say({ t: "chan", ch: "m1", msg: { k: "seg", n: 1 } });
await sleep(300);
check("a match channel reaches its players and spectators, not the sender", has(ben, (m) => m.t === "chan" && m.msg.n === 1)
  && has(timmy, (m) => m.t === "chan") && !has(ana, (m) => m.t === "chan"));
const four = await open(`/lobby/${code}?name=Cal`);
const five = await open(`/lobby/${code}?name=Dee`);
await sleep(300);
check("a full lobby says so", has(five, (m) => m.t === "error" && /full/.test(m.msg)));
const none = await open(`/lobby/0001?name=X`);
await sleep(300);
check("a wrong code says so", has(none, (m) => m.t === "error" && /No lobby/.test(m.msg)));
const dup = await open(`/lobby/${code}?name=Y&create=1`);
await sleep(300);
check("a taken code can't be created again", has(dup, (m) => m.t === "error" && /taken/.test(m.msg)));
timmy.close();
await sleep(500);
check("the owner leaving: everyone told, the next one in owns it", has(ana, (m) => m.t === "left")
  && has(ana, (m) => m.t === "owner" && m.id === aw.id));
for (const s of [ana, ben, four]) s.close();
await sleep(500);
const after = await (await fetch(HTTP + "/lobbies")).json();
check("the empty lobby leaves the list", !after.some((l) => l.code === code));
const failed = results.filter((r) => !r[1]).length;
console.log(`${results.length - failed}/${results.length} lobby checks passed`);
process.exit(failed ? 1 : 0);
