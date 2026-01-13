package exigent

import "core:mem"

Context :: struct {
	screen_width, screen_height: int,
	atlas_size:                  int,
	// persistent data
	perm_allocator:              mem.Allocator,
	input_prev, input_curr:      ^Input, // persisted so it can be diffed
	style_default:               map[Widget_Type]Widget_Style,
	hovered_widget_id:           Maybe(Widget_ID), // persisted across frames
	widget_stack:                [dynamic]^Widget,
	style_stack:                 [dynamic]Widget_Type_Style,
	// TODO: can text style stack be merged into style stack? Not easily. I
	// tried this and it creates a bunch of headaches for style push/pop because
	// now text style can be zero in a bunch of awkward places.
	text_style_stack:            [dynamic]Text_Style_Type,
	draw_cmds:                   [dynamic]Command,
	scrollbox_stack:             [dynamic]^Scrollbox,
	// temp data
	temp_allocator:              mem.Allocator,
	widget_root, widget_curr:    ^Widget,
	active_widget_id:            Maybe(Widget_ID),
	active_text_buffer:          ^Text_Buffer,
}

context_init :: proc(
	c: ^Context,
	atlas_size: int = 4096,
	perm_allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) {
	c.atlas_size = atlas_size

	c.temp_allocator = temp_allocator
	c.perm_allocator = perm_allocator
	c.widget_stack.allocator = c.perm_allocator
	c.style_stack.allocator = c.perm_allocator
	c.text_style_stack.allocator = c.perm_allocator
	c.draw_cmds.allocator = c.perm_allocator
	c.scrollbox_stack.allocator = c.perm_allocator
	c.input_prev = input_create(allocator = c.perm_allocator)
	c.input_curr = input_create(allocator = c.perm_allocator)
	c.style_default = DEFAULT_STYLES
}

context_destroy :: proc(c: ^Context) {
	context.allocator = c.perm_allocator
	input_destroy(c.input_prev)
	input_destroy(c.input_curr)
}

begin :: proc(c: ^Context, screen_width, screen_height: int) {
	c.screen_width = screen_width
	c.screen_height = screen_height
	c.widget_root = nil
	c.active_widget_id = nil
	clear(&c.draw_cmds)
	clear(&c.scrollbox_stack)
	clear(&c.widget_stack)
	clear(&c.style_stack)
	clear(&c.text_style_stack)

	root(c) // create root widget all builder-code widgets are children of

	if c.active_text_buffer != nil {
		if input_is_key_released(c, .Escape) {
			text_buffer_clear(c.active_text_buffer)
			c.active_text_buffer = nil
		}
		if input_is_key_released(c, .Enter) {
			c.active_text_buffer = nil
		}
		if input_is_key_released(c, .Backspace) {
			text_buffer_pop(c.active_text_buffer)
		}
	}
}

end :: proc(c: ^Context) {
	assert(len(c.widget_stack) == 0, "every widget_begin must have a widget_end")
	assert(len(c.style_stack) == 0, "every style_push must have a style_pop")
	assert(len(c.text_style_stack) == 0, "every text_style_push must have a text_style_pop")
	assert(len(c.scrollbox_stack) == 0, "every scrollbox must be ended")

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
	return Command_Iterator{idx = 0, cmds = &c.draw_cmds}
}

cmd_iterator_next :: proc(ci: ^Command_Iterator) -> Command {
	if ci.idx == len(ci.cmds) {
		return Command_Done{}
	}
	cmd := ci.cmds[ci.idx]
	ci.idx += 1
	return cmd
}

Command :: union {
	Command_Done,
	Command_Rect,
	Command_Text,
	Command_Clip,
	Command_Unclip,
	Command_Sprite,
}

Command_Done :: struct {}

Command_Rect :: struct {
	rect:   Rect,
	clip:   Maybe(Rect),
	color:  Color,
	border: Border_Style,
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
