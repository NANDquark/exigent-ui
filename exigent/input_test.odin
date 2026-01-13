package exigent

import "core:mem"
import "core:testing"

fixture_context_create :: proc() -> ^Context {
	c := new(Context)
	context_init(c)
	return c
}

fixture_context_delete :: proc(c: ^Context) {
	context_destroy(c)
	free(c)
}

@(test)
test_key_down_sets_down_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	testing.expect(t, input_is_key_down(c, .A), "Key should be down after input_key_down")
}

@(test)
test_key_down_sets_pressed_first_frame :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	testing.expect(t, input_is_key_pressed(c, .A), "Key should be pressed on first frame")
}

@(test)
test_key_down_not_pressed_if_already_down :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_swap(c) // Simulate next frame
	input_key_down(c, .A) // Press again
	testing.expect(t, !input_is_key_pressed(c, .A), "Key should not be pressed if already down")
	testing.expect(t, input_is_key_down(c, .A), "Key should still be down")
}

@(test)
test_key_up_clears_down_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_up(c, .A)
	testing.expect(t, !input_is_key_down(c, .A), "Key should not be down after input_key_up")
}

@(test)
test_key_up_sets_released_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_up(c, .A)
	testing.expect(t, input_is_key_released(c, .A), "Key should be released after input_key_up")
}

@(test)
test_mouse_down_sets_down_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	testing.expect(t, input_is_mouse_down(c, .Left), "Mouse button should be down")
}

@(test)
test_mouse_down_sets_pressed_first_frame :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	testing.expect(
		t,
		input_is_mouse_pressed(c, .Left),
		"Mouse button should be pressed on first frame",
	)
}

@(test)
test_mouse_down_not_pressed_if_already_down :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	input_swap(c)
	input_mouse_down(c, .Left)
	testing.expect(
		t,
		!input_is_mouse_pressed(c, .Left),
		"Mouse button should not be pressed if already down",
	)
	testing.expect(t, input_is_mouse_down(c, .Left), "Mouse button should still be down")
}

@(test)
test_mouse_up_clears_down_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	input_mouse_up(c, .Left)
	testing.expect(t, !input_is_mouse_down(c, .Left), "Mouse button should not be down after up")
}

@(test)
test_mouse_up_sets_released_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	input_mouse_up(c, .Left)
	testing.expect(
		t,
		input_is_mouse_released(c, .Left),
		"Mouse button should be released after up",
	)
}

@(test)
test_all_mouse_buttons :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	buttons := []Mouse_Button{.Left, .Right, .Middle}
	for btn in buttons {
		input_mouse_down(c, btn)
		testing.expect(t, input_is_mouse_down(c, btn))
		input_mouse_up(c, btn)
		testing.expect(t, !input_is_mouse_down(c, btn))
		testing.expect(t, input_is_mouse_released(c, btn))
	}
}

@(test)
test_mouse_pos_sets_position :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	pos := [2]f32{100, 200}
	input_mouse_pos(c, pos)
	testing.expect(t, input_get_mouse_pos(c) == pos, "Mouse position should be set")
}

@(test)
test_mouse_pos_persists_across_frames :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	pos := [2]f32{100, 200}
	input_mouse_pos(c, pos)
	input_swap(c)
	testing.expect(t, input_get_mouse_pos(c) == pos, "Mouse position should persist across swap")
}

@(test)
test_swap_preserves_key_down_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	testing.expect(t, input_is_key_down(c, .A), "Key should be down before swap")

	input_swap(c)
	testing.expect(t, input_is_key_down(c, .A), "Key should still be down after swap")
}

@(test)
test_swap_clears_key_pressed_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	testing.expect(t, input_is_key_pressed(c, .A), "Key should be pressed before swap")

	input_swap(c)
	testing.expect(t, !input_is_key_pressed(c, .A), "Key should not be pressed after swap")
}

@(test)
test_swap_clears_key_released_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_up(c, .A)
	testing.expect(t, input_is_key_released(c, .A), "Key should be released before swap")

	input_swap(c)
	testing.expect(t, !input_is_key_released(c, .A), "Key should not be released after swap")
}

@(test)
test_swap_preserves_mouse_down_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	testing.expect(t, input_is_mouse_down(c, .Left), "Mouse should be down before swap")

	input_swap(c)
	testing.expect(t, input_is_mouse_down(c, .Left), "Mouse should still be down after swap")
}

@(test)
test_swap_clears_mouse_pressed_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	testing.expect(t, input_is_mouse_pressed(c, .Left), "Mouse should be pressed before swap")

	input_swap(c)
	testing.expect(t, !input_is_mouse_pressed(c, .Left), "Mouse should not be pressed after swap")
}

@(test)
test_swap_clears_mouse_released_state :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	input_mouse_up(c, .Left)
	testing.expect(t, input_is_mouse_released(c, .Left), "Mouse should be released before swap")

	input_swap(c)
	testing.expect(
		t,
		!input_is_mouse_released(c, .Left),
		"Mouse should not be released after swap",
	)
}

@(test)
test_swap_preserves_mouse_pos :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	pos := [2]f32{10, 20}
	input_mouse_pos(c, pos)
	input_swap(c)
	testing.expect(t, input_get_mouse_pos(c) == pos)
}

@(test)
test_iterator_empty_when_no_keys :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	it := input_key_down_iterator(c)
	_, ok := input_key_down_iterator_next(&it)
	testing.expect(t, !ok, "Iterator should be empty")
}

@(test)
test_iterator_finds_single_key :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	it := input_key_down_iterator(c)
	key, ok := input_key_down_iterator_next(&it)
	testing.expect(t, ok, "Iterator should find a key")
	testing.expect(t, key == .A, "Iterator should return the correct key")
	_, ok2 := input_key_down_iterator_next(&it)
	testing.expect(t, !ok2, "Iterator should exhaust after one key")
}

@(test)
test_iterator_finds_multiple_keys :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_down(c, .B)
	input_key_down(c, .C)

	it := input_key_down_iterator(c)
	found_keys := make([dynamic]Key, 0, 3, context.temp_allocator)

	for {
		key, ok := input_key_down_iterator_next(&it)
		if !ok do break
		append(&found_keys, key)
	}

	testing.expect(t, len(found_keys) == 3, "Should find 3 keys")

	has_a, has_b, has_c := false, false, false
	for k in found_keys {
		if k == .A do has_a = true
		if k == .B do has_b = true
		if k == .C do has_c = true
	}
	testing.expect(t, has_a && has_b && has_c, "Should find all pressed keys")
}

@(test)
test_iterator_order :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	// Bit array iterator order depends on enum values
	input_key_down(c, .C)
	input_key_down(c, .A)
	input_key_down(c, .B)

	it := input_key_down_iterator(c)
	k1, _ := input_key_down_iterator_next(&it)
	k2, _ := input_key_down_iterator_next(&it)
	k3, _ := input_key_down_iterator_next(&it)

	// Key enum values: A=65, B=66, C=67
	testing.expect(t, k1 == .A)
	testing.expect(t, k2 == .B)
	testing.expect(t, k3 == .C)
}

@(test)
test_iterator_exhausts :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	it := input_key_down_iterator(c)
	input_key_down_iterator_next(&it)
	_, ok := input_key_down_iterator_next(&it)
	testing.expect(t, !ok)
}

@(test)
test_key_press_and_hold_sequence :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	// Frame 1: Press
	input_key_down(c, .A)
	testing.expect(t, input_is_key_pressed(c, .A), "Frame 1: pressed=true")
	testing.expect(t, input_is_key_down(c, .A), "Frame 1: down=true")
	testing.expect(t, !input_is_key_released(c, .A), "Frame 1: released=false")

	// Frame 2: Hold
	input_swap(c)
	input_key_down(c, .A)
	testing.expect(t, !input_is_key_pressed(c, .A), "Frame 2: pressed=false")
	testing.expect(t, input_is_key_down(c, .A), "Frame 2: down=true")
	testing.expect(t, !input_is_key_released(c, .A), "Frame 2: released=false")

	// Frame 3: Release
	input_key_up(c, .A)
	testing.expect(t, !input_is_key_pressed(c, .A), "Frame 3: pressed=false")
	testing.expect(t, !input_is_key_down(c, .A), "Frame 3: down=false")
	testing.expect(t, input_is_key_released(c, .A), "Frame 3: released=true")
}

@(test)
test_key_rapid_press_release :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	// Press and release in same frame
	input_key_down(c, .A)
	input_key_up(c, .A)
	testing.expect(
		t,
		input_is_key_pressed(c, .A),
		"Pressed should be true after down then up because they happen within the same frame",
	)
	testing.expect(t, !input_is_key_down(c, .A), "Down should be false after up")
	testing.expect(t, input_is_key_released(c, .A), "Released should be true after up")
}

@(test)
test_release_unpressed_key :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	// Release a key that was never pressed
	input_key_up(c, .A)
	testing.expect(t, !input_is_key_down(c, .A), "Unpressed key should not be down")
	testing.expect(t, input_is_key_released(c, .A), "Unpressed key should be released")
	testing.expect(t, !input_is_key_pressed(c, .A), "Unpressed key should not be pressed")
}

@(test)
test_double_press_same_key :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	testing.expect(t, input_is_key_pressed(c, .A), "First press should set pressed")
	testing.expect(t, input_is_key_down(c, .A), "First press should set down")

	input_key_down(c, .A) // Press again
	testing.expect(
		t,
		input_is_key_pressed(c, .A),
		"Second press should still have pressed (from first)",
	)
	testing.expect(t, input_is_key_down(c, .A), "Second press should keep down")
}

@(test)
test_double_release_same_key :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_up(c, .A)
	testing.expect(t, input_is_key_released(c, .A), "First release should set released")

	input_key_up(c, .A) // Release again
	testing.expect(t, !input_is_key_down(c, .A), "Second release should keep not down")
	testing.expect(t, input_is_key_released(c, .A), "Second release should set released again")
}

@(test)
test_key_pressed_handle_event_false :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)

	// Check without handling
	testing.expect(t, input_is_key_pressed(c, .A, false), "Should be pressed")
	testing.expect(t, input_is_key_pressed(c, .A, false), "Should still be pressed")

	// Check with handling (default)
	testing.expect(t, input_is_key_pressed(c, .A), "Should be pressed")
	testing.expect(t, !input_is_key_pressed(c, .A), "Should no longer be pressed")
}

@(test)
test_key_released_handle_event_false :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_up(c, .A)

	// Check without handling
	testing.expect(t, input_is_key_released(c, .A, false), "Should be released")
	testing.expect(t, input_is_key_released(c, .A, false), "Should still be released")

	// Check with handling (default)
	testing.expect(t, input_is_key_released(c, .A), "Should be released")
	testing.expect(t, !input_is_key_released(c, .A), "Should no longer be released")
}

@(test)
test_mouse_pressed_handle_event_false :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)

	// Check without handling
	testing.expect(t, input_is_mouse_pressed(c, .Left, false), "Should be pressed")
	testing.expect(t, input_is_mouse_pressed(c, .Left, false), "Should still be pressed")

	// Check with handling (default)
	testing.expect(t, input_is_mouse_pressed(c, .Left), "Should be pressed")
	testing.expect(t, !input_is_mouse_pressed(c, .Left), "Should no longer be pressed")
}

@(test)
test_mouse_released_handle_event_false :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	input_mouse_up(c, .Left)

	// Check without handling
	testing.expect(t, input_is_mouse_released(c, .Left, false), "Should be released")
	testing.expect(t, input_is_mouse_released(c, .Left, false), "Should still be released")

	// Check with handling (default)
	testing.expect(t, input_is_mouse_released(c, .Left), "Should be released")
	testing.expect(t, !input_is_mouse_released(c, .Left), "Should no longer be released")
}

@(test)
test_frame_event_iterator_basic :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_mouse_down(c, .Left)

	fei := input_events_make_iter(c)

	handle1, event1, ok1 := input_next_unhandled_event(&fei)
	testing.expect(t, ok1, "Should find first event")
	#partial switch e in event1 {
	case Key_Event:
		testing.expect(t, e.key == .A)
	case:
		testing.expect(t, false, "First event should be Key_Event")
	}

	handle2, event2, ok2 := input_next_unhandled_event(&fei)
	testing.expect(t, ok2, "Should find second event")
	#partial switch e in event2 {
	case Mouse_Event:
		testing.expect(t, e.button == .Left)
	case:
		testing.expect(t, false, "Second event should be Mouse_Event")
	}

	_, _, ok3 := input_next_unhandled_event(&fei)
	testing.expect(t, !ok3, "Should not find third event")
}

@(test)
test_handle_event_marks_as_handled :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	fei := input_events_make_iter(c)
	handle, _, ok := input_next_unhandled_event(&fei)
	testing.expect(t, ok)

	input_handle_event(c, handle)

	// input_is_key_pressed checks for unhandled events
	testing.expect(
		t,
		!input_is_key_pressed(c, .A),
		"Key should no longer be 'pressed' (unhandled) after handle_event",
	)
}

@(test)
test_iterator_skips_handled_events :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	input_key_down(c, .B)

	// Handle .A using the high-level API
	input_is_key_pressed(c, .A)

	fei := input_events_make_iter(c)
	handle, event, ok := input_next_unhandled_event(&fei)

	testing.expect(t, ok, "Should find an event")
	#partial switch e in event {
	case Key_Event:
		testing.expect(t, e.key == .B, "Should have skipped .A because it was handled")
	case:
		testing.expect(t, false, "Event should be Key_Event")
	}

	_, _, ok2 := input_next_unhandled_event(&fei)
	testing.expect(t, !ok2, "Should be no more unhandled events")
}

@(test)
test_handle_event_invalid_generation :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	fei := input_events_make_iter(c)
	handle, _, ok := input_next_unhandled_event(&fei)
	testing.expect(t, ok)

	input_swap(c) // Increments event_handle_gen

	input_handle_event(c, handle) // Should do nothing because generation is old

	// We need to check the event in the PREVIOUS frame's storage if we wanted to be sure,
	// but input_handle_event specifically checks c.input_curr.event_handle_gen.
	// Since we swapped, handle.gen != c.input_curr.event_handle_gen.
}

@(test)
test_handle_event_out_of_bounds :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_key_down(c, .A)
	handle := Input_Event_Handle {
		gen = c.input_curr.event_handle_gen,
		idx = 999,
	}

	input_handle_event(c, handle) // Should not crash
}

@(test)
test_handle_mouse_event_marks_as_handled :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input_mouse_down(c, .Left)
	fei := input_events_make_iter(c)
	handle, _, ok := input_next_unhandled_event(&fei)
	testing.expect(t, ok)

	input_handle_event(c, handle)

	testing.expect(
		t,
		!input_is_mouse_pressed(c, .Left),
		"Mouse button should no longer be 'pressed' (unhandled) after handle_event",
	)
}
