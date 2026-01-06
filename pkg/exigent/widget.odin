package exigent

import "base:runtime"
import "core:hash"
import "core:math"
import "core:mem"

Widget :: struct {
	id:          Widget_ID,
	type:        Widget_Type,
	parent:      ^Widget,
	children:    [dynamic]^Widget,
	rect, clip:  Rect,
	style:       Widget_Style,
	alpha:       u8,
	interaction: Widget_Interaction,
}

widget_begin :: proc(
	c: ^Context,
	type: Widget_Type,
	r: Rect,
	caller: runtime.Source_Code_Location,
	sub_id: int = 0,
) {
	rect := r
	if scrollbox, exists := scrollbox_curr(c); exists {
		rect.y += scrollbox_total_y_offset(c)
	}

	w := new(Widget, c.temp_allocator)
	id := widget_id_push(c, caller, sub_id)
	w.id = id
	w.type = type
	w.alpha = 255
	w.rect = rect
	w.clip = rect
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
	clip(c, c.widget_curr.clip)
}

widget_end :: proc(c: ^Context) {
	widget_id_pop(c)

	if len(c.widget_stack) > 0 {
		c.widget_curr = pop(&c.widget_stack)
	}

	unclip(c)
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

Scrollbox :: struct {
	y_offset: f32, // persists across frames
	w:        ^Widget,
	// when rect_take procs are used this contains the result, and negative height
	// means the content must clip and scroll
	// TODO: Not sure I like this solution, but it avoids caching content size
	// across frames size but it is pretty "magic" and requires careful usage so
	// not robust to using it wrong
	layout:   ^Rect,
	// _content_height: f32, // accumulated per frame
}

Widget_Type_SCROLLBOX := widget_register(
	Widget_Style {
		base = Style {
			background = Color{150, 150, 150},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0}},
		},
	},
)
// Modifies the r Rect so it is only the content section
scrollbox_begin :: proc(
	c: ^Context,
	r: ^Rect,
	data: ^Scrollbox,
	caller := #caller_location,
	sub_id: int = 0,
) {
	// this explicitly takes a copy of the r Rect since rect_take operations
	// will modify the original Rect as we add content to it
	widget_begin(c, Widget_Type_SCROLLBOX, r^, caller, sub_id)

	data.w = c.widget_curr
	data.layout = r
	draw_background(c)

	append(&c.scrollbox_stack, data)
}

scrollbox_end :: proc(c: ^Context) {
	scrollbox := pop(&c.scrollbox_stack)

	// TODO: move the scroll bar color and alpha to the Style struct

	// only show scrollbox when content extends beyond scrollbox height
	if scrollbox.layout.h < 0 {
		rect := scrollbox.w.rect
		scrollbar := rect_cut_right(&rect, 20)
		style := style_curr(c)

		// draw scrollbar track
		scrollbar_track := scrollbar
		draw_rect(
			c,
			scrollbar_track,
			style.background,
			185,
			Border_Style {
				type = .Square,
				thickness = 1,
				color = color_blend(style.border.color, Color{255, 255, 255}, 0.3),
			},
		)

		// draw scrollbar "thumb"
		scrollbox_height := scrollbox.w.rect.h
		content_height := scrollbox_height + (-scrollbox.layout.h)
		thumb_height := scrollbox_height * scrollbox_height / content_height
		thumb_height = math.max(thumb_height, 20) // min thumb size
		pct := -scrollbox.y_offset / (content_height - scrollbox_height)
		pct = math.clamp(pct, 0, 1)
		thumb := Rect {
			x = scrollbar.x,
			y = scrollbar.y + (pct * (scrollbox_height - thumb_height)),
			h = thumb_height,
			w = scrollbar.w,
		}
		thumb = rect_inset(thumb, 2)
		draw_rect(c, thumb, color_blend(style.background, Color{}, 0.3), 185)
	}

	// cleanup
	scrollbox.w = nil
	// scrollbox._content_height = 0
	widget_end(c)
}

@(private)
scrollbox_curr :: proc(c: ^Context) -> (^Scrollbox, bool) {
	if len(c.scrollbox_stack) > 0 {
		return c.scrollbox_stack[len(c.scrollbox_stack) - 1], true
	}
	return nil, false
}

@(private)
scrollbox_total_y_offset :: proc(c: ^Context) -> f32 {
	total: f32 = 0
	for sb in c.scrollbox_stack {
		total += sb.y_offset
	}
	return total
}

