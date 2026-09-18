# Steal a Rotting Brain

A Roblox parody of the *Steal a Brainrot* format, except everyone is a zombie and
the collectibles are **rotting brains** that sit on graves and passively print cash.

Built as a [Rojo](https://rojo.space) project: every script is plain Luau and the
entire map is generated procedurally at runtime, so there are no `.rbxl` binaries
or imported assets to keep in sync.

---

## Core loop

| Step | How it works in game |
| --- | --- |
| **Get a graveyard** | You are handed one of the 8 graveyards the moment you join. Your name goes up on the sign. |
| **Buy rotting brains** | Brains ride the conveyor belt down the middle of the map. Hold **E** near one to buy it; it drops onto a free grave. |
| **Earn money** | Every brain on a grave pays out cash per second, forever, multiplied by your rebirth bonus. |
| **Steal from others** | Walk into an unlocked graveyard and hold **E** on someone else's brain for 6 seconds to lift it, then carry it home. Carrying slows you down and puts a big red label over your head. |
| **Defend your graveyard** | Stand on the pad inside your gate to lock it (nobody can steal while it's shut), or click/tap to claw a thief — a hit teleports the stolen brain straight back to its grave and stuns them. |
| **Rebirth** | At the Crypt of Rebirth, trade $1M plus every brain you own for a permanent **+25% income** and **+6s gate lock**. Requirement goes x4 each time. |

Extras that keep the loop from jamming: hold **X** on one of your own brains to scrap
it for 25% of its price, and any brain left on the belt too long is incinerated.

## Brains, rarities and variants

Eight rarities — Common, Uncommon, Rare, Epic, Legendary, Mythic, Godly, Secret —
across 15 brains from *Gurglini Grotesko* ($100, $2/s) up to *The Big Rotto*
($40M, $190K/s). Rarity sets the spawn weight and the colour of the label and
podium glow.

Every brain also rolls a variant:

| Variant | Chance | Income | Price | Look |
| --- | --- | --- | --- | --- |
| **Standard** | ~94.8% | x1 | x1 | One of 8 rotten colours: Mossy, Bruised, Fleshy, Bloated, Bile, Tar, Frostbitten, Infected |
| **Gold** | ~4.3% | **x3** | x4 | Metallic gold with a warm glow |
| **Rainbow** | ~0.9% | **x8** | x12 | Neon, hue-cycling, glowing |

So the same brain can show up as `Mossy Cranium Crunchini` or, if you are lucky,
`Rainbow Cranium Crunchini`. Anything Legendary-or-better, or any Gold/Rainbow,
is announced to the whole server when it hits the belt.

## Running it

You need [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (`rojo`
CLI 7.x) and Roblox Studio.

```bash
# serve into Studio (install the Rojo plugin, then Connect)
rojo serve

# or build a place file you can open directly
rojo build -o steal-a-rotting-brain.rbxl
```

Then press **Play**. The map builds itself on the first server heartbeat.

For saving to work in Studio, enable **Game Settings → Security → Enable Studio
Access to API Services**. Without it the game still runs — it just hands out
temporary profiles and logs a warning instead of overwriting anyone's real data.

See [`docs/SETUP.md`](docs/SETUP.md) for the step-by-step version and
[`docs/DESIGN.md`](docs/DESIGN.md) for the economy math and system breakdown.

## Controls

| Input | Action |
| --- | --- |
| **E** (hold) | Buy from the belt · steal a rival's brain (6s) |
| **X** (hold) | Scrap your own brain for 25% |
| **E** on the gate pad | Lock / unlock your graveyard |
| **E** at the crypt | Rebirth |
| **Left click / tap / gamepad X** | Claw swing |

## Project layout

```
default.project.json      Rojo mapping, plus Lighting/Atmosphere setup
src/shared/               ReplicatedStorage.Shared -- used by both sides
  Config.luau             all balance numbers and content in one place
  BrainFactory.luau       builds brain models from primitives
  Format.luau             $1.23M / 1:05 formatting
  Remotes.luau            the four RemoteEvents
  Signal.luau, Tags.luau
src/server/               ServerScriptService.Server
  init.server.luau        bootstrap: Init all, Start all, then open sessions
  Services/
    DataService           DataStore load/save, autosave, save hooks
    WorldBuilder          generates the whole map
    PlotService           graveyard ownership, grave slots, gate locking
    BrainService          brain records and their models
    ConveyorService       belt spawning, movement, purchases
    StealService          steal prompts, carrying, deposit, returns, scrapping
    CombatService         claw swings and thief stunning
    EconomyService        cash, passive income, HUD state push
    RebirthService        rebirth milestones and multipliers
    ZombieService         zombie look, speed, nametags, stuns
    LeaderboardService    the in-world top-earners board
    FeedbackService       notification/effect plumbing
src/client/               StarterPlayerScripts.Client
  Controllers/            HUD, toasts, effects, attack input, rainbow hues
  UiKit.luau              palette and small UI builders
```

Services are plain modules with `:Init()` (build state, no yielding) and
`:Start()` (connect events, spawn loops). The bootstrap injects the whole service
table into each one, so they call each other without circular requires. Player
sessions only begin after every service has started, so nobody misses the
`ProfileLoaded` signal.

## Tuning

Almost everything worth changing lives in `src/shared/Config.luau`: prices,
income, spawn weights, variant multipliers, the rotten colour palette, steal hold
time, carry speed penalty, lock duration and cooldown, claw range and stun,
rebirth requirements, and the number of graveyards (`Config.Plot.Count`, which is
also the soft player cap).

Adding a brain is one line in `Config.Brains` — the conveyor, prompts, podium
labels, signs and saves all pick it up automatically.

## Anti-exploit notes

The client never decides anything: it draws pushed state and forwards a single
"I swung" message. Purchases, steals, scraps, locks and rebirths are all driven by
server-side `ProximityPrompt.Triggered`, which cannot be faked by a client, and
the claw remote is rate-limited server-side with its own range and facing checks.

## Not included

Monetisation (Robos/gamepasses), custom animations and uploaded audio, and
cross-server global leaderboards. The sounds used are the ones that ship with the
Roblox client, so nothing needs uploading to hear feedback.
