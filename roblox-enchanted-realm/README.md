# Enchanted Realm: Inkbound — Roblox Metroidvania

A complete, playable 2D side-scrolling Metroidvania built for **Roblox Studio**, ported from the "Enchanted Realm" Game Design Document (Group 5) and given a unique **hand-drawn "Inkbound"** identity.

## What it is (from the GDD, kept intact)
- **Genre:** Metroidvania (Hollow Knight / Ori / Blasphemous inspired)
- **Story:** A warrior is pulled into the fantasy world of Encantadia, befriends Mish, defeats six Guardians, claims the Grand Key from Nukos the Squid Monster, and finds a way home.
- **6 contiguous zones:** Enchanted Forest → Mechanical Ruins → Burning Forest → Frozen Ruins → Secret Cave → Sky Ruins → Forgotten Underground (final).
- **6 Guardians with GDD-accurate attacks:** Kidlat (shield/beam), Piyedro (dash/slam/pillars), Peyro (fire wall/eruption/burn), Dan (ice projectiles/stomps), Maam Jyr (lightning/thunder/wind), Nukos (tentacle slam/ink/grab, underwater phase).
- **Ability gating:** Lightning → Fire → Ice → Wind → Power Rock → Lightning Core unlock new paths (vine/wood/frozen/stone/electric/machine-seal barriers).
- **XP / leveling, Heart Containers, checkpoint lanterns, death/respawn.**

## What makes it unique (Inkbound twist)
- **Ink meter:** abilities cost Ink; landing melee hits refunds it — a risk/reward combat loop.
- **Guardian Echoes:** every Guardian you defeat grants a permanent passive (Kidlat = 3rd-hit arcs, Piyedro = stone skin, Peyro = ember cloak, Dan = still waters, Maam Jyr = gale step, Nukos = the tide remembers).
- **Mish** is an active companion who barks navigation hints and the game's story beats.
- **Hand-drawn "Inkbound" look:** matte colors + black ink outlines + neon elemental accents + comic-style Bangers UI.
- **Smooth camera, screen shake, particle bursts, boss health bars, dialogue toasts.**

## Controls
| Action | Keyboard / Gamepad | Mobile (touch) |
|---|---|---|
| Move | A / D | D-pad ◀ ▶ |
| Jump | Space | ⬆ Jump button |
| Attack / Swing | Left-click | ⚔ Attack button |
| Ability 1–6 | 1 2 3 4 5 6 | Ability buttons (bottom center) |
| Interact | E | E button |

The HUD auto-detects your device and shows **Desktop / Mobile / Console** with the active input method.

## Sound
A full SFX + music system is wired (`SoundIDs.luau`). It uses free community audio IDs by default and gracefully skips any that fail to load (nothing breaks). To use your own sounds:
1. Upload your audio to Roblox.
2. Drop a `Sound` object into `ReplicatedStorage.EnchantedRealmAudio` named exactly like a key (e.g. `SwordSlash`, `BossRoar`, `Explore` for music).
3. The game will use your asset automatically — no code changes.

## How to open in Roblox Studio
1. Install **Rojo 7** (done on this machine — `rojo` is on PATH).
2. Open **Roblox Studio**.
3. In Studio, open the folder `C:\AI\mine\games\roblox-enchanted-realm`.
4. Run: `rojo serve` inside that folder, then in Studio use the Rojo plugin to sync (`File → Rojo → Sync to Studio`).
   - Or use the Rojo plugin's "Serve" button and press the sync arrow.
5. Press **Play** to test.

### Project layout
```
src/
  ReplicatedStorage/Modules/   Config.luau   Regions.luau   SoundIDs.luau
  ServerScriptService/         Main.server.luau  Session.luau  SaveData.luau
                               WorldBuilder.luau  Enemies.luau  Bosses.luau
  StarterPlayer/StarterPlayerScripts/   GameClient.client.luau   Effects.luau
default.project.json           (Rojo project file)
```

## Notes
- Single-player focused (studio/local server). DataStores fall back to an in-memory copy when API access isn't available, so progress persists within a session.
- All parts are procedural — no external models required. Drop the project into Studio and play.

Have fun reclaiming the Grand Key! 🗝️⚔️
