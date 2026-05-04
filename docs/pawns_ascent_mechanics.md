# PAWN'S ASCENT — Mechanics Reference

**PAWN’S ASCENT**
Mechanics Reference Document
> v1.0 — For AI-assisted development reference
**How to use this document**
> Each section defines one game system with enough precision for an AI coding assistant
> to implement it independently. Every section ends with an Implementation note.
> Read alongside: pawns_ascent_concept.docx (story and world reference).
# 1. Core Roguelike Loop
Each playthrough is called a Run. A run is a single unbroken sequence of Encounters on the shifting Plain. Runs end by player death (permanent within the run) or by defeating the King at the final encounter. There is no mid-run save.
## 1.1 Run Structure
A run is divided into Encounters. Each encounter is a randomly generated board populated with enemy pieces. The player clears an encounter by eliminating all enemies. After clearing, an Item Draft fires. Then the next encounter loads.
**ENCOUNTER PROGRESSION PER RUN**

| Encounter depth | Enemy types | Map complexity | Legacy boss? |
| --- | --- | --- | --- |
| 1–2 (Early) | Pawns, Knights | Sparse, minimal terrain effects | No |
| 3–4 (Mid) | Knights, Bishops, Rooks | Moderate mutation, fog patches | No |
| 5–6 (Late) | Bishops, Rooks, Queens | Heavy mutation, cursed/fire tiles | No |
| Final | King + legacy boss (if set) | Fully mutated board | Yes, if selected last run |

> → Implementation note: run_depth is an integer incremented after each cleared encounter. Enemy type pool is filtered by depth at spawn time. Final encounter triggers at run_depth == FINAL_DEPTH (default 6, configurable in encounter_tiers.json).
## 1.2 Death and Persistence
When the player reaches 0 HP the run ends. All run state is discarded except: (a) the LegacyBoss selection, (b) lore fragments unlocked, (c) run count. These three fields are written to MetaState before RunState is discarded.
> → Implementation note: RunState and MetaState are separate objects. MetaState is serialized to disk after every write. RunState lives only in memory. Never mix them.
## 1.3 Win Condition
Defeating the King ends the run. The Legacy Boss Selection screen fires. The player picks a piece. A new run begins with the player reset to Pawn form and all run state cleared. The cycle has no hard endpoint — runs continue indefinitely.
# 2. Turn System
Combat is turn-based with two alternating phases per turn: Player Phase and Enemy Phase. Within Enemy Phase, units act in Speed (SPD) order. A Tick Phase follows Enemy Phase to resolve status effects and terrain.
## 2.1 Turn Sequence
- Player Phase starts. Player AP restores to maximum. On-turn-start item triggers fire for player.
- Player takes actions (move, attack, ability, wait) until AP exhausted or turn ended manually.
- Enemy Phase starts. Enemies sorted by SPD descending; ties broken randomly.
- Each enemy executes AI turn in sorted order. On-turn-start triggers fire per enemy.
- Tick Phase: status effects applied and decremented. Terrain standing effects applied.
- Turn counter increments. Return to Player Phase.
> → Implementation note: Phase is an enum: PLAYER | ENEMY | TICK. UI input is locked during ENEMY and TICK. Enemy actions execute with a 300ms delay per unit (configurable) for readability. Tick Phase executes instantly but animations may play.
## 2.2 Action Points (AP)
Every unit has a maximum AP defined by piece type. AP restores fully at the start of that unit’s phase. AP cannot be banked between turns. All actions cost AP. If AP reaches 0, the unit’s phase ends automatically.

| Action | AP cost | Notes |
| --- | --- | --- |
| Move (base range) | 1 | One move per turn. Distance up to move range in one action. |
| Attack (adjacent) | 1 | Triggers all on_hit item effects automatically. |
| Extended move (active ability) | 2 | +2 tiles to move range for this move only. |
| Wait | 1 | Intentional AP spend. No effect. Useful for positioning. |
| Active item ability | 2 | Only items with active triggers. Passives cost 0. |

> → Implementation note: AP is an integer field on Unit. Every action function checks AP before executing and returns an error state if insufficient. AP cannot go below 0. The UI disables action buttons when AP = 0.
## 2.3 Speed and Initiative
SPD determines enemy action order within Enemy Phase. Higher SPD acts first. The player always acts before all enemies regardless of SPD. A unit with SPD ≥ 4 gains +1 to their movement range as a passive derived stat.
# 3. Board and Movement
Each encounter board is procedurally generated. It is not a standard 8×8 chess grid. The board is a rectangular tile grid with variable dimensions and terrain types assigned per tile. The board shifts between and during encounters as the run progresses.
## 3.1 Board Generation
- Grid size: 9 columns × 8 rows at depth 1–2. Expands to 12 × 10 at depth 5+.
- Tile terrain assigned at generation by weighted random draw per tile.
- Player spawns in bottom-left quadrant. Enemies spawn in top-right quadrant.
- No two units share a spawn tile.
- Hostile terrain weights (cursed, fire, fog, void) increase +5% per run depth level.
**TERRAIN TYPES AND EFFECTS**

| Type | Base weight | Entry effect | Standing effect | Combat modifier |
| --- | --- | --- | --- | --- |
| Normal | 60 total | None | None | None |
| Cursed | 8 | −1 HP | None | Counts as dark tile for Bishop movement |
| Fire | 6 | −2 HP | −1 HP per turn (Burn 1) | None |
| Blessed | 6 | None | None | −1 to incoming damage for occupant |
| Elevated | 8 | None | None | +1 ATK for unit attacking from this tile |
| Fog | 4 | None | None | Tile contents hidden until adjacent |
| Void | 0 (depth 5+) | −3 HP | −2 HP per turn | Cannot occupy for more than 1 turn |

> → Implementation note: Board is a 2D array: Tile[row][col]. Each Tile: {type: string, piece: Unit|null, revealed: boolean}. Fog tiles have revealed=false until a unit moves within Manhattan distance 1. Entry effects fire in the move action. Standing effects fire in Tick Phase.
## 3.2 Movement Rules
Movement is hybrid. The player selects any valid destination tile within range and the piece moves there in one move action (no step-by-step). Extended movement is an active ability costing 2 AP that increases range by +2 for that move only.

| Piece | Move type | Base range | Leap (ignores pieces)? | Extended range |
| --- | --- | --- | --- | --- |
| Pawn | Cardinal only (N/S/E/W) | 2 | No | 4 cardinal |
| Knight | L-shape (2+1 in any orientation) | Any valid L | Yes | +1 leap option |
| Bishop | Diagonal only | 4 | No | 6 diagonal |
| Rook | Cardinal lines only | 5 | No | 7 cardinal |
| Queen | Omnidirectional | 6 | No | 8 omni |
| King | Omnidirectional | 3 | No | 5 omni |

- Non-leap pieces cannot pass through occupied tiles. Ray stops at first occupied tile.
- A unit cannot move onto a tile occupied by an ally.
- Moving onto an enemy tile is an attack action, not a move. Costs 1 AP separately.
- Knights check destination occupancy only. Intermediate tiles are ignored.
> → Implementation note: get_valid_moves(unit, board) casts rays from unit position based on moveType. Returns Set of {x,y} coordinates. For Knights: compute all 8 L-positions, filter out-of-bounds and friendly-occupied. Renderer highlights this set. On tile click, match against set to determine if move or attack is intended.
## 3.3 Board Mutation
The Plain mutates over time. This is both a story mechanic and a difficulty escalator. Two mutation systems run in parallel:
- Between encounters: 2–4 randomly selected empty tiles are rerolled to a new terrain type, biased toward hostile types based on run_depth.
- During encounter: every 5 turns, 1 unoccupied tile mutates. Logged as: ‘The plain shifts.’
- Mutation never targets occupied tiles.
- Void tiles only appear at run_depth 5 or higher.
# 4. Combat Resolution
Combat is HP-based. Attacks deal damage calculated from attacker ATK minus defender DEF with a small random modifier. Minimum 1 damage always. Death occurs at 0 HP. There is no instant-capture mechanic.
## 4.1 Base Stats by Piece Type

| Piece | HP | ATK | DEF | SPD | AP | Evolution threshold (kills) |
| --- | --- | --- | --- | --- | --- | --- |
| Pawn | 10 | 2 | 1 | 2 | 3 | 3 kills → Knight |
| Knight | 16 | 4 | 2 | 3 | 3 | 5 kills → Bishop |
| Bishop | 14 | 3 | 1 | 3 | 3 | 7 kills → Rook |
| Rook | 22 | 5 | 4 | 1 | 2 | 9 kills → Queen |
| Queen | 28 | 7 | 3 | 4 | 4 | 12 kills → King |
| King | 40 | 6 | 5 | 2 | 3 | Final form. No further evolution. |

## 4.2 Damage Formula
raw_damage      = attacker.ATK - defender.DEF + randint(-1, 2)
terrain_bonus   = +1 if attacker is on Elevated tile, else 0
terrain_reduce  = -1 if defender is on Blessed tile, else 0
final_damage    = max(1, raw_damage + terrain_bonus + terrain_reduce)
> → Implementation note: resolve_attack(attacker, defender) computes and returns DamageResult {raw, modifier, terrain_bonus, terrain_reduce, final, killed: bool}. HP is applied after all item triggers have inspected the result. This keeps the damage pipeline inspectable and extensible.
## 4.3 Status Effects

| Status | Source | Effect per tick | Duration | Stacks? |
| --- | --- | --- | --- | --- |
| Bleed | Bleeder’s Mark item | −2 HP | 2 turns | No (refreshes) |
| Burn | Fire tile entry | −1 HP | 1 turn | No |
| Shielded | Barricade item | −2 to incoming damage | 1 turn | No |
| Empowered | Hollow Crown item | +2 ATK | Until death | No |

> → Implementation note: Status effects are Map<StatusType, {duration, value}> on each Unit. Tick Phase iterates all units, applies effects, decrements duration, removes at 0. Tick damage bypasses DEF unless noted. Shielded reduces the final_damage value in resolve_attack before HP is applied.
## 4.4 Evolution (Player Only)
Evolution triggers automatically when the player’s kill count meets the threshold for their current form. Enemies never evolve. Evolution is permanent within the run.
- Kill count tracked on player Unit. Checked after every player kill.
- On evolve: piece type, icon, moveType, movRange, base stats update to new form.
- HP restored: new_hp = min(new_max_hp, current_hp + 8).
- All items carry over. apply_items() called immediately after stat update.
- AP restores fully. Kills counter does not reset.
- Evolution is logged and should trigger a distinct visual/audio cue.
# 5. Item System
Items operate on three simultaneous layers: flat stat bonuses (Layer 1), ability triggers (Layer 2), and synergy set bonuses (Layer 3). All three layers compose on any unit holding items — player, enemy, or legacy boss. The autopilot AI reads item behavior weights from the same item data.
## 5.1 Layer 1 — Flat Stat Bonuses
Every item has a stats object with zero or more integer deltas. Applied additively on top of base stats. Recalculated by apply_items() whenever the item list changes.
unit.final_ATK = base_ATK + sum(i.stats.atk for i in items) + synergy_bonus_atk
unit.final_DEF = base_DEF + sum(i.stats.def for i in items) + synergy_bonus_def
unit.final_HP  = base_HP  + sum(i.stats.hp  for i in items) + synergy_bonus_hp
unit.final_SPD = base_SPD + sum(i.stats.spd for i in items)
unit.max_AP    = base_AP  + sum(i.stats.ap  for i in items)
> → Implementation note: Store base stats immutably. Derived (final_) stats are computed fresh by apply_items(). Never mutate base stats. Call apply_items() after any item list change or after evolution updates base stats.
## 5.2 Layer 2 — Ability Triggers
Items with a trigger field register an event listener when apply_items() runs. Passive triggers cost 0 AP and fire automatically. Active triggers cost 2 AP and are player-initiated.

| Trigger ID | Fires when | Effect | Type |
| --- | --- | --- | --- |
| on_hit_bleed | Unit successfully attacks | Apply Bleed 2 turns to target | Passive |
| on_hit_knockback | Unit successfully attacks | Push target 1 tile away (or +1 dmg) | Passive |
| on_kill_heal | Unit kills a unit | +3 HP to self | Passive |
| on_move_extra | Player spends 2 AP | +2 move range for this move | Active |
| on_turn_ap | Start of this unit’s phase | +1 bonus AP this turn | Passive |
| on_adj_defend | Enemy adjacent at turn start | Gain Shielded 1 turn | Passive |
| on_low_hp_buff | Unit HP drops below 30% | +2 ATK permanently until run ends | Passive |

> → Implementation note: Use an EventBus. apply_items() clears unit’s listeners then re-registers one listener per trigger per item. Combat system dispatches events: ATTACK_HIT, UNIT_KILLED, TURN_START, UNIT_DAMAGED. EventBus routes to listeners. This decouples item effects from combat code entirely.
## 5.3 Layer 3 — Synergy Bonuses
Items belong to one of three schools. Equipping 2+ items from the same school activates that school’s synergy bonus. Bonuses do not stack past the threshold (3 Shadow items = same bonus as 2).

| School | Threshold | Bonus | Design intent |
| --- | --- | --- | --- |
| Shadow | 2 items | +3 ATK, attacks ignore 1 DEF | Glass cannon — high damage output, fragile |
| Holy | 2 items | +4 max HP, +2 HP regen per turn end | Sustain — wins wars of attrition |
| Siege | 2 items | +5 max HP, +2 DEF when stationary | Anchor — hard to kill while holding position |

> → Implementation note: Synergy detection is inside apply_items(). Count school occurrences in items[]. For each school meeting threshold, apply its bonus to the final_ stats being computed. Display active synergies in UI with school color. Schools defined in synergies.json.
## 5.4 Item Draft
After each cleared encounter, the player is shown 3 items from the pool. They pick 1 or skip. The draft does not show items the player already holds. Maximum item count is 6. At 6 items, the draft shows a Swap screen instead.

| Item name | School | Stats | Trigger | Flavor description |
| --- | --- | --- | --- | --- |
| Shard of Rank | Shadow | +2 ATK | none | A fragment of a higher piece. Carries their violence. |
| Ashen Veil | Shadow | +2 SPD | on_move_extra | You move before they remember to watch. |
| Bleeder’s Mark | Shadow | +1 ATK | on_hit_bleed | Wounds that don’t close. |
| Ward Rune | Holy | +3 DEF | none | Carved by a bishop who forgot the words. |
| Mending Word | Holy | none | on_kill_heal | +3 HP on kill. Something returns when something ends. |
| Rank Echo | Holy | +1 AP | on_turn_ap | Acts as if it remembers being more. |
| Iron Chain | Siege | +5 HP | on_hit_knockback | The law made physical. |
| Barricade | Siege | +2 DEF | on_adj_defend | Shielded when threatened. Instinct, not choice. |
| Grave Weight | Siege | +3 DEF, −1 SPD | none | Heavier than it looks. Slower than it should be. |
| Hollow Crown | Holy | +6 HP | on_low_hp_buff | +2 ATK when HP < 30%. Desperation given form. |

# 6. Autopilot AI — Priority Queue System
Every non-player unit uses the same priority queue AI. No hardcoded scripts per enemy type. Instead, each piece type contributes base behavior weights and each equipped item adds additional weights. The AI sums all weights into a priority map and executes the highest-scoring behavior mode.
This system means the legacy boss AI is identical to any regular enemy AI — it just has a boss modifier and whatever items were transferred. No special boss scripting required.
## 6.1 Behavior Modes

| Mode | What the unit does | When it dominates |
| --- | --- | --- |
| Aggressive | Move toward player. Attack if in range. Use full AP. | Default. Boosted by offensive items. |
| Attack | Prioritize attacking over moving. Hold adjacent position if possible. | Already adjacent. High ATK items. |
| Defend | Hold tile. Move to blessed or elevated tile if available. Don’t chase. | HP < 50% or heavy DEF items. |
| Flee | Move maximally away from player each turn. Do not attack. | HP < 30%. Overrides if weight > 15. |

## 6.2 Priority Calculation
priority = { aggressive: 0, attack: 0, defend: 0, flee: 0 }
// Step 1: base weights from piece type  (read from ai_weights.json)
priority += PIECE_BASE_WEIGHTS[unit.piece_type]
// Step 2: item behavior weights
for item in unit.items:
priority[item.ai_behavior.mode] += item.ai_behavior.weight
// Step 3: HP-state modifiers
hp_pct = unit.hp / unit.max_hp
if hp_pct < 0.5:  priority['defend']     += 4
if hp_pct < 0.3:  priority['flee']       += 8
// Step 4: boss modifier
if unit.is_boss:
priority['aggressive'] += 6
priority['attack']     += 4
// Step 5: select and execute
mode = argmax(priority)
execute_behavior(unit, mode, board)
## 6.3 Base Weights by Piece Type

| Piece | Aggressive | Attack | Defend | Flee | Behavioral character |
| --- | --- | --- | --- | --- | --- |
| Pawn | 4 | 3 | 1 | 0 | Cautious. Advances but doesn’t overcommit. |
| Knight | 6 | 4 | 1 | 0 | Fast aggressor. Leaps in, attacks immediately. |
| Bishop | 3 | 3 | 4 | 1 | Positional. Prefers cursed tiles. Attacks from range. |
| Rook | 5 | 6 | 3 | 0 | Line pusher. Drives straight. Maximizes adjacency. |
| Queen | 8 | 6 | 2 | 0 | Dominant. Always approaches. Uses full AP every turn. |
| King | 5 | 5 | 6 | 0 | Fortress. Holds ground. Never retreats. Attacks adjacent. |

## 6.4 Item AI Behavior Weights

| Item | Mode | Weight | Reasoning |
| --- | --- | --- | --- |
| Shard of Rank | attack | +8 | Raw ATK item — wants to be adjacent and hitting. |
| Ashen Veil | aggressive | +6 | SPD item — wants to close distance fast. |
| Bleeder’s Mark | attack | +9 | Bleed needs repeated hits — stay close and attack. |
| Ward Rune | defend | +8 | DEF item — benefits from holding and absorbing. |
| Mending Word | attack | +5 | Kill-to-heal — incentivizes finishing blows. |
| Rank Echo | aggressive | +6 | Bonus AP — more AP = more actions = more aggression. |
| Iron Chain | aggressive | +7 | Knockback needs adjacency — wants to close. |
| Barricade | defend | +9 | Shield on adjacent — rewards holding position. |
| Grave Weight | defend | +10 | DEF heavy, SPD penalty — pure anchor. |
| Hollow Crown | attack | +6 | Low-HP burst — aggression when wounded. |

> → Implementation note: PIECE_BASE_WEIGHTS and item ai_behavior fields are stored in ai_weights.json and items.json respectively. The AI function is data-driven. Adding a new piece type or item requires only a JSON edit, not a code change.
# 7. Legacy Boss System
At the end of each run, the player selects one piece to persist as the Boss of the following run. This piece appears as a named, item-equipped boss enemy in the next run’s final encounter alongside the King.
## 7.1 Boss Selection Screen
After win or loss, before the next run initializes, the Boss Selection screen appears. The player sees a grid of eligible pieces and selects one, or chooses no legacy.
- Eligible: the player’s own piece (at whatever evolution level they reached, with all items).
- Eligible: any enemy piece alive at the end of the final encounter.
- Eligible: ‘No legacy’ option — next run has no boss, only the King.
## 7.2 LegacyBoss Data Transfer
The selected piece is serialized into a LegacyBoss record stored in MetaState.

| Field | Source | Purpose |
| --- | --- | --- |
| piece_type | Selected piece’s current type | Determines spawn form and base stats |
| items[] | Selected piece’s full item list | Items transfer exactly. No stripping. |
| display_name | Auto-generated (e.g. ‘Rook (Crowned)’) | Shown in pre-fight dialogue intro |
| run_origin | Current run number | Flavor text: ‘survivor of run 2’ |
| kills | Selected piece’s kill count | Flavor text only. Not used in stats. |

## 7.3 Boss Scaling Formula
The legacy boss’s base stats are scaled by run number so it remains threatening. Items are NOT scaled — they apply as-is. Scaling caps at run 6 to prevent runaway difficulty.
scale       = min(run_number, 6)
boss.max_HP = floor(base_HP[piece_type]  * (1 + 0.15 * scale))
boss.ATK    = floor(base_ATK[piece_type] * (1 + 0.10 * scale))
boss.DEF    = floor(base_DEF[piece_type] * (1 + 0.10 * scale))
// SPD and AP are not scaled.
// apply_items(boss) called after scaling to add item bonuses on top.
## 7.4 Boss Spawning
The legacy boss spawns in the final encounter at a position separate from the King’s spawn. It is created via make_unit(legacy_boss.piece_type), then its items list is populated from the LegacyBoss record, then apply_items() is called, then is_boss is set to true.
Before the first Enemy Phase of the final encounter, one pre-fight dialogue line from the piece type’s dialogue pool is written to the combat log. This is the only special scripting the boss receives. Its AI runs identically to all other enemies, with the boss priority modifier applied.
> → Implementation note: make_unit(type) returns a Unit with base stats from pieces.json. Never special-case the boss in combat logic. The is_boss flag only affects: (1) priority weight modifier in the AI, (2) pre-fight dialogue trigger, (3) display name in UI. Everything else is identical to a regular enemy.
# 8. Character Roster Reference
All piece types that exist in the game: as player evolution forms, as enemies, and as potential legacy bosses. Each piece’s narrative role is listed here to keep AI-generated dialogue, behavior, and item descriptions tonally consistent.

| Piece | Narrative role | Mechanical identity | Move personality | Default pre-fight line |
| --- | --- | --- | --- | --- |
| Pawn | Desperate common soul. Fights because the law demands it. | Weakest stats. Only form that can evolve (player only). Gateway unit. | Short range. Cardinal. Predictable. Straight lines only. | “You shouldn’t be here.” |
| Knight | Restless wanderer. Long on the Plain. Resigned, not angry. | L-leap ignores terrain and pieces. Fast (SPD 3). Good damage, fragile. | Leaps unpredictably. Closes fast. Prefers flanking angles. | “I don’t enjoy this either.” |
| Bishop | Old and strange. Knows contradictory myths. Distrusts anomalies. | Diagonal only. Curses tiles it crosses. Mid-range damage, low HP. | Cuts diagonals. Seeks cursed tile positions. Avoids straight lines. | “The myths contradict each other. I’ve checked.” |
| Rook | Rigid. Has accepted its form completely. Speaks in absolutes. | Highest DEF. Long cardinal lines. Slow but unmovable. | Drives straight at target. Holds corridors. Never retreats. | “I am what the law made me. So are you.” |
| Queen | Vast and exhausted. Has seen countless Unranked challengers. | Omnidirectional. Highest ATK. High SPD. Fewer HP than threat suggests. | Closes from any angle. Uses full AP. Attacks before moving if adjacent. | “Another unranked. I’ve seen this cycle many times.” |
| King | The final piece. Aware of the cycle. Neither cruel nor kind. Enduring. | Highest HP and DEF. Never flees. Boss modifier always applied. | Holds center. Attacks anything adjacent. Slow but immovable. | “Do you understand what you are doing?” |

# 9. Implementation Guide for AI Development
Written directly for an AI coding assistant. Build systems in the order listed. Each depends on the one above it. Do not skip steps.
## 9.1 Recommended Build Order
- 1.  Unit data model — struct with all stats, items[], status_effects[], position {x, y}.
- 2.  Board data model — Tile[rows][cols] with type, piece reference, revealed flag.
- 3.  Movement system — get_valid_moves(unit, board) returning valid tile set.
- 4.  Combat system — resolve_attack(attacker, defender) returning DamageResult. Apply HP.
- 5.  Status effect system — EventBus + Tick Phase handler applying and expiring statuses.
- 6.  Item system — apply_items(unit) rebuilding all derived stats and registering triggers.
- 7.  Synergy detection — inside apply_items(), count schools and apply bonuses.
- 8.  Turn system — Phase enum, AP tracking, player input handler, enemy queue.
- 9.  AI system — calculate_priority(unit) and execute_behavior(unit, mode, board).
- 10. Board generation — weighted random terrain per tile, depth-scaled mutation weights.
- 11. Encounter flow — spawn logic, win condition (enemies == 0), item draft overlay.
- 12. Run flow — run_depth counter, tier-based enemy pool, final encounter trigger.
- 13. Evolution — kill threshold check after each player kill. Apply form change.
- 14. Legacy boss — LegacyBoss serialization to MetaState, scaling, spawn, AI flag.
- 15. UI layer — board renderer, stat sidebar, combat log, draft overlay, boss selection screen.
## 9.2 Data Separation Rule
All numerical values must live in external JSON config files, never hardcoded in game logic. This allows an AI assistant to tune the game by editing config only, with no code changes.

| Config file | Contains |
| --- | --- |
| pieces.json | Base stats (HP, ATK, DEF, SPD, AP), move type and range per piece type |
| items.json | Full item catalog: stats, trigger ID, school, ai_behavior {mode, weight}, flavor text |
| terrain.json | Terrain types: base weight, entry effect, standing effect, combat modifier |
| synergies.json | School names, item thresholds, and bonus definitions |
| ai_weights.json | PIECE_BASE_WEIGHTS per type. Boss priority modifier values. |
| encounter_tiers.json | Enemy type pool and spawn count range per depth tier. FINAL_DEPTH value. |

## 9.3 Prompt Template for AI Development Sessions
When using an AI assistant to implement a specific system, structure the prompt as follows:
Context: I am building Pawn’s Ascent, a roguelike board combat game.
[Paste the relevant section from this document]

Task: Implement [system name] exactly as described above.
Engine / language: [Godot 4 GDScript / Unity C# / etc.]
Data source: Read values from [config file name]. Do not hardcode.
Return: [specific function or class name] accepting [inputs] returning [output].
Do not implement adjacent systems. Stub them with placeholder functions.
> End of mechanics reference.
Pawn’s Ascent — v1.0 — Read alongside pawns_ascent_concept.docx