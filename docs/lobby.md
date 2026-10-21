# Online lobbies (0.8.0, live in 0.8.1)

Timmy, 18 Oct 2026 20:19: "Can we work on the lobby system? Look at the steam lobby your only move is hustle has".
YOMI's Steam lobby was studied from a video (`Standoff Workshop/references/yomi/lobby/`, frames `full_54/60/66/108/138`).
That was for study only: the screens here are our own layout, built from the same parts.

## What it has (YOMI's part -> ours)
| YOMI's Steam lobby | Standoff |
|---|---|
| Lobby list: name, version, players; Refresh; a same-version filter | `LobbyScreen` list: the same columns, Refresh, Same version, plus join by a 4-digit code (no Steam friends list) |
| Create lobby: name, public / private, max players | Create lobby: a name, Public, Max 2-16 |
| In a lobby: members with status, the owner's crown, Challenge | MEMBERS: colour, name, (you), crown, status (idle / inviting / in a match), Challenge on idle members |
| Matches going on, Spectate | MATCHES: grouped by member status, Spectate (the host sends its state, then every turn) |
| Challenge -> accept / decline | an invite box, Accept / Decline; the inviter sees who's in, and the match starts when everyone has answered (or Start now) |
| Match settings in the lobby | RULES, set by the owner: turn clock, round length, 1v1 start distance, stage width, damage, hitstun, starting meter; presets Default / Quick / Thinking / Big stage |
| Chat | CHAT, with joins and leaves |
| 1v1 only | up to 6 a match: invite several at once, bots in the empty seats, free-for-all or teams |

## How it works
- **Server:** `relay/` is a Cloudflare Worker with Durable Objects. One `Lobby` object per code holds the members, the
  owner, the rules and the last 50 chat lines. It passes on direct messages (`to` -> `from`) and match channels
  (`sub` / `chan`). `Directory` keeps the public list (`GET /lobbies`); it drops entries older than 3 min and empty
  lobbies. When the owner leaves, the lowest id becomes owner. A dropped line keeps its place (0.46.0 - "Kept places"
  below). Run it locally with `npx wrangler dev --port 8787`; check
  it with `node test.mjs` (14 checks).
- **Client:** `scripts/net/lobby_net.gd` (`LobbyNet`) talks to the server over a WebSocket. With `use_loop` it uses
  `LoopLobby` instead: the same rules in-process, every message JSON-round-tripped, used by the tests and the screenshot
  tool.
- **A match:** `scripts/net/net_match.gd` (`NetMatch`). The phone that invited runs the match (the host). Every phone
  sends its pick to the host. The host plays the turn and publishes `{t, picks, snap}`. Every phone plays the same picks
  from the same JSON state, then takes the host's snapshot as the truth. A player who leaves becomes a bot; if the host
  leaves, the match ends for everyone.
- **Tests:** `tools/test.sh online` checks:
  - lobby: made, listed, joined, chat, the owner's rules;
  - a 3-seat challenge with a bot, played to the end on all phones while one phone watches;
  - all phones end the same;
  - back to the lobby, a second match, and the host leaving.
- **Screens:** `--lobbyshots=<dir>` renders the list, a lobby, an invite and New match off-screen
  (`scripts/dev/lobby_shots.gd`).

## The live server (since 18 Oct 20:57, 0.8.1)
- `wss://standoff-relay.blissfulzephyr.workers.dev` on Timmy's Cloudflare account. The account ID is in
  `relay/wrangler.toml`.
- Deploying uses the token in his user environment (`CLOUDFLARE_API_TOKEN`, set with setx):
  1. read it into the shell;
  2. run `npx wrangler deploy` in `relay/`;
  3. run `node test.mjs wss://standoff-relay.blissfulzephyr.workers.dev`, which should pass 14 checks.
- `LobbyNet.DEFAULT_URL` points at the live server. `-- --lobbies=ws://127.0.0.1:8787` uses a local `wrangler dev`
  instead.
- `godot --headless --path . -- --livecheck` (`scripts/dev/live_check.gd`) runs three phones over the live server:
  - a private lobby, chat, a challenge with a bot, one phone watching;
  - played to the end, and all three must end the same;
  - first run 20:59: everything passed, the match took 30.6 s.

## Kept places: a phone put aside (0.46.0)
Timmy, 20 Oct 18:13: "I find the lobby dies too wuickly and in the match I minimised it to text someone and it killed
the match"; 18:50 "If we both leave the game i mean for keeping it alive".

**Why it died.** The live server cut any WebSocket that was quiet for about a minute (probed: a silent one closed at
62 s with 1006; one sending a ping every 20 s stayed up 7 min), and the game sent nothing while a lobby sat idle - so
idle phones dropped every minute and came back as someone new. In a match, the host's line dropping ended it for
everyone, and a phone that got back in had a new id, so its seat was only handed back by name.

**Now:**
- **Pings.** Each phone sends a bare `ping` every 15 s (`LobbyNet.PING_EVERY`); the relay answers `pong` itself
  without waking the lobby (`setWebSocketAutoResponse`). A ping unanswered for 8 s (`DEAD_AFTER`) = a dead line that
  never closed - the phone drops it and gets back in. Back from another app, it pings at once to check.
- **Kept places.** A phone joins with `r=1`; its welcome carries a `key`. When its line drops, its place is kept
  10 min (`AWAY_MS`): everyone gets `{t:"away", id}`, the members list shows it greyed "away - back soon". It comes
  back with `resume=<id>&key=<key>`: the same id, its member data and match channels (`{t:"back", ...}` to the rest).
  A line that died unseen is replaced the same way (a ghost - nobody's told anything). After 10 min it's `left`. A
  phone that leaves on purpose sends `{t:"leave"}`: gone at once. Old phones (no `r=1`) are gone at once, as before.
- **The server finds dead lines.** Every 30 s (`TICK_MS`) a lobby checks: a phone that pinged before and hasn't for 45 s
  (`DEAD_MS`) is dropped (place kept). So a phone that loses signal is noticed within 45-75 s.
- **Minimised.** Android pausing the app sends `{t:"away"}` at once (its line still up); resuming sends `{t:"here"}`.
- **Lobbies** wait 10 min empty (`GRACE`, was 2), and a lobby with places kept isn't empty. The lobby screen keeps
  trying to get back in while the place is kept (it gave up after 8 tries, ~12 s).
- **The match** (`NetMatch`):
  - a player away: the host's bot plays their seat at once; back (`sync` on the match channel), the seat's theirs and
    they get the state;
  - **the host away: the match moves** to the first seat (in order) whose phone is here - every phone works out the
    same one from the same events, and every phone has the same state, so it goes on from where it is. The old host
    comes back as a player, its seat back. Nobody to take it on (the rest are bots): the match waits for the host
    ("Waiting for X to come back...");
  - a phone back asks on the match channel (`sync {f, name, tick}`) - whoever runs it answers with `state {host, ...}`.
    Nobody answering after 3 asks 4 s apart (`_settle`): the one running it here but quiet - ask again (a while); away
    with its place kept - wait for it; this phone ran it, or it's gone - **of the phones asking, the one furthest on
    (highest tick, then the first seat) runs it** and says `again {t, f, snap}`; the rest follow. Two phones running it
    at once: the one behind gives way (the same rule);
  - the host leaving the lobby moves the match too (it ended it). Leaving the match from its menu still ends it.
- **Tests:** `online_test` - `_test_match_moves`, `_test_both_away`, `_test_host_alone_back`, and the earlier rejoin
  tests on kept places; `relay/test.mjs` 27 checks (ping, away / back with the key, a ghost replaced, a wrong key,
  leave, all away); `godot --headless --path . -- --awaycheck [--lobbies=<url>]` (`scripts/dev/away_check.gd`) - two
  phones on real sockets: a player minimised, the host minimised, the phone running it going silent (found dead by the
  server), played to the same end.
- **Android closing the app** in the background (0.46.1): the lobby and match this phone is in are saved
  (`user://session.cfg` - code, place id + key, the match's channel, who runs it, the seat; saved again whenever the
  app goes to the background). Started again within 9.5 min (`SESSION_KEEP` - the place is kept 10): "You were in lobby
  1234 - in a match" / Back in / No. Back in = its own place, and `NetMatch.rejoin` asks the match channel for its seat
  - whoever runs it sends the match as it is now. Leaving on purpose clears it; a Nearby lobby this phone hosted isn't
  saved (it went with the app). Test: `online_test` `_test_restart_back`.

## Back into a match after a drop (0.18.0)
Timmy 01:32 ("3 makes sense"). The phone already gets back into its lobby by itself (00:11). Now, if it was in a match:
- **While it's away:** the host gives its seat to a bot. If a turn is open, the bot picks for it at once (before, it
  waited for the clock). The away phone's banner says "Connection lost - getting back in...".
- **Back in the lobby:** the lobby screen puts its status back ("in a match", not idle) and tells the game. The game
  sends the host `reclaim {f, name}`.
  - The host hands the seat back when the seat was left by someone of that name, and sends `state` (its sim now).
  - The phone takes that state and carries on (`NetMatch.resync`). A watcher just asks to watch again.
  - If it's refused, or the phone never gets back into the lobby, the match ends on that phone with why.
- **Found on the way:** a pick that reached the host before the host had opened that turn was thrown away. That
  happened when the player's phone finished playing the last turn first, and they got Hold when the clock ran out. The
  host now keeps early picks for their turn (`NetMatch._early`).
- **Test:** `online_test` `_test_match_rejoin`. Two phones; one drops mid-match, its bot plays on, it comes back, gets
  the seat, and the match ends the same on both.

## Nearby: the same Wi-Fi or a phone's hotspot (0.16.0)
Timmy, 19 Oct 00:38: "Whats local multiplayer over Bluetooth or the likes?". The options I gave him:
1. hotspot / same Wi-Fi;
2. Bluetooth / Wi-Fi Direct (needs an Android plugin);
3. pass-and-play.

00:43: "1 sounds like a pretty good soultion to me! I didnt know that worked".
- **The lobby screen** has two tabs: **Online** (the server above) and **Nearby (Wi-Fi / hotspot)**.
  - In Nearby, **Create lobby** makes this phone the server: `LanHost` (`scripts/net/lan_host.gd`).
  - Its lobby line says "you're hosting - keep Standoff open". There are no codes or addresses: the others' Nearby
    lists find it (01:24 "Do we need the IP for hot-spot? If not I say we remove all that" - 0.17.1).
- **The host phone** runs the online server's rules in-process (`LoopLobby`).
  - It uses WebSockets on port **47270**, with the same URLs and messages, so every `LobbyNet` works unchanged. The host
    phone's own one connects through 127.0.0.1.
  - Matches, chat, spectating and reconnecting all work as online.
  - When the host leaves, it sends everyone a `bye` ("The host closed the lobby"), then closes their sockets 0.4 s later.
    A WebSocket that closes drops what arrived with the close.
- **Finding it** (`LanFinder`, `scripts/net/lan_finder.gd`):
  - the host tells the network about itself every second (UDP broadcast to port 47272 — on the general address and
    each network's own `.255`, as a hotspot isn't the phone's default route);
  - finders also ask "standoff?" on port 47271 every 1.5 s (a broadcast), and the host answers them directly - two
    ways, in case one phone filters broadcasts.
  - The typed-address fallback was taken out in 0.17.1. If a phone's list never shows a host, that's the thing to bring
    back (`git show v0.17.0:scripts/ui/lobby_screen.gd`, `join_typed`).
- **No internet needed.** The phones only need to be on one network: a router's Wi-Fi, or everyone joining the host
  phone's hotspot.
- **Test:** `online_test` `_test_nearby`, on real sockets bound to 127.0.0.1 (`LanHost.bind_to`, so the PC's firewall
  isn't asked; `LanHost.broadcasts()` is then just 127.0.0.1). A phone hosts, the other's Nearby list finds it by
  itself and joins, chat, a full match that ends the same on both, then the host leaves. `--lobbyshots` adds `L5_nearby_list` / `L6_nearby_host`.

## Not done yet
- YOMI's Chess Timer: built in 0.17.0 and taken out in 0.17.1 (01:24 "I think round and turn timers are better").
- Saving your own rule presets by name.
- Character select (there is one character).
- Rating / ranked.
- A friends list.
- (Done in 0.46.0: a host who drops - the match moves to another phone; they come back as a player.)
