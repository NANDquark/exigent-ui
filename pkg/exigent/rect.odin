package exigent


Rect :: struct {
	x, y: f32,
	w:    f32, // width
	h:    f32, // height
}

// Rect contains the point (pt), using a half-open rectangle to avoid double-hits
// on shared edges
rect_contains :: proc(r: Rect, pt: [2]f32) -> bool {
	return pt.x >= r.x && pt.y >= r.y && pt.x < r.x + r.w && pt.y < r.y + r.h
}

rect_cut_left :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.w, "cannot cut more than width of rect from left")
	left := Rect {
		x = r.x,
		y = r.y,
		w = pixels,
		h = r.h,
	}
	r.x += pixels
	r.w -= pixels
	return left
}

rect_cut_right :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.w, "cannot cut more than width of rect from right")
	r.w -= pixels
	right := Rect {
		x = r.x + r.w,
		y = r.y,
		w = pixels,
		h = r.h,
	}
	return right
}

rect_cut_top :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.h, "cannot cut more than height of rect from top")
	top := Rect {
		x = r.x,
		y = r.y,
		w = r.w,
		h = pixels,
	}
	r.y += pixels
	r.h -= pixels
	return top
}

rect_cut_bot :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.h, "cannot cut more than height of rect from bottom")
	r.h -= pixels
	bot := Rect {
		x = r.x,
		y = r.y + r.h,
		w = r.w,
		h = pixels,
	}
	return bot
}

rect_inset :: proc {
	rect_inset_even,
	rect_inset_ex,
}

rect_inset_even :: proc(r: Rect, i: f32) -> Rect {
	return rect_inset_ex(r, Inset{i, i, i, i})
}

Inset :: struct {
	Top, Right, Bottom, Left: f32,
}

rect_inset_ex :: proc(r: Rect, i: Inset) -> Rect {
	r := r

	if i.Top != 0 {
		r.y += i.Top
		r.h -= i.Top
	}
	if i.Right != 0 {
		r.w -= i.Right
	}
	if i.Bottom != 0 {
		r.h -= i.Bottom
	}
	if i.Left != 0 {
		r.x += i.Left
		r.w -= i.Left
	}

	return r
}

H_Align :: enum {
	Left,
	Center,
	Right,
}

V_Align :: enum {
	Top,
	Center,
	Bottom,
}

// Create a new Rect with the given width & height aligned inside the outer Rect
rect_align :: proc(
	outer: Rect,
	width, height: f32,
	h: H_Align = .Center,
	v: V_Align = .Center,
) -> Rect {
	assert(width <= outer.w && height <= outer.h, "new Rect must fit within outer Rect")

	inner := Rect {
		w = width,
		h = height,
	}

	switch h {
	case .Left:
		inner.x = outer.x
	case .Center:
		inner.x = outer.x + (outer.w - width) * 0.5
	case .Right:
		inner.x = outer.x + outer.w - width
	}

	switch v {
	case .Top:
		inner.y = outer.y
	case .Center:
		inner.y = outer.y + (outer.h - height) * 0.5
	case .Bottom:
		inner.y = outer.y + outer.h - height
	}

	return inner
}

rect_intersect :: proc(r1, r2: Rect) -> Rect {
	x1 := max(r1.x, r2.x)
	y1 := max(r1.y, r2.y)
	x2 := min(r1.x + r1.w, r2.x + r2.w)
	y2 := min(r1.y + r1.h, r2.y + r2.h)

	if x2 < x1 || y2 < y1 {
		return Rect{}
	}

	return Rect{x = x1, y = y1, w = x2 - x1, h = y2 - y1}
}

rect_enclosing :: proc(r1, r2: Rect) -> Rect {
	x_min := min(r1.x, r2.x)
	y_min := min(r1.y, r2.y)
	x_max := max(r1.x + r1.w, r2.x + r2.w)
	y_max := max(r1.y + r1.h, r2.y + r2.h)

	return Rect{x = x_min, y = y_min, w = x_max - x_min, h = y_max - y_min}
}

// Take pixels amount from the r Rect and if pixels is larger than r, leave it
// with a negative width to show how much of the taken Rect is clipped outside
// the original r Rect.
rect_take_left :: proc(r: ^Rect, pixels: f32) -> Rect {
	res := Rect {
		x = r.x,
		y = r.y,
		w = pixels,
		h = r.h,
	}
	r.x += pixels
	r.w -= pixels
	return res
}

// Take pixels amount from the r Rect and if pixels is larger than r, leave it
// with a negative width to show how much of the taken Rect is clipped outside
// the original r Rect.
rect_take_right :: proc(r: ^Rect, pixels: f32) -> Rect {
	r.w -= pixels
	res := Rect {
		x = r.x + r.w, // accounts for negative r.w
		y = r.y,
		w = pixels,
		h = r.h,
	}
	return res
}

// Take pixels amount from the r Rect and if pixels is larger than r, leave it
// with a negative height to show how much of the taken Rect is clipped outside
// the original r Rect.
rect_take_top :: proc(r: ^Rect, pixels: f32) -> Rect {
	res := Rect {
		x = r.x,
		y = r.y,
		w = r.w,
		h = pixels,
	}
	r.y += pixels
	r.h -= pixels
	return res
}

// Take pixels amount from the r Rect and if pixels is larger than r, leave it
// with a negative height to show how much of the taken Rect is clipped outside
// the original r Rect.
rect_take_bot :: proc(r: ^Rect, pixels: f32) -> Rect {
	r.h -= pixels
	res := Rect {
		x = r.x,
		y = r.y + r.h, // accounts for negative r.h
		w = r.w,
		h = pixels,
	}
	return res
}

