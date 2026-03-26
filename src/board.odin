package game

import "core:math/rand"
import rl "vendor:raylib"

// Calculate which ring a cell belongs to (0 = outermost)
cell_ring :: proc(board: ^Board, row, col: int) -> int {
	return min(row, col, board.size - 1 - row, board.size - 1 - col)
}

// Determine die type for a non-centre ring based on rarity gradient.
// Any cell has a SKULL_CHANCE% probability of being a skull die instead.
// Centre ring is forced d12 in board_init; this proc handles rings 0 to max_ring-1.
//
// The gradient uses a weighted random roll per tile. Each ring gets a
// probability weight per die type based on how deep it is (0.0 = outer,
// 1.0 = just before centre). Deeper rings shift weight toward bigger dice.
ring_die_type :: proc(ring, max_ring: int) -> Die_Type {
	// Skull dice can appear in any ring
	if rand.int_max(100) < SKULL_CHANCE {
		return .Skull
	}

	// Depth ratio: 0.0 at outer ring, approaches 1.0 at the ring before centre.
	last_ring := max(max_ring - 1, 1)
	depth := f32(ring) / f32(last_ring)

	// Weighted distribution that shifts smoothly from small to big dice.
	// At depth 0.0: mostly d4/d6
	// At depth 0.5: mostly d8, some d6/d10
	// At depth 1.0: mostly d10/d12, some d8
	w_d4  := max(1.0 - depth * 2.5, 0.0)             // 1.0 → 0.0 by depth 0.4
	w_d6  := max(1.0 - depth * 1.5, 0.0)              // 1.0 → 0.0 by depth 0.67
	w_d8  := max(1.0 - abs(depth - 0.5) * 1.5, 0.0)  // peaks at 0.5, nonzero across full range
	w_d10 := max(depth * 1.5 - 0.5, 0.0)              // 0.0 → 1.0 from depth 0.33
	w_d12 := max(depth * 2.0 - 1.0, 0.0)              // 0.0 → 1.0 from depth 0.5

	total := w_d4 + w_d6 + w_d8 + w_d10 + w_d12
	roll := rand.float32() * total

	roll -= w_d4;  if roll < 0 { return .D4 }
	roll -= w_d6;  if roll < 0 { return .D6 }
	roll -= w_d8;  if roll < 0 { return .D8 }
	roll -= w_d10; if roll < 0 { return .D10 }
	return .D12
}

// Initialize board with dice placed by rarity gradient
board_init :: proc() -> Board {
	board:= Board{ size = BOARD_SIZE }
	max_ring := (board.size - 1) / 2

	for row in 0 ..< board.size {
		for col in 0 ..< board.size {
			ring := cell_ring(&board, row, col)
			die_type: Die_Type
			if ring == max_ring {
				die_type = .D12  // centre tile is always d12
			} else {
				die_type = ring_die_type(ring, max_ring)
			}
			board.cells[row][col] = Board_Cell{
				die_type = die_type,
				occupied = true,
				ring     = ring,
			}
		}
	}

	return board
}

// Check if a cell is on the current perimeter (pickable).
// A cell is pickable if it's occupied and has at least one
// neighbour that is empty or out of bounds.
cell_is_pickable :: proc(board: ^Board, row, col: int) -> bool {
	if !board.cells[row][col].occupied {
		return false
	}

	neighbours := [4][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
	for offset in neighbours {
		nr := row + offset[0]
		nc := col + offset[1]
		if nr < 0 || nr >= board.size || nc < 0 || nc >= board.size {
			return true // edge of grid
		}
		if !board.cells[nr][nc].occupied {
			return true // adjacent empty cell
		}
	}

	return false
}

// Remove a die from the board. Returns the die type that was there.
board_remove_die :: proc(board: ^Board, row, col: int) -> (Die_Type, bool) {
	if !board.cells[row][col].occupied {
		return .None, false
	}
	if !cell_is_pickable(board, row, col) {
		return .None, false
	}

	die_type := board.cells[row][col].die_type
	board.cells[row][col].occupied = false
	return die_type, true
}

// Count remaining dice on the board
board_count_dice :: proc(board: ^Board) -> int {
	count := 0
	for row in 0 ..< board.size {
		for col in 0 ..< board.size {
			if board.cells[row][col].occupied {
				count += 1
			}
		}
	}
	return count
}

// Check if any pickable dice remain on the board
board_has_pickable :: proc(board: ^Board) -> bool {
	for row in 0 ..< board.size {
		for col in 0 ..< board.size {
			if cell_is_pickable(board, row, col) {
				return true
			}
		}
	}
	return false
}

// Get the top-left pixel position of the board (centred on screen)
board_origin :: proc(board: ^Board) -> (i32, i32) {
	board_px := i32(board.size * CELL_STRIDE - CELL_GAP)
	x := (WINDOW_WIDTH - board_px) / 2
	y := (WINDOW_HEIGHT - board_px) / 2
	return x, y
}

// Convert a grid position to pixel position
cell_position :: proc(board: ^Board, row, col: int) -> (i32, i32) {
	ox, oy := board_origin(board)
	x := ox + i32(col * CELL_STRIDE)
	y := oy + i32(row * CELL_STRIDE)
	return x, y
}

// Convert mouse position to grid row/col. Returns (-1,-1) if outside the board.
mouse_to_cell :: proc(board: ^Board, mouse_x, mouse_y: i32) -> (int, int) {
	ox, oy := board_origin(board)
	rel_x := mouse_x - ox
	rel_y := mouse_y - oy

	if rel_x < 0 || rel_y < 0 {
		return -1, -1
	}

	col := int(rel_x) / CELL_STRIDE
	row := int(rel_y) / CELL_STRIDE

	if row >= board.size || col >= board.size {
		return -1, -1
	}

	// Check we're inside the cell, not in the gap
	cell_local_x := int(rel_x) % CELL_STRIDE
	cell_local_y := int(rel_y) % CELL_STRIDE
	if cell_local_x >= CELL_SIZE || cell_local_y >= CELL_SIZE {
		return -1, -1
	}

	return row, col
}

// Draw the board
board_draw :: proc(board: ^Board, drag: ^Drag_State) {
	mouse_x := rl.GetMouseX()
	mouse_y := rl.GetMouseY()
	hover_row, hover_col := mouse_to_cell(board, mouse_x, mouse_y)

	for row in 0 ..< board.size {
		for col in 0 ..< board.size {
			cell := &board.cells[row][col]
			if !cell.occupied {
				continue
			}

			x, y := cell_position(board, row, col)
			is_perimeter := cell_is_pickable(board, row, col)
			is_dragged := drag.active && drag.source == .Board && drag.board_row == row && drag.board_col == col

			// Ghost the cell being dragged
			if is_dragged {
				rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.Color{60, 60, 70, 120})
				rl.DrawRectangleLines(x, y, CELL_SIZE, CELL_SIZE, rl.Color{255, 255, 255, 40})
				continue
			}

			is_hovered := row == hover_row && col == hover_col && is_perimeter && !drag.active

			// Cell background
			color: rl.Color
			if is_perimeter {
				color = DIE_TYPE_COLORS[cell.die_type]
			} else {
				color = DIE_TYPE_COLORS_DIM[cell.die_type]
			}

			rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, color)

			// Hover highlight (only when not dragging)
			if is_hovered {
				rl.DrawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.Color{255, 255, 255, 50})
				rl.DrawRectangleLines(x, y, CELL_SIZE, CELL_SIZE, rl.WHITE)
			} else if is_perimeter {
				rl.DrawRectangleLines(x, y, CELL_SIZE, CELL_SIZE, rl.Color{255, 255, 255, 80})
			}

			// Die type label
			label := DIE_TYPE_NAMES[cell.die_type]
			text_w := rl.MeasureText(label, 16)
			rl.DrawText(label, x + (CELL_SIZE - text_w) / 2, y + (CELL_SIZE - 16) / 2, 16, rl.WHITE)
		}
	}
}
