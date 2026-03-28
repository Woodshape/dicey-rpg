package game

import rl "vendor:raylib"

// Window
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "Dicey RPG"
TARGET_FPS :: 60

// Draft pool
MAX_POOL_SIZE :: 12 // generous upper bound for variable pool sizes
DEFAULT_POOL_SIZE :: 6
POOL_CELL_SIZE :: 64 // pixels per die in pool
POOL_CELL_GAP :: 6 // pixels between dice in pool

Weight_Group :: enum u8 {
	Low,      // d4, d6 bias
	Mid_Low,  // d6, d8 bias
	Mid_High, // d8, d10 bias
	High,     // d10, d12 bias
}
WEIGHT_GROUP_COUNT :: 4

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

// Probability (out of 100) that any pool die becomes a skull die
SKULL_CHANCE :: 10

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
	// Pre-formatted display strings, populated by resolve_roll (combat.odin).
	// Computed once with full context; read by both the combat log and draw layer.
	// Cleared automatically by character_clear_roll via zero-init.
	ability_desc:    [MAX_LOG_LENGTH]u8,
	resolve_desc:    [MAX_LOG_LENGTH]u8,
}

// Draft pool
Draft_Pool :: struct {
	dice:         [MAX_POOL_SIZE]Die_Type,
	count:        int,  // total dice generated this round
	remaining:    int,  // dice not yet picked
	weight_group: Weight_Group,
	skull_chance: int,
}

// Round state — tracks weight group cycling and round progression
Round_State :: struct {
	group_order:  [WEIGHT_GROUP_COUNT]Weight_Group, // shuffled cycle
	cycle_index:  int,                               // position in current cycle
	round_number: int,                               // 1-based, increments each draft round
	first_pick:   bool,                              // true = player picks first this round
	pool_size:    int,                               // dice per round (default 6)
	skull_chance: int,                               // % per die
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

Party :: struct {
	characters: [MAX_PARTY_SIZE]Character,
	count:      int,
}

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

// Conditions (status effects on characters)
Condition_Kind :: enum u8 {
	None,    // sentinel
	Shield,  // blocks next hit entirely
	Hex,     // reduces DEF by value
}

Condition_Expiry :: enum u8 {
	None,          // sentinel
	Turns,         // decrements at start of owner's turn
	On_Hit_Taken,  // decrements when owner takes a hit
}

Condition :: struct {
	kind:      Condition_Kind,
	value:     int,             // magnitude (DEF reduction for Hex, unused for Shield)
	expiry:    Condition_Expiry,
	remaining: int,             // duration left (turns or hits); removed at 0
	interval:  int,             // ticks between periodic effect (0 = passive/reactive, no periodic trigger)
	timer:     int,             // counts up toward interval; resets when periodic effect fires
}

MAX_CONDITIONS :: 4

CONDITION_NAMES := [Condition_Kind]cstring {
	.None   = "??",
	.Shield = "Shield",
	.Hex    = "Hex",
}

// Abilities
//
// Each character has exactly 3 ability slots:
// 1. ability          — main active, fires on roll if min_matches met
// 2. resolve_ability  — fires when resolve meter is full, resets meter
// 3. passive          — always active, no roll trigger (placeholder for now)

Ability_Scaling :: enum u8 {
	None,   // flat effect, no scaling (e.g. fixed damage, fixed heal)
	Match,  // scales with [MATCHES]
	Value,  // scales with [VALUE]
	Hybrid, // uses both [MATCHES] and [VALUE]
}

// Effect procedure: called when an ability fires.
// Receives the full game state for maximum flexibility (AoE, board manipulation, hand theft, etc.).
Ability_Effect :: #type proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result)

// Description procedure: same signature as Ability_Effect so it has full runtime context
// (attacker stats, target, board state, etc.). Returns a formatted cstring for UI display
// and combat log. Uses ctprintf internally — the returned cstring is temporary (one frame).
Ability_Describe :: #type proc(gs: ^Game_State, attacker: ^Character, target: ^Character, roll: ^Roll_Result) -> cstring

Ability :: struct {
	name:        cstring,
	scaling:     Ability_Scaling,
	min_matches: int, // minimum [MATCHES] required to trigger (0 = always fires)
	min_value:   int, // minimum [VALUE] required to trigger (0 = always fires, not yet wired)
	effect:      Ability_Effect,
	describe:    Ability_Describe, // post-roll dynamic description (resolved values)
	description: cstring, // formula with {MATCHES}/{VALUE} placeholders, shown in inspect UI
}

Character :: struct {
	state:           Character_State,
	name:            cstring,
	rarity:          Character_Rarity,
	max_dice:        int,
	stats:           Character_Stats,
	// Dice
	assigned:        [MAX_CHARACTER_DICE]Die_Type,
	assigned_count:  int,
	// Roll state
	has_rolled:      bool,
	roll:            Roll_Result,
	// Conditions (status effects)
	conditions:      [MAX_CONDITIONS]Condition,
	condition_count: int,
	// Abilities (1 main + 1 resolve + 1 passive)
	ability:         Ability,
	resolve_ability: Ability,
	// passive: Ability,  // TODO: wire passive system
	resolve:         int,
	resolve_max:     int,
	// Roll resolution results (for UI)
	ability_fired:   bool,
	resolve_fired:   bool,
}

// Returns true if the character is alive and can act or be targeted.
// Use ch.state != .Empty to check whether a party slot is occupied at all.
character_is_alive :: proc(character: ^Character) -> bool {
	return character.state == .Alive
}

// UI layout for character panel
CHAR_PANEL_X      :: 30
CHAR_PANEL_Y :: 80
CHAR_PANEL_WIDTH :: 160
CHAR_SLOT_SIZE :: 44
CHAR_SLOT_GAP :: 6
CHAR_PANEL_STRIDE :: 200 // vertical spacing between stacked character panels

// Turn state machine
Turn_Phase :: enum u8 {
	// Draft phase
	Draft_Player_Pick, // player picks one die from pool (free assign/discard allowed)
	Draft_Enemy_Pick,  // AI picks one die from pool
	// Combat phase
	Combat_Player_Turn,  // player assigns freely, rolls one character or passes
	Player_Roll_Result,  // timed display of roll results
	Combat_Enemy_Turn,   // AI assigns, rolls one character or passes
	Enemy_Roll_Result,   // timed display of roll results
	// Round boundary
	Round_End,           // check win/lose, advance to next draft round
	// Terminal
	Victory,
	Defeat,
}

// Combat log
MAX_LOG_ENTRIES :: 10
MAX_LOG_LENGTH :: 128

Log_Entry :: struct {
	text:  [MAX_LOG_LENGTH]u8,
	len:   int,
	color: rl.Color,
}

Combat_Log :: struct {
	entries:      [MAX_LOG_ENTRIES]Log_Entry,
	count:        int,
	head:         int, // ring buffer write position
	game_number:  int, // increments on each Play Again
	file_enabled: bool, // only true when running the actual game (not tests)
}

// Input state — collected once per frame, threaded through update procs.
// Decouples game logic from Raylib input calls for headless simulation.
Input_State :: struct {
	mouse_x:       i32,
	mouse_y:       i32,
	left_pressed:  bool,
	left_released: bool,
	right_pressed: bool,
	delta_time:    f32,
}

// Drag-and-drop state
Drag_Source :: enum {
	None, // zero value — not dragging
	Pool,
	Hand,
	Character,
}

Drag_State :: struct {
	active:     bool,
	source:     Drag_Source,
	die_type:   Die_Type,
	// Source identification (for ghosting the source slot)
	pool_index: int, // index into draft pool (for Pool source)
	index:      int, // hand slot index or character die index
	char_index: int, // which character in the party (for Character source)
}
