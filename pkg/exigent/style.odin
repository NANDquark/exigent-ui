package exigent


Style :: struct {
	border_style: Border_Style,
	// TODO: we should swap to a registry based system that the user can extend
	colors:       map[Color_Type]Color,
}

Color :: [3]u8
WHITE :: Color{255, 255, 255}
BLACK :: Color{0, 0, 0}

// Blend t percent of c2 into c1. This function uses float math so could be
// faster.
color_blend :: proc(c1, c2: Color, t: f32) -> (cb: Color) {
	assert(t >= 0 && t <= 1.0, "t must be a value from 0 and 1 (inclusive)")
	cb.r = u8(f32(c1.r) + (f32(c2.r) - f32(c1.r)) * t + 0.5)
	cb.g = u8(f32(c1.g) + (f32(c2.g) - f32(c1.g)) * t + 0.5)
	cb.b = u8(f32(c1.b) + (f32(c2.b) - f32(c1.b)) * t + 0.5)
	return cb
}

Color_Type :: distinct string
Color_Type_BACKGROUND :: Color_Type("background")
Color_Type_BACKGROUND_HOVERED :: Color_Type("background_hovered")
Color_Type_BACKGROUND_ACTIVE :: Color_Type("background_active") // ex. clicked
Color_Type_BORDER :: Color_Type("border)")
Color_Type_BORDER_HOVERED :: Color_Type("border_hovered")
Color_Type_BORDER_ACTIVE :: Color_Type("border_active")
Color_Type_INPUT :: Color_Type("input")

style_default_init :: proc(style: ^Style, allocator := context.allocator) {
	style.border_style = Border_Style {
		color     = Color{200, 200, 200},
		type      = .Square,
		thickness = 2,
	}

	style.colors = make(map[Color_Type]Color, allocator)

	style.colors[Color_Type_BACKGROUND] = Color{128, 128, 128}
	// style.colors[Color_Type_BACKGROUND_HOVERED] = color_blend(
	// 	style.colors[Color_Type_BACKGROUND],
	// 	WHITE,
	// 	0.3,
	// )
	// style.colors[Color_Type_BACKGROUND_ACTIVE] = color_blend(
	// 	style.colors[Color_Type_BACKGROUND],
	// 	BLACK,
	// 	0.3,
	// )

	// style.colors[Color_Type_INPUT] = color_blend(style.colors[Color_Type_BACKGROUND], WHITE, 0.5)
}

style_push :: proc(c: ^Context) {
	style := Style {
		colors = make(map[Color_Type]Color, c.temp_allocator),
	}
	append(&c.style_stack, style)
}

style_set_color :: proc(c: ^Context, ct: Color_Type, color: Color) {
	assert(len(c.style_stack) > 1, "must style_push before style_set_color")
	c.style_stack[len(c.style_stack) - 1].colors[ct] = color
}

style_get_color :: proc(c: ^Context, ct: Color_Type) -> Color {
	for s in c.style_stack {
		if c, found := s.colors[ct]; found {
			return c
		}
	}
	panic("could not find Colour_Type in style_stack during style_get_color")
}

style_pop :: proc(c: ^Context) {
	assert(len(c.style_stack) > 1)
	pop(&c.style_stack)
}

// Check whether a specific style Color_Type has been overriden by the caller.
// This is useful for widget internals which don't want to override if the
// caller already has done so.
style_has_override :: proc(c: ^Context, ct: Color_Type) -> bool {
	if len(c.style_stack) <= 1 {
		return false
	}

	// iterate all style overrides (not [0]) to see if the Color_Type is there
	for i in 0 ..< len(c.style_stack) - 1 {
		s := c.style_stack[i]
		if _, found := s.colors[ct]; found {
			return true
		}
	}

	return false
}

// Produces a flattened copy of the style stack for use in a widget
@(private)
style_flat_copy :: proc(c: ^Context) -> Style {
	colors_copy := make(map[Color_Type]Color, c.temp_allocator)
	border_style: Border_Style

	// by iterating forward through the style array when we append style overrides
	// to the end the result is overrides replace default or earlier overrides
	for s in c.style_stack {
		// flatten colours across multiple Style structs
		for ct, c in s.colors {
			colors_copy[ct] = c
		}
		// get first border style but skip Style structs with no border style
		if border_style == {} && s.border_style != {} {
			border_style = s.border_style
		}
	}

	return Style{colors = colors_copy, border_style = border_style}
}

Border_Style :: struct {
	type:      Border_Type,
	thickness: int,
	color:     Color,
}

Border_Type :: enum {
	None,
	Square,
	// Rounded,
}
