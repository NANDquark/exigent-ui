package exigent

import "core:strings"

// Draw a rect relative to the current widget's resolved rect.
rect :: proc(c: ^Context, r: Rect, color: Color, border := Border_Style{}) {
	append(&c.widget_curr.draw_cmds, Widget_Draw_Rect{rect = r, color = color, border = border})
}

background :: proc(c: ^Context) {
	append(&c.widget_curr.draw_cmds, Widget_Draw_Background{})
}

// Draw a horizontal line relative to the current widget's resolved rect.
line_h :: proc(c: ^Context, x_start, x_end, y: f32, thickness: f32, color: Color) {
	x_min := min(x_start, x_end)
	w := abs(x_end - x_start)
	line := Rect {
		x = x_min,
		y = y - thickness / 2,
		w = w,
		h = thickness,
	}
	rect(c, line, color)
}

// Draw a vertical line relative to the current widget's resolved rect.
line_v :: proc(c: ^Context, y_start, y_end, x: f32, thickness: f32, color: Color) {
	y_min := min(y_start, y_end)
	h := abs(y_end - y_start)
	line := Rect {
		x = x - thickness / 2,
		y = y_min,
		w = thickness,
		h = h,
	}
	rect(c, line, color)
}

text :: proc {
	text_aligned,
	text_ex,
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

text_aligned :: proc(c: ^Context, text: string, h_align: Text_Align_H, v_align: Text_Align_V) {
	assert(!strings.contains(text, "\n"), "multiline text not supported yet")
	append(
		&c.widget_curr.draw_cmds,
		Widget_Draw_Text {
			text = text,
			h_align = h_align,
			v_align = v_align,
			style = text_style_curr(c),
		},
	)
}

// Widgets support a single text string and will be automatically split on newlines
text_ex :: proc(c: ^Context, text: string, offset: [2]f32) {
	assert(!strings.contains(text, "\n"), "multiline text not supported yet")
	append(
		&c.widget_curr.draw_cmds,
		Widget_Draw_Text {
			text = text,
			offset = offset,
			h_align = .Left,
			v_align = .Top,
			style = text_style_curr(c),
		},
	)
}

// Draw a sprite, scaling it to the dst rect relative to the current widget.
// An empty dst uses the current widget's full resolved rect.
sprite :: proc(c: ^Context, sprite: Sprite, dst: Rect) {
	append(&c.widget_curr.draw_cmds, Widget_Draw_Sprite{sprite = sprite, rect = dst})
}
