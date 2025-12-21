package exigent

import "base:intrinsics"
Widget :: struct {
	key:      Widget_Key,
	parent:   ^Widget,
	children: [dynamic]^Widget,
	rect:     Rect,
	style:    Style,
	alpha:    u8,
	flags:    bit_set[Widget_Flags],
}

// Create a uint enum and give one unique entry per widget
Widget_Key :: distinct uint

key :: proc(id: $T) -> Widget_Key where intrinsics.type_is_enum(T) {
	return Widget_Key(uint(id))
}

Widget_Flags :: enum {
	DrawBackground,
}

widget_begin :: proc(c: ^Context, key: Widget_Key, r: Rect) {
	c.num_widgets += 1

	w := new(Widget, c.temp_allocator)
	w.alpha = 255
	w.rect = r
	w.style = style_flat_copy(c)

	if c.widget_curr != nil {
		parent := c.widget_curr
		append(&c.widget_stack, c.widget_curr)
		c.widget_curr = nil
		w.parent = parent
		append(&w.parent.children, w)
	}

	c.widget_curr = w

	if c.widget_root == nil {
		c.widget_root = c.widget_curr
	}
}

widget_end :: proc(c: ^Context) {
	if len(c.widget_stack) > 0 {
		c.widget_curr = pop(&c.widget_stack)
	}
}

widget_flags :: proc(c: ^Context, flags: bit_set[Widget_Flags]) {
	c.widget_curr.flags += flags
}

Widget_Interaction :: struct {
	clicked:  bool,
	hovering: bool,
}

// widget_interaction :: proc(c: ^Context, w: ^Widget) -> Widget_Interaction {

// }

panel :: proc(c: ^Context, key: Widget_Key, r: Rect) {
	widget_begin(c, key, r)
	widget_flags(c, {.DrawBackground})
	widget_end(c)
}
