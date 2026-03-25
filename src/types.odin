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
	None,  // zero value — no die present, used to detect stale data
	D4,
	D6,
	D8,
	D10,
	D12,
}

DIE_TYPE_NAMES := [Die_Type]cstring{
	.None = "??",
	.D4   = "d4",
	.D6   = "d6",
	.D8   = "d8",
	.D10  = "d10",
	.D12  = "d12",
}

DIE_TYPE_COLORS := [Die_Type]rl.Color{
	.None = rl.MAGENTA,                      // highly visible — should never render
	.D4   = rl.Color{80, 140, 220, 255},     // blue
	.D6   = rl.Color{60, 180, 100, 255},     // green
	.D8   = rl.Color{230, 200, 50, 255},     // yellow
	.D10  = rl.Color{230, 140, 40, 255},     // orange
	.D12  = rl.Color{210, 50, 60, 255},      // red
}

DIE_TYPE_COLORS_DIM := [Die_Type]rl.Color{
	.None = rl.MAGENTA,
	.D4   = rl.Color{50, 80, 120, 255},
	.D6   = rl.Color{35, 100, 55, 255},
	.D8   = rl.Color{130, 110, 30, 255},
	.D10  = rl.Color{130, 80, 25, 255},
	.D12  = rl.Color{120, 30, 35, 255},
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

// Hand
MAX_HAND_SIZE :: 5
HAND_SLOT_SIZE :: 56
HAND_SLOT_GAP  :: 8
HAND_Y_OFFSET  :: 80  // pixels from bottom

Hand :: struct {
	dice:  [MAX_HAND_SIZE]Die_Type,
	count: int,
}

// Character
MAX_CHARACTER_DICE :: 6  // legendary max

Character_Rarity :: enum u8 {
	Common,     // 3 dice
	Rare,       // 4 dice
	Epic,       // 5 dice
	Legendary,  // 6 dice
}

RARITY_MAX_DICE := [Character_Rarity]int{
	.Common    = 3,
	.Rare      = 4,
	.Epic      = 5,
	.Legendary = 6,
}

RARITY_NAMES := [Character_Rarity]cstring{
	.Common    = "Common",
	.Rare      = "Rare",
	.Epic      = "Epic",
	.Legendary = "Legendary",
}

MAX_PARTY_SIZE :: 4

Character_State :: enum u8 {
	Empty,   // zero value — no character in this slot
	Alive,
	Dead,
}

Character :: struct {
	state:          Character_State,
	name:           cstring,
	rarity:         Character_Rarity,
	max_dice:       int,
	assigned:       [MAX_CHARACTER_DICE]Die_Type,
	assigned_count: int,
}

// Check if a character slot is active (alive and present)
character_is_active :: proc(character: ^Character) -> bool {
	return character.state == .Alive
}

// UI layout for character panel
CHAR_PANEL_X      :: 30
CHAR_PANEL_Y      :: 100
CHAR_PANEL_WIDTH  :: 160
CHAR_SLOT_SIZE    :: 44
CHAR_SLOT_GAP     :: 6

// Selection state
Selection_Source :: enum {
	None,
	Hand,
	Character,
}

Selection :: struct {
	source: Selection_Source,
	index:  int,             // hand slot index or character die index
}
