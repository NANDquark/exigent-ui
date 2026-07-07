package karl2d_exigent

import ui "exigent:."
import k2 "karl2d:."
import "core:testing"

@(test)
test_rect_and_color_conversion :: proc(t: ^testing.T) {
	r := ui.Rect{x = 3, y = 5, w = 7, h = 11}
	c := ui.Color{13, 17, 19, 23}

	testing.expect_value(t, to_k2_rect(r), k2.Rect{3, 5, 7, 11})
	testing.expect_value(t, to_k2_color(c), k2.Color{13, 17, 19, 23})
}

@(test)
test_scissor_rect_rounds_fractional_bounds_outward :: proc(t: ^testing.T) {
	r := ui.Rect{x = 471.6, y = 274.95, w = 42.8, h = 16.1}

	testing.expect_value(t, scissor_rect(r), k2.Rect{x = 471, y = 274, w = 44, h = 18})
}

@(test)
test_sprite_source_rect_converts_normalized_uvs_to_pixels :: proc(t: ^testing.T) {
	sprite := ui.Sprite {
		texture = ui.Texture_Handle(7),
		uv      = ui.Rect{x = 0.25, y = 0.5, w = 0.125, h = 0.25},
		width   = 20,
		height  = 10,
	}
	texture := k2.Texture{width = 160, height = 80}

	source := sprite_source_rect(sprite, texture)

	testing.expect_value(t, source, k2.Rect{x = 40, y = 40, w = 20, h = 20})
}

@(test)
test_register_texture_assigns_stable_unique_handles :: proc(t: ^testing.T) {
	renderer: Renderer
	init(&renderer, context.allocator)
	defer destroy(&renderer)

	first_texture := k2.Texture{width = 12, height = 34}
	second_texture := k2.Texture{width = 56, height = 78}

	first := register_texture(&renderer, first_texture)
	second := register_texture(&renderer, second_texture)

	testing.expect(t, first != second)
	testing.expect_value(t, renderer.textures[first], first_texture)
	testing.expect_value(t, renderer.textures[second], second_texture)
}

@(test)
test_mouse_button_mapping :: proc(t: ^testing.T) {
	testing.expect_value(t, k2_mouse_button_to_ui(.Left), ui.Mouse_Button.Left)
	testing.expect_value(t, k2_mouse_button_to_ui(.Right), ui.Mouse_Button.Right)
	testing.expect_value(t, k2_mouse_button_to_ui(.Middle), ui.Mouse_Button.Middle)
}

@(test)
test_key_mapping_for_common_keys :: proc(t: ^testing.T) {
	testing.expect_value(t, k2_key_to_ui(.A), ui.Key.A)
	testing.expect_value(t, k2_key_to_ui(.N0), ui.Key.Zero)
	testing.expect_value(t, k2_key_to_ui(.Escape), ui.Key.Escape)
	testing.expect_value(t, k2_key_to_ui(.Left_Control), ui.Key.LCtrl)
	testing.expect_value(t, k2_key_to_ui(.Right_Shift), ui.Key.RShift)
	testing.expect_value(t, k2_key_to_ui(.NP_Decimal), ui.Key.KP_Decimal)
	testing.expect_value(t, k2_key_to_ui(.NP_Equal), ui.Key.None)
}

@(test)
test_ui_key_to_k2_mapping_for_held_state :: proc(t: ^testing.T) {
	testing.expect_value(t, ui_key_to_k2(.A), k2.Keyboard_Key.A)
	testing.expect_value(t, ui_key_to_k2(.Zero), k2.Keyboard_Key.N0)
	testing.expect_value(t, ui_key_to_k2(.Escape), k2.Keyboard_Key.Escape)
	testing.expect_value(t, ui_key_to_k2(.LCtrl), k2.Keyboard_Key.Left_Control)
	testing.expect_value(t, ui_key_to_k2(.RShift), k2.Keyboard_Key.Right_Shift)
	testing.expect_value(t, ui_key_to_k2(.KP_Decimal), k2.Keyboard_Key.NP_Decimal)
	testing.expect_value(t, ui_key_to_k2(.MediaPlay), k2.Keyboard_Key.None)
}
