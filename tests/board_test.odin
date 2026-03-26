package tests

import game "../src"
import "core:testing"

// --- Ring calculation ---

@(test)
ring_corners_are_zero :: proc(t: ^testing.T) {
	board := game.Board {
		size = 5,
	}
	// All four corners of any grid should be ring 0 (outermost)
	testing.expect_value(t, game.cell_ring(&board, 0, 0), 0)
	testing.expect_value(t, game.cell_ring(&board, 0, 4), 0)
	testing.expect_value(t, game.cell_ring(&board, 4, 0), 0)
	testing.expect_value(t, game.cell_ring(&board, 4, 4), 0)
}

@(test)
ring_centre_is_max :: proc(t: ^testing.T) {
	board5 := game.Board {
		size = 5,
	}
	board7 := game.Board {
		size = 7,
	}
	// Centre of 5x5 is ring 2
	testing.expect_value(t, game.cell_ring(&board5, 2, 2), 2)
	// Centre of 7x7 is ring 3
	testing.expect_value(t, game.cell_ring(&board7, 3, 3), 3)
}

@(test)
ring_edges_are_zero :: proc(t: ^testing.T) {
	board := game.Board {
		size = 5,
	}
	// All cells on the edge of the grid should be ring 0
	for i in 0 ..< 5 {
		testing.expect_value(t, game.cell_ring(&board, 0, i), 0) // top row
		testing.expect_value(t, game.cell_ring(&board, 4, i), 0) // bottom row
		testing.expect_value(t, game.cell_ring(&board, i, 0), 0) // left col
		testing.expect_value(t, game.cell_ring(&board, i, 4), 0) // right col
	}
}

@(test)
ring_middle_layer :: proc(t: ^testing.T) {
	board := game.Board {
		size = 5,
	}
	// Inner ring of 5x5 should be ring 1
	testing.expect_value(t, game.cell_ring(&board, 1, 1), 1)
	testing.expect_value(t, game.cell_ring(&board, 1, 3), 1)
	testing.expect_value(t, game.cell_ring(&board, 3, 1), 1)
	testing.expect_value(t, game.cell_ring(&board, 3, 3), 1)
}

// --- Perimeter detection ---

@(test)
full_board_perimeter_is_outer_ring :: proc(t: ^testing.T) {
	board := game.board_init()

	// All outer ring cells should be perimeter
	for i in 0 ..< game.BOARD_SIZE {
		testing.expect(t, game.cell_is_pickable(&board, 0, i), "top row should be perimeter")
		testing.expect(
			t,
			game.cell_is_pickable(&board, game.BOARD_SIZE - 1, i),
			"bottom row should be perimeter",
		)
		testing.expect(t, game.cell_is_pickable(&board, i, 0), "left col should be perimeter")
		testing.expect(
			t,
			game.cell_is_pickable(&board, i, game.BOARD_SIZE - 1),
			"right col should be perimeter",
		)
	}

	// Centre should NOT be perimeter on a full board
	centre := game.BOARD_SIZE / 2
	testing.expect(
		t,
		!game.cell_is_pickable(&board, centre, centre),
		"centre should not be perimeter on full board",
	)
}

@(test)
inner_cell_exposed_after_removal :: proc(t: ^testing.T) {
	board := game.board_init()

	// (1,1) is ring 1, not perimeter on full board
	testing.expect(
		t,
		!game.cell_is_pickable(&board, 1, 1),
		"(1,1) should not be perimeter initially",
	)

	// Remove its outer neighbour at (0,1)
	game.board_remove_die(&board, 0, 1)

	// Now (1,1) should be perimeter because (0,1) is empty
	testing.expect(
		t,
		game.cell_is_pickable(&board, 1, 1),
		"(1,1) should be perimeter after removing (0,1)",
	)
}

@(test)
cannot_remove_non_perimeter :: proc(t: ^testing.T) {
	board := game.board_init()

	// Centre cell is not perimeter, removal should fail
	centre := game.BOARD_SIZE / 2
	_, ok := game.board_remove_die(&board, centre, centre)
	testing.expect(t, !ok, "should not be able to remove non-perimeter cell")
	testing.expect(t, board.cells[centre][centre].occupied, "centre cell should still be occupied")
}

@(test)
remove_returns_die_type :: proc(t: ^testing.T) {
	board := game.board_init()

	expected_type := board.cells[0][0].die_type
	got_type, ok := game.board_remove_die(&board, 0, 0)

	testing.expect(t, ok, "corner removal should succeed")
	testing.expect_value(t, got_type, expected_type)
	testing.expect(t, !board.cells[0][0].occupied, "cell should be empty after removal")
}

@(test)
board_count_decreases_on_removal :: proc(t: ^testing.T) {
	board := game.board_init()

	initial := game.board_count_dice(&board)
	testing.expect_value(t, initial, game.BOARD_SIZE * game.BOARD_SIZE)

	game.board_remove_die(&board, 0, 0)
	testing.expect_value(t, game.board_count_dice(&board), initial - 1)
}

// --- Gradient plausibility (statistical, over many boards) ---
//
// The gradient uses continuous weights per ring depth. These tests verify
// the statistical properties over many board generations to ensure the
// weight curves produce a sensible distribution for the compiled BOARD_SIZE.

SAMPLE_BOARDS :: 100 // boards to generate per statistical test

// Helper: count occurrences of a die type in a specific ring across a board.
count_die_type_in_ring :: proc(board: ^game.Board, ring: int, target: game.Die_Type) -> int {
	count := 0
	for row in 0 ..< board.size {
		for col in 0 ..< board.size {
			if game.cell_ring(board, row, col) == ring &&
			   board.cells[row][col].die_type == target {
				count += 1
			}
		}
	}
	return count
}

// Helper: count all non-skull dice of a given type in a ring across many boards.
Die_Counts :: struct {
	d4, d6, d8, d10, d12, skull, total: int,
}

// --- Rarity gradient ---

@(test)
board_gradient_outer_ring_has_no_d10_d12 :: proc(t: ^testing.T) {
	// At depth 0.0 the weights for d10 and d12 are zero.
	// d8 can appear with small weight, but d10/d12 should not.
	for _ in 0 ..< SAMPLE_BOARDS {
		board := game.board_init()
		d10_count := count_die_type_in_ring(&board, 0, .D10)
		d12_count := count_die_type_in_ring(&board, 0, .D12)
		testing.expectf(
			t,
			d10_count == 0 && d12_count == 0,
			"outer ring should have no d10/d12, got d10=%d d12=%d",
			d10_count,
			d12_count,
		)
	}
}

@(test)
board_gradient_centre_is_always_d12 :: proc(t: ^testing.T) {
	board := game.board_init()
	c := game.BOARD_SIZE / 2
	centre := board.cells[c][c].die_type
	testing.expectf(t, centre == .D12, "centre should always be D12, got %v", centre)
}

count_ring_distribution :: proc(ring: int) -> Die_Counts {
	counts: Die_Counts
	for _ in 0 ..< SAMPLE_BOARDS {
		board := game.board_init()
		for row in 0 ..< board.size {
			for col in 0 ..< board.size {
				if game.cell_ring(&board, row, col) != ring {
					continue
				}
				counts.total += 1
				#partial switch board.cells[row][col].die_type {
				case .D4:
					counts.d4 += 1
				case .D6:
					counts.d6 += 1
				case .D8:
					counts.d8 += 1
				case .D10:
					counts.d10 += 1
				case .D12:
					counts.d12 += 1
				case .Skull:
					counts.skull += 1
				}
			}
		}
	}
	return counts
}

@(test)
gradient_outer_ring_is_mostly_small_dice :: proc(t: ^testing.T) {
	// At depth 0.0: d4 and d6 dominate, d8 has small weight, d10/d12 are zero.
	c := count_ring_distribution(0)
	testing.expectf(
		t,
		c.d10 == 0 && c.d12 == 0,
		"outer ring should have no d10/d12, got d10=%d d12=%d",
		c.d10,
		c.d12,
	)
	testing.expect(t, c.d4 > 0, "outer ring should have d4")
	testing.expect(t, c.d6 > 0, "outer ring should have d6")
	// d8 may appear but should be a small minority of non-skull dice
	non_skull := c.total - c.skull
	if non_skull > 0 {
		d8_ratio := f32(c.d8) / f32(non_skull)
		testing.expectf(
			t,
			d8_ratio < 0.25,
			"outer ring d8 should be <25%% of non-skull dice, got %.1f%%",
			d8_ratio * 100,
		)
	}
}

@(test)
gradient_inner_ring_has_d10_and_d12 :: proc(t: ^testing.T) {
	// The innermost non-centre ring (depth=1.0) has high weights for d10 and d12.
	// d8 weight is zero at depth 1.0 (it peaks at mid-depth), so we don't expect it here.
	max_ring := (game.BOARD_SIZE - 1) / 2
	inner_ring := max_ring - 1
	c := count_ring_distribution(inner_ring)

	testing.expectf(
		t,
		c.d10 > 0,
		"inner ring should have d10 (got 0 across %d boards)",
		SAMPLE_BOARDS,
	)
	testing.expectf(
		t,
		c.d12 > 0,
		"inner ring should have d12 (got 0 across %d boards)",
		SAMPLE_BOARDS,
	)
}

@(test)
gradient_inner_ring_has_no_d4 :: proc(t: ^testing.T) {
	// At depth 1.0 the weights for d4 and d6 are zero.
	max_ring := (game.BOARD_SIZE - 1) / 2
	inner_ring := max_ring - 1
	c := count_ring_distribution(inner_ring)

	testing.expectf(t, c.d4 == 0, "inner ring should have no d4, got %d", c.d4)
	testing.expectf(t, c.d6 == 0, "inner ring should have no d6, got %d", c.d6)
}

@(test)
gradient_d8_peaks_at_middle_depth :: proc(t: ^testing.T) {
	// d8 weight peaks at depth 0.5 and is zero at both extremes (0.0 and 1.0).
	// For boards with 3+ non-centre rings (7x7+), the middle ring should have d8.
	// For 5x5 (only 2 non-centre rings at depth 0.0 and 1.0), d8 can only appear
	// via the board-wide all-types test — there's no ring at depth 0.5.
	max_ring := (game.BOARD_SIZE - 1) / 2
	if max_ring < 3 {
		// Not enough rings to have a mid-depth ring — skip
		return
	}

	mid_ring := max_ring / 2
	c := count_ring_distribution(mid_ring)
	testing.expectf(
		t,
		c.d8 > 0,
		"middle ring (ring %d) should have d8 (got 0 across %d boards)",
		mid_ring,
		SAMPLE_BOARDS,
	)
}

@(test)
gradient_monotonic_high_tier_increases_with_depth :: proc(t: ^testing.T) {
	// For each adjacent pair of rings, the proportion of d8+ dice should
	// increase (or stay equal) as ring depth increases.
	max_ring := (game.BOARD_SIZE - 1) / 2

	prev_ratio: f32 = -1.0
	for ring in 0 ..< max_ring { 	// exclude centre (forced d12)
		c := count_ring_distribution(ring)
		non_skull := c.total - c.skull
		high_tier := c.d8 + c.d10 + c.d12
		ratio: f32 = 0.0
		if non_skull > 0 {
			ratio = f32(high_tier) / f32(non_skull)
		}

		testing.expectf(
			t,
			ratio >= prev_ratio,
			"ring %d d8+ ratio (%.2f) should be >= previous ring (%.2f)",
			ring,
			ratio,
			prev_ratio,
		)
		prev_ratio = ratio
	}
}

@(test)
gradient_all_five_die_types_appear_on_board :: proc(t: ^testing.T) {
	// Over SAMPLE_BOARDS boards, every normal die type should appear at least once
	// somewhere on the board (across all rings). This validates that the gradient
	// doesn't accidentally zero out an entire die type.
	found_d4, found_d6, found_d8, found_d10, found_d12 := false, false, false, false, false

	for _ in 0 ..< SAMPLE_BOARDS {
		board := game.board_init()
		for row in 0 ..< board.size {
			for col in 0 ..< board.size {
				#partial switch board.cells[row][col].die_type {
				case .D4:
					found_d4 = true
				case .D6:
					found_d6 = true
				case .D8:
					found_d8 = true
				case .D10:
					found_d10 = true
				case .D12:
					found_d12 = true
				}
			}
		}
		if found_d4 && found_d6 && found_d8 && found_d10 && found_d12 {
			break
		}
	}

	testing.expectf(
		t,
		found_d4,
		"d4 should appear on at least one board across %d samples",
		SAMPLE_BOARDS,
	)
	testing.expectf(
		t,
		found_d6,
		"d6 should appear on at least one board across %d samples",
		SAMPLE_BOARDS,
	)
	testing.expectf(
		t,
		found_d8,
		"d8 should appear on at least one board across %d samples",
		SAMPLE_BOARDS,
	)
	testing.expectf(
		t,
		found_d10,
		"d10 should appear on at least one board across %d samples",
		SAMPLE_BOARDS,
	)
	testing.expectf(
		t,
		found_d12,
		"d12 should appear on at least one board across %d samples",
		SAMPLE_BOARDS,
	)
}

@(test)
gradient_skull_dice_appear_in_all_rings :: proc(t: ^testing.T) {
	// Skull dice have a flat SKULL_CHANCE% in every ring. Over SAMPLE_BOARDS
	// boards, each ring should have at least one skull.
	max_ring := (game.BOARD_SIZE - 1) / 2
	for ring in 0 ..< max_ring { 	// exclude centre (forced d12, no skulls)
		c := count_ring_distribution(ring)
		testing.expectf(
			t,
			c.skull > 0,
			"ring %d should have skull dice across %d boards, got 0",
			ring,
			SAMPLE_BOARDS,
		)
	}
}
