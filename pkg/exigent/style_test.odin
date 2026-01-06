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

