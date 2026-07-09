package exigent

import "core:strings"
import "core:unicode/utf8"

Text_Style :: struct {
	font:        rawptr,
	size:        f32,
	line_height: f32,
	spacing:     f32,
	color:       Color,
}

Text_Role :: enum {
	Body,
	Muted,
	Caption,
	Section,
	Title,
	Display,
}

Text_Style_Width_Fn :: proc(data: rawptr, style: Text_Style, text: string) -> f32

text_measure_init :: proc(c: ^Context, width_data: rawptr, width_fn: Text_Style_Width_Fn) {
	c.text_width_data = width_data
	c.text_width_fn = width_fn
}

text_style_curr :: proc(c: ^Context) -> Text_Style {
	return text_style(c, .Body)
}

text_style :: proc(c: ^Context, role: Text_Role = .Body, color: Color = {}) -> Text_Style {
	th := &c.theme
	size := th.font.size_md
	fg := th.color.fg
	switch role {
	case .Body:
	case .Muted:
		fg = th.color.fg_muted
	case .Caption:
		size = th.font.size_sm
		fg = th.color.fg_muted
	case .Section:
		size = th.font.size_lg
	case .Title:
		size = th.font.size_xl
	case .Display:
		size = th.font.size_display
	}
	if color != {} {
		fg = color
	}
	return Text_Style {
		font        = th.font.font,
		size        = size,
		line_height = size * th.font.line_scale,
		spacing     = th.font.spacing,
		color       = fg,
	}
}

text_width :: proc(c: ^Context, text: string) -> f32 {
	text_style := text_style_curr(c)
	return text_width_style(c, text_style, text)
}

text_width_style :: proc(c: ^Context, style: Text_Style, text: string) -> f32 {
	assert(c.text_width_fn != nil, "must initialize text measurement with text_measure_init")
	return c.text_width_fn(c.text_width_data, style, text)
}

// Clips the text to ensure it fits within the Rect by removing characters and adding ellipses.
// When the text cannot fit a single line vertically the entire text is removed.
// When the text fits already it is just returned.
text_clip :: proc(c: ^Context, text: string, r: Rect) -> string {
	assert(!strings.contains(text, "\n"))

	text := text
	text_style := text_style_curr(c)

	// TODO: multiline support
	if c.widget_curr.rect.h < text_style.line_height {
		return ""
	}

	if text != "" && c.widget_curr.rect.w < text_width(c, text) {
		ellipses_width := text_width(c, "...")
		for true {
			if len(text) == 0 do break
			truncated_width := text_width(c, text) + ellipses_width
			if truncated_width < c.widget_curr.rect.w {
				return strings.concatenate([]string{text, "..."}, c.temp_allocator)
			}
			text = text[:len(text) - 1]
		}
	}

	return text
}

// Statically backed text buffer
Text_Buffer :: struct {
	buf: []u8,
	len: int,
}

text_buffer_create :: proc(buf: []u8) -> Text_Buffer {
	return Text_Buffer{buf = buf, len = 0}
}

text_buffer_len :: proc(tbuf: ^Text_Buffer) -> int {
	return tbuf.len
}

text_buffer_cap :: proc(tbuf: ^Text_Buffer) -> int {
	return len(tbuf.buf)
}

text_buffer_append :: proc(tbuf: ^Text_Buffer, text: []u8) -> bool {
	if tbuf.len + len(text) > text_buffer_cap(tbuf) do return false
	buf_slot := tbuf.buf[tbuf.len:tbuf.len + len(text)]
	copy(buf_slot, text)
	tbuf.len += len(text)
	return true
}

text_buffer_pop :: proc(tbuf: ^Text_Buffer) {
	if tbuf.len <= 0 do return
	_, nbytes := utf8.decode_last_rune(tbuf.buf[:tbuf.len])
	tbuf.len -= nbytes
}

text_buffer_clear :: proc(tbuf: ^Text_Buffer) {
	tbuf.len = 0
}

text_buffer_to_string :: proc(tbuf: ^Text_Buffer) -> string {
	return string(tbuf.buf[:tbuf.len])
}
