package tests

import "core:testing"
import game "../src"

// --- Turn state machine ---

@(test)
game_starts_on_draft_player_pick :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	testing.expect_value(t, gs.turn, game.Turn_Phase.Draft_Player_Pick)
}

@(test)
assign_does_not_end_turn :: proc(t: ^testing.T) {
	// Hand-to-character is a free Assign, should not change turn
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	gs.turn = .Combat_Player_Turn // move to combat phase for assign test
	game.hand_add(&gs.hand, .D6)

	testing.expect_value(t, gs.turn, game.Turn_Phase.Combat_Player_Turn)
	game.character_assign_die(&gs.player_party.characters[0], .D6)
	game.hand_remove(&gs.hand, 0)
	testing.expect_value(t, gs.turn, game.Turn_Phase.Combat_Player_Turn)
}

@(test)
cannot_roll_empty_character :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	testing.expect(t, !game.can_roll(&gs.player_party.characters[0]), "should not be able to roll with no assigned dice")
}

@(test)
can_roll_with_assigned_dice :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	game.character_assign_die(&gs.player_party.characters[0], .D6)
	testing.expect(t, game.can_roll(&gs.player_party.characters[0]), "should be able to roll with assigned dice")
}

@(test)
cannot_pick_with_full_hand :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	for _ in 0 ..< game.MAX_HAND_SIZE {
		game.hand_add(&gs.hand, .D4)
	}
	testing.expect(t, !game.can_pick(&gs.pool, &gs.hand), "should not be able to pick with full hand")
}

@(test)
can_pick_with_space_in_hand :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	testing.expect(t, game.can_pick(&gs.pool, &gs.hand), "should be able to pick with empty hand and pool dice available")
}

// --- Win/Lose ---

@(test)
enemy_death_triggers_victory :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	for i in 0 ..< gs.enemy_party.count {
		gs.enemy_party.characters[i].stats.hp = 0
		gs.enemy_party.characters[i].state = .Dead
	}

	result := game.check_win_lose(&gs, .Combat_Player_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Victory)
}

@(test)
player_death_triggers_defeat :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	for i in 0 ..< gs.player_party.count {
		gs.player_party.characters[i].stats.hp = 0
		gs.player_party.characters[i].state = .Dead
	}

	result := game.check_win_lose(&gs, .Combat_Enemy_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Defeat)
}

@(test)
both_alive_returns_default :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)

	result := game.check_win_lose(&gs, .Combat_Enemy_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Combat_Enemy_Turn)
}

@(test)
partial_enemy_death_not_victory :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	gs.enemy_party.characters[0].stats.hp = 0

	result := game.check_win_lose(&gs, .Combat_Player_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Combat_Player_Turn)
}

@(test)
all_dead_enemy_takes_priority :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	for i in 0 ..< gs.player_party.count {
		gs.player_party.characters[i].stats.hp = 0
		gs.player_party.characters[i].state = .Dead
	}
	for i in 0 ..< gs.enemy_party.count {
		gs.enemy_party.characters[i].stats.hp = 0
		gs.enemy_party.characters[i].state = .Dead
	}

	result := game.check_win_lose(&gs, .Combat_Player_Turn)
	testing.expect_value(t, result, game.Turn_Phase.Victory)
}

// --- Draft Phase ---

@(test)
draft_pool_not_empty_on_start :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	testing.expect(t, gs.pool.remaining > 0, "pool should have dice at game start")
	testing.expect_value(t, gs.pool.remaining, game.DEFAULT_POOL_SIZE)
}

@(test)
draft_pick_reduces_pool :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	initial := gs.pool.remaining
	game.pool_remove_die(&gs.pool, 0)
	testing.expect_value(t, gs.pool.remaining, initial - 1)
}

@(test)
no_assigned_dice_means_no_rollable :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)
	// All characters start with 0 assigned dice
	has_dice := game.party_has_assigned_dice(&gs.player_party)
	testing.expect(t, !has_dice, "no characters should have assigned dice at start")
}

// --- Play Again ---

@(test)
play_again_resets_game_state :: proc(t: ^testing.T) {
	gs, _ := game.game_init()
	defer game.game_free(&gs)

	// Simulate a game that ended
	gs.turn = .Victory
	gs.player_party.characters[0].stats.hp = 5
	gs.enemy_party.characters[0].stats.hp = 0
	game.hand_add(&gs.hand, .D6)

	// Reset — free first game state before reinitializing
	game.game_free(&gs)
	gs, _ = game.game_init()

	testing.expect_value(t, gs.turn, game.Turn_Phase.Draft_Player_Pick)
	testing.expect_value(t, gs.hand.count, 0)
	testing.expect(t, gs.player_party.characters[0].stats.hp > 0, "player should have full HP after restart")
	testing.expect(t, gs.enemy_party.characters[0].stats.hp > 0, "enemy should have full HP after restart")
	testing.expect(t, gs.pool.remaining > 0, "pool should be populated after restart")
}
