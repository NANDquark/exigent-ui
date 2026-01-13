package exigent
import "core:container/bit_array"
import "core:mem"
import "core:unicode/utf8"

Input :: struct {
	mouse_pos:        [2]f32,
	scroll_delta:     f32,
	key_down:         bit_array.Bit_Array,
	mouse_down:       bit_set[Mouse_Button],
	frame_events:     [dynamic]Input_Event, // memory persists but is cleared each frame
	event_handle_gen: uint,
	allocator:        mem.Allocator,
}

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

Input_Event :: union {
	Key_Event,
	Mouse_Event,
}

Key_Event :: struct {
	key:     Key,
	type:    Key_Event_Type,
	handled: bool,
}

Key_Event_Type :: enum {
	Pressed,
	Released,
}

Mouse_Event :: struct {
	button:  Mouse_Button,
	type:    Mouse_Event_Type,
	handled: bool,
}

Mouse_Event_Type :: enum {
	Pressed,
	Released,
}

MAX_EVENTS_PER_FRAME :: 64

@(private)
input_create :: proc(
	max_events := MAX_EVENTS_PER_FRAME,
	allocator := context.allocator,
) -> ^Input {
	context.allocator = allocator
	i := new(Input)
	i.allocator = allocator
	bit_array.init(&i.key_down, int(max(Key)) + 1, 0, allocator)
	i.frame_events = make([dynamic]Input_Event, 0, max_events)
	return i
}

@(private)
input_destroy :: proc(i: ^Input) {
	context.allocator = i.allocator
	bit_array.destroy(&i.key_down)
	delete(i.frame_events)
	free(i)
}

@(private)
input_swap :: proc(c: ^Context) {
	c.input_prev, c.input_curr = c.input_curr, c.input_prev
	c.input_curr.event_handle_gen += 1

	// copy persistent values to curr frame
	c.input_curr.mouse_pos = c.input_prev.mouse_pos
	copy(c.input_curr.key_down.bits[:], c.input_prev.key_down.bits[:])
	c.input_curr.mouse_down = c.input_prev.mouse_down

	// clear frame-specific values
	clear(&c.input_curr.frame_events)
	c.input_curr.scroll_delta = 0
}

input_key_down :: proc(c: ^Context, key: Key) {
	k := int(key)
	bit_array.set(&c.input_curr.key_down, k)
	if !bit_array.get(&c.input_prev.key_down, k) {
		for e in c.input_curr.frame_events {
			#partial switch ke in e {
			case Key_Event:
				if !ke.handled && ke.key == key && ke.type == .Pressed do return
			}
		}
		append(&c.input_curr.frame_events, Key_Event{key = key, type = .Pressed})
	}
}

input_is_key_down :: proc(c: ^Context, key: Key) -> bool {
	return bit_array.get(&c.input_curr.key_down, int(key))
}

// Check whether an Input_Event happened this frame. Set that event as handled
// by default so it is not continued to be used.
input_check_event :: proc {
	input_check_key_event,
	input_check_mouse_event,
}

// Check whether an Key_Event happened this frame. Set that event as handled
// by default so it is not continued to be used.
input_check_key_event :: proc(
	c: ^Context,
	key: Key,
	type: Key_Event_Type,
	handle_event := true,
) -> bool {
	found := false
	for &e in c.input_curr.frame_events {
		#partial switch &ke in e {
		case Key_Event:
			if !ke.handled && ke.key == key && ke.type == type {
				ke.handled = handle_event
				found = true
			}
		}
	}
	return found
}

// Check whether an Mouse_Event happened this frame. Set that event as handled
// by default so it is not continued to be used.
input_check_mouse_event :: proc(
	c: ^Context,
	btn: Mouse_Button,
	type: Mouse_Event_Type,
	handle_event := true,
) -> bool {
	found := false
	for &e in c.input_curr.frame_events {
		#partial switch &me in e {
		case Mouse_Event:
			if !me.handled && me.button == btn && me.type == type {
				me.handled = handle_event
				found = true
			}
		}
	}
	return found
}

// Whether the key was pressed down this exact frame
input_is_key_pressed :: proc(c: ^Context, key: Key, handle_event := true) -> (pressed: bool) {
	return input_check_event(c, key, Key_Event_Type.Pressed, handle_event)
}

input_key_up :: proc(c: ^Context, key: Key) {
	bit_array.unset(&c.input_curr.key_down, int(key))
	for e in c.input_curr.frame_events {
		#partial switch ke in e {
		case Key_Event:
			if !ke.handled && ke.key == key && ke.type == .Released do return
		}
	}
	append(&c.input_curr.frame_events, Key_Event{key = key, type = .Released})
}

// Whether the key was released this exact frame
input_is_key_released :: proc(c: ^Context, key: Key, handle_event := true) -> bool {
	return input_check_event(c, key, Key_Event_Type.Released, handle_event)
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
		for e in c.input_curr.frame_events {
			#partial switch me in e {
			case Mouse_Event:
				if !me.handled && me.button == btn && me.type == .Pressed do return
			}
		}
		append(&c.input_curr.frame_events, Mouse_Event{button = btn, type = .Pressed})
	}
}

input_mouse_up :: proc(c: ^Context, btn: Mouse_Button) {
	c.input_curr.mouse_down -= {btn}
	for e in c.input_curr.frame_events {
		#partial switch me in e {
		case Mouse_Event:
			if !me.handled && me.button == btn && me.type == .Released do return
		}
	}
	append(&c.input_curr.frame_events, Mouse_Event{button = btn, type = .Released})
}

input_is_mouse_down :: proc(c: ^Context, btn: Mouse_Button) -> bool {
	return btn in c.input_curr.mouse_down
}

// Whether the mouse button was pressed down this exact frame
input_is_mouse_pressed :: proc(c: ^Context, btn: Mouse_Button, handle_event := true) -> bool {
	return input_check_event(c, btn, Mouse_Event_Type.Pressed, handle_event)
}

input_is_mouse_released :: proc(c: ^Context, btn: Mouse_Button, handle_event := true) -> bool {
	return input_check_event(c, btn, Mouse_Event_Type.Released, handle_event)
}

input_scroll :: proc(c: ^Context, delta: f32) {
	if delta == 0 do return
	c.input_curr.scroll_delta = delta
}

// scroll amount this frame in scroll notches
input_get_scroll :: proc(c: ^Context) -> f32 {
	return c.input_curr.scroll_delta
}

Key_Down_Iterator :: struct {
	iter: bit_array.Bit_Array_Iterator,
}

input_key_down_iterator :: proc(c: ^Context) -> Key_Down_Iterator {
	return Key_Down_Iterator {
		iter = bit_array.make_iterator(&c.input_curr.key_down),
	}
}

// Returns false when done
input_key_down_iterator_next :: proc(it: ^Key_Down_Iterator) -> (Key, bool) {
	idx, ok := bit_array.iterate_by_set(&it.iter)
	if !ok do return .None, false
	return Key(idx), true
}

input_char :: proc(c: ^Context, r: rune) {
	if c.active_text_buffer == nil do return

	bytes, len := utf8.encode_rune(r)
	text_buffer_append(c.active_text_buffer, bytes[:len])
}

Frame_Event_Iterator :: struct {
	frame_events: ^[dynamic]Input_Event,
	gen:          uint,
	next_idx:     int,
}

Input_Event_Handle :: struct {
	gen: uint,
	idx: int,
}

input_events_make_iter :: proc(c: ^Context) -> Frame_Event_Iterator {
	return Frame_Event_Iterator {
		frame_events = &c.input_curr.frame_events,
		gen = c.input_curr.event_handle_gen,
		next_idx = 0,
	}
}

// Get the next Input_Event which was not handled by the UI this frame.
input_next_unhandled_event :: proc(
	fei: ^Frame_Event_Iterator,
) -> (
	Input_Event_Handle,
	Input_Event,
	bool,
) {
	for fei.next_idx < len(fei.frame_events) {
		idx := fei.next_idx
		fei.next_idx += 1
		event := fei.frame_events[idx]

		handled := false
		switch e in event {
		case Key_Event:
			handled = e.handled
		case Mouse_Event:
			handled = e.handled
		}

		if !handled {
			return Input_Event_Handle{gen = fei.gen, idx = idx}, event, true
		}
	}

	return {}, {}, false
}

// Set an Input_Event which happened this frame as handled
input_handle_event :: proc(c: ^Context, to_handle: Input_Event_Handle) {
	// TODO should we log a warning here that invalid handles are being used?
	if to_handle.gen != c.input_curr.event_handle_gen do return
	if to_handle.idx < 0 || to_handle.idx > len(c.input_curr.frame_events) - 1 do return

	switch &e in c.input_curr.frame_events[to_handle.idx] {
	case Key_Event:
		e.handled = true
	case Mouse_Event:
		e.handled = true
	}
}
