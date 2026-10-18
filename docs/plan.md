# Standoff - plan (working title)

Timmy, 18 Oct 2026 17:05: "Im looking to try make a Phone version of your only move is hustle that could support up to 6
players". His picks: same Wi-Fi (one phone hosts, online later), free-for-all and teams (picked in the lobby), simple stick
figures, playable core first.

An original game: Your Only Move Is HUSTLE is the reference for how a simultaneous-turn fighter plays - no names,
characters, art, sounds or code from it.

## The idea
The match runs at 60 ticks a second until any fighter is free to act, then stops. Everyone free picks a move in secret
(with a ghost preview of what it does), the picks play out together, and it runs on to the next stop. Up to 6 fighters on
one stage; each attack aims at a picked target.

## Steps
1. **Engine** (done 18 Oct) - `scripts/sim/`: `Sim` (turns, physics, hits), `Fighter` (state, snapshots), `Moves`
   (every move as data), `Bot`. Rules: strike beats grab, grab beats guard / parry, guard takes chip damage, a parry on
   the right frame stuns the striker, strikes meeting clash, armour soaks strikes, hitstun + combo scaling, KO, the win
   check; free-for-all or teams (no friendly fire). Tests: `tools/test.sh` (headless; bot matches with 2-6 fighters).
2. **Two characters** (done, to tune) - Bruiser (600 HP, armoured haymaker, body drop, Ground Slam super) and Dancer
   (450 HP, dash / air dash, spin kick, dive kick, Flurry super).
3. **The phone screen** - stick figures in six colours, a camera that keeps everyone in frame, HP / meter bars; the move
   menu -> aim / target -> a looping ghost preview -> Confirm; a turn timer. Landscape.
4. **Same Wi-Fi** - one phone hosts (ENet), the others find it (UDP broadcast) or type a short code; lobby: name, colour,
   character, team; bots fill empty seats. The host runs the real match and sends each segment's picks + the snapshot at
   its end; phones replay it for show and take the snapshot as the truth.
5. **Android build** to try with friends.

## His calls so far (18 Oct)
- 17:29 "for actions move them to the tabs that we pop up or from the side so we can test the frames" -> side tabs that
  slide out the moves (PickPanel), a frame scrubber over the ghost with hit / hurt boxes.
- 17:37 "I dont like target ... one char that has as many moves as what a YOMIH char would have ... fit with icons.
  Just have the direction functionality" -> no targets; a DIRECTION is the only thing picked with a move (Moves `aim`:
  facing / dir8 / up / down / none); the Dancer has 31 moves; icons are drawn from her own stick figure in each move's
  key pose (MoveIcon); parry timing became Parry Early (frames 1-6) / Parry Late (7-13).
- 17:41 online: a phone can host, but players can't reach it over the internet directly (mobile CGNAT, routers) - a
  small relay with room codes is the way (his hosting call); same Wi-Fi first.

## To tune / later
- **Match length with 6:** bot matches take 120-270 decision points with 6 fighters (50-90 with 2). At ~10 s a decision
  that's far too long - lower HP or more damage with more players (a lobby setting), and a turn timer.
- Directional influence when hit, a burst out of combos, wall bounces, more characters, online play, replays.
