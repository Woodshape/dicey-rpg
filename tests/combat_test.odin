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
	game.character_assign_die(&gs.player, .D6)
	game.hand_remove(&gs.hand, 0)
	testing.expect_value(t, gs.turn, game.Turn_Phase.Player_Turn)
}

@(test)
cannot_roll_empty_character :: proc(t: ^testing.T) {
	gs := game.game_init()
	testing.expect(t, !game.can_roll(&gs.player), "should not be able to roll with no assigned dice")
}

@(test)
can_roll_with_assigned_dice :: proc(t: ^testing.T) {
	gs := game.game_init()
	game.character_assign_die(&gs.player, .D6)
	testing.expect(t, game.can_roll(&gs.player), "should be able to roll with assigned dice")
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
