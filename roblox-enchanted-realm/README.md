# Enchanted Realm: Inkbound — Roblox Metroidvania

A complete, playable 3D third-person Metroidvania built for **Roblox Studio**, ported from the "Enchanted Realm" Game Design Document and given a unique **hand-drawn "Inkbound"** identity.

## What it is (from the GDD, kept intact)
- **Genre:** Metroidvania (Hollow Knight / Ori / Blasphemous inspired)
- **Story:** A warrior is pulled into the fantasy world of Encantadia, befriends Mish, defeats six Guardians, claims the Grand Key from Nukos the Squid Monster, and finds a way home.
- **6 contiguous zones:** Enchanted Forest → Mechanical Ruins → Burning Forest → Frozen Ruins → Secret Cave → Sky Ruins → Forgotten Underground (final).
- **6 Guardians with GDD-accurate attacks:** Kidlat (shield/beam), Piyedro (dash/slam/pillars), Peyro (fire wall/eruption/burn), Dan (ice projectiles/stomps), Maam Jyr (lightning/thunder/wind), Nukos (tentacle slam/ink/grab, underwater phase).
- **Ability gating:** Lightning → Fire → Ice → Wind → Power Rock → Lightning Core unlock new paths (vine/wood/frozen/stone/electric/machine-seal barriers).
- **XP / leveling, Heart Containers, checkpoint lanterns, death/respawn.**

## What makes it unique (Inkbound twist)
- **The world is a sketch:** every object has a matte body with a hand-drawn black ink outline.
- **Ink meter:** abilities cost Ink; landing melee hits refunds it — a risk/reward combat loop.
- **Living time:** the realm syncs to the player's local clock — dawn, midday, dusk and deep night roll through with the real-world hour, and the HUD shows local time top-right.
- **OVER-INKED:** cast while your meter is full and the spell is **free and twice as strong** — the screen bursts open and your meter burns to zero. The whole combat economy revolves around earning it.
- **Skills & Shop panel:** press **SKILLS** any time to review known/locked abilities and buy gear with XP — Shockwave tome, Heart Containers, Ink Satchels (+25 max ink), Ink Potions.
- **Merchant Syla & loot chests:** a trader by the spawn, and 12 one-shot chests along the route hiding ink and XP.
- **Guardian Echoes:** every Guardian you defeat grants a permanent passive (Kidlat = 3rd-hit arcs, Piyedro = stone skin, Peyro = ember cloak, Dan = still waters, Maam Jyr = gale step, Nukos = the tide remembers).
- **Mish** is an active companion who barks navigation hints and the game's story beats.
- **Hand-drawn "Inkbound" look:** matte colors + black ink outlines + neon elemental accents + comic-style Bangers UI.
- **Smooth camera, screen shake, particle bursts, boss health bars, dialogue toasts.**

## Controls
| Action | Keyboard / Gamepad | Mobile (touch) |
|---|---|---|
| Move | **W A S D** / arrow keys | Roblox virtual stick |
| Jump | Space | Jump button |
| Attack / Swing | Left-click | Attack button |
| Ability 1–7 | 1 2 3 4 5 6 7 | Ability buttons (bottom center) |
| Interact | E | E button |
| Skills / Shop | SKILLS button (top-right) | SKILLS button (top-right) |
| Tactical Map | M | MAP button (top-right) |

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
