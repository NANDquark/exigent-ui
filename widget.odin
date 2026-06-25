package exigent

import "base:runtime"
import "core:hash"
import "core:mem"
import "core:time"

Widget :: struct {
	id:          Widget_ID,
	type:        Widget_Type,
	parent:      ^Widget,
	children:    [dynamic]^Widget,
	layout:      Layout,
	measured_size: [2]f32,
	content_size:  [2]f32,
	intrinsic_size: [2]f32,
	rect:        Rect, // The inner size of the widget
	clip:        Rect, // The outer size (with borders) of the widget, used for clipping
	style:       Style,
	interaction: Widget_Interaction,
	draw_cmds:   [dynamic]Widget_Draw_Command,
	draw_offset: [2]f32,
	scrollbox:   ^Scrollbox,
}

Widget_Draw_Command :: union {
	Widget_Draw_Background,
	Widget_Draw_Rect,
	Widget_Draw_Text,
	Widget_Draw_Sprite,
}

Widget_Draw_Background :: struct {}

Widget_Draw_Rect :: struct {
	rect:   Rect,
	color:  Color,
	border: Border_Style,
}

Widget_Draw_Text :: struct {
	text:    string,
	offset:  [2]f32,
	h_align: Text_Align_H,
	v_align: Text_Align_V,
	style:   Text_Style,
}

Widget_Draw_Sprite :: struct {
	sprite: Sprite,
	rect:   Rect,
}

widget_begin :: proc(
	c: ^Context,
	type: Widget_Type,
	layout: Layout,
	caller: runtime.Source_Code_Location,
	sub_id: int = 0,
) {
	w := new(Widget, c.temp_allocator)
	id := widget_create_id(c, caller, sub_id)
	w.id = id
	w.type = type
	w.layout = layout

	w.interaction = widget_interaction(c, id)
	widget_style := style_get(c, type)
	style := widget_style.base
	if w.id == c.active_widget_id && widget_style.active != {} {
		style = widget_style.active
	} else if w.id == c.hovered_widget_id && widget_style.hover != {} {
		style = widget_style.hover
	}
	w.style = style

	w.children.allocator = c.temp_allocator
	w.draw_cmds.allocator = c.temp_allocator

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
	if !rect_contains(w.clip, mouse_pos) {
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
	hovered:  bool,
	down:     bool, // held down for one or more frames
	pressed:  bool, // single frame mouse press down
	released: bool, // single frame mouse released inside widget
}

@(private)
widget_interaction :: proc(c: ^Context, id: Widget_ID) -> Widget_Interaction {
	hovered_widget_id, ok := c.hovered_widget_id.?
	if ok && c.hovered_widget_id == id {
		wi := Widget_Interaction {
			hovered  = true,
			down     = input_is_mouse_down(c, .Left),
			pressed  = input_is_mouse_pressed(c, .Left),
			released = input_is_mouse_released(c, .Left),
		}

		if wi.down {
			c.active_widget_id = hovered_widget_id
		}

		if wi.released {
			c.active_text_input = nil
			c.active_widget_id = nil
		}

		return wi
	}

	return Widget_Interaction{}
}

Widget_Type :: distinct i32
Widget_Type_NONE := Widget_Type(0)

widget_register :: proc "contextless" (style: Widget_Style) -> Widget_Type {
	@(static) next_type := 1
	next_type += 1
	wt := Widget_Type(next_type)
	style_default_register(wt, style)
	return wt
}

Widget_Type_ROOT := widget_register(Widget_Style{})
root :: proc(c: ^Context, layout: Layout, caller := #caller_location, sub_id: int = 0) {
	widget_begin(c, Widget_Type_ROOT, layout, caller, sub_id)
}

Widget_Type_CONTAINER := widget_register(Widget_Style{})
container_begin :: proc(
	c: ^Context,
	layout: Layout,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, Widget_Type_CONTAINER, layout, caller, sub_id)
}

container_end :: proc(c: ^Context) {
	widget_end(c)
}

Widget_Type_PANEL := widget_register(
	Widget_Style {
		base = Style {
			background = Color{80, 80, 80, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
		},
	},
)
panel_begin :: proc(c: ^Context, layout: Layout, caller := #caller_location, sub_id: int = 0) {
	widget_begin(c, Widget_Type_PANEL, layout, caller, sub_id)
	background(c)
}

panel_end :: proc(c: ^Context) {
	widget_end(c)
}

panel :: proc(c: ^Context, layout: Layout, caller := #caller_location, sub_id: int = 0) {
	panel_begin(c, layout, caller, sub_id)
	panel_end(c)
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
			background = Color{90, 90, 90, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
		},
	},
)
button :: proc(
	c: ^Context,
	layout: Layout,
	txt: string,
	background_image := Sprite{},
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, Widget_Type_BUTTON, layout, caller, sub_id)
	defer widget_end(c)

	if c.widget_curr.interaction.down {
		c.widget_curr.draw_offset = {1, 1}
	}

	if background_image != {} {
		sprite(c, background_image, Rect{})
	} else {
		background(c)
	}
	if len(txt) > 0 {
		text(c, txt, .Center, .Center)
	}

	return c.widget_curr.interaction
}

Widget_Type_LABEL := widget_register(Widget_Style{})
label :: proc(
	c: ^Context,
	txt: string,
	h_align: Text_Align_H = .Left,
	v_align: Text_Align_V = .Top,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, Widget_Type_LABEL, layout_intrinsic(), caller, sub_id)
	text_style := text_style_curr(c)
	c.widget_curr.intrinsic_size = {text_width_style(text_style, txt), text_style.line_height}
	text(c, txt, h_align, v_align)
	widget_end(c)
}

label_sized :: proc(
	c: ^Context,
	layout: Layout,
	txt: string,
	h_align: Text_Align_H = .Left,
	v_align: Text_Align_V = .Top,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, Widget_Type_LABEL, layout, caller, sub_id)
	text(c, txt, h_align, v_align)
	widget_end(c)
}

Text_Input :: struct {
	text:        Text_Buffer,
	blink_rate:  time.Duration,
	_focused_ts: time.Time,
}

BLINK_RATE_DEFAULT: time.Duration : 750 * time.Millisecond

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
	layout: Layout,
	data: ^Text_Input,
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, Widget_Type_TEXT_INPUT, layout, caller, sub_id)
	defer widget_end(c)

	if c.widget_curr.interaction.released {
		c.active_text_input = data
		data._focused_ts = time.now()
	}

	txt := text_buffer_to_string(&data.text)

	background(c)
	offset := [2]f32{5, 5}
	if len(txt) > 0 do text(c, txt, offset)
	if data == c.active_text_input {
		blink_rate := data.blink_rate if data.blink_rate > 0 else BLINK_RATE_DEFAULT
		elapsed := time.diff(data._focused_ts, time.now())
		if (elapsed % blink_rate) < (blink_rate / 2) {
			text_style := text_style_curr(c)
			current_text_width := text_width_style(text_style, txt)
			x := offset.x + current_text_width + 4
			line_v(c, offset.y, offset.y + text_style.size, x, 2, text_style.color)
		}
	}

	return c.widget_curr.interaction
}

image :: proc(
	c: ^Context,
	layout: Layout,
	sp: Sprite,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, Widget_Type_CONTAINER, layout, caller, sub_id)
	sprite(c, sp, Rect{})
	widget_end(c)
}

spacer :: proc(c: ^Context, width, height: f32, caller := #caller_location, sub_id: int = 0) {
	widget_begin(c, Widget_Type_CONTAINER, layout_fixed(width, height), caller, sub_id)
	widget_end(c)
}

Scrollbox :: struct {
	scroll_step_px: f32, // optional config for scroll speed
	y_offset:       f32, // persists across frames
	// used within begin/end to get attributes of the widget
	_w:             ^Widget,
}

Widget_Type_SCROLLBOX := widget_register(
	Widget_Style {
		base = Style {
			background = Color{100, 100, 100, 255},
			border = Border_Style{type = .Square, thickness = 2, color = Color{0, 0, 0, 255}},
		},
	},
)
scrollbox_begin :: proc(
	c: ^Context,
	layout: Layout,
	data: ^Scrollbox,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, Widget_Type_SCROLLBOX, layout, caller, sub_id)

	data._w = c.widget_curr
	c.widget_curr.scrollbox = data
	background(c)

	append(&c.scrollbox_stack, data)
}

SCROLL_STEP_PX_DEFAULT :: 20
SCROLLBAR_WIDTH_PX_DEFAULT :: 20
SCROLLBAR_ALPHA_DEFAULT: u8 = 185

scrollbox_end :: proc(c: ^Context) {
	scrollbox := pop(&c.scrollbox_stack)
	scrollbox._w = nil
	widget_end(c)
}
