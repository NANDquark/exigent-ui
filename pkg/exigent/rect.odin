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

Rect_Align :: enum {
	None,
	Horizontal,
	Vertical,
	Both,
}

// Create a new Rect with the given width & height which is aligned inside the outer Rect
rect_align :: proc(outer: Rect, width, height: f32, align: Rect_Align) -> Rect {
	assert(width <= outer.width && height <= outer.height, "new Rect must fit within outer Rect")

	inner := Rect {
		x      = outer.x,
		y      = outer.y,
		width  = width,
		height = height,
	}
	if align == .Horizontal || align == .Both {
		inner.x = outer.x + (outer.width / 2) - (width / 2)
	}
	if align == .Vertical || align == .Both {
		inner.y = outer.y + (outer.height / 2) - (height / 2)
	}

	return inner
}
