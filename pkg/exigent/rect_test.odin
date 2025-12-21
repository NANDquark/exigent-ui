package exigent

import "core:testing"

@(test)
test_rect_cut :: proc(t: ^testing.T) {
	TestCase :: struct {
		desc:     string,
		r:        Rect,
		c:        Cut,
		expected: [2]Rect,
	}

	cases := []TestCase {
		{
			desc = "cut half horizontally on positive",
			r = Rect{0, 0, 40, 40},
			c = CUT_H_HALF,
			expected = [2]Rect{Rect{0, 0, 20, 40}, Rect{20, 0, 20, 40}},
		},
		{
			desc = "cut half horizontally on negative",
			r = Rect{-40, -40, 40, 40},
			c = CUT_H_HALF,
			expected = [2]Rect{Rect{-40, -40, 20, 40}, Rect{-20, -40, 20, 40}},
		},
		{
			desc = "cut half vertically on positive",
			r = Rect{0, 0, 40, 40},
			c = CUT_V_HALF,
			expected = [2]Rect{Rect{0, 0, 40, 20}, Rect{0, 20, 40, 20}},
		},
		{
			desc = "cut half vertically on negative",
			r = Rect{-40, -40, 40, 40},
			c = CUT_V_HALF,
			expected = [2]Rect{Rect{-40, -40, 40, 20}, Rect{-40, -20, 40, 20}},
		},
		{
			desc = "cut 10 pixels horizontally on positive",
			r = Rect{0, 0, 40, 40},
			c = Cut{type = .Pixel, dim = .Horizontal, value = 10},
			expected = [2]Rect{Rect{0, 0, 10, 40}, Rect{10, 0, 30, 40}},
		},
		{
			desc = "cut 10 pixels horizontally on negative",
			r = Rect{-40, -40, 40, 40},
			c = Cut{type = .Pixel, dim = .Horizontal, value = 10},
			expected = [2]Rect{Rect{-40, -40, 10, 40}, Rect{-30, -40, 30, 40}},
		},
		{
			desc = "cut 10 pixels vertically on positive",
			r = Rect{0, 0, 40, 40},
			c = Cut{type = .Pixel, dim = .Vertical, value = 10},
			expected = [2]Rect{Rect{0, 0, 40, 10}, Rect{0, 10, 40, 30}},
		},
		{
			desc = "cut 10 pixels vertically on negative",
			r = Rect{-40, -40, 40, 40},
			c = Cut{type = .Pixel, dim = .Vertical, value = 10},
			expected = [2]Rect{Rect{-40, -40, 40, 10}, Rect{-40, -30, 40, 30}},
		},
	}

	for c in cases {
		r1, r2 := rect_cut(c.r, c.c)
		testing.expectf(
			t,
			r1 == c.expected[0],
			"\n%s\nexpected r1: %v,\nactual: %v",
			c.desc,
			c.expected[0],
			r1,
		)
		testing.expectf(
			t,
			r2 == c.expected[1],
			"\n%s\nexpected r2: %v,\nactual: %v",
			c.desc,
			c.expected[1],
			r2,
		)
	}
}

@(test)
test_rect_inset :: proc(t: ^testing.T) {
	TestCaseInset :: struct {
		desc:     string,
		r:        Rect,
		i:        Inset,
		expected: Rect,
	}

	cases := []TestCaseInset {
		{
			desc = "positive top inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 10,
					Inset_Side.Right = 0,
					Inset_Side.Bottom = 0,
					Inset_Side.Left = 0,
				},
				sides = {.Top},
			},
			expected = Rect{0, 10, 100, 90},
		},
		{
			desc = "positive left inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 0,
					Inset_Side.Right = 0,
					Inset_Side.Bottom = 0,
					Inset_Side.Left = 5,
				},
				sides = {.Left},
			},
			expected = Rect{5, 0, 95, 100},
		},
		{
			desc = "positive right inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 0,
					Inset_Side.Right = 3,
					Inset_Side.Bottom = 0,
					Inset_Side.Left = 0,
				},
				sides = {.Right},
			},
			expected = Rect{0, 0, 97, 100},
		},
		{
			desc = "positive bottom inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 0,
					Inset_Side.Right = 0,
					Inset_Side.Bottom = 2,
					Inset_Side.Left = 0,
				},
				sides = {.Bottom},
			},
			expected = Rect{0, 0, 100, 98},
		},
		{
			desc = "negative top inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = -10,
					Inset_Side.Right = 0,
					Inset_Side.Bottom = 0,
					Inset_Side.Left = 0,
				},
				sides = {.Top},
			},
			expected = Rect{0, -10, 100, 110},
		},
		{
			desc = "negative left inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 0,
					Inset_Side.Right = 0,
					Inset_Side.Bottom = 0,
					Inset_Side.Left = -5,
				},
				sides = {.Left},
			},
			expected = Rect{-5, 0, 105, 100},
		},
		{
			desc = "negative right inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 0,
					Inset_Side.Right = -3,
					Inset_Side.Bottom = 0,
					Inset_Side.Left = 0,
				},
				sides = {.Right},
			},
			expected = Rect{0, 0, 103, 100},
		},
		{
			desc = "negative bottom inset",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {
					Inset_Side.Top = 0,
					Inset_Side.Right = 0,
					Inset_Side.Bottom = -2,
					Inset_Side.Left = 0,
				},
				sides = {.Bottom},
			},
			expected = Rect{0, 0, 100, 102},
		},
		{
			desc = "positive all sides",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {.Top = 1, .Right = 2, .Bottom = 3, .Left = 4},
				sides = {.Top, .Right, .Bottom, .Left},
			},
			expected = Rect{4, 1, 94, 96},
		},
		{
			desc = "negative all sides",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {.Top = -1, .Right = -2, .Bottom = -3, .Left = -4},
				sides = {.Top, .Right, .Bottom, .Left},
			},
			expected = Rect{-4, -1, 106, 104},
		},
		{
			desc = "mixed insets: positive top and left, negative right and bottom",
			r = Rect{0, 0, 100, 100},
			i = Inset {
				amount = {.Top = 5, .Left = 10, .Right = -2, .Bottom = -3},
				sides = {.Top, .Left, .Right, .Bottom},
			},
			expected = Rect{10, 5, 92, 98},
		},
	}

	for c in cases {
		result := rect_inset(c.r, c.i)
		testing.expectf(
			t,
			result == c.expected,
			"\n%s\nexpected: %v,\nactual: %v",
			c.desc,
			c.expected,
			result,
		)
	}
}
