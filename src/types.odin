package game

import rl "vendor:raylib"

// Window
WINDOW_WIDTH  :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE  :: "Dicey RPG"
TARGET_FPS    :: 60

// Board
BOARD_SIZE    :: 5   // 5x5 grid
CELL_SIZE     :: 64  // pixels per cell
CELL_GAP      :: 6   // pixels between cells
CELL_STRIDE   :: CELL_SIZE + CELL_GAP  // total step per cell

// Dice
Die_Type :: enum u8 {
	D4,
	D6,
	D8,
	D10,
	D12,
}

DIE_TYPE_NAMES := [Die_Type]cstring{
	.D4  = "d4",
	.D6  = "d6",
	.D8  = "d8",
	.D10 = "d10",
	.D12 = "d12",
}

DIE_TYPE_COLORS := [Die_Type]rl.Color{
	.D4  = rl.Color{80, 140, 220, 255},   // blue
	.D6  = rl.Color{60, 180, 100, 255},   // green
	.D8  = rl.Color{230, 200, 50, 255},   // yellow
	.D10 = rl.Color{230, 140, 40, 255},   // orange
	.D12 = rl.Color{210, 50, 60, 255},    // red
}

DIE_TYPE_COLORS_DIM := [Die_Type]rl.Color{
	.D4  = rl.Color{50, 80, 120, 255},
	.D6  = rl.Color{35, 100, 55, 255},
	.D8  = rl.Color{130, 110, 30, 255},
	.D10 = rl.Color{130, 80, 25, 255},
	.D12 = rl.Color{120, 30, 35, 255},
}

// Board cell
Board_Cell :: struct {
	die_type: Die_Type,
	occupied: bool,
	ring:     int,
}

// Board
Board :: struct {
	cells: [BOARD_SIZE][BOARD_SIZE]Board_Cell,
}
