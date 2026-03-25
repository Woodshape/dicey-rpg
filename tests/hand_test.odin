package tests

import "core:testing"
import game "../src"

// --- Hand capacity ---

@(test)
hand_add_up_to_max :: proc(t: ^testing.T) {
	hand: game.Hand

	for i in 0 ..< game.MAX_HAND_SIZE {
		ok := game.hand_add(&hand, .D6)
		testing.expect(t, ok, "should be able to add die to non-full hand")
	}
	testing.expect_value(t, hand.count, game.MAX_HAND_SIZE)
}

@(test)
hand_rejects_when_full :: proc(t: ^testing.T) {
	hand: game.Hand
	for _ in 0 ..< game.MAX_HAND_SIZE {
		game.hand_add(&hand, .D4)
	}

	ok := game.hand_add(&hand, .D8)
	testing.expect(t, !ok, "should reject die when hand is full")
	testing.expect_value(t, hand.count, game.MAX_HAND_SIZE)
}

@(test)
hand_remove_shifts_dice :: proc(t: ^testing.T) {
	hand: game.Hand
	game.hand_add(&hand, .D4)
	game.hand_add(&hand, .D8)
	game.hand_add(&hand, .D12)

	die, ok := game.hand_remove(&hand, 1)  // remove the d8
	testing.expect(t, ok, "removal should succeed")
	testing.expect_value(t, die, game.Die_Type.D8)
	testing.expect_value(t, hand.count, 2)
	testing.expect_value(t, hand.dice[0], game.Die_Type.D4)
	testing.expect_value(t, hand.dice[1], game.Die_Type.D12)
	testing.expect_value(t, hand.dice[2], game.Die_Type.None)  // vacated slot is .None
}

@(test)
hand_remove_clears_vacated_slots :: proc(t: ^testing.T) {
	hand: game.Hand
	// Use non-zero die types so stale data is distinguishable from zeroed memory
	game.hand_add(&hand, .D12)
	game.hand_add(&hand, .D10)
	game.hand_add(&hand, .D8)
	game.hand_add(&hand, .D6)

	// Remove from the middle
	game.hand_remove(&hand, 1)  // remove D10
	testing.expect_value(t, hand.count, 3)
	// Slot past count must be zeroed, not stale D6
	testing.expectf(t, hand.dice[hand.count] == .None, "vacated hand slot should be .None, got %v", hand.dice[hand.count])

	// Remove from the end
	game.hand_remove(&hand, 2)  // remove D6 (now at index 2)
	testing.expect_value(t, hand.count, 2)
	testing.expectf(t, hand.dice[hand.count] == .None, "vacated hand slot should be .None, got %v", hand.dice[hand.count])

	// Remove first element
	game.hand_remove(&hand, 0)  // remove D12
	testing.expect_value(t, hand.count, 1)
	testing.expectf(t, hand.dice[hand.count] == .None, "vacated hand slot should be .None, got %v", hand.dice[hand.count])
}

@(test)
hand_remove_invalid_index :: proc(t: ^testing.T) {
	hand: game.Hand
	game.hand_add(&hand, .D6)

	_, ok1 := game.hand_remove(&hand, -1)
	testing.expect(t, !ok1, "negative index should fail")

	_, ok2 := game.hand_remove(&hand, 5)
	testing.expect(t, !ok2, "out of bounds index should fail")
}
