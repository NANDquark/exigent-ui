package raylib_exigent

import ui "../"
import "core:testing"
import rl "vendor:raylib"

@(test)
test_rect_and_color_conversion :: proc(t: ^testing.T) {
	r := ui.Rect {
		x = 3,
		y = 5,
		w = 7,
		h = 11,
	}
	c := ui.Color{13, 17, 19, 23}

	testing.expect_value(t, to_rl_rect(r), rl.Rectangle{x = 3, y = 5, width = 7, height = 11})
	testing.expect_value(t, to_rl_color(c), rl.Color{13, 17, 19, 23})
}

@(test)
test_scissor_rect_rounds_fractional_bounds_outward :: proc(t: ^testing.T) {
	r := ui.Rect {
		x = 471.6,
		y = 274.95,
		w = 42.8,
		h = 16.1,
	}

	testing.expect_value(
		t,
		scissor_rect(r),
		rl.Rectangle{x = 471, y = 274, width = 44, height = 18},
	)
}

@(test)
test_rect_intersect_clamps_to_non_negative_extent :: proc(t: ^testing.T) {
	a := rl.Rectangle {
		x      = 10,
		y      = 20,
		width  = 100,
		height = 50,
	}
	b := rl.Rectangle {
		x      = 40,
		y      = 10,
		width  = 20,
		height = 30,
	}
	c := rl.Rectangle {
		x      = 200,
		y      = 200,
		width  = 20,
		height = 20,
	}

	testing.expect_value(
		t,
		rect_intersect_rl(a, b),
		rl.Rectangle{x = 40, y = 20, width = 20, height = 20},
	)
	testing.expect_value(
		t,
		rect_intersect_rl(a, c),
		rl.Rectangle{x = 200, y = 200, width = 0, height = 0},
	)
}

@(test)
test_sprite_source_rect_converts_normalized_uvs_to_pixels :: proc(t: ^testing.T) {
	sprite := ui.Sprite {
		texture = ui.Texture_Handle(7),
		uv = ui.Rect{x = 0.25, y = 0.5, w = 0.125, h = 0.25},
		width = 20,
		height = 10,
	}
	texture := rl.Texture2D {
		width  = 160,
		height = 80,
	}

	source := sprite_source_rect(sprite, texture)

	testing.expect_value(t, source, rl.Rectangle{x = 40, y = 40, width = 20, height = 20})
}

@(test)
test_registered_texture_region_becomes_normalized_sprite :: proc(t: ^testing.T) {
	texture := rl.Texture2D {
		width  = 160,
		height = 80,
	}
	sprite := sprite_from_registered_texture(
		ui.Texture_Handle(3),
		texture,
		ui.Rect{x = 40, y = 20, w = 32, h = 16},
	)

	testing.expect_value(t, sprite.texture, ui.Texture_Handle(3))
	testing.expect_value(t, sprite.uv, ui.Rect{x = 0.25, y = 0.25, w = 0.2, h = 0.2})
	testing.expect_value(t, sprite.width, 32)
	testing.expect_value(t, sprite.height, 16)
}

@(test)
test_register_texture_assigns_stable_unique_handles :: proc(t: ^testing.T) {
	renderer: Renderer
	init(&renderer, context.allocator)
	defer destroy(&renderer)

	first_texture := rl.Texture2D {
		width  = 12,
		height = 34,
	}
	second_texture := rl.Texture2D {
		width  = 56,
		height = 78,
	}

	first := register_texture(&renderer, first_texture)
	second := register_texture(&renderer, second_texture)

	testing.expect(t, first != second)
	testing.expect_value(t, renderer.textures[first], first_texture)
	testing.expect_value(t, renderer.textures[second], second_texture)
}

@(test)
test_mouse_button_mapping :: proc(t: ^testing.T) {
	testing.expect_value(t, rl_mouse_button_to_ui(.LEFT), ui.Mouse_Button.Left)
	testing.expect_value(t, rl_mouse_button_to_ui(.RIGHT), ui.Mouse_Button.Right)
	testing.expect_value(t, rl_mouse_button_to_ui(.MIDDLE), ui.Mouse_Button.Middle)
}

@(test)
test_key_mapping_for_common_keys :: proc(t: ^testing.T) {
	testing.expect_value(t, rl_key_to_ui(.A), ui.Key.A)
	testing.expect_value(t, rl_key_to_ui(.ZERO), ui.Key.Zero)
	testing.expect_value(t, rl_key_to_ui(.ESCAPE), ui.Key.Escape)
	testing.expect_value(t, rl_key_to_ui(.LEFT_CONTROL), ui.Key.LCtrl)
	testing.expect_value(t, rl_key_to_ui(.RIGHT_SHIFT), ui.Key.RShift)
	testing.expect_value(t, rl_key_to_ui(.KP_DECIMAL), ui.Key.KP_Decimal)
	testing.expect_value(t, rl_key_to_ui(.KP_EQUAL), ui.Key.None)
}

@(test)
test_ui_key_to_rl_mapping_for_held_state :: proc(t: ^testing.T) {
	testing.expect_value(t, ui_key_to_rl(.A), rl.KeyboardKey.A)
	testing.expect_value(t, ui_key_to_rl(.Zero), rl.KeyboardKey.ZERO)
	testing.expect_value(t, ui_key_to_rl(.Escape), rl.KeyboardKey.ESCAPE)
	testing.expect_value(t, ui_key_to_rl(.LCtrl), rl.KeyboardKey.LEFT_CONTROL)
	testing.expect_value(t, ui_key_to_rl(.RShift), rl.KeyboardKey.RIGHT_SHIFT)
	testing.expect_value(t, ui_key_to_rl(.KP_Decimal), rl.KeyboardKey.KP_DECIMAL)
	testing.expect_value(t, ui_key_to_rl(.MediaPlay), rl.KeyboardKey.KEY_NULL)
}
