package exigent

import "base:runtime"

Widget_Style :: struct {
	base:   Style,
	hover:  Style,
	active: Style,
}

Style :: struct {
	background:      Color,
	border:          Border_Style,
	scrollbar_width: f32,
	scrollbar_alpha: u8,
}

Color :: [4]u8

Border_Style :: struct {
	type:      Border_Type,
	thickness: f32,
	color:     Color,
}

Border_Type :: enum {
	None,
	Square,
}

Widget_Type_Style :: struct {
	type:  Widget_Type,
	style: Widget_Style,
}

// TODO: This allocated at a global scope doesn't follow the pattern to allow
// the caller to decide how allocations work, it should be cleaned up
DEFAULT_STYLES := map[Widget_Type]Widget_Style{}

@(private)
style_default_register :: proc "contextless" (type: Widget_Type, style: Widget_Style) {
	if _, ok := DEFAULT_STYLES[type]; ok {
		context = runtime.default_context()
		panic("overriding existing default widget style")
	}
	DEFAULT_STYLES[type] = style
}

// Blend t percent of c2 into c1. This function uses float math so could be
// faster.
color_blend :: proc(c1, c2: Color, t: f32) -> (cb: Color) {
	assert(t >= 0 && t <= 1.0, "t must be a value from 0 and 1 (inclusive)")
	cb.r = u8(f32(c1.r) + (f32(c2.r) - f32(c1.r)) * t + 0.5)
	cb.g = u8(f32(c1.g) + (f32(c2.g) - f32(c1.g)) * t + 0.5)
	cb.b = u8(f32(c1.b) + (f32(c2.b) - f32(c1.b)) * t + 0.5)
	cb.a = u8(f32(c1.a) + (f32(c2.a) - f32(c1.a)) * t + 0.5)
	return cb
}

// Calculate a color that would have visible contrast with c Color by blending
// white or black based on perceived luminance
color_contrast :: proc(c: Color) -> Color {
	luminance := (f32(c.r) * 0.2126 + f32(c.g) * 0.7152 + f32(c.b) * 0.0722) / 255.0
	overlay := Color{0, 0, 0, c.a}
	if luminance < 0.5 do overlay = Color{255, 255, 255, c.a}
	distance_from_edge := abs(luminance - 0.5)
	t := 0.25 + (0.20 * (1.0 - (distance_from_edge * 2.0)))
	return color_blend(c, overlay, t)
}

style_push :: proc(c: ^Context, type: Widget_Type, style: Widget_Style) {
	assert(type != Widget_Type_NONE, "invalid widget type (0)")
	append(&c.style_stack, Widget_Type_Style{type = type, style = style})
}

style_pop :: proc(c: ^Context) {
	assert(len(c.style_stack) > 1)
	pop(&c.style_stack)
}

style_get :: proc(c: ^Context, type: Widget_Type) -> Widget_Style {
	assert(type != Widget_Type_NONE, "invalid widget type (0)")
	for wts in c.style_stack {
		if wts.type == type {
			return wts.style
		}
	}
	for wtype, wstyle in c.style_default {
		if wtype == type {
			return wstyle
		}
	}
	panic("missing style for widget")
}

// Get the current widget's style, accounting for hover, active, or none (base)
style_curr :: proc(c: ^Context) -> Style {
	style := c.widget_curr.style.base
	if c.widget_curr.id == c.active_widget_id && c.widget_curr.style.active != {} {
		style = c.widget_curr.style.active
	} else if c.widget_curr.id == c.hovered_widget_id && c.widget_curr.style.hover != {} {
		style = c.widget_curr.style.hover
	}
	return style
}

