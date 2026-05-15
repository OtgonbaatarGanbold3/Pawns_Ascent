# Pawn Ascent Sprite Requirements

## Purpose

This document lists the gameplay sprites and visual assets needed to replace the current UI-placeholder visuals with authored art. It is written for the next implementation pass, where provided sprites will be wired into the board, Combat Lab, items, skills, statuses, terrain, and combat feedback.

The game currently runs on a 1680x1050 canvas with canvas-item stretch. The board can scale, especially in Combat Lab, so sprites should be crisp at multiple tile sizes. Current board tiles commonly range from about 48 px to 112 px.

## General Asset Rules

- Format: PNG preferred for raster sprites.
- Background: transparent unless explicitly listed as a full-screen or tile background.
- Color space: sRGB.
- Style: bleak mythic board-combat, readable at small size, not cute, not parody-like.
- Export scale: provide source art larger than display size when possible.
- Naming: lowercase snake_case.
- Suggested path root: `res://assets/sprites/`.
- Pivot expectation: centered for board pieces, VFX bursts, icons, and overlays.
- Safe detail: important silhouettes must remain readable at 32 px.
- Avoid text inside sprites unless the sprite is a symbol or rune.

## Resolution Tiers

Use these tiers unless a specific section overrides them.

| Use case | Display size | Provide PNG size | Notes |
|---|---:|---:|---|
| Board unit sprite | 64-96 px | 256x256 | Main pieces on board. |
| Status icon | 14-28 px | 64x64 | Small UI icon above units. |
| Item icon | 48-72 px | 256x256 | Drafts, inventory, lab buttons. |
| Skill icon | 48-72 px | 256x256 | Future skill menu and Combat Lab. |
| Tile overlay glyph | 32-72 px | 128x128 | Sits inside tile over terrain. |
| Tile base texture | 64-112 px | 256x256 | Repeating/scalable tile art. |
| VFX frame or burst | 64-160 px | 256x256 or 512x512 | One-shot visual feedback. |
| Aura/radius tile marker | 64-112 px | 256x256 | Repeated across affected tiles. |
| Full-board overlay | 1680x1050 | 3360x2100 | Evolution, death wash, major events. |
| UI panel/background | Variable | 512x512 or 1024x1024 nine-slice | Optional later. |

## Directory Layout

Recommended folders:

```text
res://assets/sprites/
  units/
  units/echoes/
  terrain/
  terrain/overlays/
  statuses/
  items/
  items/shadow/
  items/holy/
  items/siege/
  items/void/
  skills/
  vfx/
  vfx/hit/
  vfx/status/
  vfx/terrain/
  vfx/aura/
  vfx/rarity/
  ui/
```

## Unit Sprites

These replace the current chess glyphs in `BoardView`.

Provide every unit in friendly and enemy versions. Friendly should read cyan/green-blue, enemy should read red/coral, boss should support gold accents, and legacy echo variants should support purple/ghost afterimage treatment.

| Asset | File | Size | Required variants | Notes |
|---|---|---:|---|---|
| Pawn unit | `units/pawn.png` | 256x256 | friendly, enemy, boss optional | Small, expendable, forward-leaning silhouette. |
| Knight unit | `units/knight.png` | 256x256 | friendly, enemy, boss optional | Angular leap-read silhouette. |
| Bishop unit | `units/bishop.png` | 256x256 | friendly, enemy, boss optional | Tall ritual/caster silhouette. |
| Rook unit | `units/rook.png` | 256x256 | friendly, enemy, boss optional | Heavy square fortress silhouette. |
| Queen unit | `units/queen.png` | 256x256 | friendly, enemy, boss optional | Wide threatening command silhouette. |
| King unit | `units/king.png` | 256x256 | friendly, enemy, boss required | Crowned but exhausted, not heroic. |
| Dummy target | `units/dummy_target.png` | 256x256 | neutral | Combat Lab target, silent and inert. |
| Ally contract marker | `units/ally_contract_marker.png` | 128x128 | ally | Small overlay badge for temporary allies. |

Recommended variant naming:

```text
units/pawn_friendly.png
units/pawn_enemy.png
units/pawn_boss.png
units/king_boss.png
units/echoes/pawn_legacy_echo.png
```

## Unit State Sprites

These replace the current ready/low HP/boss/legacy UI labels.

| State | File | Size | Shape language | Notes |
|---|---|---:|---|---|
| Ready to act | `statuses/state_ready.png` | 64x64 | circle | Bright outline pulse icon. |
| Low HP | `statuses/state_low_hp.png` | 64x64 | triangle/crack | Heartbeat/cracked marker. |
| Threatening attack | `statuses/state_threatening.png` | 64x64 | triangle/arrow | Used with red targeting line. |
| Boss unit | `statuses/state_boss.png` | 64x64 | crown/aura | Gold crown icon, readable at 16 px. |
| Legacy boss | `statuses/state_legacy_echo.png` | 64x64 | echo/broken ring | Purple memory trail marker. |

## Status Effect Icons

These replace the persistent status icons above units and status burst center symbols.

| Status | File | Size | Shape | Color direction | Notes |
|---|---|---:|---|---|---|
| Bleed | `statuses/bleed.png` | 64x64 | triangle/slash | deep red | Dripping slash, offensive. |
| Burn | `statuses/burn.png` | 64x64 | triangle/flame | orange | Ember or flame corner. |
| Shielded | `statuses/shielded.png` | 64x64 | square/hex | pale steel | Rotating barrier or hex shield. |
| Empowered | `statuses/empowered.png` | 64x64 | circle/up aura | pale gold | Upward aura, weapon glow. |
| Frozen | `statuses/frozen.png` | 64x64 | diamond/snow | ice blue | Frost corners, control. |
| Shocked | `statuses/shocked.png` | 64x64 | diamond/arc | electric blue | Lightning arc. |
| Cursed | `statuses/cursed.png` | 64x64 | broken shape/rune | violet black | Distorted rune, smoke edge. |
| Weakened | `statuses/weakened.png` | 64x64 | diamond/down arrow | desaturated gray | Downward force, dimming. |

## Terrain Tile Sprites

These replace flat tile color blocks. Tiles should support square board rendering and still read when tinted/highlighted.

| Terrain | Base tile file | Size | Overlay file | Overlay size | Notes |
|---|---|---:|---|---:|---|
| Normal | `terrain/tile_normal.png` | 256x256 | none | - | Clean board tile, low noise. |
| Elevated | `terrain/tile_elevated.png` | 256x256 | `terrain/overlays/elevated_edge.png` | 128x128 | Raised border, edge glow. |
| Blessed | `terrain/tile_blessed.png` | 256x256 | `terrain/overlays/blessed_rune.png` | 128x128 | Symmetrical rune, gentle. |
| Fire | `terrain/tile_fire.png` | 256x256 | `terrain/overlays/fire_cracks.png` | 128x128 | Burning cracks, ember-ready. |
| Cursed | `terrain/tile_cursed.png` | 256x256 | `terrain/overlays/cursed_cracks.png` | 128x128 | Uneven dark cracks. |
| Void | `terrain/tile_void.png` | 256x256 | `terrain/overlays/void_fracture.png` | 128x128 | Missing geometry, broken edge. |
| Fog | `terrain/tile_fog.png` | 256x256 | `terrain/overlays/fog_cloud.png` | 128x128 | Desaturated cloudy overlay. |
| Rock blocker | `terrain/tile_rock.png` | 256x256 | `terrain/overlays/blocker_rock.png` | 128x128 | Clear movement blocker. |
| House blocker | `terrain/tile_house.png` | 256x256 | `terrain/overlays/blocker_house.png` | 128x128 | Structure blocker, board-appropriate. |

Optional animated terrain frames:

| Terrain | Frames | Size | Notes |
|---|---:|---:|---|
| Fire embers | 4-8 | 128x128 | Loopable ember overlay. |
| Fog drift | 4-8 | 128x128 | Slow cloud movement. |
| Void glitch | 4-8 | 128x128 | Broken geometry flicker. |
| Blessed pulse | 4 | 128x128 | Gentle rune glow. |

## Item School Sprites

These are reusable category marks for item cards, inventory slots, pickups, and trigger feedback.

| School | File | Size | Shape | Notes |
|---|---|---:|---|---|
| Shadow school mark | `items/shadow/school_shadow.png` | 128x128 | jagged triangle | Violence, speed, corruption. |
| Holy school mark | `items/holy/school_holy.png` | 128x128 | halo circle | Preservation, ritual, endurance. |
| Siege school mark | `items/siege/school_siege.png` | 128x128 | thick square | Weight, structure, force. |
| Void school mark | `items/void/school_void.png` | 128x128 | broken polygon | Entropy, unreality. |

## Current Item Icons

Provide one 256x256 icon for every current item in `data/items.json`.

| Item | File | School | Size | Visual brief |
|---|---|---|---:|---|
| Shard of Rank | `items/shadow/shard_of_rank.png` | Shadow | 256x256 | Jagged red-black rank fragment. |
| Bleeder's Mark | `items/shadow/bleeders_mark.png` | Shadow | 256x256 | Dripping slash seal. |
| Ashen Veil | `items/shadow/ashen_veil.png` | Shadow | 256x256 | Torn veil, speed flicker, dark red edge. |
| Ward Rune | `items/holy/ward_rune.png` | Holy | 256x256 | Pale gold carved ward. |
| Mending Word | `items/holy/mending_word.png` | Holy | 256x256 | Broken glyph knitting itself. |
| Rank Echo | `items/holy/rank_echo.png` | Holy | 256x256 | Faint circular rank imprint. |
| Hollow Crown | `items/holy/hollow_crown.png` | Holy | 256x256 | Empty crown, pale ritual glow. |
| Iron Chain | `items/siege/iron_chain.png` | Siege | 256x256 | Heavy chain link, impact direction. |
| Barricade | `items/siege/barricade.png` | Siege | 256x256 | Stone square shield. |
| Grave Weight | `items/siege/grave_weight.png` | Siege | 256x256 | Heavy black weight, downward pull. |

## Future Item Icon Slots

These do not all exist in data yet, but the visual system already anticipates them. Useful for the next item expansion.

| Concept | File | School | Size | Visual brief |
|---|---|---|---:|---|
| Execute relic | `items/shadow/execute_relic.png` | Shadow | 256x256 | Red crack burst, finishing blow. |
| Ambush relic | `items/shadow/ambush_relic.png` | Shadow | 256x256 | Disappearing jagged silhouette. |
| Bless relic | `items/holy/blessing_relic.png` | Holy | 256x256 | Vertical beam through a small circle. |
| Retaliation relic | `items/siege/retaliation_relic.png` | Siege | 256x256 | Delayed shockwave square. |
| Mutation relic | `items/void/mutation_relic.png` | Void | 256x256 | Purple broken hex ripple. |
| Teleport relic | `items/void/teleport_relic.png` | Void | 256x256 | Frame-skip fractured doorway. |
| Corruption relic | `items/void/corruption_relic.png` | Void | 256x256 | Spreading black-violet fracture. |

## Skill Icons

These support Combat Lab buttons now and future active skills later.

| Skill type | File | Size | Shape | Notes |
|---|---|---:|---|---|
| Mobility | `skills/skill_mobility.png` | 256x256 | diamond | Dash trail, speed lines. |
| Leap | `skills/leap.png` | 256x256 | diamond | Arc or L-step motion hint. |
| Blink | `skills/blink.png` | 256x256 | diamond/broken | Frame skip, short teleport. |
| Charge | `skills/charge.png` | 256x256 | diamond/triangle | Fast line into impact. |
| Impact | `skills/skill_impact.png` | 256x256 | triangle | Shockwave hit. |
| Smash | `skills/smash.png` | 256x256 | triangle | Downward force. |
| Slam | `skills/slam.png` | 256x256 | triangle/square | Ground crack. |
| Knockback | `skills/knockback.png` | 256x256 | triangle | Straight impact wave. |
| Summon | `skills/skill_summon.png` | 256x256 | circle/rune | Expanding rune. |
| Soul summon | `skills/soul_summon.png` | 256x256 | circle | Shadow emergence. |
| Clone | `skills/clone.png` | 256x256 | circle/echo | Duplicate outline. |
| Temporary ally | `skills/temporary_ally.png` | 256x256 | circle/banner | Contract ally call. |
| Aura | `skills/skill_aura.png` | 256x256 | circle/ring | Radius ring. |
| Fear aura | `skills/fear_aura.png` | 256x256 | red ring | Dread radius. |
| Heal aura | `skills/heal_aura.png` | 256x256 | pale ring | Preservation radius. |
| Corruption aura | `skills/corruption_aura.png` | 256x256 | broken ring | Void radius. |

## Combat VFX Sprites

These replace or augment the current UI flashes and shape bursts.

| Event | File | Size | Frames | Notes |
|---|---|---:|---:|---|
| Damage flash | `vfx/hit/damage_flash.png` | 256x256 | 1 | Red tile flash. |
| Hit slash | `vfx/hit/hit_slash.png` | 256x256 | 1-4 | Quick offensive slash. |
| Critical hit | `vfx/hit/critical_hit.png` | 512x512 | 1-6 | White flash plus sharp burst. |
| Kill dissolve | `vfx/hit/kill_dissolve.png` | 512x512 | 4-8 | Piece breaking into dust. |
| Knockback wave | `vfx/hit/knockback_wave.png` | 512x128 | 1-4 | Straight impact wave. |
| Damage number backing | `vfx/hit/damage_number_burst.png` | 128x128 | 1 | Optional backing behind numbers. |
| Small hit pause flash | `vfx/hit/hit_pause_flash.png` | 256x256 | 1 | Brief white/red pop. |

## Status VFX Sprites

These play when a status is applied or ticks.

| Status VFX | File | Size | Frames | Notes |
|---|---|---:|---:|---|
| Bleed apply | `vfx/status/bleed_apply.png` | 256x256 | 1-4 | Dripping slash. |
| Bleed tick | `vfx/status/bleed_tick.png` | 128x128 | 1-4 | Small pulse. |
| Burn apply | `vfx/status/burn_apply.png` | 256x256 | 4-8 | Orange flicker. |
| Burn tick | `vfx/status/burn_tick.png` | 128x128 | 4 | Ember pulse. |
| Shield apply | `vfx/status/shield_apply.png` | 256x256 | 4-8 | Rotating ring. |
| Empower apply | `vfx/status/empower_apply.png` | 256x256 | 4-8 | Upward aura. |
| Frozen apply | `vfx/status/frozen_apply.png` | 256x256 | 4-8 | Frost corners. |
| Shocked apply | `vfx/status/shocked_apply.png` | 256x256 | 4-8 | Electric arcs. |
| Cursed apply | `vfx/status/cursed_apply.png` | 256x256 | 4-8 | Smoke/rune distortion. |
| Weakened apply | `vfx/status/weakened_apply.png` | 256x256 | 1-4 | Dim/downward arrows. |

## Terrain And Board Event VFX

| Event | File | Size | Frames | Notes |
|---|---|---:|---:|---|
| Terrain mutation pulse | `vfx/terrain/mutation_pulse.png` | 512x512 | 4-8 | Hex ripple, board shift. |
| Board mutation wash | `vfx/terrain/board_mutation_wash.png` | 3360x2100 | 1-4 | Full board dark ripple. |
| Fire tile ember | `vfx/terrain/fire_ember_loop.png` | 128x128 | 4-8 | Loop on fire tiles. |
| Cursed smoke | `vfx/terrain/cursed_smoke_loop.png` | 128x128 | 4-8 | Slow dark drift. |
| Blessed pulse | `vfx/terrain/blessed_pulse_loop.png` | 128x128 | 4 | Gentle symmetrical pulse. |
| Fog drift | `vfx/terrain/fog_drift_loop.png` | 128x128 | 4-8 | Desaturated movement. |
| Void distortion | `vfx/terrain/void_distortion_loop.png` | 128x128 | 4-8 | Broken geometry flicker. |

## Aura And Threat Sprites

| Indicator | File | Size | Frames | Notes |
|---|---|---:|---:|---|
| Generic aura tile | `vfx/aura/aura_tile.png` | 256x256 | 1 | Used per affected tile. |
| Fear aura tile | `vfx/aura/fear_aura_tile.png` | 256x256 | 1-4 | Red dread ring. |
| Heal aura tile | `vfx/aura/heal_aura_tile.png` | 256x256 | 1-4 | Pale green/gold ring. |
| Corruption aura tile | `vfx/aura/corruption_aura_tile.png` | 256x256 | 1-4 | Broken purple ring. |
| Threat line segment | `vfx/aura/threat_line.png` | 512x64 | 1 | Red targeting line, scalable. |
| Threat endpoint | `vfx/aura/threat_endpoint.png` | 128x128 | 1 | Red target marker. |

## Rarity Sprites

These support item cards, item pickup feedback, and future draft UI polish.

| Rarity | Border file | Size | VFX file | VFX size | Notes |
|---|---|---:|---|---:|---|
| Common | `vfx/rarity/common_border.png` | 256x256 | `vfx/rarity/common_pickup.png` | 256x256 | Thin border, minimal particles. |
| Rare | `vfx/rarity/rare_border.png` | 256x256 | `vfx/rarity/rare_pickup.png` | 256x256 | Dual-layer glow. |
| Epic | `vfx/rarity/epic_border.png` | 256x256 | `vfx/rarity/epic_pickup.png` | 512x512 | Overflow particles. |
| Legendary | `vfx/rarity/legendary_crown_border.png` | 256x256 | `vfx/rarity/legendary_pickup.png` | 512x512 | Crown motif, tile-spanning. |

## Evolution Sprites

Evolution should feel uncanny, not triumphant.

| Event | File | Size | Frames | Notes |
|---|---|---:|---:|---|
| Evolution board darken | `vfx/evolution/evolution_board_wash.png` | 3360x2100 | 1 | Full board darkening. |
| Shape reconstruction | `vfx/evolution/shape_reconstruction.png` | 512x512 | 6-12 | Body rewritten by rank. |
| Rank ring | `vfx/evolution/rank_ring.png` | 512x512 | 4-8 | Circle/diamond reconstruction. |
| Legacy echo trail | `vfx/evolution/legacy_echo_trail.png` | 512x512 | 4-8 | Memory afterimage. |

## UI Sprites

These are optional but useful once gameplay sprites are ready.

| UI asset | File | Size | Notes |
|---|---|---:|---|
| Combat Lab backdrop | `ui/combat_lab_backdrop.png` | 3360x2100 | Subtle board-workbench background. |
| Side panel nine-slice | `ui/panel_side_9slice.png` | 512x512 | Quiet utilitarian panel. |
| Item card frame | `ui/item_card_frame.png` | 512x512 | Can tint by school/rarity. |
| Skill button frame | `ui/skill_button_frame.png` | 512x256 | Horizontal button backing. |
| Health pip | `ui/health_pip.png` | 64x64 | Future HP display. |
| AP pip | `ui/ap_pip.png` | 64x64 | Future AP display. |
| Gold icon | `ui/gold_icon.png` | 64x64 | Economy UI. |
| Score icon | `ui/score_icon.png` | 64x64 | End screen/path UI. |

## Minimum Sprite Pack For Next Session

If only a first batch can be prepared, prioritize this set:

1. `units/pawn_friendly.png`, `units/pawn_enemy.png`, `units/dummy_target.png`
2. `statuses/bleed.png`, `statuses/burn.png`, `statuses/shielded.png`, `statuses/empowered.png`
3. `terrain/tile_normal.png`, `terrain/tile_fire.png`, `terrain/tile_blessed.png`, `terrain/tile_cursed.png`
4. `items/shadow/bleeders_mark.png`, `items/holy/ward_rune.png`, `items/siege/iron_chain.png`
5. `skills/skill_mobility.png`, `skills/skill_impact.png`, `skills/skill_aura.png`
6. `vfx/hit/damage_flash.png`, `vfx/hit/hit_slash.png`, `vfx/terrain/mutation_pulse.png`

With only those assets, the Combat Lab can already look substantially more authored while the rest of the system continues using placeholders.

