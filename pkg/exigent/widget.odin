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
	id := widget_create_id(c, caller, sub_id)
	w.id = id
	w.type = type
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
widget_create_id :: proc(
	c: ^Context,
	caller: runtime.Source_Code_Location,
	sub_id: int = 0,
) -> Widget_ID {
	top_stack_id: u32
	if len(c.widget_stack) > 0 {
		top_stack_id = u32(c.widget_stack[len(c.widget_stack) - 1].id)
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
	return id
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
	hovered: bool,
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
			background = Color{100, 100, 100, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
		},
		hover = Style {
			background = Color{150, 150, 150, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
		},
		active = Style {
			background = Color{50, 50, 50, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
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
			background = Color{225, 225, 225, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
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
	scroll_step_px: f32, // optional config for scroll speed
	y_offset:       f32, // persists across frames
	// used within begin/end to get attributes of the widget
	_w:             ^Widget,
	// when rect_take procs are used this contains the result, and negative height
	// means the content must clip and scroll
	// TODO: Not sure I like this solution, but it avoids caching content size
	// across frames size but it is pretty "magic" and requires careful usage so
	// not robust to using it wrong
	_layout:        ^Rect,
}

Widget_Type_SCROLLBOX := widget_register(
	Widget_Style {
		base = Style {
			background = Color{0, 0, 0, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
		},
	},
)
scrollbox_begin :: proc(
	c: ^Context,
	r: ^Rect,
	data: ^Scrollbox,
	caller := #caller_location,
	sub_id: int = 0,
) {
	// this explicitly copies the r Rect since rect_take operations
	// will modify the original Rect as we add content to it
	widget_begin(c, Widget_Type_SCROLLBOX, r^, caller, sub_id)

	data._w = c.widget_curr
	data._layout = r
	draw_background(c)

	append(&c.scrollbox_stack, data)
}

SCROLL_STEP_PX_DEFAULT :: 20
SCROLLBAR_WIDTH_PX_DEFAULT :: 20
SCROLLBAR_ALPHA_DEFAULT: u8 = 185

scrollbox_end :: proc(c: ^Context) {
	scrollbox := pop(&c.scrollbox_stack)

	// only do scrollbox when content extends beyond scrollbox height
	if scrollbox._layout.h < 0 {
		scrollbox_height := scrollbox._w.rect.h
		content_height := scrollbox_height + (-scrollbox._layout.h)

		// update scroll position
		if (rect_contains(scrollbox._w.rect, input_get_mouse_pos(c))) {
			scroll_delta := input_get_scroll(c)
			speed: f32 = SCROLL_STEP_PX_DEFAULT
			if scrollbox.scroll_step_px > 0 {
				speed = scrollbox.scroll_step_px
			}
			scrollbox.y_offset += scroll_delta * speed
			scrollbox.y_offset = math.clamp(
				scrollbox.y_offset,
				-(content_height - scrollbox_height),
				0,
			)
		}

		// draw scrollbar track
		style := style_curr(c)
		rect := scrollbox._w.rect
		scrollbar_width := style.scrollbar_width
		if scrollbar_width <= 0 {
			scrollbar_width = SCROLLBAR_WIDTH_PX_DEFAULT
		}
		scrollbar := rect_cut_right(&rect, scrollbar_width)
		scrollbar_track := scrollbar
		scrollbar_alpha := style.scrollbar_alpha
		if scrollbar_alpha <= 0 {
			scrollbar_alpha = SCROLLBAR_ALPHA_DEFAULT
		}
		faded_color := style.background
		faded_color.a = scrollbar_alpha
		draw_rect(c, scrollbar_track, faded_color)

		// draw scrollbar "thumb"
		thumb_height := scrollbox_height * scrollbox_height / content_height
		thumb_height = math.max(thumb_height, scrollbar_width, 20) // min thumb size
		pct := -scrollbox.y_offset / (content_height - scrollbox_height)
		pct = math.clamp(pct, 0, 1)
		thumb := Rect {
			x = scrollbar.x,
			y = scrollbar.y + (pct * (scrollbox_height - thumb_height)),
			h = thumb_height,
			w = scrollbar.w,
		}
		thumb = rect_inset(thumb, 2)
		faded_color = color_contrast(style.background)
		faded_color.a = scrollbar_alpha
		draw_rect(c, thumb, faded_color)
	}

	// cleanup
	scrollbox._w = nil
	scrollbox._layout = {}
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
