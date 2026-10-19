# The Dancer as a zoner - research and the rework (0.29.0)

Timmy, 19 Oct 03:32: "All id say is rework dancer kit. Make sure she really fits the zoner/control space char we are
trying to make and research othrr fighting games that have these kinds of chars like Smash Bros, MK, Street Fighter and
then see how these would Translate to Hustle with the help of its wiki and 5 base chars."

Everything below is study only. No move, name or number is copied; each idea is rebuilt as our own move for a
simultaneous-turn game (docs/yomi_chars.md, memory "originality").

## Sources
- **Street Fighter**
  - Dhalsim and Guile: the SF6 pages on the SRK wiki (srk.shib.live: Strategy, Matchups, Introduction); dood.jp's
    SF6 Dhalsim page; PCGamesN and eXputer Guile guides; Sonic Hurricane's CvS2 Guile strategy; the Eventhubs SF4
    Guile move list.
  - Menat: the SRK wiki SFV page and its Strategy page; Dashfight's Menat guide.
  - JP: guides from Mobalytics ("How to beat JP", "How to play against zoners"), GGRecon, Prima and Wccftech.
  - SF defence: esports.gg on SFV defence.
- **Mortal Kombat**
  - Cetrion: Dashfight's Cetrion guide plus two "how to play against Cetrion" guides; Eventhubs on her Aftermath
    update ("zoning and a powerful mid-range game"); the Eventhubs move list.
  - Kitana: Eventhubs' MK11 moves and "Kitana's projectile" history; the Dashfight guide; Prima's MKX guide; the MKX
    variations article; the UMK3 page on the SRK wiki.
  - Jade: the Dashfight "play against Jade" guide, Shacknews, ExitLag's Jade guide, and her MK wiki page.
  - MK zoning in general: PlayStation Compete, "How to beat projectiles and zoners".
- **Smash Bros.**
  - Zoner overviews: GamersDecide "best zoning characters" and Inven Global's zoner tier list.
  - SmashWiki: Snake (SSBU) and directional influence.
  - Eventhubs on Pac-Man's hydrant play; the Villager page on the Smash fandom wiki.
- **Guilty Gear / Granblue**
  - Dustloop: Venom (ACR, Reload, Xrd), Zato (GGML), Metera (GBVSR).
  - Automaton and Shacknews on Venom in Strive.
- **Your Only Move Is HUSTLE**
  - Wizard: the gameplay.tips Wizard guide, the unofficial Wizard wiki (miraheze), the itch.io threads on Wizard and
    orbs, and the communal Wizard guide.
  - The other four: our earlier research in docs/yomi_chars.md (the wiki, WhimsNum's Robot and Mutant guides, the
    Ninja guide).
  - The mizuumi / gbl wiki pages sat behind a bot check, so they couldn't be read.

## What zoners share (across all four series)
1. **A tool for every distance**, layered so there's no safe spot:
   - Cetrion: a get-off-me close in, a frustrater at mid range, a punish at long range.
   - Guile: Sonic Boom for range and Flash Kick for jumps.
   - Dhalsim: long limbs, fire at range, slide/teleport out.
2. **Pieces left on the stage (set-play).** Things that stay after she acts and change where the enemy can stand:
   - Menat's orb: set it, then recall it, and it hits on the way back.
   - Venom's balls, Snake's C4, Pac-Man's hydrant, Wizard's Spark Bomb and Orb.
   - JP's portal, which is a trap and a teleport at once.

   This is what lifts "throws projectiles" into "controls space".
3. **Projectile control.** Their shots and the enemy's:
   - Zato's and Fox's reflectors; Villager's pocket;
   - Jade's glow that projectiles pass through;
   - Wizard's Gust, which moves projectiles AND players.
4. **A way to reset to range.** Pushback, wind, knockback that sends them back out (Kitana's fan lift, Cetrion's
   rocks, Guile's pushback), or a teleport/escape (Dhalsim, JP's portal).
5. **An anti-air** so jumping over the projectiles isn't free: Guile's Flash Kick, Dhalsim's limbs, Kitana's
   Square Boost air answers.
6. **The weakness: close range.** Every guide on beating a zoner says the same thing: get in and stay in. They're slow
   to approach, light, low on reversals and short on big close-range damage (Dhalsim's walk, Cetrion's slow buttons,
   Menat without her orb). Without that weakness a zoner is just better than everyone.

## How that translates to Hustle
YOMI is simultaneous turns, and everyone sees the ghosts, so some things change:
- **A trap must be read, not hidden.** In real time a trap works because you forget it's there. In YOMI everyone sees
  it on the ghost, so a trap works by **cutting options**: walking through it costs a hit, so they jump, roll or wait,
  which you can predict. Wizard's Spark Bomb works exactly like that.
- **Wind is a YOMI tool.** Wizard's Gust moves fighters and projectiles. Pushing someone during their startup makes
  their attack whiff, which is a prediction win with no damage. In real time that would be a gimmick; with turns it's
  a real read.
- **Distance is a slider.** YOMI lets moves take a Distance (Wizard's Mana Strike, the dashes). We already had the
  slider, so a trap's placement uses it.
- **The five base characters as a map:**

| YOMI | What it shows for a zoner | What the Dancer takes (our own version) |
|---|---|---|
| **Wizard** - the zoner | Orb and Spark Bomb (pieces on the stage), Gust (wind on fighters + shots), Flame Wave (a slow wall), Hover | **Fan Ward** (a fan left hanging), **Fan Gust** (wind), Ground Ripple already the slow wall |
| **Cowboy** - limited ammo | Bullets that bounce and take DI; Foresight's after-image to teleport to | Her two fans are the ammo; Recall with a direction (0.15.0); **Fan Step** to a fan - now also to a hanging ward |
| **Ninja** - all-rounder | Shuriken stall, Sticky Bomb, Substitute to his own projectile | Air Fan; Fan Step = swap to her projectile |
| **Robot** - the anti-zoner (armour, slow, strong mid range) | What she must beat: armour through projectiles, a slow approach | Wards and Ripple make his approach costly; she has no armour of her own |
| **Mutant** - the anti-zoner (rushdown, jukes) | What beats her: fast approaches, 50/50s up close | Her answers: Fan Gust to reset, Uppercut / Updraft vs jumps, Back Step, Mirror; still weaker close (the point-blank rule) |

## What changed in 0.29.0
### Cut: the rushdown moves
They belonged to a brawler, and they're in git (0.28.0) if any come back. Some may suit the Bruiser (Muay Thai + Little
Mac, later).

| Cut | Why |
|---|---|
| Knee Dash | Guard-breaking rush in: a rushdown tool |
| Flash Kick | A third reversal anti-air beside Uppercut and Updraft |
| One-Two -> Spin Finish | A close-range jab combo chain |
| Dive Kick, Air Spin | Air approach tools |
| Hip Toss, Spin Throw | Command grabs (a grappler's damage); she keeps the plain Grab and Air Throw |
| The Sway stance (Sway, Sway Kick, Rising Heel, Sway Step) | A close-range evasive pressure stance |

### Added: the zoner's kit
| Move | What it does | Studied from |
|---|---|---|
| **Fan Ward** (Special, f7, needs a fan) | Sends a fan out any of 8 ways; it stops where the **Distance** says (about 70-250 px) and **hangs there** for 5 s:<br>- hits anyone who walks into it, then heads home;<br>- clashing with a projectile eats it;<br>- sent into the floor, it sits low as a mine;<br>- **Recall** pulls it home through whoever's in between (a pincer);<br>- **Fan Step** blinks her to it. | Menat's orb + recall, Wizard's Spark Bomb, Venom's balls, Snake's C4, JP's portal |
| **Fan Gust** (Special, f8-15, needs a fan) | Both fans swept forward. The wind in front of her (240 px):<br>- **shoves enemies away**, with no damage and no hitstun;<br>- blows **their shots back the way they came**;<br>- sends their returning fans home;<br>- carries **her own fans further out**, and a hanging ward drifts toward them.<br>The Cyclone (a heavy) holds. | Wizard's Gust in YOMI |
| **Fan Flick** (Attack, right after landing a Fan Slash) | The fan flicked out of the slash. It hits, knocks them back out to her range and flies home. It's her one chain, and it ends at range instead of in a corner combo. | Kitana's fan toss after a strike; what One-Two was for a brawler |
| **Mirror** now **reflects** | In its window a projectile is **turned round**: back it flies, 20% faster, as hers. A returning fan is sent home instead (it isn't hers to keep); a heavy one goes through. It still catches strikes. | Zato's and Fox's reflectors |

### Her kit by distance now
- **Far:**
  - Fan Throw (8 ways, boomerang), Ground Ripple (low, unparriable), Fan Ward;
  - supers Fan Storm, Grand Finale.
- **Mid (her range):**
  - Fan Slash -> Fan Flick, Side Kick, Straight, Sweep, Spin Kick, Axe Kick (a slow overhead), Low Kick;
  - the fan's-edge bonus;
  - Cyclone.
- **Close (get-off-me):** Fan Gust, Uppercut (initiative invuln), Updraft, Back Step, Mirror, Gale (super), Grab.
- **Air:** Air Fan, Air Kick, Air Knee, Air Throw, Fan Ward in the air.
- **Moving:** Fan Step (to a fan or a ward), Silk Glide (under projectiles), Snap Step, Dodge, Recall with a direction.

### Her weaknesses (kept)
- **Point blank she's weaker:** x0.8 damage, less hitstun, worse on block.
- **No fan, no guard:** with both fans out she blocks worse. Ward, Throw and Flick send a fan out, and Gust and Fan
  Slash need one in hand, so every trap she sets leaves her a little more open.
- **Light:** 450 HP, weight 0.85.
- **No guard break, no command grab, no armour.** Her damage up close is lower than a brawler's.

## Checks
- **Tests (49, all pass):** a new section covers:
  - the ward stops at the Distance and hangs;
  - it's still there 2 s later and shows in a replay as a ward;
  - walking into it hits;
  - Recall's pincer hits;
  - a ward sent up hangs high and Fan Step blinks to it;
  - one sent down sits as a mine;
  - Gust shoves with no damage, blows a Ripple back and carries a ward on;
  - Mirror turns a Ripple back into its thrower and sends a thrown fan home;
  - the bots only use moves she has.

  The old checks moved: Guard Break is now checked on the rule itself, the no-hit-cancel check uses Encore, the
  launcher check uses Uppercut, and the air-menu check uses Air Kick.
- **Hard bots, 6 matches:**
  - Fan Ward was picked 53 times, and ward hits did 440 damage.
  - The bot's lookahead now values her range: +5 for 90-260 px, -4 point blank.
  - Fan Gust is still picked rarely. The bots prefer immediate damage, so it's a player's tool for reads.

## Open questions for Timmy
- **Encore** (Tempo at four beats) is still a melee rush. It could become a fan finisher at range.
- **Approach speed:** her dash (17) and walk (6.5) are unchanged because he liked her movement. Zoners are usually
  slower forward.
- **Snap Step and Windmill** are still in her base kit (a fast forward step; a low spinning floor attack).
