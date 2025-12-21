package exigent

import "core:container/queue"
import "core:mem"

Context :: struct {
	screen_width, screen_height: int,
	is_building:                 bool, // when between context_begin/context_end
	num_widgets:                 int,
	// persistent data
	perm_allocator:              mem.Allocator,
	input_prev, input_curr:      ^Input,
	widget_stack:                [dynamic]^Widget,
	style_stack:                 [dynamic]Style,
	// temp data
	temp_allocator:              mem.Allocator,
	widget_root, widget_curr:    ^Widget,
}

context_init :: proc(
	c: ^Context,
	key_min_index: int = 0,
	key_max_index: int = 512,
	perm_allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) {
	c.perm_allocator = perm_allocator

	c.widget_stack.allocator = c.perm_allocator

	c.input_prev = input_create(key_min_index, key_max_index, c.perm_allocator)
	c.input_curr = input_create(key_min_index, key_max_index, c.perm_allocator)
	c.style_stack.allocator = c.perm_allocator
	style := Style{}
	style_default_init(&style, perm_allocator) // TODO: allow caller override of default theme
	append(&c.style_stack, style)

	c.temp_allocator = temp_allocator
}

context_destroy :: proc(c: ^Context) {
	context.allocator = c.perm_allocator
	input_destroy(c.input_prev)
	free(c.input_prev)
	input_destroy(c.input_curr)
	free(c.input_curr)
	delete(c.widget_stack)
	delete(c.style_stack)
}

begin :: proc(c: ^Context, screen_width, screen_height: int) {
	c.screen_width = screen_width
	c.screen_height = screen_height
	c.widget_root, c.widget_curr = nil, nil
	c.num_widgets = 0
	c.is_building = true
}

end :: proc(c: ^Context) {
	assert(len(c.widget_stack) == 0, "every widget_begin must have a widge_end")
	assert(len(c.style_stack) == 1, "every style_push must have a style_pop")

	c.is_building = false
	input_swap(c)
	clear(&c.widget_stack)
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
			color := next.style.colors[Color_Type_BACKGROUND]
			append(&ci.queued, Command_Rect{rect = next.rect, color = color, alpha = next.alpha})
		}
	}

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
}

Command_Done :: struct {}

Command_Rect :: struct {
	rect:  Rect,
	color: Color,
	alpha: u8,
}
