package exigent

Style :: struct {
	// TODO: we should swap to a registry based system that the user can extend
	colors: map[Color_Type]Color,
}

Color :: [3]u8

Color_Type :: distinct string
Color_Type_BACKGROUND :: Color_Type("background")

style_default_init :: proc(style: ^Style, allocator := context.allocator) {
	style.colors = map[Color_Type]Color{}
	style.colors[Color_Type_BACKGROUND] = Color{128, 128, 128}
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

style_pop :: proc(c: ^Context) {
	assert(len(c.style_stack) > 1)
	pop(&c.style_stack)
}

// Produces a flattened copy of the style stack for use in a widget
@(private)
style_flat_copy :: proc(c: ^Context) -> Style {
	colors_copy := make(map[Color_Type]Color, c.temp_allocator)

	// by iterating forward through the style array when we append style overrides
	// to the end the result is overrides replace default or earlier overrides
	for s in c.style_stack {
		for ct, c in s.colors {
			colors_copy[ct] = c
		}
	}

	return Style{colors = colors_copy}
}
