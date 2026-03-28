package game

// Apply a condition to a character. Returns false if the condition array is full.
// interval=0 means passive/reactive (no periodic trigger). interval>0 means the
// periodic effect fires every `interval` ticks of the owner's turn.
condition_apply :: proc(ch: ^Character, kind: Condition_Kind, value: int, expiry: Condition_Expiry, remaining: int, interval: int = 0) -> bool {
	if ch.condition_count >= MAX_CONDITIONS {
		return false
	}
	ch.conditions[ch.condition_count] = Condition{
		kind      = kind,
		value     = value,
		expiry    = expiry,
		remaining = remaining,
		interval  = interval,
		timer     = 0,
	}
	ch.condition_count += 1
	return true
}

// Remove a condition by index, shifting the rest down.
condition_remove :: proc(ch: ^Character, index: int) {
	if index < 0 || index >= ch.condition_count {
		return
	}
	for i in index ..< ch.condition_count - 1 {
		ch.conditions[i] = ch.conditions[i + 1]
	}
	ch.condition_count -= 1
	ch.conditions[ch.condition_count] = {}
}

// Tick turn-based conditions. Called once at the start of a side's turn for all
// characters on that side. Each side's conditions tick on THAT side's turn only —
// a 3-turn debuff on an enemy lasts 3 enemy turns, not 3 game turns.
//
// For each condition:
// 1. If interval > 0, advance the periodic timer. Fire the periodic effect when timer reaches interval.
// 2. If expiry == .Turns, decrement remaining. Remove at 0.
condition_tick_turns :: proc(ch: ^Character) {
	i := 0
	for i < ch.condition_count {
		cond := &ch.conditions[i]

		// Periodic effect: advance timer, fire when it reaches interval
		if cond.interval > 0 {
			cond.timer += 1
			if cond.timer >= cond.interval {
				cond.timer = 0
				condition_fire_periodic(ch, cond)
			}
		}

		// Duration countdown
		if cond.expiry == .Turns {
			cond.remaining -= 1
			if cond.remaining <= 0 {
				condition_remove(ch, i)
				continue // don't increment — next condition shifted into this slot
			}
		}
		i += 1
	}
}

// Fire a periodic condition's effect. Dispatches on kind.
// Currently no periodic conditions exist — this is the hook point for future
// conditions like Poison (deal damage) or Regen (heal).
condition_fire_periodic :: proc(ch: ^Character, cond: ^Condition) {
	#partial switch cond.kind {
	// Future periodic conditions go here:
	// case .Poison: ch.stats.hp = max(ch.stats.hp - cond.value, 0)
	// case .Regen:  ch.stats.hp += cond.value
	case:
		// No-op for passive/reactive conditions that shouldn't have interval > 0
	}
}

// Check if a Shield condition absorbs damage. Returns the amount of damage actually
// absorbed (may be less than incoming if shield breaks). The caller should subtract
// the absorbed amount from the damage dealt.
// Shield.value holds the remaining absorption pool. When it reaches 0, Shield is removed.
condition_absorb_damage :: proc(ch: ^Character, incoming: int) -> int {
	for i in 0 ..< ch.condition_count {
		if ch.conditions[i].kind == .Shield {
			absorbed := min(incoming, ch.conditions[i].value)
			ch.conditions[i].value -= absorbed
			if ch.conditions[i].value <= 0 {
				condition_remove(ch, i)
			}
			return absorbed
		}
	}
	return 0
}

// Compute effective defense: base DEF minus all Hex reductions, clamped to 0.
character_effective_defense :: proc(ch: ^Character) -> int {
	def := ch.stats.defense
	for i in 0 ..< ch.condition_count {
		if ch.conditions[i].kind == .Hex {
			def -= ch.conditions[i].value
		}
	}
	return max(def, 0)
}

// Check if a character has a specific condition kind active.
condition_has :: proc(ch: ^Character, kind: Condition_Kind) -> bool {
	for i in 0 ..< ch.condition_count {
		if ch.conditions[i].kind == kind {
			return true
		}
	}
	return false
}
