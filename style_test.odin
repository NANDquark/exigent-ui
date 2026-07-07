package exigent

import "core:testing"

@(test)
test_color_blend :: proc(t: ^testing.T) {
	TestCase :: struct {
		desc:     string,
		c1, c2:   Color,
		factor:   f32,
		expected: Color,
	}

	cases := []TestCase {
		{
			desc = "blend 0.0",
			c1 = Color{100, 100, 100, 255},
			c2 = Color{200, 200, 200, 255},
			factor = 0.0,
			expected = Color{100, 100, 100, 255},
		},
		{
			desc = "blend 1.0",
			c1 = Color{100, 100, 100, 255},
			c2 = Color{200, 200, 200, 255},
			factor = 1.0,
			expected = Color{200, 200, 200, 255},
		},
		{
			desc = "blend 0.5",
			c1 = Color{100, 100, 100, 255},
			c2 = Color{200, 200, 200, 255},
			factor = 0.5,
			expected = Color{150, 150, 150, 255},
		},
		{
			desc = "blend 0.3 (rounding check)",
			c1 = Color{0, 0, 0, 255},
			c2 = Color{255, 255, 255, 255},
			factor = 0.3,
			expected = Color{77, 77, 77, 255},
		},
	}

	for c in cases {
		actual := color_blend(c.c1, c.c2, c.factor)
		testing.expectf(
			t,
			actual == c.expected,
			"\n%s\nexpected: %v,\nactual: %v",
			c.desc,
			c.expected,
			actual,
		)
	}
}

@(test)
test_theme_light_provides_semantic_tokens :: proc(t: ^testing.T) {
	th := theme_light(nil)

	testing.expect_value(t, th.color.bg, Color{255, 255, 255, 255})
	testing.expect_value(t, th.color.primary, Color{9, 105, 218, 255})
	testing.expect_value(t, th.spacing.md, f32(12))
	testing.expect_value(t, th.font.size_md, f32(14))
}

@(test)
test_theme_with_primary_updates_accent_tokens :: proc(t: ^testing.T) {
	accent := Color{20, 40, 80, 255}
	th := theme_with_primary(theme_light(nil), accent)

	testing.expect_value(t, th.color.primary, accent)
	testing.expect_value(t, th.color.on_primary, Color{255, 255, 255, 255})
	testing.expect_value(t, th.color.selection, Color{20, 40, 80, 77})
}

@(test)
test_style_get_reads_current_context_theme :: proc(t: ^testing.T) {
	c := fixture_context_create()
	defer fixture_context_delete(c)

	theme := theme_light(nil)
	theme.color.primary = Color{11, 22, 33, 255}
	theme.color.border = Color{44, 55, 66, 255}
	theme_set(c, theme)

	button_style := style_get(c, Widget_Type_BUTTON)
	testing.expect_value(t, button_style.base.background, theme.color.primary)
	testing.expect_value(t, button_style.base.border.color, theme.color.border)
}
