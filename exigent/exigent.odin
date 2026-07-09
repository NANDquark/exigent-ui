package exigent

import "core:mem"
import "core:time"

Context :: struct {
	screen_width, screen_height: int,
	atlas_size:                  int,
	// persistent data
	perm_allocator:              mem.Allocator,
	input_prev, input_curr:      ^Input, // persisted so it can be diffed
	theme:                       Theme,
	text_width_data:             rawptr,
	text_width_fn:               Text_Style_Width_Fn,
	hovered_widget_id:           Maybe(Widget_ID), // persisted across frames
	pointer_captured:            bool,
	keyboard_captured:           bool,
	widget_stack:                [dynamic]^Widget,
	cmds:                        [dynamic]Command,
	scrollbox_stack:             [dynamic]^Scrollbox,
	// temp data
	temp_allocator:              mem.Allocator,
	layers:                      [dynamic]Layer,
	layer_curr:                  ^Layer,
	widget_curr:                 ^Widget,
	active_widget_id:            Maybe(Widget_ID),
	active_text_input:           ^Text_Input,
	active_text_input_widget_id: Maybe(Widget_ID),
	active_text_input_layer_id:  Maybe(Widget_ID),
	active_text_input_seen:      bool,
}

Layer :: struct {
	id:      Widget_ID,
	root:    ^Widget,
	options: Layer_Options,
}

Layer_Options :: struct {
	// Captures pointer input when the pointer is over the layer root/empty space.
	capture_pointer_empty: bool,
	// Captures keyboard input for this layer and clears lower-layer active text input focus.
	capture_keyboard:      bool,
}

init :: proc(
	c: ^Context,
	theme: Theme,
	atlas_size: int = 4096,
	perm_allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) {
	c.atlas_size = atlas_size
	c.theme = theme

	c.temp_allocator = temp_allocator
	c.perm_allocator = perm_allocator
	c.widget_stack = make([dynamic]^Widget, c.perm_allocator)
	c.cmds = make([dynamic]Command, c.perm_allocator)
	c.scrollbox_stack = make([dynamic]^Scrollbox, c.perm_allocator)
	c.layers = make([dynamic]Layer, c.perm_allocator)
	c.input_prev = input_create(allocator = c.perm_allocator)
	c.input_curr = input_create(allocator = c.perm_allocator)
}

theme_set :: proc(c: ^Context, theme: Theme) {
	c.theme = theme
}

destroy :: proc(c: ^Context) {
	context.allocator = c.perm_allocator
	input_destroy(c.input_prev)
	input_destroy(c.input_curr)
	delete(c.widget_stack)
	delete(c.cmds)
	delete(c.scrollbox_stack)
	delete(c.layers)
}

is_pointer_captured :: proc(c: ^Context) -> bool {
	return c.pointer_captured
}

is_keyboard_captured :: proc(c: ^Context) -> bool {
	return c.keyboard_captured
}

begin :: proc(c: ^Context, screen_width, screen_height: int) {
	c.screen_width = screen_width
	c.screen_height = screen_height
	c.layer_curr = nil
	c.widget_curr = nil
	c.active_widget_id = nil
	clear(&c.cmds)
	clear(&c.scrollbox_stack)
	clear(&c.widget_stack)
	clear(&c.layers)
	c.active_text_input_seen = false
}

end :: proc(c: ^Context) {
	assert(c.layer_curr == nil, "every layer_begin must have a layer_end")
	assert(c.widget_curr == nil, "every widget_begin must have a widget_end")
	assert(len(c.widget_stack) == 0, "every widget_begin must have a widget_end")
	assert(len(c.scrollbox_stack) == 0, "every scrollbox must be ended")

	clear(&c.cmds)
	screen_rect := Rect{0, 0, f32(c.screen_width), f32(c.screen_height)}
	for &layer in c.layers {
		layout_measure_tree(c, layer.root)
		layout_position_tree(c, layer.root, [2]f32{0, 0}, screen_rect)
		layout_emit_commands(c, layer.root)
	}

	active_text_input_validate(c)
	keyboard_capture_recompute(c)
	active_text_input_apply_keys(c)
	input_apply_pending_text(c)

	c.widget_curr = nil
	input_swap(c)
	hovered, captured, found := layer_pick(c, c.input_curr.mouse_pos)
	if found {
		c.hovered_widget_id = hovered.id
		c.pointer_captured = captured
	} else {
		c.hovered_widget_id = nil
		c.active_widget_id = nil
		c.pointer_captured = false
	}
}

@(private)
active_text_input_apply_keys :: proc(c: ^Context) {
	if !active_text_input_can_mutate(c) do return

	if input_is_key_released(c, .Escape) {
		text_buffer_clear(&c.active_text_input.text)
		c.active_text_input._focused_ts = time.Time{}
		active_text_input_clear(c)
	}
	if input_is_key_released(c, .Enter) {
		active_text_input_clear(c)
	}
	if input_is_key_released(c, .Backspace) {
		text_buffer_pop(&c.active_text_input.text)
	}
}

@(private)
active_text_input_clear :: proc(c: ^Context) {
	c.active_text_input = nil
	c.active_text_input_widget_id = nil
	c.active_text_input_layer_id = nil
	c.active_text_input_seen = false
}

@(private)
active_text_input_can_mutate :: proc(c: ^Context) -> bool {
	if c.active_text_input == nil do return false
	if c.active_text_input_widget_id == nil do return false
	if c.active_text_input_layer_id == nil do return false
	return c.keyboard_captured
}

@(private)
active_text_input_validate :: proc(c: ^Context) {
	if c.active_text_input == nil do return
	if !c.active_text_input_seen {
		active_text_input_clear(c)
		return
	}

	active_layer_id, ok := c.active_text_input_layer_id.?
	if !ok {
		active_text_input_clear(c)
		return
	}

	active_layer_found := false
	for layer in c.layers {
		if active_layer_found && layer.options.capture_keyboard {
			active_text_input_clear(c)
			return
		}
		if layer.id == active_layer_id {
			active_layer_found = true
		}
	}

	if !active_layer_found {
		active_text_input_clear(c)
	}
}

@(private)
keyboard_capture_recompute :: proc(c: ^Context) {
	c.keyboard_captured = c.active_text_input != nil
	for layer in c.layers {
		if layer.options.capture_keyboard {
			c.keyboard_captured = true
			return
		}
	}
}

Command_Iterator :: struct {
	idx:  int,
	cmds: ^[dynamic]Command,
}

cmd_iterator_create :: proc(c: ^Context) -> Command_Iterator {
	return Command_Iterator{idx = 0, cmds = &c.cmds}
}

cmd_iterator_next :: proc(ci: ^Command_Iterator) -> (Command, bool) {
	if ci.idx == len(ci.cmds) {
		return Command{}, false
	}
	cmd := ci.cmds[ci.idx]
	ci.idx += 1
	return cmd, true
}

Command :: union {
	Command_Rect,
	Command_Text,
	Command_Clip,
	Command_Unclip,
	Command_Sprite,
}

Command_Rect :: struct {
	rect:   Rect,
	clip:   Maybe(Rect), // includes space for the border outside rect
	color:  Color,
	border: Border_Style, // border must be drawn outside the rect
}

Command_Text :: struct {
	text:  string,
	pos:   [2]f32,
	clip:  Maybe(Rect),
	style: Text_Style,
}

Command_Clip :: struct {
	rect: Rect,
}

Command_Unclip :: struct {}

Command_Sprite :: struct {
	sprite: Sprite,
	rect:   Rect,
}
