package exigent

import "base:intrinsics"
import "core:strings"

Widget :: struct {
	key:              Widget_Key,
	parent:           ^Widget,
	children:         [dynamic]^Widget,
	rect:             Rect,
	style:            Style,
	text:             string,
	text_pos:         [2]f32,
	text_style:       Text_Style,
	alpha:            u8,
	flags:            bit_set[Widget_Flags],
	border_style:     Border_Style,
	border_thickness: int,
	border_color:     Color,
	interaction:      Widget_Interaction,
}

// Create a uint enum and give one unique entry per widget
Widget_Key :: distinct uint

key :: proc(id: $T) -> Widget_Key where intrinsics.type_is_enum(T) {
	return Widget_Key(uint(id))
}

Widget_Flags :: enum {
	DrawBackground,
	DrawBorder,
}

Border_Style :: enum {
	None,
	Square,
	// Rounded,
}

widget_begin :: proc(
	c: ^Context,
	key: Widget_Key,
	r: Rect,
	border_style: Border_Style = .None,
	border_thickness: int = 0,
) {
	c.num_widgets += 1

	w := new(Widget, c.temp_allocator)
	w.alpha = 255
	w.rect = r
	w.border_style = border_style
	w.border_thickness = border_thickness

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

	widget_interaction(c, c.widget_curr)
}

widget_end :: proc(c: ^Context) {
	c.widget_curr.style = style_flat_copy(c)
	c.widget_curr.border_color = c.widget_curr.style.colors[Color_Type_BORDER]

	if len(c.widget_stack) > 0 {
		c.widget_curr = pop(&c.widget_stack)
	}
}

widget_flags :: proc(c: ^Context, flags: bit_set[Widget_Flags]) {
	c.widget_curr.flags += flags
}

widget_get_rect :: proc(c: ^Context) -> Rect {
	return c.widget_curr.rect
}

widget_text :: proc {
	widget_text_at_offset,
	widget_text_aligned,
}

Text_Align_H :: enum {
	Left,
	Center,
	Right,
}

Text_Align_V :: enum {
	Top,
	Center,
	Bottom,
}

widget_text_aligned :: proc(
	c: ^Context,
	text: string,
	h_align: Text_Align_H,
	v_align: Text_Align_V,
) {
	assert(!strings.contains(text, "\n"), "multiline text not supported yet")
	text := text_clip(c, text, c.widget_curr.rect)

	text_style := text_style_curr(c)
	r := widget_get_rect(c)
	tw := text_width(c, text)

	offset: [2]f32

	switch h_align {
	case .Left:
		offset.x = 0
	case .Center:
		offset.x = (r.width - f32(tw)) * 0.5
	case .Right:
		offset.x = r.width - f32(tw)
	}

	switch v_align {
	case .Top:
		offset.y = 0
	case .Center:
		offset.y = (r.height - text_style.line_height) * 0.5
	case .Bottom:
		offset.y = r.height - text_style.line_height
	}

	widget_text_at_offset(c, text, offset)
}

// Widgets support a single text string and will be automatically split on newlines
widget_text_at_offset :: proc(c: ^Context, text: string, offset: [2]f32) {
	assert(!strings.contains(text, "\n"), "multiline text not supported yet")

	c.widget_curr.text = text
	c.widget_curr.text_pos = [2]f32{c.widget_curr.rect.x, c.widget_curr.rect.y} + offset
	c.widget_curr.text_style = text_style_curr(c)
}

// pick the top-most widget at the mouse_pos
@(private)
widget_pick :: proc(w: ^Widget, mouse_pos: [2]f32) -> (focus: ^Widget, found: bool) {
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
		descendent_focus, found := widget_pick(child, mouse_pos)
		if found {
			return descendent_focus, true
		}
	}

	return w, true
}

Widget_Interaction :: struct {
	focused: bool, // hovered
	down:    bool, // held down for one or more frames
	pressed: bool, // single frame mouse press down
	clicked: bool, // single frame mouse released inside widget
}

@(private)
widget_interaction :: proc(c: ^Context, w: ^Widget) {
	widget_focus_key, ok := c.widget_focus_key.?
	if ok && c.widget_focus_key == w.key {
		w.interaction.focused = true
		w.interaction.down = input_is_mouse_down(c, .Left)
		w.interaction.pressed = input_is_mouse_pressed(c, .Left)
		w.interaction.clicked = input_is_mouse_clicked(c, .Left)
	}
}

panel :: proc(c: ^Context, key: Widget_Key, r: Rect) {
	widget_begin(c, key, r)
	widget_flags(c, {.DrawBackground})
	widget_end(c)
}

button :: proc(c: ^Context, key: Widget_Key, r: Rect, text: string) -> Widget_Interaction {
	widget_begin(c, key, r, .Square, 2)
	widget_flags(c, {.DrawBackground, .DrawBorder})
	widget_text(c, text, .Center, .Center)
	widget_end(c)
	return c.widget_curr.interaction
}
