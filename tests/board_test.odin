package tests

import "core:testing"
import game "../src"

// --- Ring calculation ---

@(test)
ring_corners_are_zero :: proc(t: ^testing.T) {
	board := game.Board{size = 5}
	// All four corners of any grid should be ring 0 (outermost)
	testing.expect_value(t, game.cell_ring(&board, 0, 0), 0)
	testing.expect_value(t, game.cell_ring(&board, 0, 4), 0)
	testing.expect_value(t, game.cell_ring(&board, 4, 0), 0)
	testing.expect_value(t, game.cell_ring(&board, 4, 4), 0)
}

@(test)
ring_centre_is_max :: proc(t: ^testing.T) {
	board5 := game.Board{size = 5}
	board7 := game.Board{size = 7}
	// Centre of 5x5 is ring 2
	testing.expect_value(t, game.cell_ring(&board5, 2, 2), 2)
	// Centre of 7x7 is ring 3
	testing.expect_value(t, game.cell_ring(&board7, 3, 3), 3)
}

@(test)
ring_edges_are_zero :: proc(t: ^testing.T) {
	board := game.Board{size = 5}
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
	board := game.Board{size = 5}
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
		testing.expect(t, game.cell_is_perimeter(&board, 0, i), "top row should be perimeter")
		testing.expect(t, game.cell_is_perimeter(&board, game.BOARD_SIZE - 1, i), "bottom row should be perimeter")
		testing.expect(t, game.cell_is_perimeter(&board, i, 0), "left col should be perimeter")
		testing.expect(t, game.cell_is_perimeter(&board, i, game.BOARD_SIZE - 1), "right col should be perimeter")
	}

	// Centre should NOT be perimeter on a full board
	testing.expect(t, !game.cell_is_perimeter(&board, 2, 2), "centre should not be perimeter on full board")
}

@(test)
inner_cell_exposed_after_removal :: proc(t: ^testing.T) {
	board := game.board_init()

	// (1,1) is ring 1, not perimeter on full board
	testing.expect(t, !game.cell_is_perimeter(&board, 1, 1), "(1,1) should not be perimeter initially")

	// Remove its outer neighbour at (0,1)
	game.board_remove(&board, 0, 1)

	// Now (1,1) should be perimeter because (0,1) is empty
	testing.expect(t, game.cell_is_perimeter(&board, 1, 1), "(1,1) should be perimeter after removing (0,1)")
}

@(test)
cannot_remove_non_perimeter :: proc(t: ^testing.T) {
	board := game.board_init()

	// Centre cell is not perimeter, removal should fail
	_, ok := game.board_remove(&board, 2, 2)
	testing.expect(t, !ok, "should not be able to remove non-perimeter cell")
	testing.expect(t, board.cells[2][2].occupied, "centre cell should still be occupied")
}

@(test)
remove_returns_die_type :: proc(t: ^testing.T) {
	board := game.board_init()

	expected_type := board.cells[0][0].die_type
	got_type, ok := game.board_remove(&board, 0, 0)

	testing.expect(t, ok, "corner removal should succeed")
	testing.expect_value(t, got_type, expected_type)
	testing.expect(t, !board.cells[0][0].occupied, "cell should be empty after removal")
}

@(test)
board_count_decreases_on_removal :: proc(t: ^testing.T) {
	board := game.board_init()

	initial := game.board_count(&board)
	testing.expect_value(t, initial, game.BOARD_SIZE * game.BOARD_SIZE)

	game.board_remove(&board, 0, 0)
	testing.expect_value(t, game.board_count(&board), initial - 1)
}

// --- Rarity gradient ---

@(test)
board_gradient_outer_ring_has_small_dice :: proc(t: ^testing.T) {
	board := game.board_init()

	// Every outer ring cell should be d4, d6, or Skull
	for i in 0 ..< game.BOARD_SIZE {
		check_outer_die :: proc(t: ^testing.T, dt: game.Die_Type, label: string) {
			testing.expectf(t, dt == .D4 || dt == .D6 || dt == .Skull, "%s: expected d4, d6, or Skull, got %v", label, dt)
		}
		check_outer_die(t, board.cells[0][i].die_type, "top row")
		check_outer_die(t, board.cells[game.BOARD_SIZE - 1][i].die_type, "bottom row")
		if i > 0 && i < game.BOARD_SIZE - 1 {
			check_outer_die(t, board.cells[i][0].die_type, "left col")
			check_outer_die(t, board.cells[i][game.BOARD_SIZE - 1].die_type, "right col")
		}
	}
}

@(test)
board_gradient_centre_is_d12_or_skull :: proc(t: ^testing.T) {
	board := game.board_init()
	centre := board.cells[2][2].die_type
	testing.expectf(t, centre == .D12 || centre == .Skull, "centre should be D12 or Skull, got %v", centre)
}
