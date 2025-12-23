package exigent

Rect :: struct {
	x, y:          f32,
	width, height: f32,
}

// Rect contains the point (pt), using a half-open rectangle to avoid double-hits
// on shared edges
rect_contains :: proc(r: Rect, pt: [2]f32) -> bool {
	assert(r.width > 0 && r.height > 0, "Rect must have positive width & height")
	return pt.x >= r.x && pt.y >= r.y && pt.x < r.x + r.width && pt.y < r.y + r.height
}

rect_cut :: proc(r: Rect, c: Cut) -> (Rect, Rect) {
	assert(r.width > 0 && r.height > 0, "Rect must have non-zero area to cut")

	switch c.type {
	case .Percent:
		switch c.dim {
		case .Horizontal:
			left_width := r.width * c.value
			right_width := r.width - left_width
			left := Rect {
				x      = r.x,
				y      = r.y,
				width  = left_width,
				height = r.height,
			}
			right := Rect {
				x      = r.x + left_width,
				y      = r.y,
				width  = right_width,
				height = r.height,
			}
			return left, right
		case .Vertical:
			top_height := r.height * c.value
			bot_height := r.height - top_height
			top := Rect {
				x      = r.x,
				y      = r.y,
				width  = r.width,
				height = top_height,
			}
			bot := Rect {
				x      = r.x,
				y      = r.y + top_height,
				width  = r.width,
				height = bot_height,
			}
			return top, bot
		}
	case .Pixel:
		switch c.dim {
		case .Horizontal:
			left_width := c.value
			right_width := r.width - left_width
			left := Rect {
				x      = r.x,
				y      = r.y,
				width  = left_width,
				height = r.height,
			}
			right := Rect {
				x      = r.x + left_width,
				y      = r.y,
				width  = right_width,
				height = r.height,
			}
			return left, right
		case .Vertical:
			top_height := c.value
			bot_height := r.height - top_height
			top := Rect {
				x      = r.x,
				y      = r.y,
				width  = r.width,
				height = top_height,
			}
			bot := Rect {
				x      = r.x,
				y      = r.y + top_height,
				width  = r.width,
				height = bot_height,
			}
			return top, bot
		}
	}

	return Rect{}, Rect{}
}

Cut :: struct {
	type:  Cut_Type,
	dim:   Cut_Dim,
	value: f32,
}

Cut_Type :: enum {
	Percent,
	Pixel,
}

Cut_Dim :: enum {
	Horizontal,
	Vertical,
}

cut_h :: proc(value: f32) -> Cut {
	return Cut{type = .Percent, dim = .Horizontal, value = value}
}

cut_h_px :: proc(value: f32) -> Cut {
	return Cut{type = .Pixel, dim = .Horizontal, value = value}
}

cut_v :: proc(value: f32) -> Cut {
	return Cut{type = .Percent, dim = .Vertical, value = value}
}

cut_v_px :: proc(value: f32) -> Cut {
	return Cut{type = .Pixel, dim = .Vertical, value = value}
}

rect_inset :: proc(r: Rect, i: Inset) -> Rect {
	r := r

	for s in i.sides {
		switch s {
		case .Top:
			r.y += i.amount[.Top]
			r.height -= i.amount[.Top]
		case .Right:
			r.width -= i.amount[.Right]
		case .Bottom:
			r.height -= i.amount[.Bottom]
		case .Left:
			r.x += i.amount[.Left]
			r.width -= i.amount[.Left]
		}
	}

	return r
}

Inset :: struct {
	amount: [Inset_Side]f32,
	sides:  bit_set[Inset_Side],
}

Inset_Side :: enum {
	Top,
	Right,
	Bottom,
	Left,
}

inset :: proc(amount: f32) -> Inset {
	return Inset {
		amount = {.Top = amount, .Right = amount, .Bottom = amount, .Left = amount},
		sides = {.Top, .Right, .Bottom, .Left},
	}
}
