# PAWN'S ASCENT — Run Progression & Systems

**PAWN’S ASCENT**
Run Progression, Systems & Score Design
> v1.0 — Planning reference for AI-assisted development
> This document defines how a single run is structured from start to finish:
> map path, zone structure, node types, run themes, allies, score, and the legacy/story system.
> Read alongside: pawns_ascent_concept.docx and pawns_ascent_mechanics.docx
# 1. Run Overview
A run is a single attempt to descend through the Plain from the Unranked’s arrival to the King’s chamber. Every run is built from the same structural skeleton — zones, nodes, a boss at each zone end — but populated differently based on the chosen Run Theme and the active Legacy Boss.
The player navigates the run via a branching overworld path, Slay-the-Spire style: after each node is cleared, 2–3 forward paths are revealed and the player chooses which to take next. There is no backtracking. Every choice forecloses alternatives.

| Layer | What it is | Analogy |
| --- | --- | --- |
| Run | One full attempt, start to King or death | A full Balatro ante sequence |
| Zone | 3–4 nodes + 1 boss node. Thematically consistent. | A Slay the Spire act |
| Node | A single event on the path: combat, shop, story, rest, etc. | A Slay the Spire room |
| Floor | Synonym for node depth. Floor 1 = first node visited. | Run depth counter |

> → Dev note: RunState tracks: current_zone (int), current_floor (int), chosen_theme (string), path_graph (DAG of nodes), player unit, inventory, gold, active allies, score_state. The path_graph is generated at run start and fully determines which nodes exist and their connections.
# 2. Run Start and Tutorial
## 2.1 Pre-Run Setup Screen
Before a run begins the player sees the Run Setup screen. This is where run theme, mode (Legacy or Themed), and difficulty modifier are chosen. These choices are locked in for the entire run.

| Choice | Options | Effect on run |
| --- | --- | --- |
| Run mode | Legacy Run (story) or Themed Run (endless) | Determines story node presence and path structure |
| Run theme | Thunder, Volcanic, Ocean, Frost, Void, Neutral | Shapes enemy pool, loot tables, terrain bias, zone aesthetics |
| Difficulty | Wanderer / Exile / Unranked | Multiplies base score. Exile ×1.5×, Unranked ×2.0×. Affects enemy HP/ATK scaling. |

> → Dev note: These three fields are written to RunState at run init and never change mid-run. They seed the path graph generator and the score multiplier stack.
## 2.2 Tutorial (First Run Only)
The tutorial fires automatically on the very first run, before the Run Setup screen. It cannot be skipped on first launch but can be skipped on all subsequent runs via a settings toggle.
- Tutorial is Zone 0: a single linear path of 4 nodes with no branching.
- Node 1: Movement tutorial. Player moves the Pawn on an empty board. Terrain effects demonstrated.
- Node 2: Combat tutorial. Single enemy Pawn. Attack, AP, and damage formula explained in-world.
- Node 3: Item draft tutorial. Player receives one forced item (Iron Chain, no choice). apply_items() explained via UI tooltip.
- Node 4: Evolution preview. A cutscene-style board shows a Pawn evolving to Knight to demonstrate the progression arc. Player does not control this.
- Tutorial ends. Run Setup screen appears. First real run begins.
> → Dev note: Tutorial state stored in MetaState.tutorial_complete (bool). Once true, Zone 0 is skipped permanently. All tutorial dialogue is written in the Plain’s voice — no fourth-wall breaking UI text. An old Pawn NPC guides the player in-world.
# 3. Zone Structure
A run is divided into 4 zones plus a final chamber. Each zone contains 3–4 combat/event nodes arranged in a branching path, ending with a mandatory Boss Node. Clearing the boss unlocks a Rest Area before the next zone begins.

| Zone | Name | Floors (nodes) | Boss type | Rest area? |
| --- | --- | --- | --- | --- |
| Zone 1 | The Outer Plain | Floors 1–4 | Zone Captain (Knight or Bishop tier) | Yes — shop + heal |
| Zone 2 | The Disputed Ground | Floors 5–8 | Zone Warden (Rook tier) | Yes — upgrade bench + ally hire |
| Zone 3 | The Inner Court | Floors 9–12 | Zone Champion (Queen tier) | Yes — story node + shop |
| Zone 4 | The Throne Approach | Floors 13–15 | The Crown Guard (Queen + legacy boss) | No — straight to final |
| Final | The King’s Chamber | Floor 16 | The King | Win screen / cycle reset |

## 3.1 Branching Path Rules
Within each zone the path is a directed acyclic graph (DAG). After each cleared node, 2–3 forward edges are revealed. The player picks one. Unchosen paths are removed permanently. The boss node is always the convergence point at zone end — all paths in the zone lead to it.

| Node count per zone | Min branches offered | Max branches offered | Guaranteed node types |
| --- | --- | --- | --- |
| 3 nodes | 2 | 2 | 1 combat, 1 event (shop/rest/story), 1 elite combat |
| 4 nodes | 2 | 3 | 1 combat, 1 elite combat, 1 event, 1 wild (any type) |

> → Dev note: Path graph is a pre-generated DAG stored in RunState.path_graph. Nodes have type, depth, and edge list. The renderer draws the graph as an overworld map. On node clear, edges from that node become selectable. The boss node has no outgoing edges — clearing it triggers the rest area transition.
## 3.2 Node Types

| Node type | Icon | What happens | Reward |
| --- | --- | --- | --- |
| Combat | Swords | Standard encounter: clear all enemies. Board generated per theme + depth. | XP, gold, possible item drop |
| Elite Combat | Skull | Harder enemy formation. 1 elite enemy with items pre-equipped. | Guaranteed item drop, bonus XP |
| Shop | Scales | Buy/sell items, buy perks, hire a temporary ally. Uses gold. | Player-chosen (costs gold) |
| Rest Area | Flame | Heal 30% max HP. OR bank 1 item to a limited persistent stash (Legacy mode only). | HP restore or item stash |
| Story Node | Scroll | Branching dialogue event. Choice affects path, loot, or next zone’s enemy disposition. | Varies by choice |
| Upgrade Bench | Anvil | Upgrade one owned item to its enhanced tier. Costs gold + 1 material drop. | Permanent item upgrade |
| Ally Hire | Banner | Recruit one temporary ally for the remainder of the zone. Lost after zone boss. | Ally unit added to board |
| Shrine | Rune | Gain a Perk (passive board/stat upgrade). One offered, take or leave. | 1 perk |
| Ambush | ! | Forced elite combat with no preparation. Enemies pre-placed on a cursed board. | Bonus gold if survived |

# 4. Experience, Loot, and Levelling
## 4.1 Experience (XP)
The player’s unit gains XP from kills and node clears. XP feeds the evolution threshold AND a separate Perk Level that unlocks passive upgrades. These are two parallel progression tracks from the same XP pool.

| XP source | XP awarded | Notes |
| --- | --- | --- |
| Enemy kill (standard) | 10 XP | Base. Scales +2 XP per zone. |
| Enemy kill (elite) | 25 XP | Elite enemies always award 25 XP regardless of zone. |
| Node cleared (combat) | 15 XP | Awarded on clearing the last enemy, in addition to kill XP. |
| Node cleared (elite) | 35 XP | Full elite node clear bonus. |
| Boss killed | 80 XP | Zone boss. Awarded once per boss. |
| Story node — good outcome | 20 XP | Outcome defined per story node. |
| Ally assist kill | 5 XP | If ally lands killing blow, player still gets 5 XP (reduced). |

## 4.2 Evolution Track (Kill-Based)
Evolution from one piece form to the next is gated by kill count as defined in the Mechanics Reference (pawns_ascent_mechanics.docx Section 4.4). XP and kill count are separate counters — killing enemies advances both. Evolution is instantaneous and permanent within the run.
- Kill count is displayed as a secondary progress bar on the player’s unit card.
- Evolution gives: new form’s base stats, new movement type, +8 HP restored, full AP refill.
- Evolution does not reset XP or Perk Level.
## 4.3 Perk Level Track (XP-Based)
Every 100 XP earned, the player gains one Perk Point. Perk Points are spent at Shrine nodes or at the Upgrade Bench. Each perk is a passive board or stat upgrade chosen from a pool of 3 offered options.
**PERK CATEGORIES**

| Category | Example perks | Effect type |
| --- | --- | --- |
| Movement perks | Ghost Step, Diagonal Reach, Leap Extension | Modify move type or range for player’s current form |
| Combat perks | Executioner (bonus dmg at kill threshold), Thick Skin (+2 DEF permanent) | Modify damage formula or base stats permanently |
| Board perks | Cartographer (reveal fog tiles), Terraformer (convert 1 tile per turn) | Modify how the player interacts with terrain |
| Ally perks | Veteran Bond (+1 ATK to all allies), Last Stand (ally fights on after zone boss) | Buff ally system |
| Score perks | Greed (+5% gold per kill), Chronicler (bonus score per story node visited) | Directly boost score multipliers |

> → Dev note: Perk pool is filtered by player’s current form and run theme. A Pawn cannot access Queen-tier movement perks. A Thunder run offers more Board and Movement perks biased toward speed and range. Perks are stored as a list on RunState.player.perks[]. Each perk has an apply() function that modifies derived stats or registers a new event listener via EventBus.
## 4.4 Loot System
Enemies drop loot on death. Loot is weighted by enemy tier and run theme. Loot types: gold (always), items (chance), materials (rare, used at Upgrade Bench).

| Enemy tier | Gold drop | Item drop chance | Material drop chance |
| --- | --- | --- | --- |
| Standard Pawn/Knight | 5–10 gold | 10% | 2% |
| Standard Bishop/Rook | 10–18 gold | 18% | 5% |
| Elite (any tier) | 20–35 gold | 60% | 20% |
| Zone boss | 50–80 gold | 100% (guaranteed) | 40% |
| King (final boss) | 150 gold | 100% + 1 legacy item | 100% |

- Items dropped by enemies are drawn from the current run theme’s loot table, not the full catalog.
- Gold is added to RunState.gold immediately on kill.
- Item drops go to a post-combat loot screen (pick up or leave). They do not auto-equip.
- Materials are named per theme (Thunder Shard, Ember Core, Tide Rune) but function identically at the Upgrade Bench.
# 5. Run Themes
A Run Theme is chosen at the Run Setup screen before the run begins. It defines: the terrain bias of generated boards, the enemy ability flavor, the loot table (which items drop), the zone aesthetic, and one unique theme mechanic that applies throughout the run.
## 5.1 Theme Table

| Theme | Terrain bias | Enemy ability flavor | Unique theme mechanic | Score difficulty multiplier |
| --- | --- | --- | --- | --- |
| Neutral (default) | Balanced, no bias | No elemental flavor. Base AI weights. | None. Pure mechanics. | 1.0× |
| Thunder | Elevated tiles more common. Fog patches. | Enemies have Shock: on hit, skip target’s next AP action. | Chain Lightning: every 3rd kill triggers AoE to adjacent enemies. | 1.2× |
| Volcanic | Fire tiles everywhere. Few blessed tiles. | Enemies have Ignite: apply Burn on attack. | Eruption: every 5 turns, 2 random tiles become fire. Player’s ATK +1 per fire tile on board. | 1.3× |
| Ocean | No fog. Fluid tiles: movement costs 0 AP but direction is random ±1 tile. | Enemies have Tide Pull: knockback toward water tiles on hit. | Undertow: player can surf fluid tiles freely. Enemies slow by 1 SPD near fluid. | 1.2× |
| Frost | Blessed tiles common. Void tiles appear from zone 2. | Enemies have Freeze: 20% chance to skip target turn on hit. | Permafrost: killing an enemy freezes their tile for 2 turns (impassable, blocks LoS). | 1.3× |
| Void | Mostly void and cursed tiles. No blessed. | Enemies have Drain: steal 1 AP from target on hit. | Entropy: board mutates every 3 turns (not 5). Player gains +1 ATK per mutation survived. | 1.5× |

## 5.2 Theme Abilities (Player Access)
Choosing a theme gives the player access to that theme’s exclusive ability pool via item drops and shrine perks. These abilities are not available in Neutral runs. This is the primary reason to choose a theme over Neutral — the unique mechanics and exclusive build options, at the cost of a harder terrain environment.
- Thunder run unlocks: Storm Step (move through enemies), Arc Strike (hits adjacent enemy too), Conductor (Shock spreads chain to adjacent units).
- Volcanic run unlocks: Molten Skin (+DEF per adjacent fire tile), Ash Cloud (blind adjacent enemies on evolve), Eruption Rider (immune to fire tile damage).
- Ocean run unlocks: Tide Walk (fluid tile movement always cardinal, no randomness), Depth Charge (ranged attack 3 tiles, AoE 1), Current (push all adjacent enemies 1 tile each turn).
- Frost run unlocks: Ice Armor (+2 DEF, shatters on hit for 2 AoE dmg), Cryo Step (leave frozen tile on move), Absolute Zero (freeze all enemies for 1 turn, once per run).
- Void run unlocks: Phase Shift (ignore terrain entry effects for 2 turns), Soul Drain (steal 1 stat point from killed enemy permanently), Entropy Embrace (each board mutation heals 3 HP).
> → Dev note: Theme ability pools are defined in theme_abilities.json per theme. Items in a theme pool replace a portion of the standard loot table. The replacement rate is 40% theme items / 60% standard items at zone 1, rising to 70% theme / 30% standard by zone 3. This ensures theme builds are available but not mandatory.
# 6. Ally System
Allies are temporary units that join the player’s side for the duration of one zone. They are lost after the zone boss fight. Allies act on the player’s side during combat but the player does not directly control them — they use the same priority queue AI as enemies, but with friendly flags.
## 6.1 Hiring Allies
Allies are recruited at Ally Hire nodes (see Section 3.2). Each hire node presents 2 available allies. The player may recruit 1. Hiring costs gold. The player may have a maximum of 2 active allies at any time.

| Ally type | Cost | Base piece form | Pre-equipped item | AI personality |
| --- | --- | --- | --- | --- |
| Wandering Pawn | 30 gold | Pawn | None | Cautious. Follows player, attacks only if adjacent. |
| Mercenary Knight | 60 gold | Knight | Bleeder’s Mark | Aggressive. Leaps toward nearest enemy, attacks first. |
| Rogue Bishop | 55 gold | Bishop | Ashen Veil | Positional. Seeks elevated/cursed tiles, curses terrain. |
| Iron Rook | 80 gold | Rook | Barricade | Anchor. Holds position between player and enemies. |
| Exiled Queen | 120 gold | Queen | Hollow Crown | Dominant. Full AP aggression. High risk, high value. |

## 6.2 Ally Behavior
Allies use the standard priority queue AI (Mechanics Reference Section 6) with friendly flags set. They will not attack the player. They share the board and act after the player’s turn ends but before enemies. Ally turn order within the ally phase is sorted by SPD descending.
- Allies have their own HP pool. They can die mid-zone. Dead allies are removed from the board permanently.
- Allies do not gain XP or levels. Their stats are fixed at hire.
- Allies do not drop items when they die.
- If the zone boss is cleared with an ally alive, the ally completes their contract. They disappear at the zone transition. No carry-over.
- The Veteran Bond perk (Section 4.3) extends one ally through the zone boss fight only, not into the next zone.
## 6.3 Ally Phase in Turn Order
The full turn sequence with allies is: Player Phase → Ally Phase → Enemy Phase → Tick Phase. Allies act between the player and enemies. This gives the player a chance to position before allies act, and allies a chance to attack before enemies respond.
> → Dev note: Ally units are stored in RunState.allies[]. Each ally is a Unit with is_ally=true, is_player=false. The AI function already handles friendly fire prevention via faction check. Ally Phase is a new phase enum value: ALLY. The enemy queue logic is reused for ally execution — same function, different unit list.
# 7. Shop and Economy
## 7.1 Gold
Gold is the run’s currency. Earned from kills, node clears, and story node outcomes. Spent at Shop nodes and Ally Hire nodes. Gold does not carry between runs — it resets to 0 at run start. In Legacy Mode only, surplus gold at run end is converted to Legacy Tokens (Section 9).
## 7.2 Shop Node Inventory
Each Shop node generates a randomized stock drawn from the current run theme’s item pool and a standard stock of services. Stock is generated once when the node is entered and does not refresh within the run.

| Stock type | Count per shop | Cost range | Notes |
| --- | --- | --- | --- |
| Items (theme pool) | 2–3 items | 40–120 gold | Drawn from theme loot table. Player may already own these. |
| Items (standard pool) | 1–2 items | 30–90 gold | From standard catalog. Different from theme items. |
| Perk (one-time buy) | 1 perk | 60–100 gold | Bypasses shrine requirement. Same perk pool as Shrine nodes. |
| Ally hire | 0–1 ally | 30–120 gold | Not always present. Presence is 40% chance per shop. |
| Item removal | Service | 25 gold | Remove one owned item. Useful for synergy management. |
| HP restore (potion) | 1–2 potions | 20–40 gold each | Restore 20% max HP. Cannot overheal. |

## 7.3 Item Upgrade (Upgrade Bench)
Upgrade Bench nodes allow the player to upgrade one owned item to its enhanced form. Each item has exactly one upgrade path. Upgrading costs gold + 1 theme material drop. Enhanced items have stronger stats or an additional trigger.

| Base item | Enhanced form | Enhanced effect added |
| --- | --- | --- |
| Shard of Rank | Shard of Dominion | +2 ATK → +4 ATK. Attacks now ignore 2 DEF instead of 1. |
| Ward Rune | Ward Inscription | +3 DEF → +5 DEF. Gain Shielded 1 turn at start of each encounter. |
| Iron Chain | Throne Chain | +5 HP → +8 HP. Knockback now pushes 2 tiles. |
| Bleeder’s Mark | Bleeder’s Covenant | +1 ATK → +2 ATK. Bleed lasts 3 turns instead of 2. |
| Hollow Crown | Shattered Crown | +6 HP → +8 HP. Low-HP buff is +3 ATK (was +2) and triggers at 40% HP. |
| Mending Word | Mending Scripture | on_kill_heal: +3 HP → +5 HP. Also heals 1 HP per ally alive. |

# 8. Score System
The score system uses a multiplier stack. A base score accumulates during the run from kills, floors cleared, and events. At the end of the run (death or win), the base score is multiplied by a stack of modifiers earned during the run. The final score is displayed on the death/win screen alongside the personal best and leaderboard position.
## 8.1 Base Score Accumulation
Base score is a running integer that increments throughout the run from the following sources:

| Event | Base score added | Notes |
| --- | --- | --- |
| Enemy killed (standard) | 100 pts | Per kill. |
| Enemy killed (elite) | 300 pts | Per elite kill. |
| Zone boss killed | 500 pts | Per boss. |
| Floor cleared (node complete) | 50 pts | Per node, any type. |
| Item acquired | 75 pts | On pickup or draft. |
| Perk acquired | 100 pts | On shrine or shop purchase. |
| Story node visited | 60 pts | On any story node entry. |
| Ally survives zone boss | 150 pts | Bonus per surviving ally. |
| Evolution triggered | 250 pts | One-time per evolution. |
| King defeated | 2000 pts | Run completion bonus. |

## 8.2 Multiplier Stack
At run end, the base score is multiplied by each modifier in the stack. Multipliers are multiplicative with each other, not additive. The final score = base_score × M1 × M2 × M3 × …

| Multiplier | Value | How earned | Stacks? |
| --- | --- | --- | --- |
| Difficulty modifier | Wanderer ×1.0 / Exile ×1.5 / Unranked ×2.0 | Chosen at run start. Fixed. | No |
| Theme difficulty | Neutral ×1.0 / Thunder ×1.2 / Volcanic ×1.3 / Frost ×1.3 / Ocean ×1.2 / Void ×1.5 | Chosen at run start. Fixed. | No |
| Death floor modifier | ×1.0 at floor 1, +0.05 per floor survived (max ×1.8) | Earned passively by surviving. | Accumulates |
| No-heal run | ×1.3 | Reach zone boss without using any HP restore (potions or rest). | No |
| Ironclad perk | ×1.2 | Perk earned at shrine. Must be active at run end. | No |
| Chronicler perk | ×1.1 per story node visited (max ×1.4) | Perk earned at shrine. | Yes, capped |
| Ally loss penalty | ×0.9 per ally who died mid-zone | Automatic. Penalizes losing hired allies. | Yes |
| Speed clear bonus | ×1.15 if run completed in under 45 minutes | Tracked by run timer. | No |

## 8.3 Score Display and Records
The death/win screen shows: final score, base score, each multiplier applied with its value, personal best for this run mode + theme combination, and all-time personal best across all modes. A run history log shows the last 10 runs with floor reached, theme, score, and cause of death.
- Personal best is stored in MetaState per mode+theme combination. e.g. Legacy+Thunder has its own PB separate from Themed+Thunder.
- Score is always shown even on death. The explicit goal: beat your last score on the same theme.
- A ‘Score Breakdown’ screen is available post-run showing every event that contributed to base score, in order. This is the score equivalent of a Balatro final hand summary.
- Optional: global leaderboard per mode+theme. Requires online integration. Scope for post-launch.
> → Dev note: score_state on RunState: {base: int, multipliers: [{name, value}], events: [{description, pts_added}]}. Every scoring event calls add_score(RunState, event_type) which updates base and appends to events[]. At run end, compute_final_score() reduces the multiplier list. Events[] powers the Score Breakdown screen.
# 9. Legacy Run and Story System
The Legacy Run is the game’s story mode. It uses the same zone/node structure as Themed Runs but adds Story Nodes with branching dialogue, tracks choices across runs, and assembles a narrative from those choices. The story has multiple endings determined by the sum of choices made across all Legacy Runs.
## 9.1 Legacy Run vs Themed Run

| Feature | Legacy Run | Themed Run |
| --- | --- | --- |
| Story nodes | Present. 1–2 per zone. Choices tracked. | Not present. Event nodes replace them. |
| Narrative continuity | Choices carry across runs in LegacyState. | No narrative. Each run is self-contained. |
| Gold carry-over | Surplus gold → Legacy Tokens (see 9.2). | Gold resets each run. No carry. |
| Boss pool | The King + legacy boss (if set). | The King + legacy boss (if set). Same. |
| Available themes | Neutral only. Theme chosen per chapter. | All 5 themes available. |
| Score tracking | Separate PB per chapter. | PB per theme. |

## 9.2 Legacy Tokens
Legacy Tokens are a meta-currency earned only in Legacy Runs. At run end (win or death), any remaining gold is converted at a rate of 10 gold = 1 Legacy Token. Tokens persist in MetaState across all runs indefinitely. They are spent at the Legacy Vault — a pre-run screen available only in Legacy mode — to unlock permanent passive bonuses that apply to all future Legacy Runs.
- Legacy Vault unlocks are cosmetic and mild mechanical: starting with 1 extra gold, starting with a guaranteed common item offered in draft 1, etc.
- Legacy Tokens are not available in Themed Runs. They do not affect Themed Run scores.
- This system rewards Legacy Run players who invest time without creating pay-to-win mechanics.
## 9.3 Story Structure — Branching Chapters
The Legacy story is divided into Chapters. Each Legacy Run is one Chapter. Chapters must be completed in order. Completing a chapter (reaching the King, win or loss) unlocks the next chapter’s content and records the choices made.

| Chapter | Working title | Zone theme | Core story question |
| --- | --- | --- | --- |
| 1 | The Arrival | Neutral — the plain as it is | Why is the Unranked unassigned? What happened before? |
| 2 | The Law Made Flesh | Volcanic — the plain’s anger | Who built the hierarchy? Is anyone trying to end it? |
| 3 | The Contradictions | Ocean — fluid and unstable | The myths the player has heard: which, if any, are true? |
| 4 | The Inner Court | Frost — cold and crystalline | What does the Queen know that the pawns don’t? |
| 5 | The Throne | Void — unravelling reality | What does the King actually want? Is the cycle breakable? |

## 9.4 Branching Choices and Outcomes
Story nodes present a short dialogue exchange with 2–3 choices. Each choice is recorded in LegacyState.choices[] as a {chapter, node_id, choice_id} entry. These entries are read in later chapters to alter dialogue, enemy dispositions, available allies, and ultimately the Chapter 5 ending.
**EXAMPLE STORY NODE — CHAPTER 1, ZONE 1**

| The old Pawn speaks "You have no rank. The plain cannot place you. In my experience that means one of two things: you were erased deliberately, or you arrived from somewhere the plain has never seen."  [Choice A] "I don't remember anything before this." [Choice B] "Tell me about the erased. Who does that?" [Choice C] Say nothing. Walk past. |
| --- |

- Choice A: recorded as 'origin_unknown'. In Chapter 3, a Bishop will recognize the Unranked as ‘one of the forgotten’ and offer a different item.
- Choice B: recorded as 'seeks_erased'. In Chapter 2, an enemy Rook will pause before fighting and say one additional line about the Erasers.
- Choice C: recorded as 'silent'. In Chapter 5, the King’s opening dialogue changes: "You’ve never been much for questions. Good. Neither am I."
> → Dev note: LegacyState.choices[] is a persistent array in MetaState. Story node scripts are data files (story_nodes.json) with choice entries containing: choice_id, display_text, record_tag, and downstream_effects[]. The story renderer reads choices[] at each node to filter available options and inject alternate dialogue lines. No branching logic lives in code — it lives in the data files.
## 9.5 Legacy Endings
Chapter 5’s ending is determined by tallying choice tags from LegacyState.choices[] at the start of the final encounter. Three endings are possible. The tags do not need to be exclusive — the ending is determined by whichever tag cluster has the highest count.

| Ending | Tag cluster | What happens | Post-run unlock |
| --- | --- | --- | --- |
| The New Cycle | Most choices: seek power, take items, defeat without hesitation | Player becomes King. Credits roll over new board. The cycle restarts. No dialogue from King. | Legacy boss system unlocked if not already. Unlock Void theme for Themed Runs. |
| The Refusal | Most choices: ask questions, help others, give up items | Player defeats King then refuses the crown. The plain pauses. Credits roll over an empty board. | Unlock a secret Perk available only in future Legacy Runs: Abdication — ×1.5 score, start each zone at Pawn form. |
| The Understanding | Balanced choices across all tags | Player and King speak at length. Player accepts but changes the first law. Ambiguous ending — may or may not break the cycle. | Unlock a Legacy Vault cosmetic. All future Legacy Runs start with the King’s dialogue pre-unlocked. |

# 10. Boss-Generated Themed Runs
When a player completes a run (defeats the King) and selects their completed unit as the Legacy Boss, that unit’s evolution path defines the zone sequence and enemy pool of all future runs where it appears as the boss. This is the ‘boss-generates-a-themed-run’ system described in the design brief.
## 10.1 Evolution Path as Zone Blueprint
Every form the player’s unit passed through during the completed run is recorded in LegacyBoss.evolution_path[]. This list defines the zone sequence of runs featuring that boss.
**EXAMPLE: A UNIT THAT EVOLVED PAWN → KNIGHT → BISHOP → ROOK GENERATES:**

| Zone | Generated theme | Dominant enemy type | Boss unit origin |
| --- | --- | --- | --- |
| Zone 1 | Pawn zone — sparse, cardinal terrain, low mutation | Pawn swarms, few Knights | Standard zone captain |
| Zone 2 | Knight zone — elevated tiles, L-shaped corridors | Knight formations, Bishops start appearing | Standard zone warden |
| Zone 3 | Bishop zone — cursed diagonals, fog-heavy boards | Bishops and Rooks, diagonal terrain emphasis | Standard zone champion |
| Zone 4 (final) | Rook zone — long cardinal corridors, siege terrain | Rook formations, Queen guard | The Crowned Rook (legacy boss) + King |

## 10.2 Enemy Pool Derivation
Each zone in the boss-generated run uses the piece form for that zone as the anchor enemy type. The full enemy pool for that zone is: anchor type (50%), one tier below (25%), one tier above (25%). This creates a zone that feels thematically cohesive to the piece form without being monotonous.
## 10.3 Loot Table Derivation
The item pool for each zone in a boss-generated run is biased toward items that the legacy boss unit carried. If the boss held 2 Shadow items, Shadow items have a +20% drop rate in that run. If the boss held a Holy synergy, Holy items appear more frequently. This creates runs where players encounter builds similar to the boss they’re fighting toward, enabling counter-build strategies.
## 10.4 Boss Presentation
When the player reaches the final encounter of a boss-generated run, the legacy boss is introduced by name. The introduction pulls the piece type’s canonical dialogue (Section 8 of Mechanics Reference) and appends a generated line referencing the boss’s original run: ‘Survivor of run [N]. [kills] pieces fallen before me.’
> → Dev note: LegacyBoss object: {piece_type, evolution_path[], items[], display_name, run_origin, kills, school_counts{shadow,holy,siege}}. The zone generator reads evolution_path[] to build the zone sequence. The loot system reads school_counts to bias drop rates. The boss intro renderer reads display_name, run_origin, and kills for the pre-fight line. All from one data object.
# 11. Full Run Flow — Reference Sequence
The complete sequence of a single run from setup to end. Use this as the implementation checklist for the run controller.

| Step | Event | System called | Output |
| --- | --- | --- | --- |
| 1 | Player opens game | MetaState loaded | Tutorial flag checked |
| 2 | Tutorial (first run only) | TutorialController | 4-node linear path, then Run Setup |
| 3 | Run Setup screen | RunSetupUI | mode, theme, difficulty written to RunState |
| 4 | Path graph generated | PathGraphGenerator(RunState) | DAG of nodes written to RunState.path_graph |
| 5 | Zone 1 begins | ZoneController(zone=1) | Player spawns. First node options shown on map. |
| 6 | Player selects node | NodeController(node_type) | Combat / Shop / Story / etc. resolves |
| 7 | Node reward | RewardSystem | XP, gold, item drop, perk offer as applicable |
| 8 | Score updated | add_score(event_type) | RunState.score_state updated |
| 9 | Next node options shown | PathGraphRenderer | 2–3 forward edges highlighted |
| 10 | Repeat steps 6–9 until zone boss node | ZoneController | Boss node has no forward edges until cleared |
| 11 | Zone boss fight | CombatController(boss_node) | Boss + legacy boss (if set) on board |
| 12 | Zone boss cleared | ZoneController.on_boss_cleared() | Rest area triggers. Ally contract ends. |
| 13 | Rest area | RestAreaUI | Heal 30% HP or stash item (Legacy only) |
| 14 | Next zone begins | ZoneController(zone+1) | New DAG generated for new zone |
| 15 | Repeat zones 1–4 | ZoneController loop | Each zone harder, more mutations, scaled enemies |
| 16 | Final encounter | CombatController(final) | King + legacy boss. Score events still fire. |
| 17a (win) | King defeated | WinController | Legacy Boss Selection screen |
| 17b (loss) | Player HP = 0 | DeathController | Score computed, death screen shown |
| 18 | Score computed | compute_final_score(RunState) | base × all multipliers = final score |
| 19 | Score recorded | MetaState.update_scores() | PB updated if beaten |
| 20 | Legacy Boss selected (win only) | LegacyBossSerializer | LegacyBoss written to MetaState |
| 21 | Legacy Tokens converted (Legacy mode) | LegacyTokenSystem | Surplus gold → tokens in MetaState |
| 22 | Run over. Return to main menu | RunState discarded | MetaState persisted to disk |

> End of run progression document.
Pawn’s Ascent — v1.0 — Read alongside pawns_ascent_concept.docx and pawns_ascent_mechanics.docx