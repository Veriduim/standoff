# Online lobbies (0.8.0)

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

## To go live
1. Timmy logs in to Cloudflare once: `! cd relay && npx wrangler login`.
2. Deploy: `npx wrangler deploy` -> `wss://standoff-relay.<account>.workers.dev`.
3. Set `LobbyNet.DEFAULT_URL` to that address and build.

Until step 3 is done, the phone build shows "Can't reach the lobby server".

## Not done yet
- YOMI's chess-clock timer.
- Saving your own rule presets by name.
- Character select (there is one character).
- Rating / ranked.
- A friends list.
- Reconnecting to a match after dropping out.
