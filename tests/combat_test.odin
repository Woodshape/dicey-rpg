package tests

import "core:testing"
import game "../src"

// --- Turn state machine ---

@(test)
game_starts_on_player_turn :: proc(t: ^testing.T) {
	gs := game.game_init()
	testing.expect_value(t, gs.turn, game.Turn_Phase.Player_Turn)
}

@(test)
assign_does_not_end_turn :: proc(t: ^testing.T) {
	// Hand-to-character is a free Assign, should not change turn
	gs := game.game_init()
	game.hand_add(&gs.hand, .D6)

	testing.expect_value(t, gs.turn, game.Turn_Phase.Player_Turn)
	game.character_assign_die(&gs.player_party.characters[0], .D6)
	game.hand_remove(&gs.hand, 0)
	testing.expect_value(t, gs.turn, game.Turn_Phase.Player_Turn)
}

@(test)
cannot_roll_empty_character :: proc(t: ^testing.T) {
	gs := game.game_init()
	testing.expect(t, !game.can_roll(&gs.player_party.characters[0]), "should not be able to roll with no assigned dice")
}

@(test)
can_roll_with_assigned_dice :: proc(t: ^testing.T) {
	gs := game.game_init()
	game.character_assign_die(&gs.player_party.characters[0], .D6)
	testing.expect(t, game.can_roll(&gs.player_party.characters[0]), "should be able to roll with assigned dice")
}

@(test)
cannot_pick_with_full_hand :: proc(t: ^testing.T) {
	gs := game.game_init()
	// Fill hand to max
	for _ in 0 ..< game.MAX_HAND_SIZE {
		game.hand_add(&gs.hand, .D4)
	}
	testing.expect(t, !game.can_pick(&gs, &gs.hand), "should not be able to pick with full hand")
}

@(test)
can_pick_with_space_in_hand :: proc(t: ^testing.T) {
	gs := game.game_init()
	testing.expect(t, game.can_pick(&gs, &gs.hand), "should be able to pick with empty hand and board dice available")
}

// --- Win/Lose ---

@(test)
enemy_death_triggers_victory :: proc(t: ^testing.T) {
	gs := game.game_init()
	// Kill all enemies
	for i in 0 ..< gs.enemy_party.count {
		gs.enemy_party.characters[i].stats.hp = 0
	}

	result := game.check_win_lose(&gs, .Player_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Victory)
}

@(test)
player_death_triggers_defeat :: proc(t: ^testing.T) {
	gs := game.game_init()
	// Kill all players
	for i in 0 ..< gs.player_party.count {
		gs.player_party.characters[i].stats.hp = 0
	}

	result := game.check_win_lose(&gs, .Enemy_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Defeat)
}

@(test)
both_alive_returns_default :: proc(t: ^testing.T) {
	gs := game.game_init()

	result := game.check_win_lose(&gs, .Enemy_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Enemy_Turn)
}

@(test)
partial_enemy_death_not_victory :: proc(t: ^testing.T) {
	gs := game.game_init()
	// Kill only the first enemy — second is still alive
	gs.enemy_party.characters[0].stats.hp = 0

	result := game.check_win_lose(&gs, .Player_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Player_Turn)
}

@(test)
all_dead_enemy_takes_priority :: proc(t: ^testing.T) {
	// If both sides fully dead, enemy death = victory
	gs := game.game_init()
	for i in 0 ..< gs.player_party.count {
		gs.player_party.characters[i].stats.hp = 0
	}
	for i in 0 ..< gs.enemy_party.count {
		gs.enemy_party.characters[i].stats.hp = 0
	}

	result := game.check_win_lose(&gs, .Player_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Victory)
}

// --- Board Refill ---

@(test)
board_refills_when_empty :: proc(t: ^testing.T) {
	gs := game.game_init()

	// Empty the board
	for row in 0 ..< game.BOARD_SIZE {
		for col in 0 ..< game.BOARD_SIZE {
			gs.board.cells[row][col].occupied = false
		}
	}
	testing.expect_value(t, game.board_count_dice(&gs.board), 0)

	game.check_board_refill(&gs)

	testing.expect_value(t, game.board_count_dice(&gs.board), game.BOARD_SIZE * game.BOARD_SIZE)
}

@(test)
board_does_not_refill_when_dice_remain :: proc(t: ^testing.T) {
	gs := game.game_init()
	initial := game.board_count_dice(&gs.board)

	// Remove one die
	game.board_remove_die(&gs.board, 0, 0)
	testing.expect_value(t, game.board_count_dice(&gs.board), initial - 1)

	game.check_board_refill(&gs)

	// Should NOT refill — still has dice
	testing.expect_value(t, game.board_count_dice(&gs.board), initial - 1)
}

// --- Play Again ---

@(test)
play_again_resets_game_state :: proc(t: ^testing.T) {
	gs := game.game_init()

	// Simulate a game that ended
	gs.turn = .Victory
	gs.player_party.characters[0].stats.hp = 5
	gs.enemy_party.characters[0].stats.hp = 0
	game.hand_add(&gs.hand, .D6)

	// Reset
	gs = game.game_init()

	testing.expect_value(t, gs.turn, game.Turn_Phase.Player_Turn)
	testing.expect_value(t, gs.hand.count, 0)
	testing.expect(t, gs.player_party.characters[0].stats.hp > 0, "player should have full HP after restart")
	testing.expect(t, gs.enemy_party.characters[0].stats.hp > 0, "enemy should have full HP after restart")
}
