# chem-dorm design lock (v0)

Mac-first 2D room tower defense. Godot 4.7.2 Standard + GDScript.
All-ages. Geometric / pixel blocks. Hits remove or chip HP. No gore.

## Match

- 1 human defender + 5 ally bots + 1 AI invader.
- Player always defends. Invader is AI. Player cannot control the invader.
- Allies use the same build table, upgrades, assets, and prices as the player.
- Allies only act in their own room. They do not operate the player's tiles.
- Player win/lose is their own room. Ally rooms falling only removes that room's fire and feeds invader XP.
- Victory: invader HP reaches 0 by turrets. Turtling the max door is not a win.
- Defeat for a room: starter building destroyed after the hatch is broken.
- Defeat for the match: all starter buildings gone.

## Opening

- Building is a corridor graph. Rooms are nodes. Edges have length.
- Rooms are simple grids (not illustrated furniture maps). Typical sizes 8x8, 10x8, 6x10.
- Bed / starter occupies 2 tiles. Hatch occupies 1 tile on the wall. Remaining tiles are buildable.
- Countdown: walk, enter an unlocked room, occupy the starter to claim. First claim locks the room; others leave.
- After countdown the invader enters the corridor from a spawn and must walk to a hatch.

## Economy

Two numbers only: money and chem feedstock.

Money mines have no upgrade bar. Buy once, fixed payout. One room may hold several mines. Uranium: one per room.

| Tier | Building |
| --- | --- |
| 0 | Starter (name TBD). Comes with the room. Upgrades with money. Produces money. |
| 1 | Iron mine |
| 2 | Tungsten mine |
| 3 | Molybdenum mine |
| 4 | Sulfur mine (money only, not sulfur) |
| 5 | Antimony mine |
| 6 | Gold mine |
| 7 | Uranium mine |

Chem plant: bought with money, produces feedstock, no upgrade bar. One plant, one product: feedstock.
No reagent split, condenser, electrolyzer, or storage cabinet in v0 (parked).

## Acid turrets

Same cell transforms in place. I-IV raise power. V is capstone title + ticket to the next substance I.
Branch lock after Carbonate V. To run both branches, build a second turret from Silicic I.

```
Silicic I-V → Carbonate I-V → pick one line
Hypochlorous I-V → Hydrosulfuric I-V → Hydrofluoric I-V
Hydrochloric I-V → Sulfuric I-V → Perchloric I-V → Fluoroantimonic I-V
```

Capstone display names: 胶幕 / 沸泉 / 漂白 / 硫沼 / 蚀晶 / 盐雾 / 发烟 / 爆氧 / 魔酸.

Every turret has range. Specials only after the branch pick:

| Turret | Special |
| --- | --- |
| Hypochlorous | Slows hatch-breaking |
| Hydrosulfuric | Ground puddle DoT |
| Hydrofluoric | Extra vs hatch armor |
| Hydrochloric | None (range + rate) |
| Sulfuric | Strip resist |
| Perchloric | Burst then hitch |
| Fluoroantimonic | Pierce through hatch to the invader |

Silicic / Carbonate: short range, slow / interrupt only. High tiers reach farther. Turrets do not cover the whole corridor.
Without a chem plant, stop at Carbonate V. Cannot branch.

## High-tech (candidates, not all in P0)

One tile, money only, no upgrade bar, room-local:

- Catalytic column: adjacent fire rate
- Focus lens: adjacent range +1
- Arm: adjacent mine / plant speed
- Regulator stack: mild room-wide speed, one per room

## Hatch

One hatch per room. Invader must break it before touching buildings.
Six kinds, each I-V (30 ranks). Previous V → next I.

Honeycomb → Iris → LN2 curtain → Zeolite flap → Lattice lock → Ion gate (cap).

Regen starts mid-chain (LN2 or zeolite), always slower than a level-15 break. Level 15 invader can break Ion gate V. After the cap, only turrets finish the fight.
Hatch upgrades cost money.

## Invader

One unit. XP from attacking any hatch (player or ally). XP pauses while walking or healing.
Walks the corridor. May abandon a hatch to switch or to heal.
Heal pads: 1-2 remote tiles, long walk from every hatch, out of default turret range.
Level 3-4 is the spike (hatches thin, economy incomplete). After that, surviving rooms continue hatch ranks.
Roster (one character per match). Skills off until the listed level.

| Character | Lv | Skill |
| --- | --- | --- |
| 蚀岩 | 5 | Faster break vs regen |
| 蚀岩 | 10 | Bonus damage to current hatch |
| 雾徙 | 5 | Fog slows nearby turrets |
| 雾徙 | 12 | Instant retarget to another hatch |
| 遏火 | 6 | Silence one turret briefly |
| 遏火 | 12 | Shorten all room turret range |
| 暴氧 | 8 | Burst break then self-hitch |
| 暴氧 | 15 | Extra hit vs Ion gate V |

Other characters at 15 still break Ion gate V with baseline break speed. No loot from the invader.

## Out of v0 implementation until a later slice

Art pass, audio, signing Mac export, reagent split, condenser, electrolyzer, cabinet, playing as invader.
