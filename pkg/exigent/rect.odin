package exigent


Rect :: struct {
	x, y:          f32,
	width, height: f32,
}

// Rect contains the point (pt), using a half-open rectangle to avoid double-hits
// on shared edges
rect_contains :: proc(r: Rect, pt: [2]f32) -> bool {
	return pt.x >= r.x && pt.y >= r.y && pt.x < r.x + r.width && pt.y < r.y + r.height
}

rect_cut_left :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.width, "cannot cut more than width of rect from left")
	left := Rect {
		x      = r.x,
		y      = r.y,
		width  = pixels,
		height = r.height,
	}
	r.x += pixels
	r.width -= pixels
	return left
}

rect_cut_right :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.width, "cannot cut more than width of rect from right")
	r.width -= pixels
	right := Rect {
		x      = r.x + r.width,
		y      = r.y,
		width  = pixels,
		height = r.height,
	}
	return right
}

rect_cut_top :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.height, "cannot cut more than height of rect from top")
	top := Rect {
		x      = r.x,
		y      = r.y,
		width  = r.width,
		height = pixels,
	}
	r.y += pixels
	r.height -= pixels
	return top
}

rect_cut_bot :: proc(r: ^Rect, pixels: f32) -> Rect {
	assert(pixels <= r.height, "cannot cut more than height of rect from bottom")
	r.height -= pixels
	bot := Rect {
		x      = r.x,
		y      = r.y + r.height,
		width  = r.width,
		height = pixels,
	}
	return bot
}

Inset :: struct {
	Top, Right, Bottom, Left: f32,
}

rect_inset :: proc(r: Rect, i: Inset) -> Rect {
	r := r

	if i.Top != 0 {
		r.y += i.Top
		r.height -= i.Top
	}
	if i.Right != 0 {
		r.width -= i.Right
	}
	if i.Bottom != 0 {
		r.height -= i.Bottom
	}
	if i.Left != 0 {
		r.x += i.Left
		r.width -= i.Left
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
	assert(width <= outer.width && height <= outer.height, "new Rect must fit within outer Rect")

	inner := Rect {
		width  = width,
		height = height,
	}

	switch h {
	case .Left:
		inner.x = outer.x
	case .Center:
		inner.x = outer.x + (outer.width - width) * 0.5
	case .Right:
		inner.x = outer.x + outer.width - width
	}

	switch v {
	case .Top:
		inner.y = outer.y
	case .Center:
		inner.y = outer.y + (outer.height - height) * 0.5
	case .Bottom:
		inner.y = outer.y + outer.height - height
	}

	return inner
}
