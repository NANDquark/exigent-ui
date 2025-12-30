package exigent

import ba "core:container/bit_array"
import "core:fmt"
import "core:unicode/utf8"

Input :: struct {
	mouse_pos:     [2]f32,
	key_down:      ba.Bit_Array,
	mouse_down:    bit_set[Mouse_Button],
	// cleared at end of frame since it is based on comparison with last frame
	key_pressed:   ba.Bit_Array,
	key_released:  ba.Bit_Array,
	mouse_pressed: bit_set[Mouse_Button],
	// TODO: Set when mouse_up occurs inside a widget. However one limitation
	// currently is that we don't assert that the mouse_down occurred within
	// the same widget, which is a common expected pattern.
	mouse_clicked: bit_set[Mouse_Button],
}

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

Special_Key :: enum (int) {
	LCtrl,
	LAlt,
	LShift,
	RCtrl,
	RAlt,
	RShift,
	Escape,
	Enter,
	Backspace,
}

@(private)
input_create :: proc(
	min_index: int = 0,
	max_index: int = 512,
	allocator := context.allocator,
) -> ^Input {
	i := new(Input, allocator)
	ba.init(&i.key_down, max_index, min_index, allocator)
	ba.init(&i.key_pressed, max_index, min_index, allocator)
	ba.init(&i.key_released, max_index, min_index, allocator)
	return i
}

@(private)
input_destroy :: proc(i: ^Input, allocator := context.allocator) {
	context.allocator = allocator
	ba.destroy(&i.key_down)
	ba.destroy(&i.key_pressed)
	ba.destroy(&i.key_released)
	free(i, allocator)
}

@(private)
input_swap :: proc(c: ^Context) {
	c.input_prev, c.input_curr = c.input_curr, c.input_prev

	// copy persistent values to curr frame
	c.input_curr.mouse_pos = c.input_prev.mouse_pos
	copy(c.input_curr.key_down.bits[:], c.input_prev.key_down.bits[:])
	c.input_curr.mouse_down = c.input_prev.mouse_down

	// clear frame-specific values
	ba.clear(&c.input_curr.key_pressed)
	ba.clear(&c.input_curr.key_released)
	c.input_curr.mouse_pressed = {}
	c.input_curr.mouse_clicked = {}

}

input_key_down :: proc(c: ^Context, key: int) {
	key := key
	// convert special keys to known values
	if spec_key, ok := c.key_map[key]; ok {
		key = c.key_max + int(spec_key)
	}
	ba.set(&c.input_curr.key_down, key)
	if !ba.get(&c.input_prev.key_down, key) {
		ba.set(&c.input_curr.key_pressed, key)
	}
}

input_is_key_down :: proc {
	input_is_key_down_norm,
	input_is_key_down_spec,
}

input_is_key_down_norm :: proc(c: ^Context, key: int) -> bool {
	return ba.get(&c.input_curr.key_down, key)
}

input_is_key_down_spec :: proc(c: ^Context, key: Special_Key) -> bool {
	return input_is_key_down_norm(c, c.key_max + int(key))
}

// Whether the key was pressed down this exact frame
input_is_key_pressed :: proc(c: ^Context, key: int) -> bool {
	return ba.get(&c.input_curr.key_pressed, key)
}

input_key_up :: proc(c: ^Context, key: int) {
	key := key
	// convert special keys to known values
	if spec_key, ok := c.key_map[key]; ok {
		key = c.key_max + int(spec_key)
	}
	ba.unset(&c.input_curr.key_down, key)
	ba.unset(&c.input_curr.key_pressed, key)
	ba.set(&c.input_curr.key_released, key)
}

input_is_key_released :: proc {
	input_is_key_released_norm,
	input_is_key_released_spec,
}

// Whether the key was released this exact frame
input_is_key_released_norm :: proc(c: ^Context, key: int) -> bool {
	return ba.get(&c.input_curr.key_released, key)
}

input_is_key_released_spec :: proc(c: ^Context, key: Special_Key) -> bool {
	return input_is_key_released_norm(c, c.key_max + int(key))
}

input_mouse_pos :: proc(c: ^Context, pos: [2]f32) {
	c.input_curr.mouse_pos = pos
}

input_get_mouse_pos :: proc(c: ^Context) -> [2]f32 {
	return c.input_curr.mouse_pos
}

input_get_mouse_delta :: proc(c: ^Context) -> [2]f32 {
	return c.input_curr.mouse_pos - c.input_prev.mouse_pos
}

input_mouse_down :: proc(c: ^Context, btn: Mouse_Button) {
	c.input_curr.mouse_down += {btn}
	if btn not_in c.input_prev.mouse_down {
		c.input_curr.mouse_pressed += {btn}
	}
}

input_mouse_up :: proc(c: ^Context, btn: Mouse_Button) {
	c.input_curr.mouse_down -= {btn}
	c.input_curr.mouse_pressed -= {btn}
	c.input_curr.mouse_clicked += {btn}
}

input_is_mouse_down :: proc(c: ^Context, btn: Mouse_Button) -> bool {
	return btn in c.input_curr.mouse_down
}

// Whether the mouse button was pressed down this exact frame
input_is_mouse_pressed :: proc(c: ^Context, btn: Mouse_Button) -> bool {
	return btn in c.input_curr.mouse_pressed
}

// Whether the mouse button was released inside the hovered widget this exact frame
input_is_mouse_clicked :: proc(c: ^Context, btn: Mouse_Button) -> bool {
	return btn in c.input_curr.mouse_clicked
}

Key_Down_Iterator :: struct {
	key_map:  map[int]Special_Key,
	key_max:  int,
	iterator: ba.Bit_Array_Iterator,
}

input_key_down_iterator :: proc(c: ^Context) -> Key_Down_Iterator {
	return Key_Down_Iterator {
		iterator = ba.make_iterator(&c.input_curr.key_down),
		key_map = c.key_map,
		key_max = c.key_max,
	}
}

// Returns false when done
input_key_down_iterator_next :: proc(it: ^Key_Down_Iterator) -> (int, bool) {
	key, ok := ba.iterate_by_set(&it.iterator)
	if !ok do return key, false

	if key > it.key_max {
		target_spec_key := Special_Key(key - it.key_max)
		// TODO: should use a reverse map
		for norm_key, spec_key in it.key_map {
			if spec_key == target_spec_key {
				return norm_key, ok
			}
		}
	}

	return key, ok
}

input_char :: proc(c: ^Context, r: rune) {
	if c.active_text_buffer == nil do return

	bytes, len := utf8.encode_rune(r)
	text_buffer_append(c.active_text_buffer, bytes[:len])
}
