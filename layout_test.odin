package exigent

import "base:runtime"
import "core:testing"

test_layout_context_create :: proc() -> ^Context {
	c := fixture_context_create()
	theme := theme_light(nil)
	theme.font.size_md = 12
	theme.font.size_lg = 18
	theme.font.line_scale = 14.0 / 12.0
	theme_set(c, theme)
	return c
}

@(test)
test_text_style_role_selects_theme_tokens :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	style := text_style(c, .Section)
	testing.expect_value(t, style.size, f32(18))
	testing.expect_value(t, style.line_height, f32(21))
	testing.expect_value(t, style.color, c.theme.color.fg)
}

@(test)
test_layout_auto_column_uses_fixed_and_intrinsic_children :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100)
	container_begin(c, layout_auto(.Column), sub_id = 1)
	button(c, layout_fixed(30, 20), "A", sub_id = 1)
	label(c, "Wide", sub_id = 2)
	container_end(c)
	end(c)

	container := c.widget_root.children[0]
	button_w := container.children[0]
	label_w := container.children[1]

	testing.expect_value(t, container.rect, Rect{0, 0, 40, 36})
	testing.expect_value(t, button_w.rect, Rect{1, 1, 30, 20})
	testing.expect_value(t, label_w.rect, Rect{0, 22, 40, 14})
	free_all(c.temp_allocator)
}

@(test)
test_layout_parent_reserves_child_border_footprint :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100)
	container_begin(c, layout_auto(.Column), sub_id = 1)
	button(c, layout_fixed(30, 20), "A", sub_id = 1)
	container_end(c)
	end(c)

	container := c.widget_root.children[0]
	button_w := container.children[0]

	testing.expect_value(t, container.rect, Rect{0, 0, 32, 22})
	testing.expect_value(t, button_w.rect, Rect{1, 1, 30, 20})
	testing.expect_value(t, button_w.clip, Rect{0, 0, 32, 22})
	free_all(c.temp_allocator)
}

@(test)
test_layout_padding_adds_space_around_children :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100)
	container_begin(
		c,
		layout_auto(.Column, padding = Inset{top = 3, right = 4, bottom = 5, left = 6}),
		sub_id = 1,
	)
	button(c, layout_fixed(10, 10), "A", sub_id = 1)
	container_end(c)
	end(c)

	container := c.widget_root.children[0]
	button_w := container.children[0]

	testing.expect_value(t, container.rect, Rect{0, 0, 22, 20})
	testing.expect_value(t, button_w.rect, Rect{7, 4, 10, 10})
	testing.expect_value(t, button_w.clip, Rect{6, 3, 12, 12})
	free_all(c.temp_allocator)
}

@(test)
test_layout_gap_adds_space_between_children :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100)
	container_begin(c, layout_auto(.Column, gap = 7), sub_id = 1)
	label(c, "One", sub_id = 1)
	label(c, "Two", sub_id = 2)
	container_end(c)
	end(c)

	container := c.widget_root.children[0]
	first := container.children[0]
	second := container.children[1]

	testing.expect_value(t, container.rect, Rect{0, 0, 30, 35})
	testing.expect_value(t, first.rect, Rect{0, 0, 30, 14})
	testing.expect_value(t, second.rect, Rect{0, 21, 30, 14})
	free_all(c.temp_allocator)
}

@(test)
test_begin_accepts_root_layout :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100, layout_fixed(200, 100, .Column, .Center, .Center))
	label(c, "Root Child", sub_id = 1)
	end(c)

	child := c.widget_root.children[0]
	testing.expect_value(t, child.rect, Rect{50, 43, 100, 14})
	free_all(c.temp_allocator)
}

@(test)
test_layout_row_aligns_children_on_main_and_cross_axes :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Row, .Center, .End), sub_id = 1)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	button(c, layout_fixed(30, 20), "B", sub_id = 2)
	container_end(c)
	end(c)

	container := c.widget_root.children[0]
	first := container.children[0]
	second := container.children[1]

	testing.expect_value(t, container.rect, Rect{0, 0, 100, 50})
	testing.expect_value(t, first.rect, Rect{24, 39, 20, 10})
	testing.expect_value(t, second.rect, Rect{46, 29, 30, 20})
	free_all(c.temp_allocator)
}

@(test)
test_layout_picking_uses_final_laid_out_rects :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, [2]f32{46, 31})
	begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Row, .Center, .End), sub_id = 1)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	button(c, layout_fixed(30, 20), "B", sub_id = 2)
	container_end(c)
	end(c)

	second := c.widget_root.children[0].children[1]
	hovered, ok := c.hovered_widget_id.?
	testing.expect(t, ok)
	testing.expect_value(t, hovered, second.id)
	free_all(c.temp_allocator)
}

@(test)
test_layout_commands_use_resolved_geometry :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Row, .Center, .End), sub_id = 1)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	container_end(c)
	end(c)

	found_button_rect := false
	expected := Rect{40, 39, 20, 10}
	it := cmd_iterator_create(c)
	for cmd in cmd_iterator_next(&it) {
		switch v in cmd {
		case Command_Rect:
			if v.rect == expected {
				found_button_rect = true
			}
		case Command_Text:
		case Command_Clip:
		case Command_Unclip:
		case Command_Sprite:
		}
	}

	testing.expect(t, found_button_rect)
	free_all(c.temp_allocator)
}

@(test)
test_custom_widget_type_can_emit_deferred_draw_commands :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	Custom_Widget_Type := widget_register(Widget_Style{})
	color := Color{1, 2, 3, 255}

	begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Column, .Center, .Center), sub_id = 1)
	widget_begin(c, Custom_Widget_Type, layout_fixed(30, 20), runtime.Source_Code_Location{}, 1)
	rect(c, Rect{5, 6, 10, 11}, color)
	widget_end(c)
	container_end(c)
	end(c)

	found_custom_rect := false
	expected := Rect{40, 21, 10, 11}
	it := cmd_iterator_create(c)
	for cmd in cmd_iterator_next(&it) {
		switch v in cmd {
		case Command_Rect:
			if v.rect == expected && v.color == color {
				found_custom_rect = true
			}
		case Command_Text:
		case Command_Clip:
		case Command_Unclip:
		case Command_Sprite:
		}
	}

	testing.expect(t, found_custom_rect)
	free_all(c.temp_allocator)
}


@(test)
test_layout_scrollbox_offsets_overflow_and_emits_scrollbar :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	sb := Scrollbox{}
	test_input_mouse_pos(c, [2]f32{10, 10})
	test_input_scroll(c, -1)

	begin(c, 200, 120)
	scrollbox_begin(c, layout_fixed(100, 100, .Column), &sb)
	container_begin(c, layout_fixed(100, 50, .Column, .Center, .Center), sub_id = 1)
	label(c, "One", sub_id = 1)
	container_end(c)
	container_begin(c, layout_fixed(100, 50, .Column, .Center, .Center), sub_id = 2)
	label(c, "Two", sub_id = 2)
	container_end(c)
	container_begin(c, layout_fixed(100, 50, .Column, .Center, .Center), sub_id = 3)
	label(c, "Three", sub_id = 3)
	container_end(c)
	scrollbox_end(c)
	end(c)

	scrollbox := c.widget_root.children[0]
	first_row := scrollbox.children[0]
	testing.expect_value(t, sb.y_offset, f32(-20))
	testing.expect_value(t, first_row.rect, Rect{1, -19, 100, 50})

	found_track := false
	expected_track := Rect{85, 1, 16, 100}
	it := cmd_iterator_create(c)
	for cmd in cmd_iterator_next(&it) {
		switch v in cmd {
		case Command_Rect:
			if v.rect == expected_track {
				found_track = true
			}
		case Command_Text:
		case Command_Clip:
		case Command_Unclip:
		case Command_Sprite:
		}
	}

	testing.expect(t, found_track)
	free_all(c.temp_allocator)
}

@(test)
test_scrollbox_scrollbar_uses_padded_viewport :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	sb := Scrollbox{}

	begin(c, 200, 120)
	scrollbox_begin(
		c,
		layout_fixed(100, 100, .Column, padding = Inset{top = 10, bottom = 10}),
		&sb,
	)
	container_begin(c, layout_fixed(100, 90, .Column, .Center, .Center), sub_id = 1)
	label(c, "One", sub_id = 1)
	container_end(c)
	scrollbox_end(c)
	end(c)

	found_track := false
	expected_track := Rect{85, 1, 16, 100}
	it := cmd_iterator_create(c)
	for cmd in cmd_iterator_next(&it) {
		switch v in cmd {
		case Command_Rect:
			if v.rect == expected_track {
				found_track = true
			}
		case Command_Text:
		case Command_Clip:
		case Command_Unclip:
		case Command_Sprite:
		}
	}

	testing.expect(t, found_track)
	free_all(c.temp_allocator)
}

@(test)
test_scrollbox_end_clears_frame_widget_pointer :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	sb := Scrollbox{}

	begin(c, 200, 120)
	scrollbox_begin(c, layout_fixed(100, 100, .Column), &sb)
	scrollbox_end(c)
	end(c)

	testing.expect_value(t, sb._w, nil)
	free_all(c.temp_allocator)
}
