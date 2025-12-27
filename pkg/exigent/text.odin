package exigent

import "core:strings"

Text_Style :: struct {
	type:        Text_Style_Type,
	font:        rawptr,
	size:        f32,
	line_height: f32,
	spacing:     f32,
	color:       Color,
}

Text_Style_Type :: distinct string

// TODO: May want to store a Text_Style_Handle (int) into the Context.text_style_stack
// rather than the string itself.
Text_Style_Registry :: struct {
	initialized:   bool,
	styles:        map[Text_Style_Type]Text_Style,
	default_style: Text_Style,
	width_fn:      Text_Style_Width_Fn,
}

Text_Style_Width_Fn :: proc(style: Text_Style, text: string) -> f32

reg: Text_Style_Registry

text_style_init :: proc(
	type: Text_Style_Type,
	default_style: Text_Style,
	width_fn: Text_Style_Width_Fn,
) {
	reg.initialized = true
	reg.default_style = default_style
	reg.width_fn = width_fn
}

text_style_push :: proc(c: ^Context, type: Text_Style_Type) {
	_text_style_check()
	append(&c.text_style_stack, type)
}

text_style_pop :: proc(c: ^Context) {
	assert(len(c.text_style_stack) > 0, "no text styles to pop")
	pop(&c.text_style_stack)
}

@(private = "file")
_text_style_check :: proc() {
	assert(reg.initialized, "must register default text style with text_style_init")
}

text_style_register :: proc(style: Text_Style) {
	_text_style_check()
	if _, ok := reg.styles[style.type]; ok {
		panic("Text_Type already registered")
	}
	reg.styles[style.type] = style
}

text_style_get :: proc(type: Text_Style_Type) -> Text_Style {
	_text_style_check()
	ts, ok := reg.styles[type]
	if !ok do return reg.default_style
	return ts
}

text_style_default :: proc() -> Text_Style {
	_text_style_check()
	return reg.default_style
}

text_style_curr :: proc(c: ^Context) -> Text_Style {
	_text_style_check()
	if len(c.text_style_stack) <= 0 do return text_style_default()
	type := c.text_style_stack[len(c.text_style_stack) - 1]
	return text_style_get(type)
}

text_width :: proc(c: ^Context, text: string) -> f32 {
	text_style := text_style_curr(c)
	return reg.width_fn(text_style, text)
}

// Clips the text to ensure it fits within the Rect by removing characters and adding ellipses.
// When the text cannot fit a single line vertically the entire text is removed.
// When the text fits already it is just returned.
text_clip :: proc(c: ^Context, text: string, r: Rect) -> string {
	assert(!strings.contains(text, "\n"))

	text := text
	text_style := text_style_curr(c)

	// TODO: multiline support
	if c.widget_curr.rect.height < text_style.line_height {
		return ""
	}

	if text != "" && c.widget_curr.rect.width < text_width(c, text) {
		ellipses_width := text_width(c, "...")
		for true {
			if len(text) == 0 do break
			truncated_width := text_width(c, text) + ellipses_width
			if truncated_width < c.widget_curr.rect.width {
				return strings.concatenate([]string{text, "..."}, c.temp_allocator)
			}
			text = text[:len(text) - 1]
		}
	}

	return text
}
