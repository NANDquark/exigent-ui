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
	widget_stack:                [dynamic]^Widget,
	cmds:                        [dynamic]Command,
	scrollbox_stack:             [dynamic]^Scrollbox,
	// temp data
	temp_allocator:              mem.Allocator,
	widget_root, widget_curr:    ^Widget,
	active_widget_id:            Maybe(Widget_ID),
	active_text_input:           ^Text_Input,
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
}

is_pointer_captured :: proc(c: ^Context) -> bool {
	hovered_widget_id, ok := c.hovered_widget_id.?
	if !ok {
		return false
	}
	if c.widget_root != nil && hovered_widget_id == c.widget_root.id {
		return false
	}
	return true
}

is_keyboard_captured :: proc(c: ^Context) -> bool {
	return c.active_text_input != nil
}

begin :: proc {
	begin_default,
	begin_ex,
}

begin_default :: proc(c: ^Context, screen_width, screen_height: int) {
	begin_ex(c, screen_width, screen_height, layout_fixed(f32(screen_width), f32(screen_height)))
}

begin_ex :: proc(
	c: ^Context,
	screen_width, screen_height: int,
	root_layout: Layout,
) {
	c.screen_width = screen_width
	c.screen_height = screen_height
	c.widget_root = nil
	c.active_widget_id = nil
	clear(&c.cmds)
	clear(&c.scrollbox_stack)
	clear(&c.widget_stack)

	root(c, root_layout) // create root widget all builder-code widgets are children of

	if c.active_text_input != nil {
		if input_is_key_released(c, .Escape) {
			text_buffer_clear(&c.active_text_input.text)
			c.active_text_input._focused_ts = time.Time{}
			c.active_text_input = nil
		}
		if input_is_key_released(c, .Enter) {
			c.active_text_input = nil
		}
		if input_is_key_released(c, .Backspace) {
			text_buffer_pop(&c.active_text_input.text)
		}
	}
}

end :: proc(c: ^Context) {
	assert(len(c.widget_stack) == 0, "every widget_begin must have a widget_end")
	assert(len(c.scrollbox_stack) == 0, "every scrollbox must be ended")

	clear(&c.cmds)
	layout_measure_tree(c, c.widget_root)
	layout_position_tree(
		c,
		c.widget_root,
		[2]f32{0, 0},
		Rect{0, 0, f32(c.screen_width), f32(c.screen_height)},
	)
	layout_emit_commands(c, c.widget_root)

	c.widget_curr = nil
	input_swap(c)
	hovered, found := widget_pick(c.widget_root, c.input_curr.mouse_pos)
	if found {
		c.hovered_widget_id = hovered.id
	} else {
		c.hovered_widget_id = nil
		c.active_widget_id = nil
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
