# PAWN'S ASCENT — Visual Indicator System

## Purpose

This document defines a scalable visual language system for:
- Status effects
- Item categories
- Skills
- Terrain interactions
- Buffs/debuffs
- Trigger events
- Threat levels
- Unit states

The system is designed for:
- Placeholder graphics
- Godot UI-driven visuals
- Shape-based readability
- Minimalistic tactical clarity
- Future stylized expansion

---

# CORE VISUAL LANGUAGE

## Universal Shape Rules

| Shape | Meaning |
|---|---|
| Circle | Buff / positive |
| Triangle | Offensive / aggressive |
| Square | Defensive / structure |
| Diamond | Utility / manipulation |
| Hexagon | Terrain / mutation |
| Broken shape | Void / corruption |

---

## Motion Rules

| Motion | Meaning |
|---|---|
| Slow pulse | Passive |
| Fast pulse | Trigger ready |
| Shake | Damage |
| Expanding ring | Aura |
| Flicker | Temporary |
| Glitch | Void / entropy |

---

# ITEM CATEGORY VISUALS

## Shadow Items
Theme:
- Violence
- Corruption
- Speed

Visuals:
- Dark crimson
- Jagged triangles
- Flickering slash trails

Examples:
- Bleed → dripping slash icon
- Execute → red crack burst
- Ambush → flicker/disappear

---

## Holy Items
Theme:
- Preservation
- Ritual
- Endurance

Visuals:
- Pale gold
- Halo circles
- Stable glow

Examples:
- Heal → rising particles
- Shield → rotating ring
- Bless → vertical light beam

---

## Siege Items
Theme:
- Weight
- Structure
- Force

Visuals:
- Thick squares
- Heavy borders
- Ground cracks

Examples:
- Knockback → straight impact wave
- Fortify → stone outline
- Retaliation → delayed shockwave

---

## Void Items
Theme:
- Entropy
- Instability
- Unreality

Visuals:
- Broken geometry
- Glitching effects
- Fragmented polygons

Examples:
- Mutation → distortion ripple
- Teleport → frame skip flicker
- Corruption → spreading fracture

---

# STATUS EFFECT VISUALS

## Bleed
- Red slash icon
- Dripping particles
- Tick pulse

## Burn
- Ember particles
- Orange flicker
- Heat distortion

## Shielded
- Rotating barrier ring
- Hex overlay

## Empowered
- Upward aura
- Weapon glow

## Frozen
- Frost corners
- Snow particles

## Shocked
- Electric arcs
- Blue flashes

## Cursed
- Black smoke
- Distorted rune

## Weakened
- Dimmed saturation
- Downward arrows

---

# TERRAIN VISUALS

## Normal
- Clean board tile

## Elevated
- Raised border
- Edge glow

## Blessed
- Symmetrical rune
- Gentle pulse

## Fire
- Burning cracks
- Ember particles

## Cursed
- Uneven dark cracks
- Smoke drift

## Void
- Missing geometry
- Distortion effect

## Fog
- Desaturated overlay
- Slow cloud movement

---

# SKILL TYPE VISUALS

## Mobility Skills
Visuals:
- Dash trails
- Speed lines
- Afterimages

Examples:
- Leap
- Blink
- Charge

---

## Impact Skills
Visuals:
- Hit pause
- Shockwaves
- Tile shake

Examples:
- Smash
- Slam
- Knockback

---

## Summon Skills
Visuals:
- Expanding rune
- Shadow emergence

Examples:
- Soul summon
- Clone
- Temporary ally

---

## Aura Skills
Visuals:
- Radius ring
- Environmental pulse

Examples:
- Fear aura
- Heal aura
- Corruption aura

---

# RARITY VISUALS

## Common
- Thin border
- Minimal particles

## Rare
- Dual-layer border
- Glow pulse

## Epic
- Overflow particles
- Animated icon

## Legendary
- Tile-spanning VFX
- Crown border motif

---

# UNIT STATE INDICATORS

## Ready To Act
- Bright outline pulse

## Low HP
- Heartbeat pulse
- Cracked HP bar

## Threatening Attack
- Red targeting line

## Boss Unit
- Large aura
- Crown icon

## Legacy Boss
- Echo afterimages
- Memory trails

---

# EVENT FEEDBACK

## On Hit
- Damage flash
- Floating number
- Small hit pause

## Critical Hit
- Strong shake
- White flash

## Kill
- Dissolve effect
- Particle burst

## Evolution
- Board darkens
- Unit expands
- Shape reconstruction

## Terrain Mutation
- Ripple through board
- Geometry shift

Text:
“The Plain shifts.”

---

# GODOT IMPLEMENTATION

## Suggested Node Structure

EffectRoot
├── Sprite2D / Polygon2D
├── GPUParticles2D
├── AnimationPlayer
├── AudioStreamPlayer2D
└── ShaderMaterial

---

# RECOMMENDED SYSTEMS

| System | Purpose |
|---|---|
| EffectManager | Spawn/despawn VFX |
| FloatingTextManager | Damage numbers |
| TileOverlayManager | Terrain visuals |
| AuraRenderer | Radius visuals |
| StatusIconLayer | Buff/debuff icons |

---

# PRIORITY IMPLEMENTATION

## Phase 1
Implement first:
1. Damage flash
2. Movement highlight
3. Terrain colors
4. Status icons
5. Evolution effect
6. Mutation pulse

## Phase 2
1. Theme particles
2. Aura effects
3. Skill trails
4. Ally visuals
5. Boss visuals

## Phase 3
1. Distortion shaders
2. Ambient effects
3. Legacy memory effects
4. Dynamic environment reactions

---

# FINAL PRINCIPLE

The visual system should communicate:
- what happened
- why it happened
- who caused it
- how dangerous it is

WITHOUT requiring text.

The board itself should eventually explain the gameplay.
