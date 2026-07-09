package exigent

Theme :: struct {
	color:   Theme_Colors,
	spacing: Theme_Spacing,
	font:    Theme_Font,
}

Theme_Colors :: struct {
	bg:         Color,
	surface:    Color,
	elevated:   Color,
	border:     Color,
	fg:         Color,
	fg_muted:   Color,
	primary:    Color,
	on_primary: Color,
	selection:  Color,
	success:    Color,
	warning:    Color,
	danger:     Color,
}

Theme_Spacing :: struct {
	xs: f32,
	sm: f32,
	md: f32,
	lg: f32,
	xl: f32,
}

Theme_Font :: struct {
	font:         rawptr,
	spacing:      f32,
	line_scale:   f32,
	size_xs:      f32,
	size_sm:      f32,
	size_md:      f32,
	size_lg:      f32,
	size_xl:      f32,
	size_display: f32,
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

rgb :: proc(hex: u32) -> Color {
	return Color{u8(hex >> 16), u8(hex >> 8), u8(hex), 255}
}

rgba :: proc(hex: u32) -> Color {
	return Color{u8(hex >> 24), u8(hex >> 16), u8(hex >> 8), u8(hex)}
}

theme_dark :: proc(font: rawptr) -> Theme {
	return Theme {
		color = {
			bg = rgb(0x0f1115),
			surface = rgb(0x17191e),
			elevated = rgb(0x21242b),
			border = rgb(0x2e323a),
			fg = rgb(0xe6edf3),
			fg_muted = rgb(0x8b95a3),
			primary = rgb(0x3b82f6),
			on_primary = rgb(0xffffff),
			selection = rgba(0x3b82f659),
			success = rgb(0x2ea043),
			warning = rgb(0xd29922),
			danger = rgb(0xe5484d),
		},
		spacing = theme_default_spacing(),
		font = theme_default_font(font),
	}
}

theme_light :: proc(font: rawptr) -> Theme {
	return Theme {
		color = {
			bg = rgb(0xffffff),
			surface = rgb(0xf6f8fa),
			elevated = rgb(0xffffff),
			border = rgb(0xd0d7de),
			fg = rgb(0x1f2328),
			fg_muted = rgb(0x59636e),
			primary = rgb(0x0969da),
			on_primary = rgb(0xffffff),
			selection = rgba(0x0969da40),
			success = rgb(0x1a7f37),
			warning = rgb(0x9a6700),
			danger = rgb(0xcf222e),
		},
		spacing = theme_default_spacing(),
		font = theme_default_font(font),
	}
}

theme_with_primary :: proc(base: Theme, accent: Color) -> Theme {
	t := base
	t.color.primary = accent
	if color_luminance(accent) < 0.5 {
		t.color.on_primary = Color{255, 255, 255, 255}
	} else {
		t.color.on_primary = Color{0, 0, 0, 255}
	}
	t.color.selection = accent
	t.color.selection.a = 77
	return t
}

@(private)
theme_default_spacing :: proc() -> Theme_Spacing {
	return {xs = 4, sm = 8, md = 12, lg = 16, xl = 24}
}

@(private)
theme_default_font :: proc(font: rawptr) -> Theme_Font {
	return {
		font = font,
		spacing = 1,
		line_scale = 1.15,
		size_xs = 11,
		size_sm = 13,
		size_md = 14,
		size_lg = 18,
		size_xl = 24,
		size_display = 36,
	}
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

// Darken color c1 by blending with t percent of black
color_darken :: proc(c1: Color, t: f32) -> Color {
	return color_blend(c1, Color{0, 0, 0, c1.a}, t)
}

// Lighten color c1 by blending with t percent of white
color_lighten :: proc(c1: Color, t: f32) -> Color {
	return color_blend(c1, Color{255, 255, 255, c1.a}, t)
}

color_luminance :: proc(c: Color) -> f32 {
	return (f32(c.r) * 0.2126 + f32(c.g) * 0.7152 + f32(c.b) * 0.0722) / 255.0
}

// Calculate a color that would have visible contrast with c Color by blending
// white or black based on perceived luminance
color_contrast :: proc(c: Color) -> Color {
	luminance := color_luminance(c)
	overlay := Color{0, 0, 0, c.a}
	if luminance < 0.5 do overlay = Color{255, 255, 255, c.a}
	distance_from_edge := abs(luminance - 0.5)
	t := 0.25 + (0.20 * (1.0 - (distance_from_edge * 2.0)))
	return color_blend(c, overlay, t)
}

style_get :: proc(c: ^Context) -> Style {
	return c.widget_curr.style
}

style_set :: proc(c: ^Context, style: Style) {
	c.widget_curr.style = style
}
