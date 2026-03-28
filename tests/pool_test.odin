package tests

import "core:testing"
import "core:math/rand"
import game "../src"

// --- Pool Generation ---

@(test)
pool_generate_correct_count :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	pool := game.pool_generate(&rs)
	testing.expect_value(t, pool.count, game.DEFAULT_POOL_SIZE)
	testing.expect_value(t, pool.remaining, game.DEFAULT_POOL_SIZE)
}

@(test)
pool_generate_custom_size :: proc(t: ^testing.T) {
	rs := game.round_state_init(pool_size = 8)
	pool := game.pool_generate(&rs)
	testing.expect_value(t, pool.count, 8)
	testing.expect_value(t, pool.remaining, 8)
}

@(test)
pool_generate_all_dice_are_valid :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	pool := game.pool_generate(&rs)
	for i in 0 ..< pool.count {
		testing.expect(t, pool.dice[i] != .None, "pool die should not be None")
	}
}

// --- Pool Operations ---

@(test)
pool_remove_shifts_remaining :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	pool := game.pool_generate(&rs)
	second_die := pool.dice[1]

	die_type, ok := game.pool_remove_die(&pool, 0)
	testing.expect(t, ok, "should remove die at index 0")
	testing.expect(t, die_type != .None, "removed die should not be None")
	testing.expect_value(t, pool.remaining, game.DEFAULT_POOL_SIZE - 1)
	// Second die should have shifted to index 0
	testing.expect_value(t, pool.dice[0], second_die)
}

@(test)
pool_remove_clears_vacated_slot :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	pool := game.pool_generate(&rs)

	game.pool_remove_die(&pool, 0)
	// The slot beyond remaining should be zeroed
	testing.expect_value(t, pool.dice[pool.remaining], game.Die_Type.None)
}

@(test)
pool_remove_invalid_index :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	pool := game.pool_generate(&rs)

	_, ok_neg := game.pool_remove_die(&pool, -1)
	testing.expect(t, !ok_neg, "should fail on negative index")

	_, ok_over := game.pool_remove_die(&pool, pool.remaining)
	testing.expect(t, !ok_over, "should fail on out-of-bounds index")
}

@(test)
pool_is_empty_after_full_draft :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	pool := game.pool_generate(&rs)

	for i := pool.remaining; i > 0; i -= 1 {
		game.pool_remove_die(&pool, 0)
	}
	testing.expect(t, game.pool_is_empty(&pool), "pool should be empty after removing all dice")
	testing.expect_value(t, pool.remaining, 0)
}

// --- Weight Group Distribution (statistical) ---

@(test)
pool_low_group_is_mostly_small_dice :: proc(t: ^testing.T) {
	rand.reset(12345)
	d4_count, d6_count, big_count := 0, 0, 0
	N :: 500

	for _ in 0 ..< N {
		dt := game.weight_group_die_type(.Low, 0) // no skulls
		#partial switch dt {
		case .D4:  d4_count += 1
		case .D6:  d6_count += 1
		case .D10, .D12: big_count += 1
		}
	}

	testing.expect(t, d4_count + d6_count > N / 2, "Low group should be mostly d4/d6")
	testing.expect_value(t, big_count, 0) // Low group weights d10/d12 at 0
}

@(test)
pool_high_group_is_mostly_big_dice :: proc(t: ^testing.T) {
	rand.reset(12345)
	d10_count, d12_count, small_count := 0, 0, 0
	N :: 500

	for _ in 0 ..< N {
		dt := game.weight_group_die_type(.High, 0)
		#partial switch dt {
		case .D10: d10_count += 1
		case .D12: d12_count += 1
		case .D4:  small_count += 1
		}
	}

	testing.expect(t, d10_count + d12_count > N / 2, "High group should be mostly d10/d12")
	testing.expect_value(t, small_count, 0) // High group weights d4 at 0
}

@(test)
pool_mid_groups_include_d8 :: proc(t: ^testing.T) {
	rand.reset(12345)
	d8_mid_low, d8_mid_high := 0, 0
	N :: 500

	for _ in 0 ..< N {
		dt := game.weight_group_die_type(.Mid_Low, 0)
		if dt == .D8 { d8_mid_low += 1 }
	}
	for _ in 0 ..< N {
		dt := game.weight_group_die_type(.Mid_High, 0)
		if dt == .D8 { d8_mid_high += 1 }
	}

	testing.expect(t, d8_mid_low > 0, "Mid_Low group should produce some d8s")
	testing.expect(t, d8_mid_high > 0, "Mid_High group should produce some d8s")
}

@(test)
pool_all_die_types_appear_across_groups :: proc(t: ^testing.T) {
	rand.reset(12345)
	seen: [game.Die_Type]bool
	N :: 200

	groups := [4]game.Weight_Group{.Low, .Mid_Low, .Mid_High, .High}
	for group in groups {
		for _ in 0 ..< N {
			dt := game.weight_group_die_type(group, 0)
			seen[dt] = true
		}
	}

	testing.expect(t, seen[.D4], "d4 should appear across all groups")
	testing.expect(t, seen[.D6], "d6 should appear across all groups")
	testing.expect(t, seen[.D8], "d8 should appear across all groups")
	testing.expect(t, seen[.D10], "d10 should appear across all groups")
	testing.expect(t, seen[.D12], "d12 should appear across all groups")
}

@(test)
pool_skull_dice_appear_at_configured_rate :: proc(t: ^testing.T) {
	rand.reset(12345)
	skull_count := 0
	N :: 1000

	for _ in 0 ..< N {
		dt := game.weight_group_die_type(.Low, 50) // 50% skull chance
		if dt == .Skull { skull_count += 1 }
	}

	// With 50% skull chance, expect roughly 500 skulls. Allow wide margin.
	testing.expect(t, skull_count > 300, "50% skull chance should produce many skulls")
	testing.expect(t, skull_count < 700, "50% skull chance should not produce all skulls")
}

@(test)
pool_no_skulls_when_zero_chance :: proc(t: ^testing.T) {
	rand.reset(12345)
	N :: 200

	for _ in 0 ..< N {
		dt := game.weight_group_die_type(.Low, 0)
		testing.expect(t, dt != .Skull, "0% skull chance should produce no skulls")
	}
}

// --- Weight Group Cycling ---

@(test)
weight_group_cycle_visits_all_four :: proc(t: ^testing.T) {
	rand.reset(12345)
	rs := game.round_state_init()

	seen: [game.WEIGHT_GROUP_COUNT]bool
	for _ in 0 ..< game.WEIGHT_GROUP_COUNT {
		group := rs.group_order[rs.cycle_index]
		seen[int(group)] = true
		game.round_state_advance(&rs)
	}

	for i in 0 ..< game.WEIGHT_GROUP_COUNT {
		testing.expectf(t, seen[i], "weight group %d should appear in first cycle", i)
	}
}

@(test)
weight_group_non_repeating_within_cycle :: proc(t: ^testing.T) {
	rand.reset(12345)
	rs := game.round_state_init()

	for i in 0 ..< game.WEIGHT_GROUP_COUNT {
		for j in i + 1 ..< game.WEIGHT_GROUP_COUNT {
			testing.expect(t, rs.group_order[i] != rs.group_order[j],
				"no group should appear twice in one cycle")
		}
	}
}

// --- Round State ---

@(test)
first_pick_alternates :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	testing.expect(t, rs.first_pick, "player should pick first in round 1")

	game.round_state_advance(&rs)
	testing.expect(t, !rs.first_pick, "enemy should pick first in round 2")

	game.round_state_advance(&rs)
	testing.expect(t, rs.first_pick, "player should pick first in round 3")
}

@(test)
round_number_increments :: proc(t: ^testing.T) {
	rs := game.round_state_init()
	testing.expect_value(t, rs.round_number, 1)

	game.round_state_advance(&rs)
	testing.expect_value(t, rs.round_number, 2)

	game.round_state_advance(&rs)
	testing.expect_value(t, rs.round_number, 3)
}
