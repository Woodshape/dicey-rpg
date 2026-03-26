package game

import rl "vendor:raylib"

// Window
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "Dicey RPG"
TARGET_FPS :: 60

// Board
BOARD_SIZE :: 5 // 5x5 grid
// BOARD_SIZE :: 7 // 7x7 grid
CELL_SIZE :: 64 // pixels per cell
CELL_GAP :: 6 // pixels between cells
CELL_STRIDE :: CELL_SIZE + CELL_GAP // total step per cell

// Dice
Die_Type :: enum u8 {
	None, // zero value — no die present, used to detect stale data
	D4,
	D6,
	D8,
	D10,
	D12,
	Skull, // damage die — exempt from pure type constraint
}

die_type_is_normal :: proc(dt: Die_Type) -> bool {
	#partial switch dt {
	case .D4, .D6, .D8, .D10, .D12:
		return true
	}
	return false
}

DIE_TYPE_NAMES := [Die_Type]cstring {
	.None  = "??",
	.D4    = "d4",
	.D6    = "d6",
	.D8    = "d8",
	.D10   = "d10",
	.D12   = "d12",
	.Skull = "Skl",
}

DIE_TYPE_COLORS := [Die_Type]rl.Color {
	.None  = rl.MAGENTA, // should never render
	.D4    = rl.Color{80, 140, 220, 255}, // blue
	.D6    = rl.Color{60, 180, 100, 255}, // green
	.D8    = rl.Color{230, 200, 50, 255}, // yellow
	.D10   = rl.Color{230, 140, 40, 255}, // orange
	.D12   = rl.Color{210, 50, 60, 255}, // red
	.Skull = rl.Color{200, 200, 210, 255}, // pale bone white
}

DIE_TYPE_COLORS_DIM := [Die_Type]rl.Color {
	.None  = rl.MAGENTA,
	.D4    = rl.Color{50, 80, 120, 255},
	.D6    = rl.Color{35, 100, 55, 255},
	.D8    = rl.Color{130, 110, 30, 255},
	.D10   = rl.Color{130, 80, 25, 255},
	.D12   = rl.Color{120, 30, 35, 255},
	.Skull = rl.Color{100, 100, 105, 255},
}

DIE_FACES := [Die_Type]int {
	.None  = 0,
	.D4    = 4,
	.D6    = 6,
	.D8    = 8,
	.D10   = 10,
	.D12   = 12,
	.Skull = 0, // skull dice are not rolled for a value
}

// Probability (out of 100) that any board cell becomes a skull die
SKULL_CHANCE :: 20

MAX_DIE_VALUE :: 12

// Result of rolling and evaluating a character's dice.
// Abilities read [MATCHES] (matched_count) and [VALUE] (matched_value) directly.
Roll_Result :: struct {
	values:          [MAX_CHARACTER_DICE]int, // rolled face values (1-12), 0 for skull dice
	count:           int, // total dice rolled (skull + normal)
	skulls:          [MAX_CHARACTER_DICE]int, // 1 if this die is a skull (for now, we can think of even bigger skull dice that have a different value)
	skull_count:     int, // number of skull dice in this roll
	matched_value:   int, // [VALUE]: face value of the best match group
	matched:         [MAX_CHARACTER_DICE]bool, // true = part of a match group (never true for skulls)
	matched_count:   int, // [MATCHES]: normal dice in match groups
	unmatched_count: int, // normal dice NOT in match groups
	// Invariant: matched_count + unmatched_count + skull_count == count
}

// Board cell
Board_Cell :: struct {
	die_type: Die_Type,
	occupied: bool,
	ring:     int,
}

// Board
Board :: struct {
	size:  int,
	cells: [BOARD_SIZE][BOARD_SIZE]Board_Cell,
}

// Hand
MAX_HAND_SIZE :: 5
HAND_SLOT_SIZE :: 56
HAND_SLOT_GAP :: 8
HAND_Y_OFFSET :: 80 // pixels from bottom

Hand :: struct {
	dice:  [MAX_HAND_SIZE]Die_Type,
	count: int,
}

// Character
MAX_CHARACTER_DICE :: 6 // legendary max

Character_Rarity :: enum u8 {
	Common, // 3 dice
	Rare, // 4 dice
	Epic, // 5 dice
	Legendary, // 6 dice
}

RARITY_MAX_DICE := [Character_Rarity]int {
	.Common    = 3,
	.Rare      = 4,
	.Epic      = 5,
	.Legendary = 6,
}

RARITY_NAMES := [Character_Rarity]cstring {
	.Common    = "Common",
	.Rare      = "Rare",
	.Epic      = "Epic",
	.Legendary = "Legendary",
}

MAX_PARTY_SIZE :: 4

Character_State :: enum u8 {
	Empty, // zero value — no character in this slot
	Alive,
	Dead,
}

Character_Stats :: struct {
	hp:      int,
	attack:  int,
	defense: int,
}

// Abilities
//
// Each character has exactly 3 ability slots:
// 1. ability          — main active, fires on roll if min_matches met
// 2. resolve_ability  — fires when resolve meter is full, resets meter
// 3. passive          — always active, no roll trigger (placeholder for now)

Ability_Scaling :: enum u8 {
	Match,  // scales with [MATCHES]
	Value,  // scales with [VALUE]
	Hybrid, // uses both [MATCHES] and [VALUE]
}

// Effect procedure: called when an ability fires.
// Receives the full Roll_Result so effects can use any roll data.
Ability_Effect :: #type proc(attacker: ^Character, target: ^Character, roll: ^Roll_Result)

// Description procedure: returns a formatted string for UI display after firing.
// Uses ctprintf internally — the returned cstring is temporary (valid for one frame).
Ability_Describe :: #type proc(roll: ^Roll_Result) -> cstring

Ability :: struct {
	name:        cstring,
	scaling:     Ability_Scaling,
	min_matches: int,            // minimum [MATCHES] required to trigger (0 = always fires)
	effect:      Ability_Effect,
	describe:    Ability_Describe,
}

Character :: struct {
	state:          Character_State,
	name:           cstring,
	rarity:         Character_Rarity,
	max_dice:       int,
	stats:          Character_Stats,
	// Dice
	assigned:       [MAX_CHARACTER_DICE]Die_Type,
	assigned_count: int,
	// Roll state
	has_rolled:     bool,
	roll:           Roll_Result,
	// Abilities (1 main + 1 resolve + 1 passive)
	ability:          Ability,
	resolve_ability:  Ability,
	// passive: Ability,  // TODO: wire passive system
	resolve:          int,
	resolve_max:      int,
	// Roll resolution results (for UI)
	ability_fired:    bool,
	resolve_fired:    bool,
}

// Check if a character slot is active (alive and present)
character_is_active :: proc(character: ^Character) -> bool {
	return character.state == .Alive
}

// UI layout for character panel
CHAR_PANEL_X :: 30
CHAR_PANEL_Y :: 100
CHAR_PANEL_WIDTH :: 160
CHAR_SLOT_SIZE :: 44
CHAR_SLOT_GAP :: 6

// Turn state machine
Turn_Phase :: enum u8 {
	Player_Turn, // player can assign freely, pick or roll to end turn
	Player_Roll_Result, // showing player's roll results, click Clear to advance
	Enemy_Turn, // AI evaluates and executes one action
	Enemy_Roll_Result, // brief pause showing enemy roll results, then auto-advances
}

// Drag-and-drop state
Drag_Source :: enum {
	None, // zero value — not dragging
	Board,
	Hand,
	Character,
}

Drag_State :: struct {
	active:    bool,
	source:    Drag_Source,
	die_type:  Die_Type,
	// Source identification (for ghosting the source slot)
	board_row: int,
	board_col: int,
	index:     int, // hand slot index or character die index
}
