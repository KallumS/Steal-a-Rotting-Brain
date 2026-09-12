# Setup

## 1. Install the tooling

You need Roblox Studio plus the Rojo CLI (7.x). Pick whichever installer you
already use:

```bash
# Rokit (recommended, cross-platform)
rokit add rojo-rbx/rojo

# Aftman
aftman add rojo-rbx/rojo

# Cargo
cargo install rojo

# Windows
winget install Rojo.Rojo
```

Then install the **Rojo** plugin inside Studio (Studio → Plugins → Marketplace →
search "Rojo"), which is what talks to the CLI.

## 2. Open the project

Two ways to work:

**Live sync (best while developing)**

```bash
rojo serve
```

Open any empty baseplate in Studio, open the Rojo plugin, press **Connect**, and
every file save syncs straight into the open place.

**One-shot build**

```bash
rojo build -o steal-a-rotting-brain.rbxl
```

Open the generated `.rbxl` in Studio. Rebuild whenever you change a file.

> The map is built at runtime by `WorldBuilder`, so an empty baseplate is
> expected — don't be alarmed by a blank Workspace before you press Play.
> Any baseplate part already in the place is harmless; the generated world
> sits above and around the origin.

## 3. Turn on saving (optional but recommended)

DataStores are unavailable in Studio unless you allow them:

**Home → Game Settings → Security → Enable Studio Access to API Services**

Without it, `DataService` logs `DataStores unavailable, running with temporary
profiles` and everyone plays on a throwaway profile. Gameplay is identical; it
just won't persist.

## 4. Play

Press **Play** (F5). You will be assigned a graveyard, and the belt starts with
three brains already on it.

To exercise the stealing and clawing, use Studio's multiplayer test:

**Test → Clients and Servers → 2 players → Start**

Each client gets its own graveyard, and you can run brains between them.

## 5. Publish

File → Publish to Roblox, then in the place's settings on the website:

- Set max players to **8** or fewer. `Config.Plot.Count` is 8, and a ninth player
  is told every graveyard is taken (they can still walk around and steal, but
  have nowhere to put anything).
- Publishing is what makes DataStores work for real players; Studio's API access
  toggle only affects Studio sessions.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Nothing appears when you press Play | Rojo isn't connected, or the sync landed in a different place file. Check `ServerScriptService.Server` exists. |
| `missing service module "X"` | A file under `src/server/Services` didn't sync; reconnect Rojo. |
| Progress resets every session | Studio API access is off, or the place isn't published. |
| "Every graveyard is taken!" | More players than `Config.Plot.Count`. Raise it (the world builder lays out any even count) or lower max players. |
| No prompts appear near the belt | You're further away than `Config.Conveyor.PromptDistance` (14 studs), or another prompt is winning the keybind — walk closer. |
