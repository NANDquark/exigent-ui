#+build !js

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

test_layer_begin :: proc(
	c: ^Context,
	screen_width, screen_height: int,
	layout: Layout = {},
	caller := #caller_location,
	sub_id: int = 0,
) {
	layer_layout := layout
	if layer_layout == {} {
		layer_layout = layout_fixed(f32(screen_width), f32(screen_height))
	}
	begin(c, screen_width, screen_height)
	layer_begin(c, layer_layout, caller = caller, sub_id = sub_id)
}

test_layer_widget :: proc(c: ^Context, idx: int = 0) -> ^Widget {
	return c.layers[idx].root
}

test_same_callsite_button :: proc(c: ^Context, label: string, sub_id: int = 0) -> Widget_Interaction {
	return button(c, layout_fixed(20, 20), label, sub_id = sub_id)
}

test_expect_rect_command_order :: proc(t: ^testing.T, c: ^Context, colors: []Color) {
	idx := 0
	it := cmd_iterator_create(c)
	for cmd in cmd_iterator_next(&it) {
		switch v in cmd {
		case Command_Rect:
			if idx < len(colors) && v.color == colors[idx] {
				idx += 1
			}
		case Command_Text:
		case Command_Clip:
		case Command_Unclip:
		case Command_Sprite:
		}
	}

	testing.expect_value(t, idx, len(colors))
}

@(test)
test_widget_begin_requires_layer :: proc(t: ^testing.T) {
	testing.expect_assert(t, "widget_begin without layer_begin")
	c: Context
	container_begin(&c, layout_fixed(1, 1))
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
test_empty_frame_without_layers_emits_no_commands_and_captures_nothing :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {10, 10})
	begin(c, 200, 100)
	end(c)

	testing.expect_value(t, len(c.cmds), 0)
	testing.expect(t, !is_pointer_captured(c))
	free_all(c.temp_allocator)
}

@(test)
test_layers_emit_draw_commands_in_declaration_order :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	red := Color{255, 0, 0, 255}
	blue := Color{0, 0, 255, 255}

	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	container_begin(c, layout_fixed(10, 10), sub_id = 1)
	background(c, red)
	container_end(c)
	layer_end(c)
	layer_begin(c, layout_fixed(100, 100), sub_id = 2)
	container_begin(c, layout_fixed(10, 10), sub_id = 2)
	background(c, blue)
	container_end(c)
	layer_end(c)
	end(c)

	test_expect_rect_command_order(t, c, []Color{red, blue})
	free_all(c.temp_allocator)
}

@(test)
test_direct_children_in_different_layers_have_distinct_ids :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	_ = test_same_callsite_button(c, "A", sub_id = 1)
	layer_end(c)
	layer_begin(c, layout_fixed(100, 100), sub_id = 2)
	_ = test_same_callsite_button(c, "B", sub_id = 1)
	layer_end(c)
	end(c)

	lower_button := test_layer_widget(c, 0).children[0]
	upper_button := test_layer_widget(c, 1).children[0]
	testing.expect(t, lower_button.id != upper_button.id)
	free_all(c.temp_allocator)
}

@(test)
test_overlapping_widgets_pick_later_layer_first :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {5, 5})
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	button(c, layout_fixed(20, 20), "A", sub_id = 1)
	layer_end(c)
	layer_begin(c, layout_fixed(100, 100), sub_id = 2)
	button(c, layout_fixed(20, 20), "B", sub_id = 2)
	layer_end(c)
	end(c)

	top_button := test_layer_widget(c, 1).children[0]
	hovered, ok := c.hovered_widget_id.?
	testing.expect(t, ok)
	testing.expect_value(t, hovered, top_button.id)
	free_all(c.temp_allocator)
}

@(test)
test_empty_space_on_noncapturing_layer_passes_hover_to_lower_layer :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {5, 5})
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	button(c, layout_fixed(20, 20), "A", sub_id = 1)
	layer_end(c)
	layer_begin(c, layout_fixed(100, 100), sub_id = 2)
	layer_end(c)
	end(c)

	lower_button := test_layer_widget(c, 0).children[0]
	hovered, ok := c.hovered_widget_id.?
	testing.expect(t, ok)
	testing.expect_value(t, hovered, lower_button.id)
	testing.expect(t, is_pointer_captured(c))
	free_all(c.temp_allocator)
}

@(test)
test_empty_space_on_capturing_layer_blocks_lower_layer :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_input_mouse_pos(c, {5, 5})
	begin(c, 100, 100)
	layer_begin(c, layout_fixed(100, 100), sub_id = 1)
	button(c, layout_fixed(20, 20), "A", sub_id = 1)
	layer_end(c)
	layer_begin(c, layout_fixed(100, 100), Layer_Options{capture_pointer_empty = true}, sub_id = 2)
	layer_end(c)
	end(c)

	hovered, ok := c.hovered_widget_id.?
	testing.expect(t, ok)
	testing.expect_value(t, hovered, test_layer_widget(c, 1).id)
	testing.expect(t, is_pointer_captured(c))
	free_all(c.temp_allocator)
}

@(test)
test_layout_auto_column_uses_fixed_and_intrinsic_children :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(c, layout_auto(.Column), sub_id = 1)
	button(c, layout_fixed(30, 20), "A", sub_id = 1)
	label(c, "Wide", sub_id = 2)
	container_end(c)
	layer_end(c)
	end(c)

	container := test_layer_widget(c).children[0]
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

	test_layer_begin(c, 200, 100)
	container_begin(c, layout_auto(.Column), sub_id = 1)
	button(c, layout_fixed(30, 20), "A", sub_id = 1)
	container_end(c)
	layer_end(c)
	end(c)

	container := test_layer_widget(c).children[0]
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

	test_layer_begin(c, 200, 100)
	container_begin(
		c,
		layout_auto(.Column, padding = Inset{top = 3, right = 4, bottom = 5, left = 6}),
		sub_id = 1,
	)
	button(c, layout_fixed(10, 10), "A", sub_id = 1)
	container_end(c)
	layer_end(c)
	end(c)

	container := test_layer_widget(c).children[0]
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

	test_layer_begin(c, 200, 100)
	container_begin(c, layout_auto(.Column, gap = 7), sub_id = 1)
	label(c, "One", sub_id = 1)
	label(c, "Two", sub_id = 2)
	container_end(c)
	layer_end(c)
	end(c)

	container := test_layer_widget(c).children[0]
	first := container.children[0]
	second := container.children[1]

	testing.expect_value(t, container.rect, Rect{0, 0, 30, 35})
	testing.expect_value(t, first.rect, Rect{0, 0, 30, 14})
	testing.expect_value(t, second.rect, Rect{0, 21, 30, 14})
	free_all(c.temp_allocator)
}

@(test)
test_layer_accepts_layout :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100, layout_fixed(200, 100, .Column, .Center, .Center))
	label(c, "Layer Child", sub_id = 1)
	layer_end(c)
	end(c)

	child := test_layer_widget(c).children[0]
	testing.expect_value(t, child.rect, Rect{45, 43, 110, 14})
	free_all(c.temp_allocator)
}

@(test)
test_layout_row_aligns_children_on_main_and_cross_axes :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Row, .Center, .End), sub_id = 1)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	button(c, layout_fixed(30, 20), "B", sub_id = 2)
	container_end(c)
	layer_end(c)
	end(c)

	container := test_layer_widget(c).children[0]
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
	test_layer_begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Row, .Center, .End), sub_id = 1)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	button(c, layout_fixed(30, 20), "B", sub_id = 2)
	container_end(c)
	layer_end(c)
	end(c)

	second := test_layer_widget(c).children[0].children[1]
	hovered, ok := c.hovered_widget_id.?
	testing.expect(t, ok)
	testing.expect_value(t, hovered, second.id)
	free_all(c.temp_allocator)
}

@(test)
test_layout_commands_use_resolved_geometry :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(c, layout_fixed(100, 50, .Row, .Center, .End), sub_id = 1)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	container_end(c)
	layer_end(c)
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
test_anchored_container_bottom_center_defaults_pivot_to_anchor :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(
		c,
		layout_fixed(40, 20),
		Container_Options {
			positioning = .Anchored,
			anchor      = .Bottom_Center,
			offset      = {0, -5},
		},
	)
	container_end(c)
	layer_end(c)
	end(c)

	anchored := test_layer_widget(c).children[0]
	testing.expect_value(t, anchored.rect, Rect{80, 75, 40, 20})
	free_all(c.temp_allocator)
}

@(test)
test_anchored_container_center_and_top_right_origins :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(
		c,
		layout_fixed(40, 20),
		Container_Options{positioning = .Anchored, anchor = .Center},
		sub_id = 1,
	)
	container_end(c)
	container_begin(
		c,
		layout_fixed(30, 10),
		Container_Options {
			positioning = .Anchored,
			anchor      = .Top_Right,
			offset      = {-10, 5},
		},
		sub_id = 2,
	)
	container_end(c)
	layer_end(c)
	end(c)

	centered := test_layer_widget(c).children[0]
	top_right := test_layer_widget(c).children[1]
	testing.expect_value(t, centered.rect, Rect{80, 40, 40, 20})
	testing.expect_value(t, top_right.rect, Rect{160, 5, 30, 10})
	free_all(c.temp_allocator)
}

@(test)
test_anchored_container_explicit_pivot_changes_origin :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(
		c,
		layout_fixed(40, 20),
		Container_Options {
			positioning = .Anchored,
			anchor      = .Bottom_Center,
			pivot       = .Top_Left,
			offset      = {0, -20},
		},
	)
	container_end(c)
	layer_end(c)
	end(c)

	anchored := test_layer_widget(c).children[0]
	testing.expect_value(t, anchored.rect, Rect{100, 80, 40, 20})
	free_all(c.temp_allocator)
}

@(test)
test_anchored_container_does_not_affect_parent_flow_size_or_siblings :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(c, layout_auto(.Column, gap = 5), sub_id = 1)
	container_begin(c, layout_fixed(10, 10), sub_id = 1)
	container_end(c)
	container_begin(
		c,
		layout_fixed(100, 100),
		Container_Options{positioning = .Anchored, anchor = .Top_Left},
		sub_id = 2,
	)
	container_end(c)
	container_begin(c, layout_fixed(20, 10), sub_id = 3)
	container_end(c)
	container_end(c)
	layer_end(c)
	end(c)

	parent := test_layer_widget(c).children[0]
	first := parent.children[0]
	anchored := parent.children[1]
	second := parent.children[2]
	testing.expect_value(t, parent.rect, Rect{0, 0, 20, 25})
	testing.expect_value(t, first.rect, Rect{0, 0, 10, 10})
	testing.expect_value(t, anchored.rect, Rect{0, 0, 100, 100})
	testing.expect_value(t, second.rect, Rect{0, 15, 20, 10})
	free_all(c.temp_allocator)
}

@(test)
test_children_inside_anchored_container_use_normal_layout :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(
		c,
		layout_fixed(100, 50, .Row, .Center, .End),
		Container_Options{positioning = .Anchored, anchor = .Center},
		sub_id = 1,
	)
	button(c, layout_fixed(20, 10), "A", sub_id = 1)
	button(c, layout_fixed(30, 20), "B", sub_id = 2)
	container_end(c)
	layer_end(c)
	end(c)

	anchored := test_layer_widget(c).children[0]
	first := anchored.children[0]
	second := anchored.children[1]
	testing.expect_value(t, anchored.rect, Rect{50, 25, 100, 50})
	testing.expect_value(t, first.rect, Rect{74, 64, 20, 10})
	testing.expect_value(t, second.rect, Rect{96, 54, 30, 20})
	free_all(c.temp_allocator)
}

@(test)
test_anchored_container_is_clipped_to_parent :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	container_begin(
		c,
		layout_fixed(40, 20),
		Container_Options {
			positioning = .Anchored,
			anchor      = .Top_Right,
			offset      = {10, 0},
		},
	)
	container_end(c)
	layer_end(c)
	end(c)

	anchored := test_layer_widget(c).children[0]
	testing.expect_value(t, anchored.rect, Rect{170, 0, 40, 20})
	testing.expect_value(t, anchored.clip, Rect{170, 0, 30, 20})
	free_all(c.temp_allocator)
}

@(test)
test_repeated_anchored_containers_keep_distinct_sub_ids :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	test_layer_begin(c, 200, 100)
	for i in 0 ..< 2 {
		container_begin(
			c,
			layout_fixed(10, 10),
			Container_Options{positioning = .Anchored, anchor = .Top_Left, offset = {f32(i * 10), 0}},
			sub_id = i,
		)
		container_end(c)
	}
	layer_end(c)
	end(c)

	first := test_layer_widget(c).children[0]
	second := test_layer_widget(c).children[1]
	testing.expect(t, first.id != second.id)
	testing.expect_value(t, first.rect, Rect{0, 0, 10, 10})
	testing.expect_value(t, second.rect, Rect{10, 0, 10, 10})
	free_all(c.temp_allocator)
}

// @(test)
// test_custom_widget_type_can_emit_deferred_draw_commands :: proc(t: ^testing.T) {
// 	c := test_layout_context_create()
// 	defer fixture_context_delete(c)

// 	Custom_Widget_Type := widget_register(Widget_Style{})
// 	color := Color{1, 2, 3, 255}

// 	test_layer_begin(c, 200, 100)
// 	container_begin(c, layout_fixed(100, 50, .Column, .Center, .Center), sub_id = 1)
// 	widget_begin(c, Custom_Widget_Type, layout_fixed(30, 20), runtime.Source_Code_Location{}, 1)
// 	rect(c, Rect{5, 6, 10, 11}, color)
// 	widget_end(c)
// 	container_end(c)
// 	layer_end(c)
// 	end(c)

// 	found_custom_rect := false
// 	expected := Rect{40, 21, 10, 11}
// 	it := cmd_iterator_create(c)
// 	for cmd in cmd_iterator_next(&it) {
// 		switch v in cmd {
// 		case Command_Rect:
// 			if v.rect == expected && v.color == color {
// 				found_custom_rect = true
// 			}
// 		case Command_Text:
// 		case Command_Clip:
// 		case Command_Unclip:
// 		case Command_Sprite:
// 		}
// 	}

// 	testing.expect(t, found_custom_rect)
// 	free_all(c.temp_allocator)
// }


@(test)
test_layout_scrollbox_offsets_overflow_and_emits_scrollbar :: proc(t: ^testing.T) {
	c := test_layout_context_create()
	defer fixture_context_delete(c)

	sb := Scrollbox{}
	test_input_mouse_pos(c, [2]f32{10, 10})
	test_input_scroll(c, -1)

	test_layer_begin(c, 200, 120)
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
	layer_end(c)
	end(c)

	scrollbox := test_layer_widget(c).children[0]
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

	test_layer_begin(c, 200, 120)
	scrollbox_begin(
		c,
		layout_fixed(100, 100, .Column, padding = Inset{top = 10, bottom = 10}),
		&sb,
	)
	container_begin(c, layout_fixed(100, 90, .Column, .Center, .Center), sub_id = 1)
	label(c, "One", sub_id = 1)
	container_end(c)
	scrollbox_end(c)
	layer_end(c)
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

	test_layer_begin(c, 200, 120)
	scrollbox_begin(c, layout_fixed(100, 100, .Column), &sb)
	scrollbox_end(c)
	layer_end(c)
	end(c)

	testing.expect_value(t, sb._w, nil)
	free_all(c.temp_allocator)
}
