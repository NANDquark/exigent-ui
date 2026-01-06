package exigent

import "core:strings"

draw_rect :: proc(c: ^Context, r: Rect, color: Color, border := Border_Style{}) {
	append(
		&c.draw_cmds,
		Command_Rect{rect = r, color = color, border = border, clip = c.widget_curr.clip},
	)
}

draw_background :: proc(c: ^Context) {
	style := style_curr(c)
	draw_rect(c, c.widget_curr.rect, style.background, style.border)
}

// Draw a horizontal line
draw_line_h :: proc(c: ^Context, x_start, x_end, y: f32, thickness: f32, color: Color) {
	x_min := min(x_start, x_end)
	w := abs(x_end - x_start)
	line := Rect {
		x = x_min,
		y = y - thickness / 2,
		w = w,
		h = thickness,
	}
	draw_rect(c, line, color)
}

// Draw a vertical line
draw_line_v :: proc(c: ^Context, y_start, y_end, x: f32, thickness: f32, color: Color) {
	y_min := min(y_start, y_end)
	h := abs(y_end - y_start)
	line := Rect {
		x = x - thickness / 2,
		y = y_min,
		w = thickness,
		h = h,
	}
	draw_rect(c, line, color)
}

draw_text :: proc {
	draw_text_aligned,
	draw_text_ex,
}

Text_Align_H :: enum {
	Left,
	Center,
	Right,
}

Text_Align_V :: enum {
	Top,
	Center,
	Bottom,
}

draw_text_aligned :: proc(
	c: ^Context,
	text: string,
	h_align: Text_Align_H,
	v_align: Text_Align_V,
) {
	assert(!strings.contains(text, "\n"), "multiline text not supported yet")
	text := text_clip(c, text, c.widget_curr.rect)

	text_style := text_style_curr(c)
	r := c.widget_curr.rect
	tw := text_width(c, text)

	offset: [2]f32

	switch h_align {
	case .Left:
		offset.x = 0
	case .Center:
		offset.x = (r.w - f32(tw)) * 0.5
	case .Right:
		offset.x = r.w - f32(tw)
	}

	switch v_align {
	case .Top:
		offset.y = 0
	case .Center:
		offset.y = (r.h - text_style.line_height) * 0.5
	case .Bottom:
		offset.y = r.h - text_style.line_height
	}

	draw_text_ex(c, text, offset)
}

// Widgets support a single text string and will be automatically split on newlines
draw_text_ex :: proc(c: ^Context, text: string, offset: [2]f32) {
	assert(!strings.contains(text, "\n"), "multiline text not supported yet")
	r := c.widget_curr.rect
	append(
		&c.draw_cmds,
		Command_Text {
			text = text,
			pos = [2]f32{r.x, r.y} + offset,
			style = text_style_curr(c),
			clip = c.widget_curr.clip,
		},
	)
}

@(private)
clip :: proc(c: ^Context, r: Rect) {
	append(&c.draw_cmds, Command_Clip{rect = r})
}

@(private)
unclip :: proc(c: ^Context) {
	append(&c.draw_cmds, Command_Unclip{})
}

