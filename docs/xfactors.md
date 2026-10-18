# The Dancer's x-factor - on trial (0.9.0)

**Timmy, 18 Oct:**
- 21:11: "So who is the char we are working in first? As every char an x factor so to speak"
- 21:14: "Can we try the fans, temp and dance forms? Maybe combine two of them honestly"
- 21:17: "Just to explain. We may pick one or a combination of two"

**How they're switched on:**
- Each one is a switch: on the home screen (DANCER'S X-FACTOR, bottom left, kept between plays), or in a lobby's rules
  (the owner sets it).
- In code it's the rules' `"xf"`, e.g. `"fans,tempo"`, held in `Sim.xf`.
- With all three off, the game is as it was.
- YOMI gives each character one system of their own, e.g. Cowboy's gun with its limited bullets and Ninja's momentum.
  These are our own versions of that idea.

| | What it is | Moves it adds | Numbers (`Sim`) |
|---|---|---|---|
| **Fans** | She has two fans in hand (gold ◆ on her card). Fan Throw and Air Fan send one out like a boomerang: it flies out, turns, and comes back to her hand. It hits on the way out and on the way back, once per enemy per throw. If it's blocked, it bounces home. Fan Throw and Fan Slash need a fan in hand. | **Fan Slash** (Attack: a wide, quick slash). **Recall** (Special, while a fan is out: it turns for home at once, fast, and can hit everyone again on the way). | `FANS_MAX` 2, `FAN_OUT` 24 ticks, `FAN_BACK` 13 px/tick, `FAN_RECALL` 20, `FAN_LIFE` 240 |
| **Tempo** | A beat (pink ▮ on her card) for each move of hers that lands or is blocked (once per move; a fan counts once per throw), and for dodging through a hit. Each beat adds damage. Getting hit loses them all, and with no new beat one fades. | **Encore** (Special, at four beats: a four-hit dance ending in a launch; it spends all four). | `TEMPO_MAX` 4, `TEMPO_DMG` +6% a beat, `TEMPO_FADE` 300 ticks |
| **Forms** | Flow is the Dancer as she was. **Snap**: her strikes do 15% more damage and +2 hitstun. **Floor**: she's low (56 tall instead of 104), so high hits pass over her; she only has her floor moves, low kicks / sweeps / ripple / Dodge, defence and supers. No jumps. Getting up off a knockdown puts her back in Flow. | **Snap Form / Floor Form / Flow Form** (Special, 8f). Snap: **Pop** (a 2f jab), **Snap Kick**. Floor: **Windmill** (three low hits, a knockdown), **Kip-Up** (invulnerable rising kick, back to Flow), **Floor Slide** (Movement). | `FLOOR_HEIGHT` 56, `SNAP_DMG` 1.15, `SNAP_STUN` 2 |

**Tests and screenshots:**
- `tools/test.sh sim`, section "The Dancer's x-factors on trial" (19 checks):
  - each switch, each move, the numbers;
  - the state survives a JSON round trip, as online play needs;
  - bot matches end with each switch on its own and with each pair.
- `tools/test.sh ui`: the home switches and a whole match.
- `-- --xfshots=<dir>` renders the screenshots.
