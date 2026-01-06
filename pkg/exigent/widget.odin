package exigent

import "base:runtime"
import "core:hash"
import "core:mem"

Widget :: struct {
	id:          Widget_ID,
	type:        Widget_Type,
	parent:      ^Widget,
	children:    [dynamic]^Widget,
	rect, clip:  Rect,
	style:       Widget_Style,
	// text:        string,
	// text_pos:    [2]f32,
	// text_style:  Text_Style,
	alpha:       u8,
	// flags:       bit_set[Widget_Flags],
	interaction: Widget_Interaction,
}

widget_begin :: proc(
	c: ^Context,
	type: Widget_Type,
	r: Rect,
	caller: runtime.Source_Code_Location,
	sub_id: int = 0,
) {
	w := new(Widget, c.temp_allocator)
	id := widget_id_push(c, caller, sub_id)
	w.id = id
	w.type = type
	w.alpha = 255
	w.rect = r
	w.clip = r
	w.style = style_get(c, type)
	w.children.allocator = c.temp_allocator

	if c.widget_curr != nil {
		parent := c.widget_curr
		append(&c.widget_stack, c.widget_curr)
		c.widget_curr = nil
		w.parent = parent
		w.clip = rect_intersect(w.parent.clip, w.clip)
		append(&w.parent.children, w)
	}

	c.widget_curr = w

	if c.widget_root == nil {
		c.widget_root = c.widget_curr
	}

	widget_interaction(c, c.widget_curr)
}

widget_end :: proc(c: ^Context) {
	widget_id_pop(c)

	if len(c.widget_stack) > 0 {
		c.widget_curr = pop(&c.widget_stack)
	}
}

Widget_ID :: distinct u32

@(private = "file")
Raw_Widget_ID :: struct #packed {
	stack_id: u32,
	fp:       u32, // hashed filepath
	line:     i32,
	col:      i32,
	sub_id:   int,
}

@(private = "file")
widget_id_push :: proc(
	c: ^Context,
	caller: runtime.Source_Code_Location,
	sub_id: int = 0,
) -> Widget_ID {
	top_stack_id: u32
	if len(c.id_stack) > 0 {
		top_stack_id = u32(c.id_stack[len(c.id_stack) - 1])
	}
	raw := Raw_Widget_ID {
		stack_id = top_stack_id,
		fp       = hash.fnv32a(transmute([]u8)caller.file_path),
		line     = caller.line,
		col      = caller.column,
		sub_id   = sub_id,
	}
	bytes := mem.any_to_bytes(raw)
	id := Widget_ID(hash.fnv32a(bytes))
	append(&c.id_stack, id)
	return id
}

@(private = "file")
widget_id_pop :: proc(c: ^Context) {
	pop(&c.id_stack)
}

// Widget_Flags :: enum {
// 	DrawBackground,
// 	DrawBorder,
// 	HasHover,
// 	HasActive,
// 	HasNoClip,
// }

// widget_flags :: proc(c: ^Context, flags: bit_set[Widget_Flags]) {
// 	c.widget_curr.flags += flags
// }

widget_get_rect :: proc(c: ^Context) -> Rect {
	return c.widget_curr.rect
}

// pick the top-most widget at the mouse_pos
@(private)
widget_pick :: proc(w: ^Widget, mouse_pos: [2]f32) -> (hovered: ^Widget, found: bool) {
	if w == nil {
		return nil, false
	}

	// TODO: This requires that each parent always contains their children fully.
	// Should we assert this during widget building to prevent surprises? Or
	// do we want an alternate approach?
	if !rect_contains(w.rect, mouse_pos) {
		return nil, false
	}

	#reverse for child in w.children {
		descendent, found := widget_pick(child, mouse_pos)
		if found {
			return descendent, true
		}
	}

	return w, true
}

Widget_Interaction :: struct {
	hovered: bool, // hovered
	down:    bool, // held down for one or more frames
	pressed: bool, // single frame mouse press down
	clicked: bool, // single frame mouse released inside widget
}

@(private)
widget_interaction :: proc(c: ^Context, w: ^Widget) {
	hovered_widget_id, ok := c.hovered_widget_id.?
	if ok && c.hovered_widget_id == w.id {
		w.interaction.hovered = true
		w.interaction.down = input_is_mouse_down(c, .Left)
		w.interaction.pressed = input_is_mouse_pressed(c, .Left)
		w.interaction.clicked = input_is_mouse_clicked(c, .Left)

		if w.interaction.down {
			c.active_widget_id = hovered_widget_id
		}

		if w.interaction.clicked {
			c.active_text_buffer = nil
		}
	}
}

Widget_Type :: distinct i32
Widget_Type_NONE := Widget_Type(0)

@(private = "file")
_next_widget_type := 1

widget_register :: proc "contextless" (style: Widget_Style) -> Widget_Type {
	wt := Widget_Type(_next_widget_type)
	_next_widget_type += 1
	style_default_register(wt, style)
	return wt
}

Widget_Type_ROOT := widget_register(Widget_Style{})
root :: proc(c: ^Context, caller := #caller_location, sub_id: int = 0) {
	screen := Rect{0, 0, f32(c.screen_width), f32(c.screen_height)}
	widget_begin(c, Widget_Type_ROOT, screen, caller, sub_id)
	widget_end(c)
}

// Widget_Type_PANEL := widget_register(Widget_Style{base = Style{background = Color{128, 128, 128}}})
// panel :: proc(c: ^Context, r: Rect, caller := #caller_location, sub_id: int = 0) {
// 	widget_begin(c, Widget_Type_PANEL, r, caller, sub_id)
// 	draw_background(c)
// 	widget_end(c)
// }

Widget_Type_BUTTON := widget_register(
	Widget_Style {
		base = Style {
			background = Color{100, 100, 100},
			border = Border_Style{type = .Square, thickness = 2},
		},
		hover = Style {
			background = Color{150, 150, 150},
			border = Border_Style{type = .Square, thickness = 2},
		},
		active = Style {
			background = Color{50, 50, 50},
			border = Border_Style{type = .Square, thickness = 2},
		},
	},
)
button :: proc(
	c: ^Context,
	r: Rect,
	text: string,
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, Widget_Type_BUTTON, r, caller, sub_id)
	defer widget_end(c)

	draw_background(c)
	draw_text(c, text, .Center, .Center)

	return c.widget_curr.interaction
}

Widget_Type_LABEL := widget_register(Widget_Style{})
label :: proc(
	c: ^Context,
	r: Rect,
	text: string,
	h_align: Text_Align_H = .Left,
	v_align: Text_Align_V = .Top,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, Widget_Type_LABEL, r, caller, sub_id)
	draw_text(c, text, h_align, v_align)
	widget_end(c)
}

Text_Input :: struct {
	text: Text_Buffer,
}

Widget_Type_TEXT_INPUT := widget_register(
	Widget_Style {
		base = Style {
			background = Color{225, 225, 225},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0}},
		},
	},
)
text_input :: proc(
	c: ^Context,
	r: Rect,
	text_buf: ^Text_Buffer,
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, Widget_Type_TEXT_INPUT, r, caller, sub_id)
	defer widget_end(c)

	draw_background(c)
	draw_text(c, text_buffer_to_string(text_buf), [2]f32{5, 5})

	if c.widget_curr.interaction.clicked {
		c.active_text_buffer = text_buf
	}

	return c.widget_curr.interaction
}

ScrollBox :: struct {
	y_offset: int,
}

Widget_Type_SCROLLBOX := widget_register(Widget_Style{})
scrollbox :: proc(
	c: ^Context,
	r: Rect,
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, Widget_Type_SCROLLBOX, r, caller, sub_id)
	defer widget_end(c)

	// widget_flags(c, {.DrawBackground})

	content := r
	scroll_container := rect_cut_right(&content, 20)

	return c.widget_curr.interaction
}

