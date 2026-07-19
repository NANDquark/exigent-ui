#+build !js

package exigent

import "core:testing"

capture_test_text_layer :: proc(
	c: ^Context,
	input: ^Text_Input,
	options := Layer_Options{},
	layer_sub_id: int = 1,
) {
	layer_begin(c, layout_fixed(100, 100), options, sub_id = layer_sub_id)
	text_input(c, layout_fixed(40, 20), input, sub_id = 1)
	layer_end(c)
}

capture_test_focus_text_input :: proc(
	c: ^Context,
	input: ^Text_Input,
	options := Layer_Options{},
	layer_sub_id: int = 1,
) {
	test_input_mouse_pos(c, {5, 5})
	begin(c, 100, 100)
	capture_test_text_layer(c, input, options, layer_sub_id)
	end(c)
	free_all(c.temp_allocator)

	test_input_mouse_up(c, .Left)
	begin(c, 100, 100)
	capture_test_text_layer(c, input, options, layer_sub_id)
	end(c)
	free_all(c.temp_allocator)
}

@(test)
test_is_pointer_captured_false_by_default :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	testing.expect(t, !is_pointer_captured(c), "Pointer should not be captured by default")
}

@(test)
test_is_pointer_captured_false_for_empty_layer_hover_by_default :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {10, 10})
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100))
	layer_end(c)
	end(c)

	testing.expect(t, !is_pointer_captured(c), "Empty layer hover should pass through by default")
	free_all(c.temp_allocator)
}

@(test)
test_is_pointer_captured_true_when_child_widget_hovered :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {10, 10})
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100))
	button(c, "A")
	layer_end(c)
	end(c)

	testing.expect(
		t,
		is_pointer_captured(c),
		"Pointer should be captured when a child widget is hovered",
	)
	free_all(c.temp_allocator)
}

@(test)
test_is_pointer_captured_true_when_layer_captures_empty_space :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {10, 10})
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), Layer_Options{capture_pointer_empty = true})
	layer_end(c)
	end(c)

	testing.expect(t, is_pointer_captured(c), "Capturing layer should capture empty-space hover")
	free_all(c.temp_allocator)
}

@(test)
test_is_keyboard_captured_false_by_default :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	testing.expect(t, !is_keyboard_captured(c), "Keyboard should not be captured by default")
}

@(test)
test_is_keyboard_captured_true_when_text_input_active :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input: Text_Input
	capture_test_focus_text_input(c, &input)

	testing.expect(
		t,
		is_keyboard_captured(c),
		"Keyboard should be captured when text input is active",
	)
}

@(test)
test_is_keyboard_captured_true_when_layer_captures_keyboard :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), Layer_Options{capture_keyboard = true})
	layer_end(c)
	end(c)

	testing.expect(
		t,
		is_keyboard_captured(c),
		"Keyboard-capturing layer should capture keyboard without a text input",
	)
	free_all(c.temp_allocator)
}

@(test)
test_lower_text_input_stays_active_under_noncapturing_layer :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input: Text_Input
	capture_test_focus_text_input(c, &input)

	begin(c, 100, 100)
	capture_test_text_layer(c, &input, layer_sub_id = 1)
	layer_begin(c, layout_fixed(100, 100), sub_id = 2)
	layer_end(c)
	end(c)

	testing.expect_value(t, c.active_text_input, &input)
	testing.expect(t, is_keyboard_captured(c))
	free_all(c.temp_allocator)
}

@(test)
test_lower_text_input_cleared_by_higher_keyboard_capturing_layer :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input: Text_Input
	capture_test_focus_text_input(c, &input)

	begin(c, 100, 100)
	capture_test_text_layer(c, &input, layer_sub_id = 1)
	layer_begin(c, layout_fixed(100, 100), Layer_Options{capture_keyboard = true}, sub_id = 2)
	layer_end(c)
	end(c)

	testing.expect_value(t, c.active_text_input, nil)
	testing.expect(
		t,
		is_keyboard_captured(c),
		"Keyboard should remain captured by the modal layer",
	)
	free_all(c.temp_allocator)
}

@(test)
test_char_after_keyboard_capture_clears_focus_does_not_mutate_lower_input :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	buf: [8]u8
	input := Text_Input {
		text = text_buffer_create(buf[:]),
	}
	capture_test_focus_text_input(c, &input)

	begin(c, 100, 100)
	capture_test_text_layer(c, &input, layer_sub_id = 1)
	layer_begin(c, layout_fixed(100, 100), Layer_Options{capture_keyboard = true}, sub_id = 2)
	layer_end(c)
	end(c)
	free_all(c.temp_allocator)

	test_input_char(c, 'x')
	begin(c, 100, 100)
	capture_test_text_layer(c, &input, layer_sub_id = 1)
	end(c)

	testing.expect_value(t, text_buffer_to_string(&input.text), "")
	free_all(c.temp_allocator)
}

@(test)
test_backspace_after_keyboard_capture_clears_focus_does_not_mutate_lower_input :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	buf: [8]u8
	input := Text_Input {
		text = text_buffer_create(buf[:]),
	}
	initial_text := [?]u8{97, 98}
	text_buffer_append(&input.text, initial_text[:])
	capture_test_focus_text_input(c, &input)

	test_input_key_up(c, .Backspace)
	begin(c, 100, 100)
	capture_test_text_layer(c, &input, layer_sub_id = 1)
	layer_begin(c, layout_fixed(100, 100), Layer_Options{capture_keyboard = true}, sub_id = 2)
	layer_end(c)
	end(c)

	testing.expect_value(t, text_buffer_to_string(&input.text), "ab")
	testing.expect_value(t, c.active_text_input, nil)
	free_all(c.temp_allocator)
}

@(test)
test_active_text_input_cleared_when_owner_not_emitted :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	input: Text_Input
	capture_test_focus_text_input(c, &input)

	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	layer_end(c)
	end(c)

	testing.expect_value(t, c.active_text_input, nil)
	testing.expect(t, !is_keyboard_captured(c))
	free_all(c.temp_allocator)
}

@(test)
test_text_input_inside_keyboard_capturing_layer_receives_characters :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	buf: [8]u8
	input := Text_Input {
		text = text_buffer_create(buf[:]),
	}
	capture_test_focus_text_input(
		c,
		&input,
		Layer_Options{capture_keyboard = true},
		layer_sub_id = 2,
	)

	test_input_char(c, 'z')
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	layer_end(c)
	capture_test_text_layer(c, &input, Layer_Options{capture_keyboard = true}, layer_sub_id = 2)
	end(c)

	testing.expect_value(t, text_buffer_to_string(&input.text), "z")
	testing.expect_value(t, c.active_text_input, &input)
	free_all(c.temp_allocator)
}
