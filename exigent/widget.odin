package exigent

import "base:runtime"
import "core:hash"
import "core:mem"
import "core:time"

Widget :: struct {
	id:             Widget_ID,
	parent:         ^Widget,
	children:       [dynamic]^Widget,
	layout:         Layout,
	options:        Container_Options,
	measured_size:  [2]f32,
	content_size:   [2]f32,
	intrinsic_size: [2]f32,
	rect:           Rect, // The inner size of the widget
	clip:           Rect, // The outer size (with borders) of the widget, used for clipping
	style:          Style,
	interaction:    Widget_Interaction,
	draw_cmds:      [dynamic]Widget_Draw_Command,
	draw_offset:    [2]f32,
	scrollbox:      ^Scrollbox,
}

Anchor_Point :: enum {
	Top_Left,
	Top_Center,
	Top_Right,
	Center_Left,
	Center,
	Center_Right,
	Bottom_Left,
	Bottom_Center,
	Bottom_Right,
}

Widget_Positioning :: enum {
	Flow,
	Anchored,
}

Container_Options :: struct {
	positioning: Widget_Positioning,
	anchor:      Anchor_Point,
	pivot:       Maybe(Anchor_Point),
	offset:      [2]f32,
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
	layout: Layout,
	options := Container_Options{},
	interactable := true,
	caller: runtime.Source_Code_Location,
	sub_id: int = 0,
) {
	assert(c.widget_curr != nil || c.layer_curr != nil, "widget_begin without layer_begin")

	w := new(Widget, c.temp_allocator)
	id := widget_create_id(c, caller, sub_id)
	w.id = id
	w.layout = layout
	w.options = options

	if interactable {
		w.interaction = widget_interaction(c, id)
	}

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

	if c.layer_curr != nil && c.layer_curr.root == nil {
		c.layer_curr.root = c.widget_curr
	}
}

widget_end :: proc(c: ^Context) {
	if len(c.widget_stack) > 0 {
		c.widget_curr = pop(&c.widget_stack)
	} else {
		c.widget_curr = nil
	}
}

Widget_ID :: distinct u32

@(private = "file")
Raw_Widget_ID :: struct #packed {
	scope_id: u32,
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
	scope_id: u32
	if c.widget_curr != nil {
		scope_id = u32(c.widget_curr.id)
	} else if c.layer_curr != nil {
		scope_id = u32(c.layer_curr.id)
	}
	raw := Raw_Widget_ID {
		scope_id = scope_id,
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

@(private)
layer_pick :: proc(
	c: ^Context,
	mouse_pos: [2]f32,
) -> (
	hovered: ^Widget,
	captured: bool,
	found: bool,
) {
	#reverse for &layer in c.layers {
		hovered, ok := widget_pick(layer.root, mouse_pos)
		if !ok {
			continue
		}
		if hovered == layer.root && !layer.options.capture_pointer_empty {
			continue
		}
		return hovered, hovered != layer.root || layer.options.capture_pointer_empty, true
	}

	return nil, false, false
}

Widget_Interaction :: struct {
	disabled: bool,
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
			active_text_input_clear(c)
			c.active_widget_id = nil
		}

		return wi
	}

	return Widget_Interaction{}
}

background :: proc(c: ^Context, color: Color) {
	style := style_get(c)
	style.background = color
	style_set(c, style)
	append(&c.widget_curr.draw_cmds, Widget_Draw_Background{})
}

border :: proc(c: ^Context, border: Border_Style) {
	style := style_get(c)
	style.border = border
	style_set(c, style)
}

scrollbar :: proc(c: ^Context, width: f32, alpha: u8) {
	style := style_get(c)
	style.scrollbar_width = width
	style.scrollbar_alpha = alpha
	style_set(c, style)
}

is_active :: proc(c: ^Context) -> bool {
	return c.widget_curr.id == c.active_widget_id
}

is_hovered :: proc(c: ^Context) -> bool {
	return c.widget_curr.id == c.hovered_widget_id
}

layer_begin :: proc(
	c: ^Context,
	layout: Layout,
	options := Layer_Options{},
	caller := #caller_location,
	sub_id: int = 0,
) {
	assert(c.layer_curr == nil, "layers cannot be nested")
	assert(c.widget_curr == nil, "layer_begin must not be called inside a widget")

	layer := Layer {
		id      = widget_create_id(c, caller, sub_id),
		options = options,
	}
	append(&c.layers, layer)
	c.layer_curr = &c.layers[len(c.layers) - 1]
	widget_begin(c, layout, interactable = false, caller = caller, sub_id = sub_id)
}

layer_end :: proc(c: ^Context) {
	assert(c.layer_curr != nil, "layer_end without layer_begin")
	assert(c.widget_curr == c.layer_curr.root, "every widget_begin must have a widget_end")

	widget_end(c)
	c.layer_curr = nil
}

container_begin :: proc(
	c: ^Context,
	layout: Layout,
	options := Container_Options{},
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, layout, options = options, caller = caller, sub_id = sub_id)
}

container_end :: proc(c: ^Context) {
	widget_end(c)
}

panel_begin :: proc(
	c: ^Context,
	layout: Layout,
	options := Container_Options{},
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, layout, options = options, caller = caller, sub_id = sub_id)
	background(c, c.theme.color.surface)
	border(c, {type = .Square, thickness = 1, color = c.theme.color.border})
}

panel_end :: proc(c: ^Context) {
	widget_end(c)
}

button :: proc(
	c: ^Context,
	layout: Layout,
	txt: string,
	background_image := Sprite{},
	bg_color: Color = {},
	text_color: Color = {},
	disabled := false,
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, layout, interactable = !disabled, caller = caller, sub_id = sub_id)
	defer widget_end(c)

	button_text_color := text_color if text_color != {} else c.theme.color.on_primary

	if disabled {
		c.widget_curr.interaction.disabled = true
		button_text_color = c.theme.color.fg_muted
	} else if c.widget_curr.interaction.down {
		c.widget_curr.draw_offset = {1, 1}
	}

	if background_image != {} {
		sprite(c, background_image, Rect{})
		if disabled {
			rect(c, Rect{}, Color{c.theme.color.surface.r, c.theme.color.surface.g, c.theme.color.surface.b, 180})
		}
	} else {
		background_color := bg_color if bg_color != {} else c.theme.color.primary
		if disabled {
			background_color = color_blend(background_color, c.theme.color.surface, 0.72)
		} else if is_active(c) {
			background_color = color_blend(background_color, c.theme.color.on_primary, 0.12)
		} else if is_hovered(c) {
			background_color = color_blend(background_color, Color{0, 0, 0, background_color.a}, 0.18)
		}
		background(c, background_color)
		border(c, {type = .Square, thickness = 1, color = c.theme.color.border})
	}

	if len(txt) > 0 {
		text(c, txt, Text_Align_H.Center, Text_Align_V.Center, text_style(c, .Body, button_text_color))
	}

	return c.widget_curr.interaction
}

label :: proc(
	c: ^Context,
	txt: string,
	h_align: Text_Align_H = .Left,
	v_align: Text_Align_V = .Top,
	role: Text_Role = .Body,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, layout_intrinsic(), caller = caller, sub_id = sub_id)
	text_style := text_style(c, role)
	c.widget_curr.intrinsic_size = {text_width_style(c, text_style, txt), text_style.line_height}
	text(c, txt, h_align, v_align, text_style)
	widget_end(c)
}

label_sized :: proc(
	c: ^Context,
	layout: Layout,
	txt: string,
	h_align: Text_Align_H = .Left,
	v_align: Text_Align_V = .Top,
	role: Text_Role = .Body,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, layout, caller = caller, sub_id = sub_id)
	text(c, txt, h_align, v_align, text_style(c, role))
	widget_end(c)
}

Text_Input :: struct {
	text:        Text_Buffer,
	blink_rate:  time.Duration,
	_focused_ts: time.Time,
}

BLINK_RATE_DEFAULT: time.Duration : 750 * time.Millisecond

text_input :: proc(
	c: ^Context,
	layout: Layout,
	data: ^Text_Input,
	caller := #caller_location,
	sub_id: int = 0,
) -> Widget_Interaction {
	widget_begin(c, layout, caller = caller, sub_id = sub_id)
	defer widget_end(c)

	if c.widget_curr.interaction.released {
		c.active_text_input = data
		c.active_text_input_widget_id = c.widget_curr.id
		c.active_text_input_layer_id = c.layer_curr.id
		c.active_text_input_seen = true
		data._focused_ts = time.now()
	}
	if data == c.active_text_input &&
	   c.widget_curr.id == c.active_text_input_widget_id &&
	   c.layer_curr.id == c.active_text_input_layer_id {
		c.active_text_input_seen = true
	}

	txt := text_buffer_to_string(&data.text)

	background(c, c.theme.color.elevated)
	border(c, {type = .Square, thickness = 1, color = c.theme.color.border})
	offset := [2]f32{c.theme.spacing.sm, c.theme.spacing.sm}
	input_text_style := text_style_curr(c)
	if len(txt) > 0 do text(c, txt, offset, input_text_style)
	if data == c.active_text_input {
		blink_rate := data.blink_rate if data.blink_rate > 0 else BLINK_RATE_DEFAULT
		elapsed := time.diff(data._focused_ts, time.now())
		if (elapsed % blink_rate) < (blink_rate / 2) {
			current_text_width := text_width_style(c, input_text_style, txt)
			x := offset.x + current_text_width + 4
			line_v(c, offset.y, offset.y + input_text_style.size, x, 2, input_text_style.color)
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
	widget_begin(c, layout, caller = caller, sub_id = sub_id)
	sprite(c, sp, Rect{})
	widget_end(c)
}

spacer :: proc(c: ^Context, width, height: f32, caller := #caller_location, sub_id: int = 0) {
	widget_begin(c, layout_fixed(width, height), caller = caller, sub_id = sub_id)
	widget_end(c)
}

Scrollbox :: struct {
	scroll_step_px: f32, // optional config for scroll speed
	y_offset:       f32, // persists across frames
	// used within begin/end to get attributes of the widget
	_w:             ^Widget,
}

scrollbox_begin :: proc(
	c: ^Context,
	layout: Layout,
	data: ^Scrollbox,
	caller := #caller_location,
	sub_id: int = 0,
) {
	widget_begin(c, layout, caller = caller, sub_id = sub_id)

	data._w = c.widget_curr
	c.widget_curr.scrollbox = data
	background(
		c,
		color_blend(c.theme.color.surface, Color{0, 0, 0, c.theme.color.surface.a}, 0.14),
	)
	border(c, {type = .Square, thickness = 1, color = c.theme.color.border})
	scrollbar(c, c.theme.spacing.lg, 185)

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
