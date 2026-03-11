package exigent

import "core:testing"

@(test)
test_is_pointer_captured_false_by_default :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	testing.expect(t, !is_pointer_captured(c), "Pointer should not be captured by default")
}

@(test)
test_is_pointer_captured_false_for_root_hover :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	root := new(Widget)
	defer free(root)
	root.id = Widget_ID(1)
	c.widget_root = root
	c.hovered_widget_id = root.id

	testing.expect(t, !is_pointer_captured(c), "Root hover should not count as pointer capture")
}

@(test)
test_is_pointer_captured_true_when_non_root_widget_hovered :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	root := new(Widget)
	defer free(root)
	root.id = Widget_ID(1)
	c.widget_root = root
	c.hovered_widget_id = Widget_ID(2)

	testing.expect(t, is_pointer_captured(c), "Pointer should be captured when a non-root widget is hovered")
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

	text_input := new(Text_Input)
	defer free(text_input)
	c.active_text_input = text_input

	testing.expect(t, is_keyboard_captured(c), "Keyboard should be captured when text input is active")
}
