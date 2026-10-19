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
  lobbies. When the owner leaves, the lowest id becomes owner. Run it locally with `npx wrangler dev --port 8787`; check
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
- A host who drops can't get back into their match (it ends for everyone, as before).
