package exigent

import "core:math"
import "core:strings"

Layout_Direction :: enum {
	Row,
	Column,
}

Layout_Align :: enum {
	Start,
	Center,
	End,
}

Size_Mode :: enum {
	Auto,
	Fixed,
	Intrinsic,
}

Size_Value :: struct {
	mode:  Size_Mode,
	value: f32,
}

Layout :: struct {
	width, height:          Size_Value,
	direction:              Layout_Direction,
	main_align, cross_align: Layout_Align,
	padding:                Inset,
	gap:                    f32,
}

size_auto :: proc() -> Size_Value {
	return Size_Value{mode = .Auto}
}

size_fixed :: proc(px: f32) -> Size_Value {
	return Size_Value{mode = .Fixed, value = px}
}

size_intrinsic :: proc() -> Size_Value {
	return Size_Value{mode = .Intrinsic}
}

layout_auto :: proc(
	direction: Layout_Direction = .Column,
	main_align: Layout_Align = .Start,
	cross_align: Layout_Align = .Start,
	padding := Inset{},
	gap: f32 = 0,
) -> Layout {
	return Layout {
		width = size_auto(),
		height = size_auto(),
		direction = direction,
		main_align = main_align,
		cross_align = cross_align,
		padding = padding,
		gap = gap,
	}
}

layout_fixed :: proc(
	width, height: f32,
	direction: Layout_Direction = .Column,
	main_align: Layout_Align = .Start,
	cross_align: Layout_Align = .Start,
	padding := Inset{},
	gap: f32 = 0,
) -> Layout {
	return Layout {
		width = size_fixed(width),
		height = size_fixed(height),
		direction = direction,
		main_align = main_align,
		cross_align = cross_align,
		padding = padding,
		gap = gap,
	}
}

@(private)
layout_intrinsic :: proc() -> Layout {
	return Layout {
		width = size_intrinsic(),
		height = size_intrinsic(),
		direction = .Column,
		main_align = .Start,
		cross_align = .Start,
		padding = {},
		gap = 0,
	}
}

@(private)
layout_align_offset :: proc(align: Layout_Align, available, used: f32) -> f32 {
	extra := max(available - used, 0)
	switch align {
	case .Start:
		return 0
	case .Center:
		return extra * 0.5
	case .End:
		return extra
	}
	return 0
}

@(private)
layout_measure_tree :: proc(c: ^Context, w: ^Widget) -> [2]f32 {
	content: [2]f32
	flow_child_count := 0

	for child in w.children {
		child_size := layout_measure_tree(c, child)
		if child.options.positioning != .Flow {
			continue
		}
		flow_child_count += 1
		switch w.layout.direction {
		case .Column:
			content.x = max(content.x, child_size.x)
			content.y += child_size.y
		case .Row:
			content.x += child_size.x
			content.y = max(content.y, child_size.y)
		}
	}
	if flow_child_count > 1 {
		gap_total := f32(flow_child_count - 1) * w.layout.gap
		switch w.layout.direction {
		case .Column:
			content.y += gap_total
		case .Row:
			content.x += gap_total
		}
	}

	w.content_size = content

	padding_size := layout_padding_size(w.layout.padding)
	padded_content := content + padding_size
	padded_intrinsic := w.intrinsic_size + padding_size

	inner_size: [2]f32
	inner_size.x = layout_resolve_size(w.layout.width, padded_content.x, padded_intrinsic.x)
	inner_size.y = layout_resolve_size(w.layout.height, padded_content.y, padded_intrinsic.y)
	w.measured_size = inner_size + layout_border_size(w)
	return w.measured_size
}

@(private)
layout_resolve_size :: proc(s: Size_Value, content, intrinsic: f32) -> f32 {
	switch s.mode {
	case .Fixed:
		return s.value
	case .Intrinsic:
		return intrinsic
	case .Auto:
		return content
	}
	return 0
}

@(private)
layout_position_tree :: proc(c: ^Context, w: ^Widget, origin: [2]f32, parent_clip: Rect) {
	border := w.style.border.thickness
	w.rect = Rect {
		x = origin.x + border,
		y = origin.y + border,
		w = w.measured_size.x - border * 2,
		h = w.measured_size.y - border * 2,
	}
	w.clip = rect_intersect(parent_clip, Rect{origin.x, origin.y, w.measured_size.x, w.measured_size.y})

	if w.scrollbox != nil {
		layout_update_scrollbox(c, w)
	}

	content_rect := layout_content_rect(w)
	main_used, cross_available: f32
	switch w.layout.direction {
	case .Column:
		main_used = w.content_size.y
		cross_available = content_rect.w
	case .Row:
		main_used = w.content_size.x
		cross_available = content_rect.h
	}

	main_available := content_rect.h
	if w.layout.direction == .Row do main_available = content_rect.w
	cursor := layout_align_offset(w.layout.main_align, main_available, main_used)

	for child in w.children {
		child_origin := [2]f32{content_rect.x, content_rect.y}
		if child.options.positioning == .Anchored {
			child_origin = layout_anchor_origin(content_rect, child.measured_size, child.options)
			layout_position_tree(c, child, child_origin, w.clip)
			continue
		}

		switch w.layout.direction {
		case .Column:
			child_origin.y += cursor
			child_origin.x += layout_align_offset(w.layout.cross_align, cross_available, child.measured_size.x)
			cursor += child.measured_size.y + w.layout.gap
		case .Row:
			child_origin.x += cursor
			child_origin.y += layout_align_offset(w.layout.cross_align, cross_available, child.measured_size.y)
			cursor += child.measured_size.x + w.layout.gap
		}
		if w.scrollbox != nil {
			child_origin.y += w.scrollbox.y_offset
		}
		layout_position_tree(c, child, child_origin, w.clip)
	}
}

@(private)
layout_anchor_origin :: proc(parent_content_rect: Rect, child_size: [2]f32, options: Container_Options) -> [2]f32 {
	pivot, ok := options.pivot.?
	if !ok {
		pivot = options.anchor
	}

	parent_pt := layout_anchor_point(parent_content_rect, options.anchor)
	child_pt := layout_anchor_point(Rect{0, 0, child_size.x, child_size.y}, pivot)
	return parent_pt + options.offset - child_pt
}

@(private)
layout_anchor_point :: proc(r: Rect, anchor: Anchor_Point) -> [2]f32 {
	switch anchor {
	case .Top_Left:
		return {r.x, r.y}
	case .Top_Center:
		return {r.x + r.w * 0.5, r.y}
	case .Top_Right:
		return {r.x + r.w, r.y}
	case .Center_Left:
		return {r.x, r.y + r.h * 0.5}
	case .Center:
		return {r.x + r.w * 0.5, r.y + r.h * 0.5}
	case .Center_Right:
		return {r.x + r.w, r.y + r.h * 0.5}
	case .Bottom_Left:
		return {r.x, r.y + r.h}
	case .Bottom_Center:
		return {r.x + r.w * 0.5, r.y + r.h}
	case .Bottom_Right:
		return {r.x + r.w, r.y + r.h}
	}

	return {r.x, r.y}
}

@(private)
layout_border_size :: proc(w: ^Widget) -> [2]f32 {
	border := w.style.border.thickness * 2
	return {border, border}
}

@(private)
layout_padding_size :: proc(padding: Inset) -> [2]f32 {
	return {padding.left + padding.right, padding.top + padding.bottom}
}

@(private)
layout_content_rect :: proc(w: ^Widget) -> Rect {
	return rect_inset(w.rect, w.layout.padding)
}

@(private)
layout_update_scrollbox :: proc(c: ^Context, w: ^Widget) {
	scrollbox := w.scrollbox
	if scrollbox == nil do return

	viewport := layout_content_rect(w)
	if w.content_size.y <= viewport.h {
		scrollbox.y_offset = 0
		return
	}

	if rect_contains(w.rect, input_get_mouse_pos(c)) {
		speed: f32 = SCROLL_STEP_PX_DEFAULT
		if scrollbox.scroll_step_px > 0 {
			speed = scrollbox.scroll_step_px
		}
		scrollbox.y_offset += input_get_scroll(c) * speed
	}
	scrollbox.y_offset = math.clamp(scrollbox.y_offset, -(w.content_size.y - viewport.h), 0)
}

@(private)
layout_emit_commands :: proc(c: ^Context, w: ^Widget) {
	append(&c.cmds, Command_Clip{rect = w.clip})

	for draw_cmd in w.draw_cmds {
		layout_emit_draw_command(c, w, draw_cmd)
	}

	for child in w.children {
		layout_emit_commands(c, child)
	}

	if w.scrollbox != nil {
		layout_emit_scrollbar(c, w)
	}

	append(&c.cmds, Command_Unclip{})
}

@(private)
layout_emit_draw_command :: proc(c: ^Context, w: ^Widget, draw_cmd: Widget_Draw_Command) {
	switch dc in draw_cmd {
	case Widget_Draw_Background:
		r := layout_offset_rect(w.rect, w.draw_offset)
		append(&c.cmds, Command_Rect{rect = r, color = w.style.background, border = w.style.border, clip = w.clip})
	case Widget_Draw_Rect:
		r := layout_local_rect(w, dc.rect)
		append(&c.cmds, Command_Rect{rect = r, color = dc.color, border = dc.border, clip = w.clip})
	case Widget_Draw_Text:
		layout_emit_text(c, w, dc)
	case Widget_Draw_Sprite:
		r := layout_local_rect(w, dc.rect)
		append(&c.cmds, Command_Sprite{sprite = dc.sprite, rect = r})
	}
}

@(private)
layout_local_rect :: proc(w: ^Widget, r: Rect) -> Rect {
	if r == {} {
		return layout_offset_rect(w.rect, w.draw_offset)
	}
	return Rect {
		x = w.rect.x + w.draw_offset.x + r.x,
		y = w.rect.y + w.draw_offset.y + r.y,
		w = r.w,
		h = r.h,
	}
}

@(private)
layout_offset_rect :: proc(r: Rect, offset: [2]f32) -> Rect {
	r := r
	r.x += offset.x
	r.y += offset.y
	return r
}

@(private)
layout_emit_text :: proc(c: ^Context, w: ^Widget, dc: Widget_Draw_Text) {
	assert(!strings.contains(dc.text, "\n"), "multiline text not supported yet")
	r := layout_offset_rect(w.rect, w.draw_offset)
	txt := layout_text_clip(c, dc.text, r, dc.style)
	if len(txt) == 0 do return

	tw := text_width_style(c, dc.style, txt)
	offset := dc.offset

	switch dc.h_align {
	case .Left:
	case .Center:
		offset.x = (r.w - tw) * 0.5
	case .Right:
		offset.x = r.w - tw
	}

	switch dc.v_align {
	case .Top:
	case .Center:
		offset.y = (r.h - dc.style.line_height) * 0.5
	case .Bottom:
		offset.y = r.h - dc.style.line_height
	}

	append(
		&c.cmds,
		Command_Text {
			text = txt,
			pos = [2]f32{r.x, r.y} + offset,
			style = dc.style,
			clip = w.clip,
		},
	)
}

@(private)
layout_text_clip :: proc(c: ^Context, text: string, r: Rect, style: Text_Style) -> string {
	if r.h < style.line_height {
		return ""
	}

	text := text
	if text != "" && r.w < text_width_style(c, style, text) {
		ellipses_width := text_width_style(c, style, "...")
		for true {
			if len(text) == 0 do break
			truncated_width := text_width_style(c, style, text) + ellipses_width
			if truncated_width < r.w {
				return strings.concatenate([]string{text, "..."}, c.temp_allocator)
			}
			text = text[:len(text) - 1]
		}
	}

	return text
}

layout_emit_scrollbar :: proc(c: ^Context, w: ^Widget) {
	scrollbox := w.scrollbox
	if scrollbox == nil do return

	viewport := layout_content_rect(w)
	if w.content_size.y <= viewport.h do return

	scrollbox_height := viewport.h
	content_height := w.content_size.y
	style := w.style
	r := w.rect
	scrollbar_width := style.scrollbar_width
	if scrollbar_width <= 0 {
		scrollbar_width = SCROLLBAR_WIDTH_PX_DEFAULT
	}
	scrollbar := rect_cut_right(&r, scrollbar_width)
	scrollbar_alpha := style.scrollbar_alpha
	if scrollbar_alpha <= 0 {
		scrollbar_alpha = SCROLLBAR_ALPHA_DEFAULT
	}
	faded_color := style.background
	faded_color.a = scrollbar_alpha
	append(&c.cmds, Command_Rect{rect = scrollbar, color = faded_color, clip = w.clip})

	thumb_height := scrollbox_height * scrollbox_height / content_height
	thumb_height = math.max(thumb_height, scrollbar_width, 20)
	pct := -scrollbox.y_offset / (content_height - scrollbox_height)
	pct = math.clamp(pct, 0, 1)
	thumb := Rect {
		x = scrollbar.x,
		y = scrollbar.y + (pct * (scrollbox_height - thumb_height)),
		h = thumb_height,
		w = scrollbar.w,
	}
	thumb = rect_inset(thumb, 2)
	faded_color = color_contrast(style.background)
	faded_color.a = scrollbar_alpha
	append(&c.cmds, Command_Rect{rect = thumb, color = faded_color, clip = w.clip})
}
