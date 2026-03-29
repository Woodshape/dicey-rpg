# Passive Ability Ideas

## Trigger Design Space

Passives are always-on effects that fire at specific points in the game loop. The resolution pipeline and game flow provide these hook points:

### Roll-Based Triggers (per character roll)

| Trigger | When | Available Data | Use Case |
|---------|------|----------------|----------|
| On Roll | After `character_roll`, before ability resolution | Full roll result, attacker, target | Buff self, chip damage, conditional effects based on roll quality |
| On Match | After roll, only if matched_count > 0 | Roll result with match data | Bonus effects that amplify successful rolls |
| On Miss | After roll, only if matched_count == 0 | Roll result (all unmatched) | Consolation effects that soften bad rolls |
| On Skull Hit | Inside `apply_skull_damage` per-hit loop | Per-hit damage, attacker, target | On-hit procs (poison chance, lifesteal, reflect) |
| On Ability Fire | After main ability resolves | Roll, ability result, target HP delta | Amplifiers that chain off the main ability |
| On Resolve Fire | After resolve ability triggers | Roll, resolve result | Effects that reward filling the meter |

### Damage-Based Triggers (reactive)

| Trigger | When | Available Data | Use Case |
|---------|------|----------------|----------|
| On Damage Taken | When this character loses HP (skull or ability) | Damage amount, attacker, source type | Thorns, damage reduction, counter-attack |
| On Ally Damaged | When a teammate loses HP | Damage amount, ally, attacker | Protective reactions, resolve charge, empathy effects |
| On Kill | When this character's attack kills a target | Target, overkill amount | Execute bonuses, snowball effects |
| On Death | When this character dies | Killer, game state | Death rattles, last stand effects |

### Turn-Based Triggers (periodic)

| Trigger | When | Available Data | Use Case |
|---------|------|----------------|----------|
| On Turn Start | At the beginning of owner's combat phase | Full game state | Regen, DoT, aura effects |
| On Round Start | When a new draft round begins | Round state, pool | Draft bonuses, round-scoped buffs |
| On Ally Roll | When a teammate rolls (not self) | Ally's roll result, ally ref | Support synergies, combo chains |

### State-Based Triggers (continuous)

| Trigger | When | Available Data | Use Case |
|---------|------|----------------|----------|
| Stat Modifier | Always active, modifies a stat calculation | Character stats | Flat or conditional +ATK, +DEF, +resolve_max |
| Condition Modifier | Modifies condition application or ticking | Condition being applied/ticked | Resistance, duration extension, amplified debuffs |

### Implementation Complexity

- **Simplest (start here):** On Roll — same proc signature as abilities, single call site in `resolve_roll`
- **Medium:** On Damage Taken, On Ally Damaged — requires adding a hook call at damage application sites
- **Complex:** On Skull Hit (per-hit loop), On Turn Start (new call in combat phase transitions), Stat Modifier (changes how stats are read everywhere)

The first implementation uses **On Roll** as the universal trigger. Future passives can add trigger points as needed — each new trigger type is one new call site in the game loop.

---

## Current Passives (v1)

| Character | Passive | Trigger | Effect |
|-----------|---------|---------|--------|
| Warrior | Tenacity | On Roll (miss) | Heal 1 HP on miss |
| Healer | Empathy | On Ally Damaged | +1 resolve when any ally takes damage |
| Goblin | Scavenger | On Roll (miss) | 2 flat damage to target on miss (ignores DEF) |
| Shaman | Curse Weaver | On Roll | 1 damage per active condition on target (ignores DEF) |

### Design Notes

- **Tenacity** gives the Warrior chip sustain on missed rolls — mirrors Scavenger's chip damage with chip healing. Keeps him alive longer through sheer stubbornness. Simple, no stat modification needed.
- **Empathy** charges Healer's resolve (Mass Heal) faster when the team is under pressure. Creates a comeback dynamic: more damage taken = faster party-wide heal. Requires the On Ally Damaged trigger hook.
- **Scavenger** turns Goblin's dead turns into chip damage. Fireball needs matches; Scavenger ensures even total misses contribute. Thematically: goblins find value in garbage.
- **Curse Weaver** rewards condition stacking. Hex + Shield break + any future conditions all amplify Shaman's output. Creates cross-character synergy — any teammate that applies conditions helps Shaman.

### Passives vs Conditions — Design Rule

**Passives must NOT create per-ability Condition_Kinds.** Conditions are shared, reusable game mechanics (Shield, Hex, future Poison/Burn/Freeze) that multiple abilities can apply. If a passive needs to modify a stat, it should either:

1. **Do it directly** — modify HP, resolve, or deal damage inline (Tenacity heals 1 HP, Scavenger deals 2 dmg)
2. **Apply a shared condition** — a passive that applies Shield or Hex is fine, since those are reusable effects
3. **Use a stat modifier field** — for permanent accumulating effects like Battle Rage (+1 ATK per skull, rest of combat), add a `bonus_attack: int` field to Character rather than a condition

The wrong approach: creating `Iron_Skin`, `Battle_Rage_Buff`, `Aura_Of_Might` as separate Condition_Kinds. That leads to condition bloat where each ability has its own condition that nothing else interacts with.

## Alternative Passives (Future)

| Character | Passive | Trigger | Effect |
|-----------|---------|---------|--------|
| Warrior | Iron Skin | On Roll | +1 DEF after rolling — needs stat modifier field, not a condition |
| Warrior | Battle Rage | On Roll | +1 ATK per skull in roll (permanent, rest of combat) — needs `bonus_attack` field |
| Healer | Triage | On Roll | Heal lowest-HP ally for 2 (flat, always fires) |
| Goblin | Pyromaniac | On Ability Fire | When Fireball fires, apply 1-turn Burn to target |
| Shaman | Spirit Link | On Roll (miss) | If unmatched >= 2, apply random debuff to target |
| Any | Thorns | On Damage Taken | Reflect 1 damage per hit back to attacker |
| Any | Last Stand | On Death | Deal ATK damage to all enemies on death |
| Any | Aura of Might | On Ally Roll | Allies get +1 to matched_value when this character is alive |
