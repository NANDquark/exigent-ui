package exigent

import "core:container/queue"
import "core:mem"
import "core:slice"

Context :: struct {
	screen_width, screen_height: int,
	is_building:                 bool, // when between begin/end
	num_widgets:                 int,
	key_map:                     map[int]Special_Key,
	key_max:                     int,
	// persistent data
	perm_allocator:              mem.Allocator,
	input_prev, input_curr:      ^Input,
	widget_stack:                [dynamic]^Widget,
	style_stack:                 [dynamic]Style,
	text_style_stack:            [dynamic]Text_Style_Type,
	hovered_widget_id:           Maybe(Widget_ID),
	active_text_buffer:          ^Text_Buffer,
	// temp data
	temp_allocator:              mem.Allocator,
	widget_root, widget_curr:    ^Widget,
	id_stack:                    [dynamic]Widget_ID,
}

context_init :: proc(
	c: ^Context,
	key_map: map[int]Special_Key,
	key_min: int = 0,
	key_max: int = 512,
	perm_allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) {
	c.key_map = key_map
	c.key_max = key_max

	c.perm_allocator = perm_allocator
	c.widget_stack.allocator = c.perm_allocator
	c.input_prev = input_create(key_min, key_max + len(Special_Key), c.perm_allocator)
	c.input_curr = input_create(key_min, key_max + len(Special_Key), c.perm_allocator)
	c.style_stack.allocator = c.perm_allocator
	style := Style{}
	style_default_init(&style, perm_allocator) // TODO: allow caller override of default theme
	append(&c.style_stack, style)

	c.temp_allocator = temp_allocator
	c.text_style_stack.allocator = c.temp_allocator
	c.id_stack.allocator = c.temp_allocator
}

context_destroy :: proc(c: ^Context) {
	context.allocator = c.perm_allocator
	input_destroy(c.input_prev)
	input_destroy(c.input_curr)
	delete(c.widget_stack)
	delete(c.style_stack)
}

begin :: proc(c: ^Context, screen_width, screen_height: int) {
	c.screen_width = screen_width
	c.screen_height = screen_height
	c.widget_root = nil
	c.widget_curr = nil
	c.num_widgets = 0
	c.is_building = true

	root(c) // create root widget all builder-code widgets are children of

	if c.active_text_buffer != nil {
		if input_is_key_released(c, Special_Key.Escape) {
			text_buffer_clear(c.active_text_buffer)
			c.active_text_buffer = nil
		}
		if input_is_key_released(c, Special_Key.Enter) {
			c.active_text_buffer = nil
		}
		if input_is_key_released(c, Special_Key.Backspace) {
			text_buffer_pop(c.active_text_buffer)
		}
	}
}

end :: proc(c: ^Context) {
	assert(len(c.widget_stack) == 0, "every widget_begin must have a widge_end")
	assert(len(c.style_stack) == 1, "every style_push must have a style_pop")
	assert(len(c.text_style_stack) == 0, "every text_style_push must have a text_style_pop")

	c.is_building = false
	input_swap(c)
	hovered, found := widget_pick(c.widget_root, c.input_curr.mouse_pos)
	c.hovered_widget_id = hovered.id if found else nil
	clear(&c.widget_stack)
	clear(&c.text_style_stack)
	clear(&c.id_stack)
}

Command_Iterator :: struct {
	queued: [dynamic]Command,
	idx:    int,
}

DEFAULT_CMDS_PER_WIDGET_HEURISTIC :: 5

cmd_iterator_create :: proc(
	c: ^Context,
	cmds_per_widget_heuristic := DEFAULT_CMDS_PER_WIDGET_HEURISTIC,
	allocator := context.temp_allocator,
) -> Command_Iterator {
	context.allocator = allocator

	ci := Command_Iterator {
		queued = make([dynamic]Command, 0, c.num_widgets * cmds_per_widget_heuristic),
	}

	widgets: queue.Queue(^Widget)
	queue.init(&widgets, c.num_widgets, c.temp_allocator)
	queue.push_back(&widgets, c.widget_root)

	for true {
		if queue.len(widgets) <= 0 {
			break
		}

		next := queue.pop_front(&widgets)
		queue.push_back_elems(&widgets, ..next.children[:])

		if .DrawBackground in next.flags {
			assert(Color_Type_BACKGROUND in next.style.colors)
			cmd := Command_Rect {
				rect  = next.rect,
				color = next.style.colors[Color_Type_BACKGROUND],
				alpha = next.alpha,
			}
			if .HasActive in next.flags && next.interaction.down {
				cmd.color = next.style.colors[Color_Type_BACKGROUND_ACTIVE]
			} else if .HasHover in next.flags && next.interaction.hovered {
				cmd.color = next.style.colors[Color_Type_BACKGROUND_HOVERED]
			}
			if .DrawBorder in next.flags {
				cmd.border_type = next.style.border_style.type
				cmd.border_thickness = next.style.border_style.thickness
			}
			append(&ci.queued, cmd)
		}

		if len(next.text) > 0 {
			cmd := Command_Text {
				text  = next.text,
				pos   = next.text_pos,
				style = next.text_style,
			}
			append(&ci.queued, cmd)
		}

	}

	slice.reverse(ci.queued[:])

	return ci
}

cmd_iterator_destroy :: proc(ci: ^Command_Iterator) {
	delete(ci.queued)
}

cmd_iterator_next :: proc(ci: ^Command_Iterator) -> Command {
	if len(ci.queued) <= 0 {
		return Command_Done{}
	}
	return pop(&ci.queued)
}

Command :: union {
	Command_Done,
	Command_Rect,
	Command_Text,
}

Command_Done :: struct {}

Command_Rect :: struct {
	rect:             Rect,
	color:            Color,
	alpha:            u8,
	border_type:      Border_Type,
	border_thickness: int,
	border_color:     Color,
}

Command_Text :: struct {
	text:  string,
	pos:   [2]f32,
	style: Text_Style,
}
