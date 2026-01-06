package exigent

import "core:testing"

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
			desc = "zero insets",
			r = Rect{0, 0, 100, 100},
			i = Inset{0, 0, 0, 0},
			expected = Rect{0, 0, 100, 100},
		},
		{
			desc = "positive top inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 10, Right = 0, Bottom = 0, Left = 0},
			expected = Rect{0, 10, 100, 90},
		},
		{
			desc = "positive left inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 0, Right = 0, Bottom = 0, Left = 5},
			expected = Rect{5, 0, 95, 100},
		},
		{
			desc = "positive right inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 0, Right = 3, Bottom = 0, Left = 0},
			expected = Rect{0, 0, 97, 100},
		},
		{
			desc = "positive bottom inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 0, Right = 0, Bottom = 2, Left = 0},
			expected = Rect{0, 0, 100, 98},
		},
		{
			desc = "negative top inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = -10, Right = 0, Bottom = 0, Left = 0},
			expected = Rect{0, -10, 100, 110},
		},
		{
			desc = "negative left inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 0, Right = 0, Bottom = 0, Left = -5},
			expected = Rect{-5, 0, 105, 100},
		},
		{
			desc = "negative right inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 0, Right = -3, Bottom = 0, Left = 0},
			expected = Rect{0, 0, 103, 100},
		},
		{
			desc = "negative bottom inset",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 0, Right = 0, Bottom = -2, Left = 0},
			expected = Rect{0, 0, 100, 102},
		},
		{
			desc = "positive all sides",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 1, Right = 2, Bottom = 3, Left = 4},
			expected = Rect{4, 1, 94, 96},
		},
		{
			desc = "negative all sides",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = -1, Right = -2, Bottom = -3, Left = -4},
			expected = Rect{-4, -1, 106, 104},
		},
		{
			desc = "mixed insets: positive top and left, negative right and bottom",
			r = Rect{0, 0, 100, 100},
			i = Inset{Top = 5, Left = 10, Right = -2, Bottom = -3},
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

@(test)
test_rect_cut_side :: proc(t: ^testing.T) {
	TestCase :: struct {
		desc:              string,
		initial:           Rect,
		pixels:            f32,
		cut_func:          proc(_: ^Rect, _: f32) -> Rect,
		expected_returned: Rect,
		expected_modified: Rect,
	}

	cases := []TestCase {
		{
			desc = "cut left 10 pixels from positive rect",
			initial = Rect{0, 0, 100, 100},
			pixels = 10,
			cut_func = rect_cut_left,
			expected_returned = Rect{0, 0, 10, 100},
			expected_modified = Rect{10, 0, 90, 100},
		},
		{
			desc = "cut full width from left",
			initial = Rect{0, 0, 100, 100},
			pixels = 100,
			cut_func = rect_cut_left,
			expected_returned = Rect{0, 0, 100, 100},
			expected_modified = Rect{100, 0, 0, 100},
		},
		{
			desc = "cut left 5 pixels from negative rect",
			initial = Rect{-50, -50, 100, 100},
			pixels = 5,
			cut_func = rect_cut_left,
			expected_returned = Rect{-50, -50, 5, 100},
			expected_modified = Rect{-45, -50, 95, 100},
		},
		{
			desc = "cut right 20 pixels from positive rect",
			initial = Rect{0, 0, 100, 100},
			pixels = 20,
			cut_func = rect_cut_right,
			expected_returned = Rect{80, 0, 20, 100},
			expected_modified = Rect{0, 0, 80, 100},
		},
		{
			desc = "cut full width from right",
			initial = Rect{0, 0, 100, 100},
			pixels = 100,
			cut_func = rect_cut_right,
			expected_returned = Rect{0, 0, 100, 100},
			expected_modified = Rect{0, 0, 0, 100},
		},
		{
			desc = "cut right 15 pixels from negative rect",
			initial = Rect{-50, -50, 100, 100},
			pixels = 15,
			cut_func = rect_cut_right,
			expected_returned = Rect{35, -50, 15, 100},
			expected_modified = Rect{-50, -50, 85, 100},
		},
		{
			desc = "cut top 30 pixels from positive rect",
			initial = Rect{0, 0, 100, 100},
			pixels = 30,
			cut_func = rect_cut_top,
			expected_returned = Rect{0, 0, 100, 30},
			expected_modified = Rect{0, 30, 100, 70},
		},
		{
			desc = "cut full height from top",
			initial = Rect{0, 0, 100, 100},
			pixels = 100,
			cut_func = rect_cut_top,
			expected_returned = Rect{0, 0, 100, 100},
			expected_modified = Rect{0, 100, 100, 0},
		},
		{
			desc = "cut top 25 pixels from negative rect",
			initial = Rect{-50, -50, 100, 100},
			pixels = 25,
			cut_func = rect_cut_top,
			expected_returned = Rect{-50, -50, 100, 25},
			expected_modified = Rect{-50, -25, 100, 75},
		},
		{
			desc = "cut bottom 40 pixels from positive rect",
			initial = Rect{0, 0, 100, 100},
			pixels = 40,
			cut_func = rect_cut_bot,
			expected_returned = Rect{0, 60, 100, 40},
			expected_modified = Rect{0, 0, 100, 60},
		},
		{
			desc = "cut full height from bottom",
			initial = Rect{0, 0, 100, 100},
			pixels = 100,
			cut_func = rect_cut_bot,
			expected_returned = Rect{0, 0, 100, 100},
			expected_modified = Rect{0, 0, 100, 0},
		},
		{
			desc = "cut bottom 35 pixels from negative rect",
			initial = Rect{-50, -50, 100, 100},
			pixels = 35,
			cut_func = rect_cut_bot,
			expected_returned = Rect{-50, 15, 100, 35},
			expected_modified = Rect{-50, -50, 100, 65},
		},
	}

	for c in cases {
		r := c.initial
		returned := c.cut_func(&r, c.pixels)
		testing.expectf(
			t,
			returned == c.expected_returned,
			"\n%s\nexpected returned: %v,\nactual: %v",
			c.desc,
			c.expected_returned,
			returned,
		)
		testing.expectf(
			t,
			r == c.expected_modified,
			"\n%s\nexpected modified: %v,\nactual: %v",
			c.desc,
			c.expected_modified,
			r,
		)
	}
}

@(test)
test_rect_contains :: proc(t: ^testing.T) {
	TestCase :: struct {
		desc:     string,
		r:        Rect,
		pt:       [2]f32,
		expected: bool,
	}

	cases := []TestCase {
		{desc = "point inside", r = Rect{0, 0, 10, 10}, pt = {5, 5}, expected = true},
		{desc = "point on top-left corner", r = Rect{0, 0, 10, 10}, pt = {0, 0}, expected = true},
		{desc = "point on top edge", r = Rect{0, 0, 10, 10}, pt = {5, 0}, expected = true},
		{desc = "point on left edge", r = Rect{0, 0, 10, 10}, pt = {0, 5}, expected = true},
		{
			desc = "point on bottom-right corner (exclusive)",
			r = Rect{0, 0, 10, 10},
			pt = {10, 10},
			expected = false,
		},
		{
			desc = "point on bottom edge (exclusive)",
			r = Rect{0, 0, 10, 10},
			pt = {5, 10},
			expected = false,
		},
		{
			desc = "point on right edge (exclusive)",
			r = Rect{0, 0, 10, 10},
			pt = {10, 5},
			expected = false,
		},
		{desc = "point outside (left)", r = Rect{0, 0, 10, 10}, pt = {-1, 5}, expected = false},
		{desc = "point outside (right)", r = Rect{0, 0, 10, 10}, pt = {11, 5}, expected = false},
		{desc = "point outside (top)", r = Rect{0, 0, 10, 10}, pt = {5, -1}, expected = false},
		{desc = "point outside (bottom)", r = Rect{0, 0, 10, 10}, pt = {5, 11}, expected = false},
		{
			desc = "negative coordinates, point inside",
			r = Rect{-20, -20, 10, 10},
			pt = {-15, -15},
			expected = true,
		},
		{
			desc = "negative coordinates, point on top-left",
			r = Rect{-20, -20, 10, 10},
			pt = {-20, -20},
			expected = true,
		},
		{
			desc = "negative coordinates, point on bottom-right (exclusive)",
			r = Rect{-20, -20, 10, 10},
			pt = {-10, -10},
			expected = false,
		},
		{
			desc = "zero-sized rectangle contains nothing",
			r = Rect{0, 0, 0, 0},
			pt = {0, 0},
			expected = false,
		},
	}

	for c in cases {
		result := rect_contains(c.r, c.pt)
		testing.expectf(
			t,
			result == c.expected,
			"\n%s\nexpected: %v,\nactual: %v\nrect: %v, pt: %v",
			c.desc,
			c.expected,
			result,
			c.r,
			c.pt,
		)
	}
}

@(test)
test_rect_align :: proc(t: ^testing.T) {
	TestCaseAlign :: struct {
		desc:     string,
		outer:    Rect,
		width:    f32,
		height:   f32,
		h:        H_Align,
		v:        V_Align,
		expected: Rect,
	}

	cases := []TestCaseAlign {
		{
			desc = "align horizontal on positive rect",
			outer = Rect{0, 0, 100, 100},
			width = 50,
			height = 50,
			h = .Center,
			v = .Top,
			expected = Rect{25, 0, 50, 50},
		},
		{
			desc = "align vertical on positive rect",
			outer = Rect{0, 0, 100, 100},
			width = 50,
			height = 50,
			h = .Left,
			v = .Center,
			expected = Rect{0, 25, 50, 50},
		},
		{
			desc = "align both on positive rect",
			outer = Rect{0, 0, 100, 100},
			width = 50,
			height = 50,
			h = .Center,
			v = .Center,
			expected = Rect{25, 25, 50, 50},
		},
		{
			desc = "align both with exact fit",
			outer = Rect{0, 0, 100, 100},
			width = 100,
			height = 100,
			h = .Center,
			v = .Center,
			expected = Rect{0, 0, 100, 100},
		},
		{
			desc = "align none on positive rect",
			outer = Rect{0, 0, 100, 100},
			width = 50,
			height = 50,
			h = .Left,
			v = .Top,
			expected = Rect{0, 0, 50, 50},
		},
		{
			desc = "align none on negative rect",
			outer = Rect{-50, -50, 100, 100},
			width = 30,
			height = 40,
			h = .Left,
			v = .Top,
			expected = Rect{-50, -50, 30, 40},
		},
		{
			desc = "align horizontal on negative rect",
			outer = Rect{-50, -50, 100, 100},
			width = 30,
			height = 40,
			h = .Center,
			v = .Top,
			expected = Rect{-15, -50, 30, 40},
		},
		{
			desc = "align vertical on negative rect",
			outer = Rect{-50, -50, 100, 100},
			width = 30,
			height = 40,
			h = .Left,
			v = .Center,
			expected = Rect{-50, -20, 30, 40},
		},
		{
			desc = "align both on negative rect",
			outer = Rect{-50, -50, 100, 100},
			width = 30,
			height = 40,
			h = .Center,
			v = .Center,
			expected = Rect{-15, -20, 30, 40},
		},
	}

	for c in cases {
		result := rect_align(c.outer, c.width, c.height, c.h, c.v)
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

@(test)
test_rect_take_side :: proc(t: ^testing.T) {
	TestCase :: struct {
		desc:              string,
		initial:           Rect,
		pixels:            f32,
		take_func:         proc(_: ^Rect, _: f32) -> Rect,
		expected_returned: Rect,
		expected_modified: Rect,
	}

	cases := []TestCase {
		{
			desc = "take left 10 pixels",
			initial = Rect{0, 0, 100, 100},
			pixels = 10,
			take_func = rect_take_left,
			expected_returned = Rect{0, 0, 10, 100},
			expected_modified = Rect{10, 0, 90, 100},
		},
		{
			desc = "take left more than width",
			initial = Rect{0, 0, 100, 100},
			pixels = 120,
			take_func = rect_take_left,
			expected_returned = Rect{0, 0, 120, 100},
			expected_modified = Rect{120, 0, -20, 100},
		},
		{
			desc = "take right 20 pixels",
			initial = Rect{0, 0, 100, 100},
			pixels = 20,
			take_func = rect_take_right,
			expected_returned = Rect{80, 0, 20, 100},
			expected_modified = Rect{0, 0, 80, 100},
		},
		{
			desc = "take right more than width",
			initial = Rect{0, 0, 100, 100},
			pixels = 120,
			take_func = rect_take_right,
			expected_returned = Rect{-20, 0, 120, 100},
			expected_modified = Rect{0, 0, -20, 100},
		},
		{
			desc = "take top 30 pixels",
			initial = Rect{0, 0, 100, 100},
			pixels = 30,
			take_func = rect_take_top,
			expected_returned = Rect{0, 0, 100, 30},
			expected_modified = Rect{0, 30, 100, 70},
		},
		{
			desc = "take top more than height",
			initial = Rect{0, 0, 100, 100},
			pixels = 120,
			take_func = rect_take_top,
			expected_returned = Rect{0, 0, 100, 120},
			expected_modified = Rect{0, 120, 100, -20},
		},
		{
			desc = "take bottom 40 pixels",
			initial = Rect{0, 0, 100, 100},
			pixels = 40,
			take_func = rect_take_bot,
			expected_returned = Rect{0, 60, 100, 40},
			expected_modified = Rect{0, 0, 100, 60},
		},
		{
			desc = "take bottom more than height",
			initial = Rect{0, 0, 100, 100},
			pixels = 120,
			take_func = rect_take_bot,
			expected_returned = Rect{0, -20, 100, 120},
			expected_modified = Rect{0, 0, 100, -20},
		},
	}

	for c in cases {
		r := c.initial
		returned := c.take_func(&r, c.pixels)
		testing.expectf(
			t,
			returned == c.expected_returned,
			"\n%s\nexpected returned: %v,\nactual: %v",
			c.desc,
			c.expected_returned,
			returned,
		)
		testing.expectf(
			t,
			r == c.expected_modified,
			"\n%s\nexpected modified: %v,\nactual: %v",
			c.desc,
			c.expected_modified,
			r,
		)
	}
}

@(test)
test_rect_intersect :: proc(t: ^testing.T) {
	TestCaseIntersect :: struct {
		desc:     string,
		r1, r2:   Rect,
		expected: Rect,
	}

	cases := []TestCaseIntersect {
		{
			desc = "no intersection (separate)",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{20, 20, 10, 10},
			expected = Rect{0, 0, 0, 0},
		},
		{
			desc = "partial intersection",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{5, 5, 10, 10},
			expected = Rect{5, 5, 5, 5},
		},
		{
			desc = "one inside another",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{2, 2, 2, 2},
			expected = Rect{2, 2, 2, 2},
		},
		{
			desc = "identical rectangles",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{0, 0, 10, 10},
			expected = Rect{0, 0, 10, 10},
		},
		{
			desc = "touching at right edge (returns zero-width rect at touch point)",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{10, 0, 10, 10},
			expected = Rect{10, 0, 0, 10},
		},
		{
			desc = "touching at bottom edge (returns zero-height rect at touch point)",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{0, 10, 10, 10},
			expected = Rect{0, 10, 10, 0},
		},
		{
			desc = "no intersection (overlapping x, separate y)",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{0, 20, 10, 10},
			expected = Rect{0, 0, 0, 0},
		},
		{
			desc = "negative coordinates intersection",
			r1 = Rect{-10, -10, 20, 20},
			r2 = Rect{0, 0, 20, 20},
			expected = Rect{0, 0, 10, 10},
		},
	}

	for c in cases {
		result := rect_intersect(c.r1, c.r2)
		testing.expectf(
			t,
			result == c.expected,
			"\n%s\nexpected: %v,\nactual: %v\nr1: %v, r2: %v",
			c.desc,
			c.expected,
			result,
			c.r1,
			c.r2,
		)
	}
}

@(test)
test_rect_enclosing :: proc(t: ^testing.T) {
	TestCaseEnclosing :: struct {
		desc:     string,
		r1, r2:   Rect,
		expected: Rect,
	}

	cases := []TestCaseEnclosing {
		{
			desc = "identical rectangles",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{0, 0, 10, 10},
			expected = Rect{0, 0, 10, 10},
		},
		{
			desc = "one inside another",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{2, 2, 2, 2},
			expected = Rect{0, 0, 10, 10},
		},
		{
			desc = "separate rectangles",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{20, 20, 10, 10},
			expected = Rect{0, 0, 30, 30},
		},
		{
			desc = "partial overlap",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{5, 5, 10, 10},
			expected = Rect{0, 0, 15, 15},
		},
		{
			desc = "negative coordinates",
			r1 = Rect{-10, -10, 5, 5},
			r2 = Rect{5, 5, 5, 5},
			expected = Rect{-10, -10, 20, 20},
		},
		{
			desc = "zero-sized rectangle at origin",
			r1 = Rect{0, 0, 10, 10},
			r2 = Rect{0, 0, 0, 0},
			expected = Rect{0, 0, 10, 10},
		},
	}

	for c in cases {
		result := rect_enclosing(c.r1, c.r2)
		testing.expectf(
			t,
			result == c.expected,
			"\n%s\nexpected: %v,\nactual: %v\nr1: %v, r2: %v",
			c.desc,
			c.expected,
			result,
			c.r1,
			c.r2,
		)
	}
}

