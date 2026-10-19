// The web version in a hidden Chrome (never on the screen), posing as a phone held sideways: its console and screenshots
// (19 Oct, 0.33.0). Serve build/web first, e.g. python -m http.server 8765 --directory build/web, or use the live site.
//   node tools/web_check.mjs <url> <out prefix> '<steps json>'      env: IOS=1 an iPhone's Safari, PORTRAIT=1 upright
//   steps: [{"at": secs, "shot": "name"} | {"at": secs, "tap": [x, y]} | {"at": secs, "eval": "js"}]
//   (x, y in CSS px of the 844x390 screen = half a 1688x780 screenshot's px)
// Chrome on Windows outlives a plain kill: each run uses a fresh port and closes its whole tree, or the next run
// talks to the old one (and its cache - the old build).
import { spawn, spawnSync } from "node:child_process";

const [url, out, stepsJson] = process.argv.slice(2);
const steps = JSON.parse(stepsJson || '[{"at":20,"shot":"a"}]');
const UP = process.env.PORTRAIT === "1";   // (held upright)
const W = UP ? 390 : 844, H = UP ? 844 : 390, PORT = 9400 + Math.floor(Math.random() * 500);   // (a fresh port: never an old Chrome)
const chrome = spawn("C:/Program Files/Google/Chrome/Application/chrome.exe", [
  "--headless=new", `--remote-debugging-port=${PORT}`, `--user-data-dir=${out}_prof`, "--no-first-run",
  "--use-angle=swiftshader", "--enable-unsafe-swiftshader", `--window-size=${W},${H}`, "about:blank"]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ws, id = 0;
const waiting = new Map();
const send = (method, params = {}) => new Promise((res) => { const i = ++id; waiting.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });

let target;
for (let k = 0; k < 40 && !target; k++) {
  await sleep(250);
  try { target = (await (await fetch(`http://127.0.0.1:${PORT}/json`)).json()).find((t) => t.type === "page"); } catch {}
}
ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
const t0 = Date.now();
const stamp = () => ((Date.now() - t0) / 1000).toFixed(1).padStart(5);
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && waiting.has(m.id)) { waiting.get(m.id)(m.result || m.error); waiting.delete(m.id); return; }
  if (m.method === "Runtime.consoleAPICalled")
    console.log(stamp(), m.params.type, m.params.args.map((a) => a.value ?? a.description ?? "").join(" ").slice(0, 300));
  if (m.method === "Runtime.exceptionThrown") console.log(stamp(), "EXCEPTION", JSON.stringify(m.params.exceptionDetails).slice(0, 400));
  if (m.method === "Log.entryAdded") console.log(stamp(), "LOG", m.params.entry.level, m.params.entry.text.slice(0, 300));
};
await send("Runtime.enable");
await send("Log.enable");
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: W, height: H, deviceScaleFactor: 2, mobile: true,
  screenOrientation: UP ? { type: "portraitPrimary", angle: 0 } : { type: "landscapePrimary", angle: 90 } });
await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
if (process.env.IOS === "1")   // (an iPhone's Safari, as far as the page can tell)
  await send("Emulation.setUserAgentOverride", { userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1" });
await send("Page.navigate", { url });
for (const s of steps) {
  const wait = s.at * 1000 - (Date.now() - t0);
  if (wait > 0) await sleep(wait);
  if (s.shot) {
    const r = await send("Page.captureScreenshot", { format: "png" });
    await import("node:fs").then((fs) => fs.writeFileSync(`${out}_${s.shot}.png`, Buffer.from(r.data, "base64")));
    console.log(stamp(), "shot", s.shot);
  }
  if (s.tap) {
    const p = [{ x: s.tap[0], y: s.tap[1] }];
    await send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: p });
    await sleep(80);
    await send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    console.log(stamp(), "tap", s.tap);
  }
  if (s.eval) {
    const r = await send("Runtime.evaluate", { expression: s.eval, returnByValue: true });
    console.log(stamp(), "eval", JSON.stringify(r.result?.value ?? r).slice(0, 300));
  }
}
// (Chrome on Windows outlives a plain kill - its whole tree, or the next run talks to this one)
spawnSync("taskkill", ["/PID", String(chrome.pid), "/T", "/F"]);
const prof = `${out}_prof`.replace(/\//g, "\\");   // (and any of its helpers that slipped the tree, by their profile)
spawnSync("powershell.exe", ["-NoProfile", "-Command", `Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'chrome.exe' -and $_.CommandLine -like '*${prof.split("\\").pop()}*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }`]);
process.exit(0);
