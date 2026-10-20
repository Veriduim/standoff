// The lobby server's checks (against `wrangler dev`): create, the public list, join, chat, member data, the owner's
// rules, a direct message (a challenge), a match channel (players + a spectator), errors, the owner leaving; kept
// places (a line dropping, back with its key, a dead line replaced, leaving on purpose - 0.46.0).
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
const back = await open(`/lobby/${code}?name=Timmy`);
await sleep(400);
check("an empty lobby waits for them to come back (Timmy 00:11 - the phone put aside)", has(back, (m) => m.t === "welcome"
  && m.owner === m.id));
back.close();
await sleep(300);
const put = await (await fetch(HTTP + "/replays", { method: "POST", body: JSON.stringify({ data: "H4sIAAAAAAAAA-test", v: "0.24.0" }) })).json();
const got = put.code ? await (await fetch(HTTP + "/replays/" + put.code)).json() : {};
check("a replay shared gets a code, and the code gets it back (02:36)", /^[0-9]{6}$/.test(put.code || "")
  && got.data === "H4sIAAAAAAAAA-test" && got.v === "0.24.0");
const none404 = await fetch(HTTP + "/replays/000000");
check("a wrong replay code says so", none404.status === 404);
const pre = await fetch(HTTP + "/replays", { method: "OPTIONS", headers: { origin: "https://veriduim.github.io",
  "access-control-request-method": "POST", "access-control-request-headers": "content-type" } });
check("a browser (the web version) may share a replay: its ask-first is answered, the answer readable from any site",
  pre.status === 204 && /content-type/i.test(pre.headers.get("access-control-allow-headers") || "")
  && none404.headers.get("access-control-allow-origin") === "*");
// Kept places (20 Oct 18:13 "I find the lobby dies too wuickly and in the match I minimised it to text someone and it
// killed the match"): phones that can come back (r=1) keep their place when the line drops.
const code2 = String(1000 + Math.floor(Math.random() * 8999));
const ann = await open(`/lobby/${code2}?name=Ann&create=1&lname=Kept&public=0&max=4&v=0.46.0&r=1`);
const bob = await open(`/lobby/${code2}?name=Bob&v=0.46.0&r=1`);
await sleep(400);
const annW = ann.got.find((m) => m.t === "welcome");
const bobW = bob.got.find((m) => m.t === "welcome");
check("a welcome carries a key to come back with", !!bobW && typeof bobW.key === "string" && bobW.key.length > 8
  && bobW.resumed === false);
const pong = new Promise((res) => { const was = bob.onmessage; bob.onmessage = (e) => { if (e.data === "pong") res(true);
  else was(e); }; setTimeout(() => res(false), 2000); });
bob.send("ping");
check("a ping is answered (the line's alive)", await pong);
for (const s of [ann, bob]) s.say({ t: "sub", ch: "m2" });
await sleep(200);
bob.close();
await sleep(600);
check("a line that drops keeps its place: the others are told it's away, not gone", has(ann, (m) => m.t === "away"
  && m.id === bobW.id) && !has(ann, (m) => m.t === "left"));
const bob2 = await open(`/lobby/${code2}?name=Bob&v=0.46.0&r=1&resume=${bobW.id}&key=${bobW.key}`);
await sleep(400);
const b2w = bob2.got.find((m) => m.t === "welcome");
check("back with its key: the same member again (same id), told it was away; the others told it's back",
  !!b2w && b2w.id === bobW.id && b2w.resumed === true && b2w.was_away === true
  && has(ann, (m) => m.t === "back" && m.id === bobW.id));
ann.say({ t: "chan", ch: "m2", msg: { k: "seg", n: 2 } });
await sleep(300);
check("...still on its match channel", has(bob2, (m) => m.t === "chan" && m.msg.n === 2));
const bob3 = await open(`/lobby/${code2}?name=Bob&v=0.46.0&r=1&resume=${bobW.id}&key=${bobW.key}`);
await sleep(500);
const b3w = bob3.got.find((m) => m.t === "welcome");
check("a dead line replaced (it never closed): the same member, the old line shut, nobody told anything",
  !!b3w && b3w.id === bobW.id && b3w.was_away === false && bob2.readyState !== 1
  && ann.got.filter((m) => m.t === "away" || m.t === "left").length === 1);
const fake = await open(`/lobby/${code2}?name=Bob&v=0.46.0&r=1&resume=${bobW.id}&key=wrong`);
await sleep(400);
const fw = fake.got.find((m) => m.t === "welcome");
check("a wrong key is just a new member", !!fw && fw.id !== bobW.id && fw.resumed === false);
fake.say({ t: "leave" });
await sleep(400);
check("leaving on purpose: gone at once", has(ann, (m) => m.t === "left" && m.id === fw.id));
ann.close();
bob3.close();
await sleep(500);
const keep = await open(`/lobby/${code2}?name=Cy&v=0.46.0&r=1`);
await sleep(400);
check("everyone's line dropped: the lobby's still there (their places kept)", has(keep, (m) => m.t === "welcome"
  && m.members.filter((x) => x.away).length === 2));
keep.say({ t: "leave" });
await sleep(300);
const failed = results.filter((r) => !r[1]).length;
console.log(`${results.length - failed}/${results.length} lobby checks passed`);
process.exit(failed ? 1 : 0);
